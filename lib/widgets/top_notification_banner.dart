import 'dart:async';
import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../theme.dart';

/// Icône et couleur d'une notification selon son type (cloche, bandeau, push).
(IconData, Color) notificationStyle(String type) => switch (type) {
      'arrival' => (Icons.place_rounded, VoyagoColors.primary),
      'trip_ready' => (Icons.flight_takeoff_rounded, VoyagoColors.blue),
      'comment' => (Icons.mode_comment_rounded, VoyagoColors.primary),
      'trip_remixed' => (Icons.explore_rounded, VoyagoColors.yellow),
      'tribe_trip' => (Icons.groups_rounded, VoyagoColors.primary),
      'circle_request' => (Icons.lock_person_rounded, VoyagoColors.yellow),
      'price_drop' => (Icons.trending_down_rounded, VoyagoColors.primary),
      'plan_b' => (Icons.umbrella_rounded, VoyagoColors.blue),
      'review_thanks' => (Icons.star_rounded, VoyagoColors.yellow),
      _ => (Icons.notifications_active_rounded, VoyagoColors.orange),
    };

/// Bandeau façon notification native, qui glisse depuis le haut de l'écran.
/// Toucher : ouvre. Glisser vers le haut : ferme. Plusieurs d'affilée : regroupées.
class TopNotificationBanner {
  TopNotificationBanner._();

  static OverlayEntry? _entry;
  static final _state = ValueNotifier<_BannerData?>(null);
  static Timer? _timer;

  static void show(OverlayState overlay, AppNotification n, {VoidCallback? onOpen}) {
    final current = _state.value;
    // Déjà affiché : on regroupe (« 3 nouvelles notifications ») en gardant la plus récente
    _state.value = _BannerData(n, onOpen, current == null ? 1 : current.count + 1);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 5), hide);
    if (_entry != null) return;
    _entry = OverlayEntry(builder: (_) => _BannerHost(state: _state, onDismiss: hide));
    overlay.insert(_entry!);
  }

  static void hide() {
    _timer?.cancel();
    _state.value = null;
    // Laisse l'animation de sortie se jouer
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (_state.value != null) return;
      _entry?.remove();
      _entry = null;
    });
  }
}

class _BannerData {
  final AppNotification n;
  final VoidCallback? onOpen;
  final int count;
  const _BannerData(this.n, this.onOpen, this.count);
}

class _BannerHost extends StatelessWidget {
  final ValueNotifier<_BannerData?> state;
  final VoidCallback onDismiss;
  const _BannerHost({required this.state, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return ValueListenableBuilder<_BannerData?>(
      valueListenable: state,
      builder: (context, data, _) {
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          left: 10,
          right: 10,
          top: data == null ? -160 : top + 8,
          child: data == null ? const SizedBox.shrink() : _BannerCard(data: data, onDismiss: onDismiss),
        );
      },
    );
  }
}

class _BannerCard extends StatelessWidget {
  final _BannerData data;
  final VoidCallback onDismiss;
  const _BannerCard({required this.data, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final n = data.n;
    final (icon, color) = notificationStyle(n.type);
    final image = n.data['image_url']?.toString();
    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) < -100) onDismiss();
      },
      onTap: () {
        onDismiss();
        data.onOpen?.call();
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: VoyagoColors.surface.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.45)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Image.asset('assets/logo/logo.png', width: 16, height: 16, errorBuilder: (_, __, ___) => const Text('🦜', style: TextStyle(fontSize: 12))),
                  const SizedBox(width: 6),
                  const Text('VOYAGOOO',
                      style: TextStyle(color: VoyagoColors.muted, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                  const Text(' · maintenant', style: TextStyle(color: VoyagoColors.muted, fontSize: 10.5)),
                  const Spacer(),
                  if (data.count > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(color: VoyagoColors.coral, borderRadius: BorderRadius.circular(10)),
                      child: Text('${data.count} nouvelles',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: VoyagoColors.text, fontSize: 14, fontWeight: FontWeight.w800)),
                        if (n.body.isNotEmpty)
                          Text(n.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: VoyagoColors.muted, fontSize: 12.5, height: 1.3)),
                      ],
                    ),
                  ),
                  if (image != null && image.startsWith('http')) ...[
                    const SizedBox(width: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(image, width: 44, height: 44, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                    ),
                  ],
                ],
              ),
              if (data.onOpen != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(n.type == 'plan_b' ? 'Basculer à l’abri ›' : 'Voir ›',
                      style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w800)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
