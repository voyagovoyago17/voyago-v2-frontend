import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/community_circle.dart';
import '../theme.dart';

class CircleCard extends StatelessWidget {
  final CommunityCircle circle;
  final VoidCallback onTap;
  final VoidCallback onToggleJoin;
  final bool isJoining;

  const CircleCard({
    super.key,
    required this.circle,
    required this.onTap,
    required this.onToggleJoin,
    this.isJoining = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: VoyagoColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: circle.isMember
                ? VoyagoColors.primary.withOpacity(0.5)
                : VoyagoColors.cardBorder,
            width: circle.isMember ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover Image with Gradient & Overlays
            Stack(
              children: [
                SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: CachedNetworkImage(
                    imageUrl: circle.coverImageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: VoyagoColors.cardBorder,
                      child: const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: VoyagoColors.primary,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: VoyagoColors.cardBorder,
                      child: const Center(
                        child: Icon(Icons.terrain_rounded, color: VoyagoColors.muted, size: 40),
                      ),
                    ),
                  ),
                ),
                // Gradient Scrim
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.2),
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ),
                // Emoji Avatar Top Left
                Positioned(
                  top: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: VoyagoColors.surface.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                      circle.avatarEmoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                // Category Chip Top Right
                Positioned(
                  top: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.65),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Text(
                      circle.categoryLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Location badge Bottom Left
                if (circle.destinationCity != null || circle.destinationCountry != null)
                  Positioned(
                    bottom: 12,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: VoyagoColors.surface.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_rounded, size: 13, color: VoyagoColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            circle.locationDisplay,
                            style: const TextStyle(
                              color: VoyagoColors.text,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // Content Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Join Button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (!circle.isPublic) ...[
                        const Icon(Icons.lock_outline, size: 16, color: VoyagoColors.muted),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          circle.name,
                          style: const TextStyle(
                            color: VoyagoColors.text,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      _buildJoinButton(),
                    ],
                  ),

                  if (circle.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      circle.description,
                      style: const TextStyle(
                        color: VoyagoColors.muted,
                        fontSize: 13,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  const SizedBox(height: 14),
                  const Divider(height: 1, color: VoyagoColors.cardBorder),
                  const SizedBox(height: 12),

                  // Stats row: Members, Trips, Posts
                  Row(
                    children: [
                      _StatItem(
                        icon: Icons.group_outlined,
                        label: '${circle.membersCount} membre${circle.membersCount > 1 ? 's' : ''}',
                        color: VoyagoColors.blue,
                      ),
                      const SizedBox(width: 14),
                      _StatItem(
                        icon: Icons.flight_takeoff_rounded,
                        label: '${circle.tripsCount} voyage${circle.tripsCount > 1 ? 's' : ''}',
                        color: VoyagoColors.yellow,
                      ),
                      const SizedBox(width: 14),
                      _StatItem(
                        icon: Icons.forum_outlined,
                        label: '${circle.postsCount} post${circle.postsCount > 1 ? 's' : ''}',
                        color: VoyagoColors.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinButton() {
    if (isJoining) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: VoyagoColors.primary,
        ),
      );
    }

    if (circle.isMember) {
      return InkWell(
        onTap: onToggleJoin,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: VoyagoColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: VoyagoColors.primary.withOpacity(0.5)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded, size: 14, color: VoyagoColors.primary),
              SizedBox(width: 4),
              Text(
                'Membre',
                style: TextStyle(
                  color: VoyagoColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ElevatedButton(
      onPressed: onToggleJoin,
      style: ElevatedButton.styleFrom(
        backgroundColor: VoyagoColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: const Text(
        'Rejoindre',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: VoyagoColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
