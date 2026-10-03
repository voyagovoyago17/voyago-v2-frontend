import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/dio_client.dart';
import '../api/endpoints.dart';
import '../models/app_notification.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import '../router.dart';
import '../widgets/notification_actions.dart';
import '../widgets/top_notification_banner.dart';
import 'app_sounds.dart';

/// Affichage d'une notification reçue app ouverte : bandeau en haut, son signature, cloche à jour.
/// Le flux temps réel et FCM peuvent livrer la même notification : elle n'est montrée qu'une fois.
class InAppNotifications {
  InAppNotifications._();
  static final InAppNotifications instance = InAppNotifications._();

  final _seen = <String>[];

  /// Nouvelle notification arrivée (cloche qui s'anime)
  final ValueNotifier<int> pulse = ValueNotifier(0);

  bool _alreadySeen(String id) {
    if (id.isEmpty) return false;
    if (_seen.contains(id)) return true;
    _seen.add(id);
    if (_seen.length > 60) _seen.removeAt(0);
    return false;
  }

  void present(Ref ref, AppNotification n, {required bool sound, bool vibrate = true}) {
    if (n.title.isEmpty || _alreadySeen(n.id)) return;
    ref.read(notificationsProvider.notifier).refresh();
    pulse.value++;
    AppSounds.instance.notification(sound: sound, vibrate: vibrate);
    final navigator = ref.read(routerProvider).routerDelegate.navigatorKey.currentState;
    final overlay = navigator?.overlay;
    if (overlay == null) return;
    TopNotificationBanner.show(
      overlay,
      n,
      onOpen: canOpenNotification(n)
          ? () {
              ref.read(notificationsProvider.notifier).markRead(n);
              final context = navigator?.context;
              if (context != null && context.mounted) openNotificationTarget(context, n);
            }
          : null,
    );
  }
}

/// Flux temps réel (SSE) : tant que l'app est ouverte et la session active, chaque
/// notification arrive à la seconde. Reconnexion automatique, coupé en arrière-plan.
class _LiveStream with WidgetsBindingObserver {
  final Ref ref;
  CancelToken? _cancel;
  Timer? _retry;
  int _failures = 0;
  bool _foreground = true;
  bool _loggedIn = false;

  _LiveStream(this.ref) {
    WidgetsBinding.instance.addObserver(this);
  }

  void setLoggedIn(bool value) {
    _loggedIn = value;
    _restart();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      // De retour dans l'app : la cloche rattrape ce qui est arrivé entre-temps
      if (_loggedIn) ref.read(notificationsProvider.notifier).refresh();
      _restart();
    } else if (state == AppLifecycleState.paused) {
      _stop();
    }
  }

  void _stop() {
    _retry?.cancel();
    _cancel?.cancel();
    _cancel = null;
  }

  void _restart() {
    _stop();
    if (_loggedIn && _foreground) _connect();
  }

  void _scheduleRetry() {
    if (!_loggedIn || !_foreground) return;
    _failures++;
    final seconds = [2, 5, 10, 30, 60][(_failures - 1).clamp(0, 4)];
    _retry?.cancel();
    _retry = Timer(Duration(seconds: seconds), _connect);
  }

  Future<void> _connect() async {
    final cancel = _cancel = CancelToken();
    try {
      final body = await DioClient.instance.get(
        '${Endpoints.notifications}/stream',
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          // Un battement arrive toutes les 25 s : au-delà, la connexion est morte
          receiveTimeout: const Duration(seconds: 70),
          headers: {'Accept': 'text/event-stream', 'Cache-Control': 'no-cache'},
        ),
      ) as ResponseBody;
      _failures = 0;
      String? event;
      final data = StringBuffer();
      await for (final line in body.stream.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.isEmpty) {
          if (event == 'notification' && data.isNotEmpty) _onNotification(data.toString());
          event = null;
          data.clear();
        } else if (line.startsWith('event:')) {
          event = line.substring(6).trim();
        } else if (line.startsWith('data:')) {
          data.write(line.substring(5).trim());
        }
      }
      // Fin du flux côté serveur : on se reconnecte
      if (!cancel.isCancelled) _scheduleRetry();
    } catch (e) {
      if (cancel.isCancelled) return;
      debugPrint('Flux temps réel interrompu : $e');
      _scheduleRetry();
    }
  }

  void _onNotification(String raw) {
    try {
      final json = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final n = AppNotification.fromJson(json);
      InAppNotifications.instance.present(ref, n, sound: json['sound'] != false, vibrate: json['vibrate'] != false);
    } catch (e) {
      debugPrint('Notification temps réel illisible : $e');
    }
  }

  void dispose() {
    _stop();
    WidgetsBinding.instance.removeObserver(this);
  }
}

/// À regarder une fois depuis la racine de l'app.
final liveNotificationsProvider = Provider<void>((ref) {
  if (kIsWeb) return;
  AppSounds.instance.warmUp();
  final live = _LiveStream(ref);
  ref.listen<bool>(isAuthenticatedProvider, (_, loggedIn) => live.setLoggedIn(loggedIn), fireImmediately: true);
  ref.onDispose(live.dispose);
});
