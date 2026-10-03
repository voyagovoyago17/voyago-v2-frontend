import '../models/app_notification.dart';
import 'dio_client.dart';
import 'endpoints.dart';

class NotificationsApi {
  final DioClient _client;

  NotificationsApi({DioClient? client}) : _client = client ?? DioClient.instance;

  /// Dernières notifications + nombre de non lues
  Future<({List<AppNotification> items, int unreadCount})> list({int limit = 30}) async {
    final data = await _client.get(Endpoints.notifications, queryParameters: {'limit': limit});
    final map = data as Map<String, dynamic>;
    final items = (map['notifications'] as List? ?? [])
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
    return (items: items, unreadCount: (map['unread_count'] as num?)?.toInt() ?? 0);
  }

  Future<int> unreadCount() async {
    final data = await _client.get(Endpoints.notificationsUnreadCount);
    return ((data as Map<String, dynamic>)['unread_count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String id) => _client.post(Endpoints.notificationRead(id));

  Future<void> markAllRead() => _client.post(Endpoints.notificationsReadAll);

  /// Signale l'arrivée sur un lieu de l'itinéraire (idempotent côté serveur)
  Future<AppNotification> recordArrival({
    required String placeName,
    required double lat,
    required double lng,
    String? tripId,
    String? destination,
    int? day,
    String? imageUrl,
  }) async {
    final data = await _client.post(Endpoints.notificationsArrival, data: {
      'place_name': placeName,
      'lat': lat,
      'lng': lng,
      if (tripId != null && tripId.isNotEmpty) 'trip_id': tripId,
      if (destination != null && destination.isNotEmpty) 'destination': destination,
      if (day != null) 'day': day,
      if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
    });
    return AppNotification.fromJson(data as Map<String, dynamic>);
  }

  /// Enregistre le jeton push (FCM) de cet appareil pour le compte connecté
  Future<void> registerDevice({required String token, required String platform, String? appVersion}) =>
      _client.post(Endpoints.notificationDevices, data: {
        'token': token,
        'platform': platform,
        if (appVersion != null) 'app_version': appVersion,
        // Heure locale du voyageur : rappels envoyés au bon moment de la journée
        'utc_offset_minutes': DateTime.now().timeZoneOffset.inMinutes,
      });

  /// Oublie cet appareil : il ne reçoit plus les push du compte (déconnexion)
  Future<void> unregisterDevice(String token) => _client.delete(Endpoints.notificationDevices, data: {'token': token});
}
