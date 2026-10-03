import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Les 5 phases atmosphériques et solaires astronomiques calculées en temps réel
/// selon les coordonnées exactes du lieu (position de l'utilisateur ou lieu recherché).
enum MapAmbiancePhase {
  dawn,       // Lever du jour / Aube (matin naissant avant le soleil)
  day,        // Plein jour / Jour ensoleillé (soleil au zénith, carte claire OSM)
  goldenHour, // Heure dorée (lumière rasante dorée, lever ou coucher)
  twilight,   // Crépuscule (soir après le coucher du soleil jusqu'à la nuit noire)
  night,      // Nuit (carte sombre ardoise/cyan, ciel étoilé, lune)
}

/// Service d'ambiance 100% automatique Jour / Nuit / Crépuscule / Lever du jour sans aucune clé d'API.
/// Inspiré directement de MapAmbianceResolver dans hellobarber_frontend.
/// Détermine l'ambiance selon :
/// 1. La géolocalisation ou la ville recherchée (position solaire astronomique exacte par longitude/latitude)
/// 2. Les conditions météo en direct (orages violents assombrissant le ciel)
/// 3. L'écoulement naturel du temps (mise à jour automatique minute par minute)
class MapAmbiance {
  final MapAmbiancePhase phase;
  final String tileUrlTemplate;
  final String attribution;
  final String phaseLabel;
  final IconData phaseIcon;
  final bool isNight;
  final int localHour;
  final int localMinute;
  final double tileWarmth;
  final double ambientOverlay;
  final Color ambientColor;
  final List<Color> skyGradient;
  final double skyGradientOpacity;
  final bool showStars;
  final bool showSun;
  final bool showMoon;
  final bool showClouds;

  final ColorFilter? customTileFilter;

  /// URL OpenStreetMap 100% gratuite, sans aucune clé d'API, sans watermark
  static const String osmTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String osmAttribution = '© OpenStreetMap contributors';

  /// Filtre sombre haute fidélité pour OpenStreetMap :
  /// Transforme les tuiles claires OSM en une somptueuse carte de nuit (fond sombre ardoise #101E22,
  /// rues et libellés néon/cyan ultra nets, 100% gratuit sans aucune clé API ni filigrane).
  static const ColorFilter nightMatrixFilter = ColorFilter.matrix(<double>[
    -0.80,  0.00,  0.00, 0.0, 215.0,
     0.00, -0.74,  0.00, 0.0, 222.0,
     0.00,  0.00, -0.68, 0.0, 230.0,
     0.00,  0.00,  0.00, 1.0,   0.0,
  ]);

  /// Filtre crépuscule bleuté pour OpenStreetMap
  static const ColorFilter twilightMatrixFilter = ColorFilter.matrix(<double>[
    -0.60,  0.00,  0.00, 0.0, 185.0,
     0.00, -0.55,  0.00, 0.0, 195.0,
     0.00,  0.00, -0.42, 0.0, 215.0,
     0.00,  0.00,  0.00, 1.0,   0.0,
  ]);

  /// Filtre lever du jour doux pour OpenStreetMap
  static const ColorFilter dawnMatrixFilter = ColorFilter.matrix(<double>[
    1.02, 0.00, 0.00, 0.0, 12.0,
    0.00, 0.98, 0.00, 0.0,  6.0,
    0.00, 0.00, 0.95, 0.0, -4.0,
    0.00, 0.00, 0.00, 1.0,  0.0,
  ]);

  const MapAmbiance({
    required this.phase,
    required this.tileUrlTemplate,
    required this.attribution,
    required this.phaseLabel,
    required this.phaseIcon,
    required this.isNight,
    required this.localHour,
    required this.localMinute,
    this.customTileFilter,
    this.tileWarmth = 0,
    this.ambientOverlay = 0,
    this.ambientColor = Colors.transparent,
    this.skyGradient = const [],
    this.skyGradientOpacity = 0.0,
    this.showStars = false,
    this.showSun = false,
    this.showMoon = false,
    this.showClouds = false,
  });

  /// Filtre appliqué aux tuiles de la carte (chaleur dorée ou mode nuit sombre haute définition)
  ColorFilter? get tileColorFilter {
    if (customTileFilter != null) return customTileFilter;
    if (tileWarmth <= 0) return null;
    return ColorFilter.mode(
      Color.lerp(
        Colors.transparent,
        const Color(0xFFFFB74D),
        tileWarmth.clamp(0.0, 1.0),
      )!,
      BlendMode.softLight,
    );
  }

  /// Calcul astronomique précis du lever et coucher du soleil aux coordonnées données
  static ({double sunriseHour, double sunsetHour}) _calcSunriseSunset(
      double lat, double lng, DateTime date) {
    final dayOfYear =
        date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    const rad = math.pi / 180.0;

    // Déclinaison solaire approximée
    final declination =
        23.45 * math.sin((360.0 / 365.0 * (dayOfYear - 81)) * rad) * rad;
    final latRad = lat * rad;

    // Angle horaire pour le lever / coucher (zénith = 90.833° pour aube/crépuscule civil)
    final cosHourAngle = (math.sin(-0.833 * rad) -
            math.sin(latRad) * math.sin(declination)) /
        (math.cos(latRad) * math.cos(declination));

    if (cosHourAngle >= 1.0) {
      // Nuit polaire
      return (sunriseHour: 12.0, sunsetHour: 12.0);
    }
    if (cosHourAngle <= -1.0) {
      // Jour polaire (soleil de minuit)
      return (sunriseHour: 0.0, sunsetHour: 24.0);
    }

    final hourAngleDeg = math.acos(cosHourAngle) * (180.0 / math.pi);
    final halfDayHours = hourAngleDeg / 15.0;

    final sunrise = (12.0 - halfDayHours).clamp(0.0, 24.0);
    final sunset = (12.0 + halfDayHours).clamp(0.0, 24.0);

    return (sunriseHour: sunrise, sunsetHour: sunset);
  }

  /// Résolution 100% automatique en fonction de la position (lat/lng) et de la météo.
  /// S'adapte dynamiquement à la position GPS de l'utilisateur ou à la ville recherchée.
  static MapAmbiance resolve({
    required LatLng center,
    int? weatherCode,
    DateTime? nowUtc,
    /// Fuseau légal du lieu (Open-Meteo, heure d'été comprise) ; sinon estimé
    int? utcOffsetMinutes,
  }) {
    final utc = (nowUtc ?? DateTime.now()).toUtc();
    // Temps solaire (1° de longitude = 4 min) : sert au calcul astronomique jour / nuit / heure dorée
    final offsetMinutes = (center.longitude * 4.0).round();
    final localTime = utc.add(Duration(minutes: offsetMinutes));
    // Heure affichée : l'heure légale du lieu, comme sur le téléphone de quelqu'un qui s'y trouve
    final civilTime = utc.add(Duration(minutes: utcOffsetMinutes ?? _estimatedUtcOffset(center.longitude)));
    final localHourDecimal = localTime.hour + (localTime.minute / 60.0);

    // Calcul astronomique du soleil pour ce lieu et cette date
    final sun = _calcSunriseSunset(center.latitude, center.longitude, localTime);
    final sunrise = sun.sunriseHour;
    final sunset = sun.sunsetHour;

    // Fenêtres crépusculaires et golden hour (en heures)
    const twilightWindowHours = 40.0 / 60.0; // 40 min
    const goldenWindowHours = 50.0 / 60.0;   // 50 min

    final civilDawn = (sunrise - twilightWindowHours).clamp(0.0, 24.0);
    final civilDusk = (sunset + twilightWindowHours).clamp(0.0, 24.0);

    // Conditions orageuses violentes assombrissant le ciel (WMO >= 95)
    final isStormy = weatherCode != null && weatherCode >= 95;

    MapAmbiancePhase phase;
    if (isStormy) {
      phase = MapAmbiancePhase.night;
    } else if (localHourDecimal < civilDawn || localHourDecimal >= civilDusk) {
      // Nuit complète
      phase = MapAmbiancePhase.night;
    } else if (localHourDecimal >= civilDawn && localHourDecimal < sunrise) {
      // Lever du jour (Aube matinale avant que le disque solaire ne perce)
      phase = MapAmbiancePhase.dawn;
    } else if (localHourDecimal >= sunrise && localHourDecimal < (sunrise + goldenWindowHours)) {
      // Heure dorée matinale (soleil rasant du matin)
      phase = MapAmbiancePhase.goldenHour;
    } else if (localHourDecimal >= (sunset - goldenWindowHours) && localHourDecimal < sunset) {
      // Heure dorée du soir (coucher de soleil éclatant)
      phase = MapAmbiancePhase.goldenHour;
    } else if (localHourDecimal >= sunset && localHourDecimal < civilDusk) {
      // Crépuscule vespéral (ciel violet/indigo, premières étoiles)
      phase = MapAmbiancePhase.twilight;
    } else {
      // Plein jour / Journée ensoleillée
      phase = MapAmbiancePhase.day;
    }

    final timeStr =
        '${civilTime.hour.toString().padLeft(2, '0')}:${civilTime.minute.toString().padLeft(2, '0')}';

    return _themeForPhase(
      phase: phase,
      timeStr: timeStr,
      localHour: civilTime.hour,
      localMinute: civilTime.minute,
      isStormy: isStormy,
      weatherCode: weatherCode,
    );
  }

  /// Fuseau inconnu : celui du téléphone si le lieu est dans sa région (cas le plus courant),
  /// sinon le fuseau nominal de la longitude (à l'heure près)
  static int estimatedUtcOffset(double longitude) => _estimatedUtcOffset(longitude);

  static int _estimatedUtcOffset(double longitude) {
    final device = DateTime.now().timeZoneOffset.inMinutes;
    final solar = (longitude * 4.0).round();
    if ((device - solar).abs() <= 150) return device;
    return ((longitude / 15.0).round() * 60).clamp(-12 * 60, 14 * 60);
  }

  static MapAmbiance _themeForPhase({
    required MapAmbiancePhase phase,
    required String timeStr,
    required int localHour,
    required int localMinute,
    required bool isStormy,
    int? weatherCode,
  }) {
    switch (phase) {
      case MapAmbiancePhase.dawn:
        return MapAmbiance(
          phase: phase,
          tileUrlTemplate: osmTileUrl,
          attribution: osmAttribution,
          phaseLabel: 'Lever du jour · $timeStr',
          phaseIcon: Icons.wb_twilight_rounded,
          isNight: false,
          localHour: localHour,
          localMinute: localMinute,
          customTileFilter: dawnMatrixFilter,
          tileWarmth: 0.20,
          ambientOverlay: 0.04,
          ambientColor: const Color(0xFFFFAB91),
          skyGradient: const [
            Color(0x38FF8A65), // Douceur aurore
            Color(0x20FFB74D), // Doré naissant
            Color(0x00FFE082),
          ],
          skyGradientOpacity: 0.35,
          showStars: false,
          showSun: true,
          showMoon: false,
          showClouds: true,
        );

      case MapAmbiancePhase.day:
        return MapAmbiance(
          phase: phase,
          // OpenStreetMap standard : 100% gratuit, sans clé d'API, rues, édifices, boulevards en pleine clarté
          tileUrlTemplate: osmTileUrl,
          attribution: osmAttribution,
          phaseLabel: 'Jour ensoleillé · $timeStr',
          phaseIcon: Icons.wb_sunny_rounded,
          isNight: false,
          localHour: localHour,
          localMinute: localMinute,
          customTileFilter: null,
          tileWarmth: 0.0,
          ambientOverlay: 0.0,
          ambientColor: Colors.transparent,
          skyGradient: const [
            Color(0x264FC3F7),
            Color(0x1481D4FA),
            Color(0x00E1F5FE),
          ],
          skyGradientOpacity: 0.20,
          showStars: false,
          showSun: true,
          showMoon: false,
          showClouds: true,
        );

      case MapAmbiancePhase.goldenHour:
        return MapAmbiance(
          phase: phase,
          tileUrlTemplate: osmTileUrl,
          attribution: osmAttribution,
          phaseLabel: 'Heure dorée · $timeStr',
          phaseIcon: Icons.wb_twilight_rounded,
          isNight: false,
          localHour: localHour,
          localMinute: localMinute,
          customTileFilter: null,
          tileWarmth: 0.38,
          ambientOverlay: 0.06,
          ambientColor: const Color(0xFFFF7043),
          skyGradient: const [
            Color(0x38FF7043),
            Color(0x1EFFAB40),
            Color(0x00FFE082),
          ],
          skyGradientOpacity: 0.30,
          showStars: false,
          showSun: true,
          showMoon: false,
          showClouds: true,
        );

      case MapAmbiancePhase.twilight:
        return MapAmbiance(
          phase: phase,
          tileUrlTemplate: osmTileUrl,
          attribution: osmAttribution,
          phaseLabel: 'Crépuscule · $timeStr',
          phaseIcon: Icons.brightness_4_rounded,
          isNight: false,
          localHour: localHour,
          localMinute: localMinute,
          customTileFilter: twilightMatrixFilter,
          tileWarmth: 0.0,
          ambientOverlay: 0.08,
          ambientColor: const Color(0xFF283593),
          skyGradient: const [
            Color(0x403949AB),
            Color(0x207E57C2),
            Color(0x00CE93D8),
          ],
          skyGradientOpacity: 0.35,
          showStars: true,
          showSun: false,
          showMoon: true,
          showClouds: false,
        );

      case MapAmbiancePhase.night:
        final label = isStormy ? 'Ciel d\'orage · $timeStr' : 'Nuit · $timeStr';
        return MapAmbiance(
          phase: phase,
          // OpenStreetMap avec matrice sombre haute définition : Rues et édifices nets, 100% sans filigrane
          tileUrlTemplate: osmTileUrl,
          attribution: osmAttribution,
          phaseLabel: label,
          phaseIcon: isStormy ? Icons.thunderstorm : Icons.nightlight_round,
          isNight: true,
          localHour: localHour,
          localMinute: localMinute,
          customTileFilter: nightMatrixFilter,
          tileWarmth: 0.0,
          ambientOverlay: isStormy ? 0.12 : 0.04,
          ambientColor:
              isStormy ? const Color(0xFF1A1A2E) : const Color(0xFF050B14),
          skyGradient: const [
            Color(0x4D050B14),
            Color(0x260D1B2A),
            Color(0x001B263B),
          ],
          skyGradientOpacity: 0.35,
          showStars: !isStormy,
          showSun: false,
          showMoon: !isStormy,
          showClouds: isStormy,
        );
    }
  }
}
