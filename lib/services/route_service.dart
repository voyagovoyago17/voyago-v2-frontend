import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show IconData, Icons;
import 'package:latlong2/latlong.dart';

/// Mode de déplacement entre deux étapes, déduit des transports choisis à la création du voyage.
enum TravelMode {
  walk('à pied', Icons.directions_walk_rounded, 'routed-foot'),
  bike('à vélo', Icons.directions_bike_rounded, 'routed-bike'),
  car('en voiture', Icons.directions_car_rounded, 'routed-car'),
  transit('en transport', Icons.directions_bus_rounded, 'routed-car'),
  boat('en bateau', Icons.directions_boat_rounded, 'routed-car');

  const TravelMode(this.label, this.icon, this.osrmService);

  /// Libellé court affiché après la durée (ex : « 12 min en transport »).
  final String label;
  final IconData icon;

  /// Service OSRM de routing.openstreetmap.de (vrais profils piéton / vélo / voiture).
  final String osrmService;

  /// Au-delà de cette distance à vol d'oiseau, on ne propose plus la marche
  /// si le voyageur a choisi un autre moyen de transport.
  static const double walkableMeters = 1200;

  /// Au-delà (vol d'oiseau), le vélo et la marche ne sont plus réalistes
  static const double bikeableMeters = 20000;

  /// Choisit le mode d'un trajet selon les transports du voyage et la distance.
  /// La marche reste privilégiée pour les courts trajets si elle a été choisie.
  static TravelMode forTrip(List<String> transports, double straightMeters) {
    final modes = transports.map(_fromTransport).whereType<TravelMode>().toSet();
    // Au-delà d'une distance raisonnable à vélo ou à pied, on passe à un mode motorisé
    if (straightMeters > bikeableMeters) {
      for (final motorized in const [TravelMode.car, TravelMode.transit, TravelMode.boat]) {
        if (modes.contains(motorized)) return motorized;
      }
      return TravelMode.car;
    }
    if (modes.isEmpty) return TravelMode.walk;
    if (modes.contains(TravelMode.walk) && (straightMeters <= walkableMeters || modes.length == 1)) {
      return TravelMode.walk;
    }
    for (final preferred in const [TravelMode.car, TravelMode.transit, TravelMode.bike, TravelMode.boat]) {
      if (modes.contains(preferred)) return preferred;
    }
    return TravelMode.walk;
  }

  /// Mode principal du voyage (icône du bouton « Y aller »).
  static TravelMode primaryFor(List<String> transports) => forTrip(transports, double.infinity);

  static TravelMode? _fromTransport(String raw) {
    final t = raw.toLowerCase().trim();
    if (t.contains('march') || t.contains('pied') || t == 'walk') return TravelMode.walk;
    if (t.contains('velo') || t.contains('vélo') || t.contains('bike') || t.contains('trottinette')) {
      return TravelMode.bike;
    }
    if (t.contains('voiture') || t.contains('taxi') || t.contains('vtc') || t == 'car') return TravelMode.car;
    if (t.contains('bateau') || t.contains('ferry') || t == 'boat') return TravelMode.boat;
    if (t.contains('transport') || t.contains('metro') || t.contains('métro') || t.contains('bus') ||
        t.contains('tram') || t.contains('train')) {
      return TravelMode.transit;
    }
    return null;
  }
}

/// Résultat d'un calcul d'itinéraire entre deux points.
class RouteResult {
  /// Distance en mètres.
  final double distanceMeters;

  /// Durée estimée en secondes.
  final double durationSeconds;

  /// Points du tracé de la route (polyline).
  final List<LatLng> geometry;

  /// Nom de la rue de départ (si disponible).
  final String? originStreet;

  /// Nom de la rue d'arrivée (si disponible).
  final String? destinationStreet;

  /// Mode de déplacement utilisé pour ce calcul.
  final TravelMode mode;

  /// true si la durée vient d'une estimation locale (réseau indisponible).
  final bool isEstimate;

  const RouteResult({
    required this.distanceMeters,
    required this.durationSeconds,
    required this.geometry,
    this.originStreet,
    this.destinationStreet,
    this.mode = TravelMode.walk,
    this.isEstimate = false,
  });

  int get durationMinutes => (durationSeconds / 60).ceil();

  /// Distance formatée (ex: "1.2 km" ou "450 m").
  String get distanceLabel {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
    }
    return '${distanceMeters.round()} m';
  }

  /// Durée formatée (ex: "6 min" ou "1h12").
  String get durationLabel {
    final totalMin = durationMinutes;
    if (totalMin < 60) return '$totalMin min';
    final h = totalMin ~/ 60;
    final m = totalMin % 60;
    return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
  }
}

/// Service de calcul d'itinéraire utilisant OSRM (100% gratuit, pas de clé API).
/// Cache mémoire intégré pour éviter de re-solliciter l'API lors de micro-mouvements.
class RouteService {
  RouteService._();
  static final RouteService instance = RouteService._();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));

  /// Cache par clé "<originRounded>|<destRounded>|<profile>" -> RouteResult
  final Map<String, _CacheEntry> _cache = {};
  static const int _maxCacheSize = 60;
  static const Duration _cacheTtl = Duration(minutes: 10);

  /// Profils OSRM supportés.
  static const String walking = 'foot';
  static const String driving = 'car';
  static const String cycling = 'bike';

  /// Calcule l'itinéraire entre [origin] et [destination] via OSRM.
  /// [mode] prime sur [profile] (conservé pour compatibilité : foot, car, bike).
  /// Fallback : estimation locale à vol d'oiseau si le réseau est indisponible.
  Future<RouteResult> getRoute(
    LatLng origin,
    LatLng destination, {
    String profile = 'foot',
    TravelMode? mode,
  }) async {
    final travelMode = mode ??
        (profile == 'bike'
            ? TravelMode.bike
            : profile == 'car'
                ? TravelMode.car
                : TravelMode.walk);
    final key = _cacheKey(origin, destination, travelMode.name);
    final cached = _cache[key];
    if (cached != null && DateTime.now().difference(cached.time) < _cacheTtl) {
      return cached.result;
    }

    try {
      // routing.openstreetmap.de expose de vrais profils piéton / vélo / voiture
      // (le serveur de démo router.project-osrm.org ne calcule qu'en voiture).
      final url = 'https://routing.openstreetmap.de/${travelMode.osrmService}/route/v1/driving/'
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}'
          '?overview=full&geometries=geojson&steps=false';

      final response = await _dio.get(url);
      final data = response.data;

      if (data['code'] == 'Ok' && data['routes'] != null && (data['routes'] as List).isNotEmpty) {
        final route = data['routes'][0];
        final distance = (route['distance'] as num).toDouble();
        final roadDuration = (route['duration'] as num).toDouble();

        // Parse GeoJSON geometry
        final coords = route['geometry']['coordinates'] as List;
        final points = coords.map<LatLng>((c) {
          final coord = c as List;
          return LatLng(
            (coord[1] as num).toDouble(),
            (coord[0] as num).toDouble(),
          );
        }).toList();

        // Extract street names from waypoints
        String? originStreet;
        String? destStreet;
        if (data['waypoints'] != null) {
          final waypoints = data['waypoints'] as List;
          if (waypoints.isNotEmpty) {
            originStreet = waypoints.first['name']?.toString();
            if (waypoints.length > 1) {
              destStreet = waypoints.last['name']?.toString();
            }
          }
        }

        final result = RouteResult(
          distanceMeters: distance,
          durationSeconds: _durationForMode(travelMode, distance, roadDuration),
          geometry: points,
          originStreet: originStreet,
          destinationStreet: destStreet,
          mode: travelMode,
        );

        _putCache(key, result);
        return result;
      }
    } catch (_) {
      // Réseau indisponible → estimation locale
    }

    return estimate(origin, destination, travelMode);
  }

  /// Estimation instantanée sans réseau (affichage immédiat avant le calcul OSRM).
  static RouteResult estimate(LatLng origin, LatLng destination, TravelMode mode) {
    // Majoration du vol d'oiseau pour tenir compte du tracé réel des rues
    final distance = _haversineDistance(origin, destination) * (mode == TravelMode.walk ? 1.35 : 1.3);
    return RouteResult(
      distanceMeters: distance,
      durationSeconds: _durationForMode(mode, distance, null),
      geometry: [origin, destination],
      mode: mode,
      isEstimate: true,
    );
  }

  /// Durée selon le mode. Les transports en commun et le bateau n'ont pas de profil
  /// OSRM : on part de la distance routière, à vitesse moyenne arrêts compris,
  /// plus le temps d'attente.
  static double _durationForMode(TravelMode mode, double distanceMeters, double? roadDurationSeconds) {
    switch (mode) {
      case TravelMode.transit:
        return distanceMeters / 5.5 + 300; // ~20 km/h + 5 min d'attente / correspondance
      case TravelMode.boat:
        return distanceMeters / 4.5 + 420; // ~16 km/h + 7 min d'embarquement
      case TravelMode.walk:
        return roadDurationSeconds ?? distanceMeters / 1.25;
      case TravelMode.bike:
        return roadDurationSeconds ?? distanceMeters / 4.2;
      case TravelMode.car:
        // + 3 min pour se garer ; vitesse urbaine si pas de durée OSRM
        return (roadDurationSeconds ?? distanceMeters / 8.5) + 180;
    }
  }

  /// Calcule les distances depuis [userPosition] vers chaque POI de la liste.
  /// Retourne une Map {index POI → RouteResult}.
  /// Utilise `Future.wait` pour paralléliser les appels.
  Future<Map<int, RouteResult>> getDistancesToPois(
    LatLng userPosition,
    List<LatLng> poiPositions, {
    String profile = 'foot',
    List<String>? transports,
  }) async {
    final futures = <int, Future<RouteResult>>{};
    for (int i = 0; i < poiPositions.length; i++) {
      final mode = transports == null
          ? null
          : TravelMode.forTrip(transports, _haversineDistance(userPosition, poiPositions[i]));
      futures[i] = getRoute(userPosition, poiPositions[i], profile: profile, mode: mode);
    }

    final results = <int, RouteResult>{};
    final entries = futures.entries.toList();
    final routeResults = await Future.wait(entries.map((e) => e.value));
    for (int i = 0; i < entries.length; i++) {
      results[entries[i].key] = routeResults[i];
    }
    return results;
  }

  /// Distance Haversine en mètres entre deux points GPS.
  static double _haversineDistance(LatLng a, LatLng b) {
    const R = 6371000.0; // Rayon moyen de la Terre en mètres
    final dLat = _toRad(b.latitude - a.latitude);
    final dLon = _toRad(b.longitude - a.longitude);
    final sinDLat = math.sin(dLat / 2);
    final sinDLon = math.sin(dLon / 2);
    final h = sinDLat * sinDLat +
        math.cos(_toRad(a.latitude)) * math.cos(_toRad(b.latitude)) * sinDLon * sinDLon;
    return 2 * R * math.asin(math.sqrt(h));
  }

  /// Distance rapide à vol d'oiseau en mètres (utilisation publique).
  static double straightLineDistance(LatLng a, LatLng b) => _haversineDistance(a, b);

  static double _toRad(double deg) => deg * math.pi / 180;

  String _cacheKey(LatLng a, LatLng b, String profile) {
    // Arrondi à ~100m pour grouper les requêtes proches
    final aLat = (a.latitude * 1000).round();
    final aLng = (a.longitude * 1000).round();
    final bLat = (b.latitude * 1000).round();
    final bLng = (b.longitude * 1000).round();
    return '$aLat,$aLng|$bLat,$bLng|$profile';
  }

  void _putCache(String key, RouteResult result) {
    if (_cache.length >= _maxCacheSize) {
      // Supprimer les entrées les plus anciennes
      final sortedKeys = _cache.keys.toList()
        ..sort((a, b) => _cache[a]!.time.compareTo(_cache[b]!.time));
      for (int i = 0; i < _maxCacheSize ~/ 3; i++) {
        _cache.remove(sortedKeys[i]);
      }
    }
    _cache[key] = _CacheEntry(result: result, time: DateTime.now());
  }
}

class _CacheEntry {
  final RouteResult result;
  final DateTime time;
  const _CacheEntry({required this.result, required this.time});
}
