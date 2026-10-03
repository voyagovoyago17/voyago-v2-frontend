import '../models/trip.dart';
import '../models/packing.dart';
import '../models/trip_bookings.dart';
import '../models/trip_gem.dart';
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
    Map<String, dynamic> extra = const {},
  }) async {
    final payload = {
      // Groupe et budget chiffré (facultatifs)
      ...extra,
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

  /// Ajouter ou changer les dates d'un voyage (la fin découle de la durée, météo rafraîchie)
  Future<Trip> updateDates(String tripId, DateTime start) async {
    final day = '${start.year.toString().padLeft(4, '0')}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
    final data = await _client.patch(Endpoints.tripDates(tripId), data: {'start_date': day});
    return Trip.fromJson(data as Map<String, dynamic>);
  }

  /// Valise du voyage (générée par l'IA au premier appel, quelques secondes)
  /// Réservations & Budget : propositions selon le budget et prestations réservées
  Future<TripBookings> getBookings(String tripId, {bool retry = false}) async {
    final data = await _client.get(Endpoints.tripBookings(tripId), queryParameters: retry ? {'retry': 1} : null);
    return TripBookings.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<TripBookings> addBooking(
    String tripId, {
    required String category,
    required String label,
    required int amount,
    String? url,
  }) async {
    final data = await _client.post(Endpoints.tripBookings(tripId), data: {
      'category': category,
      'label': label,
      'amount': amount,
      if (url != null) 'url': url,
    });
    return TripBookings.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// « Prix incorrect ? » : le prix de cette visite sera revérifié pour tous les voyageurs
  Future<void> reportActivityPrice(String tripId, String name) async {
    await _client.post('${Endpoints.tripBookings(tripId)}/price-report', data: {'name': name});
  }

  Future<TripBookings> removeBooking(String tripId, String itemId) async {
    final data = await _client.delete('${Endpoints.tripBookings(tripId)}/$itemId');
    return TripBookings.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Alerte prix du vol : activer / couper
  Future<PriceAlertState> setPriceAlert(String tripId, bool enabled) async {
    final data = enabled
        ? await _client.post(Endpoints.tripPriceAlert(tripId))
        : await _client.delete(Endpoints.tripPriceAlert(tripId));
    return PriceAlertState.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Inspiration budget : vols les moins chers depuis la ville du voyageur
  Future<FlightInspiration> getFlightInspiration({int? maxPrice, String currency = 'EUR', int adults = 1, List<int> childrenAges = const []}) async {
    final data = await _client.get(Endpoints.flightInspiration, queryParameters: {
      if (maxPrice != null && maxPrice > 0) 'max_price': maxPrice,
      'currency': currency,
      'adults': adults,
      if (childrenAges.isNotEmpty) 'children_ages': childrenAges.join(','),
    });
    return FlightInspiration.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<PackingList> getPacking(String tripId) async {
    final data = await _client.get(Endpoints.tripPacking(tripId));
    return PackingList.fromJson(data as Map<String, dynamic>);
  }

  Future<PackingList> togglePackingItem(String tripId, String itemId, bool packed) async {
    final data = await _client.patch('${Endpoints.tripPackingItems(tripId)}/$itemId', data: {'packed': packed});
    return PackingList.fromJson(data as Map<String, dynamic>);
  }

  Future<PackingList> addPackingItem(String tripId, String label, {String? category}) async {
    final data = await _client.post(Endpoints.tripPackingItems(tripId), data: {
      'label': label,
      if (category != null) 'category': category,
    });
    return PackingList.fromJson(data as Map<String, dynamic>);
  }

  Future<PackingList> removePackingItem(String tripId, String itemId) async {
    final data = await _client.delete('${Endpoints.tripPackingItems(tripId)}/$itemId');
    return PackingList.fromJson(data as Map<String, dynamic>);
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

  /// Radar : pépites de mon voyage et fenêtre d'activité
  Future<TripGems> getGems(String tripId) async {
    final data = await _client.get(Endpoints.tripGems(tripId));
    return TripGems.fromJson(data as Map<String, dynamic>);
  }

  /// Voyage sans dates : démarre le radar pour la durée du voyage
  Future<TripGems> startGems(String tripId) async {
    final data = await _client.post(Endpoints.tripGemsStart(tripId));
    return TripGems.fromJson(data as Map<String, dynamic>);
  }

  /// Ramasse une pépite sur place ; renvoie l'XP gagnée (0 si déjà ramassée)
  Future<int> collectGem(String tripId, String gemId, {required double lat, required double lng}) async {
    final data = await _client.post(Endpoints.tripGemCollect(tripId, gemId), data: {'lat': lat, 'lng': lng});
    return ((data as Map<String, dynamic>)['xp_awarded'] as num?)?.toInt() ?? 0;
  }

  /// Récupération du détail d'un voyage
  Future<Trip> getTripById(String tripId) async {
    final data = await _client.get(Endpoints.tripDetail(tripId));
    return Trip.fromJson(data as Map<String, dynamic>);
  }
}
