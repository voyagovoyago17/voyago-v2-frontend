import '../models/trip.dart';
import '../models/community_circle.dart';
import '../models/community_post.dart';
import 'dio_client.dart';
import 'endpoints.dart';

class CommunityTripItem {
  final Trip trip;
  final String authorName;
  final String? authorPseudo;
  final String? authorAvatarEmoji;
  final String? authorPicture;
  final bool authorIsPro;

  CommunityTripItem({
    required this.trip,
    required this.authorName,
    this.authorPseudo,
    this.authorAvatarEmoji,
    this.authorPicture,
    this.authorIsPro = false,
  });

  factory CommunityTripItem.fromJson(Map<String, dynamic> json) {
    final tripMap = json['trip'] as Map<String, dynamic>? ?? json;
    final userMap = json['author'] as Map<String, dynamic>? ??
        json['user'] as Map<String, dynamic>? ??
        {};

    return CommunityTripItem(
      trip: Trip.fromJson(tripMap),
      authorName: userMap['name']?.toString() ?? 'Voyageur',
      authorPseudo: userMap['pseudo']?.toString(),
      authorAvatarEmoji: userMap['avatar_emoji']?.toString() ?? userMap['avatarEmoji']?.toString(),
      authorPicture: userMap['picture']?.toString(),
      authorIsPro: userMap['is_pro'] as bool? ?? userMap['isPro'] as bool? ?? false,
    );
  }

  String get authorDisplay => authorPseudo ?? authorName;
}

class CommunityApi {
  final DioClient _client;

  CommunityApi({DioClient? client}) : _client = client ?? DioClient.instance;

  // =========================================================================
  // 1. FLUX PUBLIC EXISTANT (PRÉSERVÉ À 100%)
  // =========================================================================

  /// Récupération du flux public des itinéraires partagés
  Future<List<CommunityTripItem>> getPublicFeed() async {
    final data = await _client.get(Endpoints.publicFeed);
    if (data is List) {
      return data
          .map((e) => CommunityTripItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Liker ou retirer un like sur un voyage
  Future<Map<String, dynamic>> likeTrip(String tripId) async {
    final data = await _client.post(Endpoints.likeTrip(tripId));
    return data as Map<String, dynamic>;
  }

  // =========================================================================
  // 2. CERCLES & COMMUNAUTÉS VOYAGOOO (NOUVELLE EXPÉRIENCE IMMERSIVE)
  // =========================================================================

  /// Récupération des cercles/tribus avec filtres
  Future<List<CommunityCircle>> getCircles({
    String? category,
    String? destination,
    String? search,
    String? myUserId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (category != null && category.isNotEmpty && category != 'all') {
      queryParams['category'] = category;
    }
    if (destination != null && destination.isNotEmpty) {
      queryParams['destination'] = destination;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (myUserId != null && myUserId.isNotEmpty) {
      queryParams['my_user_id'] = myUserId;
    }

    final data = await _client.get(
      Endpoints.communityCircles,
      queryParameters: queryParams,
    );

    if (data is List) {
      return data
          .map((e) => CommunityCircle.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Détail d'un cercle avec échantillon de membres
  Future<CommunityCircle> getCircleDetail(String circleId, {String? userId}) async {
    final queryParams = <String, dynamic>{};
    if (userId != null && userId.isNotEmpty) {
      queryParams['user_id'] = userId;
    }

    final data = await _client.get(
      Endpoints.circleDetail(circleId),
      queryParameters: queryParams,
    );

    return CommunityCircle.fromJson(data as Map<String, dynamic>);
  }

  /// Création d'une nouvelle communauté
  Future<CommunityCircle> createCircle({
    required String name,
    required String description,
    String? avatarEmoji,
    String? coverImageUrl,
    String? category,
    String? destinationCity,
    String? destinationCountry,
    List<String>? tags,
    bool isPublic = true,
  }) async {
    final payload = {
      'name': name,
      'description': description,
      if (avatarEmoji != null) 'avatar_emoji': avatarEmoji,
      if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
      if (category != null) 'category': category,
      if (destinationCity != null) 'destination_city': destinationCity,
      if (destinationCountry != null) 'destination_country': destinationCountry,
      if (tags != null) 'tags': tags,
      'is_public': isPublic,
    };

    final data = await _client.post(
      Endpoints.communityCircles,
      data: payload,
    );

    return CommunityCircle.fromJson(data as Map<String, dynamic>);
  }

  /// Rejoindre un cercle
  Future<Map<String, dynamic>> joinCircle(String circleId) async {
    final data = await _client.post(Endpoints.joinCircle(circleId));
    return data as Map<String, dynamic>;
  }

  /// Rejoindre un cercle privé grâce à son code d'invitation (renvoie circle_id, slug, name)
  Future<Map<String, dynamic>> joinCircleByCode(String code) async {
    final data = await _client.post(
      Endpoints.joinCircleByCode,
      data: {'code': code.trim()},
    );
    return data as Map<String, dynamic>;
  }

  /// Générer un nouveau code d'invitation (l'ancien cesse de fonctionner)
  Future<String> regenerateInviteCode(String circleId) async {
    final data = await _client.post(Endpoints.circleInviteCode(circleId));
    return (data as Map<String, dynamic>)['invite_code']?.toString() ?? '';
  }

  /// Quitter un cercle
  Future<Map<String, dynamic>> leaveCircle(String circleId) async {
    final data = await _client.post(Endpoints.leaveCircle(circleId));
    return data as Map<String, dynamic>;
  }

  // =========================================================================
  // 3. POSTS, MOMENTS & PARTAGES D'ITINÉRAIRES
  // =========================================================================

  /// Récupérer les posts d'un cercle
  Future<List<CommunityPost>> getCirclePosts(String circleId) async {
    final data = await _client.get(Endpoints.circlePosts(circleId));
    if (data is List) {
      return data
          .map((e) => CommunityPost.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Créer un post/moment dans un cercle
  Future<CommunityPost> createPost(
    String circleId, {
    required String content,
    String? tripId,
    String? poiTitle,
    String? poiCity,
    String? poiCountry,
    List<String>? imageUrls,
  }) async {
    final payload = {
      'content': content,
      if (tripId != null) 'trip_id': tripId,
      if (poiTitle != null) 'poi_title': poiTitle,
      if (poiCity != null) 'poi_city': poiCity,
      if (poiCountry != null) 'poi_country': poiCountry,
      if (imageUrls != null) 'image_urls': imageUrls,
    };

    final data = await _client.post(
      Endpoints.circlePosts(circleId),
      data: payload,
    );

    return CommunityPost.fromJson(data as Map<String, dynamic>);
  }

  /// Partager un voyage dans un cercle (déclenche aussi l'XP share_trip côté backend)
  Future<Map<String, dynamic>> shareTripToCircle(
    String circleId, {
    required String tripId,
    String? comment,
  }) async {
    final payload = {
      'trip_id': tripId,
      if (comment != null) 'comment': comment,
    };

    final data = await _client.post(
      Endpoints.shareTripToCircle(circleId),
      data: payload,
    );

    return data as Map<String, dynamic>;
  }

  /// Liker ou retirer un like sur un post
  Future<Map<String, dynamic>> toggleLikePost(String postId) async {
    final data = await _client.post(Endpoints.likeCommunityPost(postId));
    return data as Map<String, dynamic>;
  }
}
