import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/app_notification.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import '../theme.dart';
import 'place_review_sheet.dart';
import 'community/comments_sheet.dart';

/// Cloche de notifications avec badge du nombre de non lues.
class NotificationBell extends ConsumerWidget {
  final Color iconColor;
  final double size;

  const NotificationBell({super.key, this.iconColor = VoyagoColors.muted, this.size = 22});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(notificationsProvider.select((s) => s.unreadCount));

    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => _open(context, ref),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            unread > 0 ? Icons.notifications_active_rounded : Icons.notifications_none,
            color: unread > 0 ? VoyagoColors.text : iconColor,
            size: size,
          ),
          if (unread > 0)
            Positioned(
              right: -5,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                constraints: const BoxConstraints(minWidth: 17),
                decoration: BoxDecoration(
                  color: VoyagoColors.coral,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: VoyagoColors.surface, width: 1.5),
                ),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _open(BuildContext context, WidgetRef ref) {
    if (!ref.read(isAuthenticatedProvider)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: const Text('Connecte-toi pour recevoir tes notifications de voyage'),
          action: SnackBarAction(label: 'Connexion', onPressed: () => context.go('/auth')),
        ),
      );
      return;
    }
    ref.read(notificationsProvider.notifier).refresh();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationsSheet(hostContext: context),
    );
  }
}

class _NotificationsSheet extends ConsumerWidget {
  /// Contexte de la cloche : sert à ouvrir la suite (notation, itinéraire) après fermeture.
  final BuildContext hostContext;

  const _NotificationsSheet({required this.hostContext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsProvider);
    final notifier = ref.read(notificationsProvider.notifier);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: const BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VoyagoColors.muted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(color: VoyagoColors.text, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  if (state.unreadCount > 0)
                    TextButton(
                      onPressed: notifier.markAllRead,
                      child: const Text(
                        'Tout marquer lu',
                        style: TextStyle(color: VoyagoColors.primary, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            if (state.isLoading && !state.loadedOnce)
              const Padding(
                padding: EdgeInsets.all(40),
                child: CircularProgressIndicator(color: VoyagoColors.primary, strokeWidth: 2.5),
              )
            else if (state.items.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(32, 30, 32, 48),
                child: Column(
                  children: [
                    Text('🔔', style: TextStyle(fontSize: 40)),
                    SizedBox(height: 12),
                    Text(
                      'Aucune notification pour l\'instant',
                      style: TextStyle(color: VoyagoColors.text, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'À ton arrivée sur un lieu de ton itinéraire, on te proposera de le noter.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: VoyagoColors.muted, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: state.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _NotificationTile(
                    notification: state.items[i],
                    hostContext: hostContext,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final AppNotification notification;
  final BuildContext hostContext;

  const _NotificationTile({required this.notification, required this.hostContext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = notification;
    final (icon, color) = switch (n.type) {
      'arrival' => (Icons.place_rounded, VoyagoColors.primary),
      'trip_ready' => (Icons.flight_takeoff_rounded, VoyagoColors.blue),
      'review_thanks' => (Icons.star_rounded, VoyagoColors.yellow),
      'comment' => (Icons.mode_comment_rounded, VoyagoColors.primary),
      _ => (Icons.notifications_rounded, VoyagoColors.orange),
    };
    final canReview = n.isArrival && !n.isReviewed && n.lat != null && n.lng != null;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _onTap(context, ref),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: n.read ? VoyagoColors.background : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: n.read ? VoyagoColors.cardBorder : color.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    style: TextStyle(
                      color: VoyagoColors.text,
                      fontSize: 13.5,
                      fontWeight: n.read ? FontWeight.w600 : FontWeight.w800,
                    ),
                  ),
                  if (n.body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(n.body, style: const TextStyle(color: VoyagoColors.muted, fontSize: 12, height: 1.35)),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        _timeAgo(n.createdAt),
                        style: TextStyle(color: VoyagoColors.muted.withValues(alpha: 0.8), fontSize: 11),
                      ),
                      const Spacer(),
                      if (canReview)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: VoyagoColors.yellow.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: VoyagoColors.yellow.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, color: VoyagoColors.yellow, size: 13),
                              SizedBox(width: 3),
                              Text(
                                'Noter',
                                style: TextStyle(color: VoyagoColors.yellow, fontSize: 11, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        )
                      else if (n.isArrival && n.isReviewed)
                        const Text(
                          'Avis publié ✓',
                          style: TextStyle(color: VoyagoColors.primary, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (!n.read)
              Container(
                margin: const EdgeInsets.only(left: 6, top: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }

  void _onTap(BuildContext context, WidgetRef ref) {
    final n = notification;
    ref.read(notificationsProvider.notifier).markRead(n);
    final navigator = Navigator.of(context);

    if (n.isArrival && n.lat != null && n.lng != null && !n.isReviewed) {
      navigator.pop();
      if (!hostContext.mounted) return;
      showPlaceReviewSheet(
        hostContext,
        ReviewTarget(
          name: n.placeName ?? n.title,
          lat: n.lat!,
          lng: n.lng!,
          imageUrl: n.data['image_url']?.toString(),
          destination: n.data['destination']?.toString(),
          tripId: n.tripId,
        ),
        fromArrival: true,
      );
    } else if (n.type == 'trip_ready' && (n.tripId?.isNotEmpty ?? false)) {
      navigator.pop();
      if (hostContext.mounted) hostContext.go('/itinerary/${n.tripId}');
    } else if (n.type == 'comment') {
      final targetType = n.data['target_type']?.toString();
      final targetId = n.data['target_id']?.toString();
      if (targetType == null || targetId == null) return;
      navigator.pop();
      if (hostContext.mounted) {
        showCommentsSheet(hostContext, targetType: targetType, targetId: targetId);
      }
    }
  }

  static String _timeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
