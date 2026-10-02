import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'poi.dart';

/// Pépite à ramasser sur place pendant le voyage (radar) : lieu secret hors itinéraire.
class TripGem {
  final String id;
  final String name;
  final String teaser;
  final double lat;
  final double lng;
  final int day;
  final String category;
  final String rarity; // commune | rare | legendaire
  final String? imageUrl;
  final DateTime? collectedAt;
  final int xp;

  const TripGem({
    required this.id,
    required this.name,
    required this.teaser,
    required this.lat,
    required this.lng,
    required this.day,
    required this.category,
    required this.rarity,
    this.imageUrl,
    this.collectedAt,
    this.xp = 5,
  });

  bool get isCollected => collectedAt != null;

  factory TripGem.fromJson(Map<String, dynamic> json) {
    return TripGem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Pépite',
      teaser: json['teaser']?.toString() ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0,
      day: (json['day'] as num?)?.toInt() ?? 1,
      category: json['category']?.toString() ?? '',
      rarity: json['rarity']?.toString() ?? 'commune',
      imageUrl: json['image_url']?.toString(),
      collectedAt: DateTime.tryParse(json['collected_at']?.toString() ?? '')?.toLocal(),
      xp: (json['xp'] as num?)?.toInt() ?? 5,
    );
  }

  String get rarityLabel => switch (rarity) {
        'legendaire' => 'Légendaire',
        'rare' => 'Rare',
        _ => 'Commune',
      };

  Color get rarityColor => switch (rarity) {
        'legendaire' => const Color(0xFFFFC800),
        'rare' => const Color(0xFFB57BFF),
        _ => const Color(0xFF0DF2CC),
      };

  /// Distance en mètres depuis une position GPS (haversine).
  double distanceFrom(double fromLat, double fromLng) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat - fromLat);
    final dLng = rad(lng - fromLng);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(fromLat)) * math.cos(rad(lat)) * math.pow(math.sin(dLng / 2), 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Pour réutiliser le guidage existant de la carte (détour vers la pépite)
  POI toPoi() => POI(
        name: name,
        description: teaser,
        category: category,
        imageQuery: name,
        lat: lat,
        lng: lng,
        day: day,
        order: 0,
        durationMinutes: 20,
        imageUrl: imageUrl,
        hiddenGem: true,
      );
}

/// État du radar d'un voyage : fenêtre d'activité et pépites.
class TripGems {
  final bool active;
  final bool needsStart;
  final bool ended;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int collectRadiusM;
  final List<TripGem> gems;
  final int xpEarned;
  final int xpAvailable;

  const TripGems({
    this.active = false,
    this.needsStart = false,
    this.ended = false,
    this.startsAt,
    this.endsAt,
    this.collectRadiusM = 80,
    this.gems = const [],
    this.xpEarned = 0,
    this.xpAvailable = 0,
  });

  List<TripGem> get remaining => gems.where((g) => !g.isCollected).toList();
  int get collectedCount => gems.length - remaining.length;

  factory TripGems.fromJson(Map<String, dynamic> json) {
    final window = json['window'] as Map<String, dynamic>? ?? const {};
    return TripGems(
      active: window['active'] as bool? ?? false,
      needsStart: window['needs_start'] as bool? ?? false,
      ended: window['ended'] as bool? ?? false,
      startsAt: DateTime.tryParse(window['starts_at']?.toString() ?? '')?.toLocal(),
      endsAt: DateTime.tryParse(window['ends_at']?.toString() ?? '')?.toLocal(),
      collectRadiusM: (json['collect_radius_m'] as num?)?.toInt() ?? 80,
      gems: (json['gems'] as List? ?? []).whereType<Map<String, dynamic>>().map(TripGem.fromJson).toList(),
      xpEarned: (json['xp_earned'] as num?)?.toInt() ?? 0,
      xpAvailable: (json['xp_available'] as num?)?.toInt() ?? 0,
    );
  }
}
