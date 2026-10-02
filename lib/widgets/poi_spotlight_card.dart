import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/poi.dart';
import '../services/route_service.dart';
import '../theme.dart';
import 'map_poi_pin.dart';

/// Fiche flottante d'un lieu touché sur la carte : photo animée, infos clés et bref résumé.
/// Elle apparaît avec un léger rebond depuis le haut, comme la carte météo.
class PoiSpotlightCard extends StatelessWidget {
  final POI poi;

  /// Position du lieu dans la journée (0 = première étape)
  final int index;

  /// Trajet depuis ma position, s'il est connu
  final RouteResult? routeFromMe;
  final VoidCallback onClose;
  final VoidCallback onNavigate;

  const PoiSpotlightCard({
    super.key,
    required this.poi,
    required this.index,
    this.routeFromMe,
    required this.onClose,
    required this.onNavigate,
  });

  String get _visitDuration {
    final m = poi.durationMinutes;
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final rest = m % 60;
    return rest == 0 ? '${h}h' : '${h}h${rest.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xF2121520),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 24, offset: const Offset(0, 10)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHero(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _InfoChip(icon: Icons.star_rounded, color: VoyagoColors.yellow,
                            label: '${poi.rating.toStringAsFixed(1)} (${_compact(poi.reviewsCount)})'),
                        _InfoChip(icon: Icons.schedule_rounded, color: VoyagoColors.blue, label: _visitDuration),
                        if (routeFromMe != null)
                          _InfoChip(
                            icon: routeFromMe!.mode.icon,
                            color: VoyagoColors.primary,
                            label: '${routeFromMe!.durationLabel} · ${routeFromMe!.distanceLabel}',
                          ),
                      ],
                    ),
                    if (poi.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        poi.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4),
                      ),
                    ],
                    if (poi.insiderTip != null && poi.insiderTip!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('💡', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              poi.insiderTip!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onNavigate,
                        icon: const Icon(Icons.near_me_rounded, size: 18),
                        label: const Text('Y aller', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VoyagoColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    final image = poi.imageUrl;
    return SizedBox(
      height: 150,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Zoom lent façon « Ken Burns » pour donner vie à la photo
          if (image != null && image.isNotEmpty)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.0, end: 1.12),
              duration: const Duration(seconds: 8),
              curve: Curves.easeOut,
              builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
              child: CachedNetworkImage(
                imageUrl: image,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: VoyagoColors.cardBorder),
                errorWidget: (_, __, ___) => _fallbackHero(),
              ),
            )
          else
            _fallbackHero(),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x55000000), Colors.transparent, Color(0xE6121520)],
                stops: [0, 0.4, 1],
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 12,
            child: Row(
              children: [
                _Badge(label: 'Étape ${index + 1}', color: Colors.black.withValues(alpha: 0.55)),
                if (poi.hiddenGem) ...[
                  const SizedBox(width: 6),
                  _Badge(label: '💎 Pépite', color: VoyagoColors.blue.withValues(alpha: 0.85)),
                ],
              ],
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              onPressed: onClose,
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(getCategoryIcon(poi.category), color: Colors.white70, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      poi.category.isEmpty ? 'Lieu' : poi.category[0].toUpperCase() + poi.category.substring(1),
                      style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  poi.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, height: 1.15),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackHero() {
    return Container(
      color: VoyagoColors.cardBorder,
      alignment: Alignment.center,
      child: Icon(getCategoryIcon(poi.category), color: Colors.white38, size: 48),
    );
  }

  static String _compact(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k' : '$n';
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _InfoChip({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

/// Transition d'apparition de la fiche : rebond, fondu et glissement depuis le haut.
Widget poiSpotlightTransition(Widget child, Animation<double> animation) {
  final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
  return FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: SlideTransition(
      position: Tween(begin: const Offset(0, -0.15), end: Offset.zero).animate(curved),
      child: ScaleTransition(scale: Tween(begin: 0.88, end: 1.0).animate(curved), alignment: Alignment.topCenter, child: child),
    ),
  );
}
