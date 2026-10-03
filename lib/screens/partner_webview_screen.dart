import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme.dart';

/// Ouvre un site partenaire (Booking.com, Aviasales, Tiqets…) dans Voyagooo.
/// Renvoie `true` quand le voyageur indique avoir réservé.
Future<bool> openPartnerPage(BuildContext context, {required String url, required String title}) async {
  final booked = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => PartnerWebViewScreen(url: url, title: title), fullscreenDialog: true),
  );
  return booked == true;
}

class PartnerWebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const PartnerWebViewScreen({super.key, required this.url, required this.title});

  @override
  State<PartnerWebViewScreen> createState() => _PartnerWebViewScreenState();
}

class _PartnerWebViewScreenState extends State<PartnerWebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  String _host = '';
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _host = Uri.tryParse(widget.url)?.host ?? '';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
        onPageStarted: (url) {
          if (mounted) setState(() => _host = Uri.tryParse(url)?.host ?? _host);
        },
        onWebResourceError: (error) {
          // Seule une erreur sur la page principale empêche la réservation
          if (error.isForMainFrame == true && mounted) setState(() => _failed = true);
        },
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);
          if (uri == null) return NavigationDecision.prevent;
          if (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'about' || uri.scheme == 'data') {
            return NavigationDecision.navigate;
          }
          // Liens vers une app (paiement, téléphone, e-mail, store) : ouverts par le système
          launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
          return NavigationDecision.prevent;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _back() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else if (mounted) {
      Navigator.of(context).pop(false);
    }
  }

  Future<void> _openExternally() async {
    final current = await _controller.currentUrl() ?? widget.url;
    await launchUrl(Uri.parse(current), mode: LaunchMode.externalApplication);
  }

  void _retry() {
    setState(() => _failed = false);
    _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: VoyagoColors.background,
        appBar: AppBar(
          backgroundColor: VoyagoColors.surface,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 0,
          leading: IconButton(
            tooltip: 'Fermer',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: VoyagoColors.text, fontSize: 16, fontWeight: FontWeight.w800)),
              Row(
                children: [
                  const Icon(Icons.lock_rounded, size: 11, color: VoyagoColors.primary),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(_host,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: VoyagoColors.muted, fontSize: 11.5)),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(tooltip: 'Page précédente', icon: const Icon(Icons.arrow_back_rounded), onPressed: _back),
            PopupMenuButton<String>(
              color: VoyagoColors.surface,
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) {
                if (v == 'reload') _controller.reload();
                if (v == 'external') _openExternally();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'reload', child: Text('Actualiser')),
                PopupMenuItem(value: 'external', child: Text('Ouvrir dans le navigateur')),
              ],
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: AnimatedOpacity(
              opacity: _progress < 100 ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: LinearProgressIndicator(
                value: _progress == 0 ? null : _progress / 100,
                minHeight: 3,
                color: VoyagoColors.primary,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        ),
        body: _failed
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 52, color: VoyagoColors.muted),
                      const SizedBox(height: 12),
                      const Text('La page ne répond pas. Vérifie ta connexion.',
                          textAlign: TextAlign.center, style: TextStyle(color: VoyagoColors.text, fontSize: 15)),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _retry, child: const Text('Réessayer')),
                    ],
                  ),
                ),
              )
            : WebViewWidget(controller: _controller),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: VoyagoColors.surface,
            border: Border(top: BorderSide(color: VoyagoColors.cardBorder)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Réservation confirmée ? Ajoute-la à ton budget.',
                      style: TextStyle(color: VoyagoColors.muted, fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.of(context).pop(true);
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text("J'ai réservé"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
