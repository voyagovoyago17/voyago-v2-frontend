import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../models/trip.dart';
import '../theme.dart';

class TripCard extends StatelessWidget {
  final Trip trip;
  final VoidCallback? onTap;
  final Map<String, dynamic>? authorInfo;

  /// Si fourni (voyages de l'auteur), affiche la visibilité et permet de la changer.
  final VoidCallback? onVisibilityTap;

  const TripCard({
    super.key,
    required this.trip,
    this.onTap,
    this.authorInfo,
    this.onVisibilityTap,
  });

  String _formatDate(DateTime dt) {
    try {
      return DateFormat('d MMM yyyy', 'fr').format(dt);
    } catch (_) {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final coverUrl = trip.displayCoverImage;
    final dateStr = _formatDate(trip.createdAt);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: VoyagoColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: VoyagoColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image (Édifice emblématique du pays ou premier POI)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: coverUrl != null && coverUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: coverUrl,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _placeholder(),
                      errorWidget: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Destination + duration
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          trip.destination,
                          style: const TextStyle(
                            color: VoyagoColors.text,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _Badge(
                        label: '${trip.durationDays}j',
                        color: VoyagoColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Date + pace
                  Row(
                    children: [
                      Text(
                        dateStr,
                        style: const TextStyle(
                          color: VoyagoColors.muted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('·', style: const TextStyle(color: VoyagoColors.muted)),
                      const SizedBox(width: 8),
                      Text(
                        _paceEmoji(trip.pace),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const Spacer(),
                      if (onVisibilityTap != null)
                        _VisibilityChip(visibility: trip.visibility, onTap: onVisibilityTap)
                      else if (trip.visibility == TripVisibility.tribe)
                        const _VisibilityChip(visibility: TripVisibility.tribe),
                    ],
                  ),

                  // Author info if provided
                  if (authorInfo != null) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          authorInfo!['avatar_emoji']?.toString() ?? '🦜',
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            authorInfo!['pseudo']?.toString() ??
                                authorInfo!['name']?.toString() ??
                                'Voyageur',
                            style: const TextStyle(
                              color: VoyagoColors.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (authorInfo!['is_pro'] == true)
                          _Badge(label: '💎 Pro', color: VoyagoColors.blue),
                        if (trip.likes > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '❤ ${trip.likes}',
                            style: const TextStyle(
                              color: VoyagoColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 180,
      width: double.infinity,
      color: VoyagoColors.cardBorder,
      child: const Center(
        child: Text('🦜', style: TextStyle(fontSize: 40)),
      ),
    );
  }

  String _paceEmoji(String pace) {
    switch (pace.toLowerCase()) {
      case 'tranquille':
        return '🚶 Tranquille';
      case 'equilibre':
      case 'équilibré':
        return '🚴 Équilibré';
      case 'intensif':
        return '🏃 Intensif';
      default:
        return pace;
    }
  }
}

class _VisibilityChip extends StatelessWidget {
  final TripVisibility visibility;
  final VoidCallback? onTap;

  const _VisibilityChip({required this.visibility, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = visibility == TripVisibility.private ? VoyagoColors.muted : VoyagoColors.blue;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(visibility.icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              visibility.label,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 2),
              Icon(Icons.expand_more, size: 14, color: color),
            ],
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
