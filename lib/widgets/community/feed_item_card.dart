import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../api/api_exceptions.dart';
import '../../models/feed_item.dart';
import '../../models/trip.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../theme.dart';
import 'comments_sheet.dart';

/// Carte du fil d'actualité, façon réseau social : auteur, contenu, aperçu du voyage,
/// puis la barre « J'aime / Commenter ».
class FeedItemCard extends ConsumerWidget {
  final FeedItem item;

  const FeedItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = item.isTrip ? item.trip : item.post?.trip;
    final post = item.post;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VoyagoColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, ref),
          if (post != null && post.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(post.content, style: const TextStyle(color: VoyagoColors.text, fontSize: 14, height: 1.4)),
            ),
          if (item.isTrip && trip != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(
                'a partagé son voyage à ${trip.destination} 🌍',
                style: const TextStyle(color: VoyagoColors.text, fontSize: 14),
              ),
            ),
          if (trip != null)
            _TripPreview(trip: trip, onTap: () => context.go('/itinerary/${trip.id}', extra: trip))
          else if (post != null && post.imageUrls.isNotEmpty)
            CachedNetworkImage(
              imageUrl: post.imageUrls.first,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          _buildCounters(),
          const Divider(height: 1, color: VoyagoColors.cardBorder),
          _buildActions(context, ref),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final circle = item.circle;
    final trip = item.trip;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 10),
      child: Row(
        children: [
          AuthorAvatar(picture: item.authorPicture, emoji: item.authorEmoji, size: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: item.authorDisplayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (item.authorIsPro)
                        const TextSpan(text: ' 💎', style: TextStyle(fontSize: 12)),
                      if (circle != null) ...[
                        const TextSpan(text: '  ▸  ', style: TextStyle(color: VoyagoColors.muted)),
                        TextSpan(
                          text: '${circle['avatar_emoji'] ?? '🧭'} ${circle['name'] ?? 'Cercle'}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: VoyagoColors.primary),
                        ),
                      ],
                    ],
                  ),
                  style: const TextStyle(color: VoyagoColors.text, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(timeAgo(item.createdAt), style: const TextStyle(color: VoyagoColors.muted, fontSize: 12)),
                    const SizedBox(width: 6),
                    Icon(
                      circle != null
                          ? (circle['is_public'] == false ? Icons.lock_outline : Icons.groups_outlined)
                          : (trip?.visibility.icon ?? Icons.public),
                      size: 13,
                      color: VoyagoColors.muted,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (circle != null)
            IconButton(
              tooltip: 'Voir le cercle',
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: VoyagoColors.muted),
              onPressed: () => context.go('/circle/${circle['id']}'),
            ),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: VoyagoColors.muted),
            onPressed: () => _showMenu(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildCounters() {
    if (item.likes == 0 && item.commentsCount == 0) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(
        children: [
          if (item.likes > 0) ...[
            const Icon(Icons.favorite_rounded, size: 14, color: VoyagoColors.coral),
            const SizedBox(width: 4),
            Text('${item.likes}', style: const TextStyle(color: VoyagoColors.muted, fontSize: 12)),
          ],
          const Spacer(),
          if (item.commentsCount > 0)
            Text(
              '${item.commentsCount} commentaire${item.commentsCount > 1 ? 's' : ''}',
              style: const TextStyle(color: VoyagoColors.muted, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(homeFeedProvider.notifier);
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: item.likedByMe ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            label: "J'aime",
            color: item.likedByMe ? VoyagoColors.coral : VoyagoColors.muted,
            onTap: () {
              if (!_requireLogin(context, ref, 'aimer')) return;
              notifier.toggleLike(item);
            },
          ),
        ),
        Expanded(
          child: _ActionButton(
            icon: Icons.mode_comment_outlined,
            label: 'Commenter',
            color: VoyagoColors.muted,
            onTap: () => showCommentsSheet(
              context,
              targetType: item.type,
              targetId: item.id,
              title: item.isTrip ? 'Commentaires · ${item.trip?.destination ?? ''}' : 'Commentaires',
              onCountChanged: (count) => notifier.setCommentsCount(item.key, count),
            ),
          ),
        ),
      ],
    );
  }

  bool _requireLogin(BuildContext context, WidgetRef ref, String action) {
    if (ref.read(currentUserProvider) != null) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connecte-toi pour $action')),
    );
    return false;
  }

  Future<void> _showMenu(BuildContext context, WidgetRef ref) async {
    final me = ref.read(currentUserProvider)?.userId;
    final isMine = me != null && me == item.authorId;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: VoyagoColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.isPost && isMine)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: VoyagoColors.coral),
                title: const Text('Supprimer la publication', style: TextStyle(color: VoyagoColors.coral)),
                onTap: () => Navigator.of(ctx).pop('delete'),
              ),
            if (!isMine)
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: VoyagoColors.muted),
                title: const Text('Signaler', style: TextStyle(color: VoyagoColors.text)),
                onTap: () => Navigator.of(ctx).pop('report'),
              ),
            if (item.isTrip && isMine)
              const ListTile(
                leading: Icon(Icons.info_outline, color: VoyagoColors.muted),
                title: Text(
                  'Change la visibilité de ce voyage depuis ton profil',
                  style: TextStyle(color: VoyagoColors.muted),
                ),
              ),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'report') {
      if (!_requireLogin(context, ref, 'signaler')) return;
      await reportContent(context, ref, targetType: item.type, targetId: item.id);
    } else if (action == 'delete' && item.post != null) {
      try {
        await ref.read(communityControllerProvider).deletePost(postId: item.id, circleId: item.post!.circleId);
      } on ApiException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)),
          );
        }
      }
    }
  }
}

class _TripPreview extends StatelessWidget {
  final Trip trip;
  final VoidCallback onTap;

  const _TripPreview({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cover = trip.displayCoverImage;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cover != null && cover.isNotEmpty)
            CachedNetworkImage(
              imageUrl: cover,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(height: 200, color: VoyagoColors.cardBorder),
              errorWidget: (_, __, ___) => Container(height: 200, color: VoyagoColors.cardBorder),
            ),
          Container(
            width: double.infinity,
            color: VoyagoColors.background,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.destination,
                        style: const TextStyle(color: VoyagoColors.text, fontSize: 15, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${trip.durationDays} jours • ${trip.pois.length} étapes',
                        style: const TextStyle(color: VoyagoColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Text(
                  "Voir l'itinéraire",
                  style: TextStyle(color: VoyagoColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
