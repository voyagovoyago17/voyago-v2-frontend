import 'package:flutter/material.dart';
import '../models/poi.dart';
import '../theme.dart';

/// Map marker pin styled like the HTML mockup — circular with icon & label.
class MapPoiPin extends StatelessWidget {
  final POI poi;
  final int index;
  final bool isActive;
  final VoidCallback? onTap;

  const MapPoiPin({
    super.key,
    required this.poi,
    required this.index,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tooltip label (always visible for active, hidden for others)
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: VoyagoColors.surface,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: VoyagoColors.cardBorder,
                  width: 1,
                ),
              ),
              child: Text(
                poi.name.length > 24
                    ? '${poi.name.substring(0, 22)}…'
                    : poi.name,
                style: const TextStyle(
                  color: VoyagoColors.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

          // Circular pin
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? VoyagoColors.primary : VoyagoColors.blue,
              shape: BoxShape.circle,
              border: Border.all(
                color: VoyagoColors.surface,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isActive ? VoyagoColors.primary : VoyagoColors.blue)
                      .withValues(alpha: 0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          // Pin spike
          if (isActive)
            Container(
              width: 3,
              height: 10,
              decoration: BoxDecoration(
                color: VoyagoColors.primary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
        ],
      ),
    );
  }
}

/// The icon for a POI category
IconData getCategoryIcon(String category) {
  final cat = category.toLowerCase();
  if (cat.contains('gaming') || cat.contains('jeu') || cat.contains('esport') || cat.contains('arcade')) {
    return Icons.sports_esports;
  }
  if (cat.contains('montagne') || cat.contains('sommet') || cat.contains('alpin')) {
    return Icons.landscape;
  }
  if (cat.contains('safari') || cat.contains('faune') || cat.contains('animal')) {
    return Icons.pets;
  }
  if (cat.contains('tech') || cat.contains('vr') || cat.contains('futur')) {
    return Icons.memory;
  }
  if (cat.contains('cinema') || cat.contains('film') || cat.contains('série')) {
    return Icons.movie;
  }
  if (cat.contains('photo') || cat.contains('mirador') || cat.contains('vue')) {
    return Icons.camera_alt;
  }
  if (cat.contains('mystere') || cat.contains('legende') || cat.contains('chateau')) {
    return Icons.castle;
  }
  if (cat.contains('sensation') || cat.contains('attraction') || cat.contains('parc')) {
    return Icons.attractions;
  }
  if (cat.contains('roadtrip') || cat.contains('route') || cat.contains('auto')) {
    return Icons.directions_car;
  }
  if (cat.contains('spiritualite') || cat.contains('temple') || cat.contains('zen')) {
    return Icons.self_improvement;
  }
  if (cat.contains('famille') || cat.contains('enfant')) {
    return Icons.family_restroom;
  }
  if (cat.contains('gastro') || cat.contains('restaurant') || cat.contains('food')) {
    return Icons.restaurant;
  }
  if (cat.contains('culture') || cat.contains('museum') || cat.contains('art')) {
    return Icons.museum;
  }
  if (cat.contains('nature') || cat.contains('foret') || cat.contains('forêt')) {
    return Icons.park;
  }
  if (cat.contains('shopping') || cat.contains('mode') || cat.contains('vintage')) {
    return Icons.shopping_bag;
  }
  if (cat.contains('nightlife') || cat.contains('bar') || cat.contains('club')) {
    return Icons.local_bar;
  }
  if (cat.contains('bien_etre') || cat.contains('spa') || cat.contains('wellness') || cat.contains('yoga')) {
    return Icons.spa;
  }
  if (cat.contains('sport') || cat.contains('surf') || cat.contains('escalade')) {
    return Icons.surfing;
  }
  if (cat.contains('plage') || cat.contains('mer') || cat.contains('beach')) {
    return Icons.beach_access;
  }
  return Icons.place;
}
