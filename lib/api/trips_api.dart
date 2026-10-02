import '../models/trip.dart';
import 'dio_client.dart';
import 'endpoints.dart';

class TripsApi {
  final DioClient _client;

  TripsApi({DioClient? client}) : _client = client ?? DioClient.instance;

  /// Génération d'un itinéraire de voyage complet par l'IA (Claude Sonnet / Gemini)
  Future<Trip> generateTrip({
    required String destination,
    required int durationDays,
    required String pace,
    required List<String> transports,
    required String budget,
    required List<String> interests,
    String? startDate,
    String? endDate,
    String? city,
    String? country,
    String? countryCode,
    String? tenantId,
  }) async {
    final payload = {
      'destination': destination.trim(),
      'duration_days': durationDays,
      'pace': pace,
      'transports': transports,
      'budget': budget,
      'interests': interests,
      if (startDate != null && startDate.isNotEmpty) 'start_date': startDate,
      if (endDate != null && endDate.isNotEmpty) 'end_date': endDate,
      if (city != null && city.isNotEmpty) 'city': city,
      if (country != null && country.isNotEmpty) 'country': country,
      if (countryCode != null && countryCode.isNotEmpty) 'country_code': countryCode,
      if (tenantId != null) 'tenant_id': tenantId,
    };

    final data = await _client.post(Endpoints.generateTrip, data: payload);
    return Trip.fromJson(data as Map<String, dynamic>);
  }

  /// Récupération des voyages d'un utilisateur
  Future<List<Trip>> getUserTrips(String userId) async {
    final data = await _client.get(Endpoints.userTrips(userId));
    if (data is List) {
      return data.map((e) => Trip.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Rendre un voyage privé, visible par sa tribu ou public (auteur uniquement)
  Future<TripVisibility> updateVisibility(String tripId, TripVisibility visibility) async {
    final data = await _client.patch(
      Endpoints.tripVisibility(tripId),
      data: {'visibility': visibility.value},
    );
    final json = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    return TripVisibility.fromJson(json['visibility'], isPublic: json['is_public'] as bool?);
  }

  /// « Refaire ce voyage » : copie l'itinéraire d'un autre voyageur dans mes voyages (privé)
  Future<Trip> remixTrip(String tripId, {DateTime? startDate}) async {
    final data = await _client.post(
      Endpoints.tripRemix(tripId),
      data: {
        if (startDate != null)
          'start_date': '${startDate.year.toString().padLeft(4, '0')}-'
              '${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
      },
    );
    return Trip.fromJson(data as Map<String, dynamic>);
  }

  /// Récupération du détail d'un voyage
  Future<Trip> getTripById(String tripId) async {
    final data = await _client.get(Endpoints.tripDetail(tripId));
    return Trip.fromJson(data as Map<String, dynamic>);
  }
}
