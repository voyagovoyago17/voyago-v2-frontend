import '../api/api.dart';
import '../core/storage/secure_storage_service.dart';
import '../models/auth_user.dart';
import '../models/interest.dart';
import '../models/trip.dart';
import '../models/user_profile.dart';

export '../api/api_exceptions.dart';
export '../api/endpoints.dart';

/// Façade unifiée ApiService (déléguant vers les modules spécialisés de lib/api/)
class ApiService {
  static ApiService? _instance;

  final AuthApi auth;
  final TripsApi trips;
  final CommunityApi community;
  final GamificationApi gamification;
  final ProApi pro;
  final InterestsApi interests;

  ApiService._({
    required this.auth,
    required this.trips,
    required this.community,
    required this.gamification,
    required this.pro,
    required this.interests,
  });

  static ApiService get instance {
    _instance ??= ApiService._(
      auth: AuthApi(),
      trips: TripsApi(),
      community: CommunityApi(),
      gamification: GamificationApi(),
      pro: ProApi(),
      interests: InterestsApi(),
    );
    return _instance!;
  }

  // --- AUTH BRIDGE METHODS ---
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await auth.loginEmail(email: email, password: password);
    return {
      'user': res.user.toJson(),
      'token': res.sessionToken,
      'session_token': res.sessionToken,
      'tenant_id': res.tenantId,
    };
  }

  Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
    String? pseudo,
    String? avatarEmoji,
    String? dateOfBirth,
    String? country,
    String? city,
  }) async {
    final res = await auth.signupEmail(
      email: email,
      password: password,
      name: name,
      dateOfBirth: dateOfBirth ?? '2000-01-01',
      country: country ?? 'France',
      city: city ?? 'Paris',
      pseudo: pseudo,
      avatarEmoji: avatarEmoji,
    );
    return {
      'user': res.user.toJson(),
      'token': res.sessionToken,
      'session_token': res.sessionToken,
      'tenant_id': res.tenantId,
    };
  }

  Future<Map<String, dynamic>> googleSession({
    required String idToken,
    required String name,
    required String email,
    String? picture,
  }) async {
    final res = await auth.loginGoogleSession(
      idToken: idToken,
      name: name,
      email: email,
      picture: picture,
    );
    return {
      'user': res.user.toJson(),
      'token': res.sessionToken,
      'session_token': res.sessionToken,
      'tenant_id': res.tenantId,
    };
  }

  Future<Map<String, dynamic>> guestSession({String? guestId}) async {
    final res = await auth.loginGuest(guestId: guestId);
    return {
      'user': res.user.toJson(),
      'token': res.sessionToken,
      'session_token': res.sessionToken,
      'tenant_id': res.tenantId,
    };
  }

  Future<Map<String, dynamic>> forgotPassword(String email) =>
      auth.forgotPassword(email);

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) =>
      auth.resetPassword(email: email, code: code, newPassword: newPassword);

  Future<Map<String, dynamic>> getAuthOptions() => auth.getAuthOptions();

  Future<AuthUser> updateProfile(Map<String, dynamic> data) => auth.updateProfile(
        name: data['name']?.toString(),
        pseudo: data['pseudo']?.toString(),
        avatarEmoji: data['avatar_emoji']?.toString() ?? data['avatarEmoji']?.toString(),
        country: data['country']?.toString(),
        city: data['city']?.toString(),
      );

  Future<void> logout() => auth.logout();

  // --- TRIPS BRIDGE METHODS ---
  Future<Trip> generateTrip({
    required String destination,
    required int durationDays,
    required String pace,
    required String budget,
    required List<String> transports,
    required List<String> interests,
    String? userId,
  }) =>
      trips.generateTrip(
        destination: destination,
        durationDays: durationDays,
        pace: pace,
        transports: transports,
        budget: budget,
        interests: interests,
      );

  Future<List<Trip>> getTrips(String userId) => trips.getUserTrips(userId);

  Future<Trip> getTrip(String tripId) => trips.getTripById(tripId);

  // --- COMMUNITY BRIDGE METHODS ---
  Future<List<Map<String, dynamic>>> getCommunityFeed() async {
    final items = await community.getPublicFeed();
    return items.map((item) {
      return {
        'trip': item.trip.toJson(),
        'author': {
          'name': item.authorName,
          'pseudo': item.authorPseudo,
          'avatar_emoji': item.authorAvatarEmoji,
          'picture': item.authorPicture,
          'is_pro': item.authorIsPro,
        },
      };
    }).toList();
  }

  Future<Map<String, dynamic>> likeTrip(String tripId) =>
      community.likeTrip(tripId);

  // --- GAMIFICATION BRIDGE METHODS ---
  Future<UserProfile> getProfile(String userId) => gamification.getProfile(userId);

  Future<Map<String, dynamic>> awardXP(String userId, String action) =>
      gamification.awardXp(userId: userId, action: action);

  Future<Map<String, dynamic>> getXpRewards([String? userId]) =>
      gamification.getXpRewards(userId);

  Future<List<Map<String, dynamic>>> getBadges() => gamification.getBadges();

  Future<Map<String, dynamic>> getPublicUser(String userId) async {
    final profile = await gamification.getProfile(userId);
    return {
      'user_id': profile.userId,
      'name': profile.name,
      'pseudo': profile.pseudo,
      'avatar_emoji': profile.avatarEmoji,
      'country': profile.country,
      'city': profile.city,
      'xp': profile.xp,
      'level': profile.level,
      'streak': profile.streak,
      'trips_count': profile.tripsCount,
      'badges': profile.badges,
      'is_pro': profile.isPro,
    };
  }

  // --- PRO BRIDGE METHODS ---
  Future<Map<String, dynamic>> createCheckout(String tier, {String? userId}) async {
    final uid = userId ?? (await SecureStorageService.instance.getUserId()) ?? '';
    final res = await pro.createCheckoutSession(userId: uid, tier: tier);
    return {
      'checkout_url': res.checkoutUrl,
      'session_id': res.sessionId,
    };
  }

  /// Formules Pro depuis le serveur (prix, avantages, quotas), au format des cartes
  Future<List<Map<String, dynamic>>> getProTiers() async {
    final tiers = await pro.getTiers();
    return [
      for (final t in tiers)
        {
          ...t,
          'price': (t['price'] as num?)?.toStringAsFixed(2) ?? t['price']?.toString() ?? '',
          'currency': '€',
          'period': switch (t['duration']?.toString()) { 'month' => 'mois', 'year' => 'an', _ => '' },
          'is_best': t['best_offer'] == true,
        },
    ];
  }

  Future<Map<String, dynamic>> getFreePlan() => pro.getFreePlan();

  Future<Map<String, dynamic>> getProStatus(String sessionId) =>
      pro.getProStatus(sessionId);

  // --- INTERESTS BRIDGE METHODS ---
  Future<List<Interest>> getInterests() => interests.getInterests();
}
