import 'dio_client.dart';
import 'endpoints.dart';

class ProCheckoutResponse {
  final String checkoutUrl;
  final String sessionId;

  ProCheckoutResponse({
    required this.checkoutUrl,
    required this.sessionId,
  });

  factory ProCheckoutResponse.fromJson(Map<String, dynamic> json) {
    return ProCheckoutResponse(
      checkoutUrl: json['checkout_url']?.toString() ?? json['url']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? json['id']?.toString() ?? '',
    );
  }
}

class ProApi {
  final DioClient _client;

  ProApi({DioClient? client}) : _client = client ?? DioClient.instance;

  /// Création d'une session Stripe Checkout pour un abonnement Pro
  Future<ProCheckoutResponse> createCheckoutSession({
    required String userId,
    required String tier,
  }) async {
    final payload = {
      'user_id': userId,
      'tier': tier,
    };
    final data = await _client.post(Endpoints.proCheckout, data: payload);
    return ProCheckoutResponse.fromJson(data as Map<String, dynamic>);
  }

  /// Formules Pro (prix, avantages, quotas de modification)
  Future<List<Map<String, dynamic>>> getTiers() async {
    final data = await _client.get(Endpoints.proTiers);
    if (data is! List) return const [];
    return [for (final t in data) Map<String, dynamic>.from(t as Map)];
  }

  /// Formule gratuite : inclus / manquant
  Future<Map<String, dynamic>> getFreePlan() async {
    final data = await _client.get(Endpoints.proFreePlan);
    return Map<String, dynamic>.from(data as Map);
  }

  /// Pack de 3 modifications pour un voyage (paiement unique)
  Future<ProCheckoutResponse> createEditPackCheckout(String tripId) async {
    final data = await _client.post(Endpoints.proEditPack, data: {'trip_id': tripId});
    return ProCheckoutResponse.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// Statut d'une session de paiement Stripe (polling après checkout)
  Future<Map<String, dynamic>> getProStatus(String sessionId) async {
    final data = await _client.get(Endpoints.proStatus(sessionId));
    return data as Map<String, dynamic>;
  }
}
