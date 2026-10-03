import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_settings.dart';
import 'route_service.dart';

/// Liens vers les apps de navigation (aucune clé API nécessaire).
///
/// Waze : https://developers.google.com/waze/deeplinks — `utm_source` permet à Waze
/// d'associer l'usage à Voyagooo ; les options « éviter » reprennent les réglages du voyageur.
class NavigationLinks {
  NavigationLinks._();

  static const utmSource = 'voyagooo';

  static Uri waze(double lat, double lng, {AppSettings? settings}) {
    final s = settings ?? AppSettingsNotifier.current;
    return Uri.https('waze.com', '/ul', {
      'll': '$lat,$lng',
      'navigate': 'yes',
      'utm_source': utmSource,
      if (s.avoidTolls) 'avoid_tolls': 'true',
      if (s.avoidFerries) 'avoid_ferries': 'true',
      if (s.avoidFreeways) 'avoid_freeways': 'true',
    });
  }

  /// Google Maps (format universel « api=1 »), mode de déplacement selon le trajet
  static Uri google(double lat, double lng, {double? fromLat, double? fromLng, TravelMode mode = TravelMode.walk}) {
    return Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      if (fromLat != null && fromLng != null) 'origin': '$fromLat,$fromLng',
      'destination': '$lat,$lng',
      'travelmode': switch (mode) {
        TravelMode.car => 'driving',
        TravelMode.bike => 'bicycling',
        TravelMode.transit || TravelMode.boat => 'transit',
        TravelMode.walk => 'walking',
      },
    });
  }

  static Uri apple(double lat, double lng, {TravelMode mode = TravelMode.walk}) => Uri.https('maps.apple.com', '/', {
        'daddr': '$lat,$lng',
        'dirflg': switch (mode) {
          TravelMode.car => 'd',
          TravelMode.transit || TravelMode.boat => 'r',
          _ => 'w',
        },
      });

  static bool get appleAvailable => !kIsWeb && Platform.isIOS;

  static Future<bool> open(Uri uri) => launchUrl(uri, mode: LaunchMode.externalApplication);
}
