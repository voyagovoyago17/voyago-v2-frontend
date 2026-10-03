import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/day_weather.dart';

class CityLocation {
  final String name;
  final String country;
  final double lat;
  final double lng;

  const CityLocation({
    required this.name,
    required this.country,
    required this.lat,
    required this.lng,
  });

  String get displayName => country.isNotEmpty ? '$name, $country' : name;
}

class _CachedWeather {
  final List<DayWeather> list;
  final DateTime fetchedAt;
  const _CachedWeather(this.list, this.fetchedAt);
}

class LiveWeatherService {
  LiveWeatherService._();
  static final LiveWeatherService instance = LiveWeatherService._();

  static const Duration _cacheTtl = Duration(minutes: 20);

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  final Map<String, _CachedWeather> _cache = {};

  /// Fuseau horaire légal (heure d'été comprise) des lieux déjà consultés, renvoyé par Open-Meteo
  final List<({double lat, double lng, int offsetMinutes})> _utcOffsets = [];

  /// Décalage UTC réel (minutes) du lieu le plus proche déjà connu (≤ 150 km), sinon null
  int? utcOffsetNear(double lat, double lng) {
    ({double lat, double lng, int offsetMinutes})? best;
    var bestDist = double.infinity;
    for (final o in _utcOffsets) {
      final d = (o.lat - lat) * (o.lat - lat) + (o.lng - lng) * (o.lng - lng);
      if (d < bestDist) {
        bestDist = d;
        best = o;
      }
    }
    // ≈ 1,35° ≈ 150 km : au-delà, le fuseau peut changer
    return best != null && bestDist <= 1.35 * 1.35 ? best.offsetMinutes : null;
  }

  void _rememberUtcOffset(double lat, double lng, int offsetMinutes) {
    _utcOffsets.removeWhere((o) => (o.lat - lat).abs() < 0.05 && (o.lng - lng).abs() < 0.05);
    _utcOffsets.add((lat: lat, lng: lng, offsetMinutes: offsetMinutes));
    if (_utcOffsets.length > 50) _utcOffsets.removeAt(0);
  }
  final Map<String, String> _reverseGeocodeCache = {};

  String _cacheKey(double lat, double lng) =>
      '${lat.toStringAsFixed(2)}_${lng.toStringAsFixed(2)}';

  static const List<CityLocation> _presetCities = [
    CityLocation(name: 'Paris', country: 'France', lat: 48.8566, lng: 2.3522),
    CityLocation(name: 'Versailles', country: 'France', lat: 48.8049, lng: 2.1204),
    CityLocation(name: 'Tokyo', country: 'Japon', lat: 35.6762, lng: 139.6503),
    CityLocation(name: 'Rome', country: 'Italie', lat: 41.9028, lng: 12.4964),
    CityLocation(name: 'Barcelone', country: 'Espagne', lat: 41.3851, lng: 2.1734),
    CityLocation(name: 'New York', country: 'USA', lat: 40.7128, lng: -74.0060),
    CityLocation(name: 'Londres', country: 'Royaume-Uni', lat: 51.5074, lng: -0.1278),
    CityLocation(name: 'Dubai', country: 'Émirats', lat: 25.2048, lng: 55.2708),
    CityLocation(name: 'Bangkok', country: 'Thaïlande', lat: 13.7563, lng: 100.5018),
    CityLocation(name: 'Sydney', country: 'Australie', lat: -33.8688, lng: 151.2093),
    CityLocation(name: 'Berlin', country: 'Allemagne', lat: 52.5200, lng: 13.4050),
    CityLocation(name: 'Amsterdam', country: 'Pays-Bas', lat: 52.3676, lng: 4.9041),
    CityLocation(name: 'Marrakech', country: 'Maroc', lat: 31.6295, lng: -7.9811),
    CityLocation(name: 'Abidjan', country: 'Côte d\'Ivoire', lat: 5.3600, lng: -4.0083),
    CityLocation(name: 'Dakar', country: 'Sénégal', lat: 14.7167, lng: -17.4677),
  ];

  /// Find a city by query, checks preset first, then queries OpenStreetMap Nominatim
  Future<List<CityLocation>> searchCities(String query) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return _presetCities.take(5).toList();

    // Check presets first
    final matchedPresets = _presetCities
        .where((c) =>
            c.name.toLowerCase() == clean ||
            c.name.toLowerCase().contains(clean) ||
            clean.startsWith(c.name.toLowerCase()))
        .toList();

    if (matchedPresets.isNotEmpty && !query.contains(',')) {
      return matchedPresets;
    }

    // Call Nominatim Geocoding via Dio
    try {
      final res = await _dio.get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'q': query,
          'format': 'json',
          'limit': '5',
          'addressdetails': '1',
        },
        options: Options(
          headers: {'User-Agent': 'VoyagoooApp/1.0 (contact@voyago.com)'},
        ),
      );

      if (res.statusCode == 200 && res.data is List) {
        final List data = res.data as List;
        final list = data.map((item) {
          final lat = double.tryParse(item['lat']?.toString() ?? '0') ?? 0.0;
          final lon = double.tryParse(item['lon']?.toString() ?? '0') ?? 0.0;
          final name = (item['name'] as String?)?.isNotEmpty == true
              ? item['name'] as String
              : (item['display_name'] as String).split(',').first.trim();
          final country = item['address']?['country'] as String? ?? '';
          return CityLocation(
            name: name,
            country: country,
            lat: lat,
            lng: lon,
          );
        }).toList();

        if (list.isNotEmpty) return list;
      }
    } catch (e) {
      debugPrint('⚠️ [LiveWeatherService] Erreur géocodage Nominatim: $e');
    }

    return matchedPresets.isNotEmpty ? matchedPresets : _presetCities.take(3).toList();
  }

  /// Fetches real-time weather from Open-Meteo for any latitude/longitude with 20min caching
  Future<List<DayWeather>> fetchWeather(double lat, double lng) async {
    final key = _cacheKey(lat, lng);
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheTtl) {
      return cached.list;
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': lat,
          'longitude': lng,
          'current': 'temperature_2m,weather_code,is_day,precipitation,rain',
          'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
          'timezone': 'auto',
        },
      );

      final data = response.data;
      if (data != null) {
        final offsetSeconds = (data['utc_offset_seconds'] as num?)?.toInt();
        if (offsetSeconds != null) _rememberUtcOffset(lat, lng, offsetSeconds ~/ 60);
        final current = data['current'] as Map<String, dynamic>?;
        final currentCode = (current?['weather_code'] as num?)?.toInt();
        final currentTemp = (current?['temperature_2m'] as num?)?.toDouble();
        final isDayNow = ((current?['is_day'] as num?)?.toInt() ?? 1) == 1;

        final daily = data['daily'] as Map<String, dynamic>?;
        if (daily != null) {
          final dates = daily['time'] as List? ?? [];
          final codes = daily['weather_code'] as List? ?? [];
          final maxTemps = daily['temperature_2m_max'] as List? ?? [];
          final minTemps = daily['temperature_2m_min'] as List? ?? [];

          final List<DayWeather> list = [];
          final count = dates.isNotEmpty ? dates.length : 1;
          for (var i = 0; i < count; i++) {
            final isToday = i == 0;
            final code = (isToday && currentCode != null)
                ? currentCode
                : ((i < codes.length ? codes[i] as num? : null)?.toInt() ?? 0);
            final maxT = (isToday && currentTemp != null)
                ? currentTemp
                : ((i < maxTemps.length ? maxTemps[i] as num? : null)?.toDouble() ?? 20.0);
            final minT = ((i < minTemps.length ? minTemps[i] as num? : null)?.toDouble() ?? 14.0);
            final isDay = isToday ? isDayNow : true;

            list.add(DayWeather(
              date: isToday ? 'Aujourd\'hui' : dates[i].toString(),
              icon: _weatherCodeToIcon(code, isDay: isDay),
              summary: _weatherCodeToSummary(code, isDay: isDay),
              weatherCode: code,
              tempMax: maxT,
              tempMin: minT,
            ));
          }

          if (list.isNotEmpty) {
            _cache[key] = _CachedWeather(list, DateTime.now());
            debugPrint('🌤️ [LiveWeatherService] Météo live reçue ($lat, $lng): ${list.first.summary} ${list.first.tempMax.round()}°C (code ${list.first.weatherCode})');
            return list;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [LiveWeatherService] Erreur appel Open-Meteo: $e');
      if (cached != null) return cached.list;
    }

    // Fallback dynamique
    final nowHour = DateTime.now().hour;
    final isNightNow = nowHour < 6 || nowHour >= 19;
    return [
      DayWeather(
        date: 'Aujourd\'hui',
        icon: isNightNow ? '🌙' : '🌤️',
        summary: isNightNow ? 'Nuit dégagée' : 'Partiellement nuageux',
        weatherCode: 0,
        tempMax: isNightNow ? 16.0 : 20.0,
        tempMin: 12.0,
      )
    ];
  }

  /// Reverse geocodes latitude/longitude into City / Country name with caching
  Future<String?> reverseGeocode(double lat, double lng) async {
    final key = '${lat.toStringAsFixed(2)}_${lng.toStringAsFixed(2)}';
    if (_reverseGeocodeCache.containsKey(key)) {
      return _reverseGeocodeCache[key];
    }

    // Check presets if within ~15km
    for (final preset in _presetCities) {
      final dLat = (preset.lat - lat).abs();
      final dLng = (preset.lng - lng).abs();
      if (dLat < 0.12 && dLng < 0.12) {
        _reverseGeocodeCache[key] = preset.displayName;
        return preset.displayName;
      }
    }

    try {
      final res = await _dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'format': 'json',
          'zoom': '10',
        },
        options: Options(
          headers: {'User-Agent': 'VoyagoooApp/1.0 (contact@voyago.com)'},
        ),
      );
      if (res.statusCode == 200 && res.data is Map) {
        final data = res.data as Map;
        final address = data['address'] as Map?;
        String? result;
        if (address != null) {
          final city = address['city'] ?? address['town'] ?? address['village'] ?? address['municipality'] ?? address['county'];
          final country = address['country'];
          if (city != null && country != null) {
            result = '$city, $country';
          } else if (city != null) {
            result = city.toString();
          }
        }
        final displayName = data['display_name'] as String?;
        if (result == null && displayName != null) {
          result = displayName.split(',').take(2).join(', ').trim();
        }
        if (result != null) {
          _reverseGeocodeCache[key] = result;
          return result;
        }
      }
    } catch (_) {}
    return null;
  }

  static String _weatherCodeToIcon(int code, {bool isDay = true}) {
    if (code >= 95) return '⛈️';
    if (code >= 80 && code <= 82) return '🌧️';
    if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) return '❄️';
    if (code >= 61 && code <= 67) return '🌧️';
    if (code >= 51 && code <= 57) return '🌦️';
    if (code == 45 || code == 48) return '🌫️';
    if (code == 2 || code == 3) return '☁️';
    if (code == 1) return isDay ? '⛅' : '☁️🌙';
    return isDay ? '☀️' : '🌙';
  }

  static String _weatherCodeToSummary(int code, {bool isDay = true}) {
    if (code >= 95) return 'Orages';
    if (code >= 80 && code <= 82) return 'Averses de pluie';
    if ((code >= 71 && code <= 77) || (code >= 85 && code <= 86)) return 'Chutes de neige';
    if (code >= 61 && code <= 67) return 'Pluie';
    if (code >= 51 && code <= 57) return 'Bruine';
    if (code == 45 || code == 48) return 'Brouillard';
    if (code == 3) return 'Très nuageux';
    if (code == 2) return 'Nuageux';
    if (code == 1) return isDay ? 'Éclaircies' : 'Nuit voilée';
    return isDay ? 'Ensoleillé' : 'Nuit claire';
  }
}
