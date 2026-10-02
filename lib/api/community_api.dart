import '../models/trip.dart';
import '../models/community_circle.dart';
import '../models/community_post.dart';
import '../models/community_comment.dart';
import '../models/feed_item.dart';
import '../models/tribe.dart';
import 'api_exceptions.dart';
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

  // =========================================================================
  // FIL D'ACTUALITÉ, COMMENTAIRES & MODÉRATION
  // =========================================================================

  /// Fil d'actualité : voyages visibles + publications de mes cercles
  Future<FeedPage> getHomeFeed({String? before, int limit = 20}) async {
    final dynamic data;
    try {
      data = await _client.get(
        Endpoints.homeFeed,
        queryParameters: {'limit': limit, if (before != null) 'before': before},
      );
    } on ApiException catch (e) {
      // Backend pas encore à jour : on se rabat sur l'ancien fil des voyages publics
      if (e.statusCode != 404) rethrow;
      if (before != null) return const FeedPage(items: []);
      return FeedPage(items: (await getPublicFeed()).map(_legacyFeedItem).toList());
    }
    final json = data as Map<String, dynamic>;
    final items = (json['items'] as List? ?? [])
        .map((e) => FeedItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return FeedPage(items: items, nextBefore: json['next_before']?.toString());
  }

  FeedItem _legacyFeedItem(CommunityTripItem item) {
    return FeedItem(
      type: 'trip',
      id: item.trip.id,
      createdAt: item.trip.createdAt,
      author: {
        'user_id': item.trip.userId,
        'name': item.authorName,
        'pseudo': item.authorPseudo,
        'avatar_emoji': item.authorAvatarEmoji,
        'picture': item.authorPicture,
        'is_pro': item.authorIsPro,
      },
      trip: item.trip,
      likes: item.trip.likes,
    );
  }

  Future<List<CommunityComment>> getComments(String targetType, String targetId) async {
    final data = await _client.get(
      Endpoints.communityComments,
      queryParameters: {'target_type': targetType, 'target_id': targetId},
    );
    if (data is List) {
      return data.map((e) => CommunityComment.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<CommunityComment> addComment({
    required String targetType,
    required String targetId,
    required String content,
    String? parentId,
  }) async {
    final data = await _client.post(
      Endpoints.communityComments,
      data: {
        'target_type': targetType,
        'target_id': targetId,
        'content': content.trim(),
        if (parentId != null) 'parent_id': parentId,
      },
    );
    return CommunityComment.fromJson(data as Map<String, dynamic>);
  }

  /// Supprime un commentaire et ses réponses ; renvoie le nombre de commentaires supprimés
  Future<int> deleteComment(String commentId) async {
    final data = await _client.delete(Endpoints.communityComment(commentId));
    return ((data as Map<String, dynamic>)['deleted_count'] as num?)?.toInt() ?? 1;
  }

  // =========================================================================
  // VOYAGES DE TRIBU & DÉFIS
  // =========================================================================

  Future<CircleChallenges> getChallenges(String circleId) async {
    final data = await _client.get(Endpoints.circleChallenges(circleId));
    return CircleChallenges.fromJson(data as Map<String, dynamic>);
  }

  Future<List<TribeTripPlan>> getTripPlans(String circleId) async {
    final data = await _client.get(Endpoints.circleTripPlans(circleId));
    if (data is List) {
      return data.map((e) => TribeTripPlan.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Lance un voyage de tribu. mode 'fresh' : nouvel itinéraire IA (jusqu'à une minute) ;
  /// 'reuse' : parcours déjà connu pour la destination, instantané.
  Future<TribeTripPlan> createTripPlan(
    String circleId, {
    required String destination,
    required int durationDays,
    String? pace,
    String? startDate,
    String mode = 'fresh',
  }) async {
    final data = await _client.post(
      Endpoints.circleTripPlans(circleId),
      data: {
        'destination': destination.trim(),
        'duration_days': durationDays,
        'mode': mode,
        if (pace != null) 'pace': pace,
        if (startDate != null) 'start_date': startDate,
      },
    );
    return TribeTripPlan.fromJson(data as Map<String, dynamic>);
  }

  Future<TribeTripPlan> getTripPlan(String planId) async {
    final data = await _client.get(Endpoints.tripPlan(planId));
    return TribeTripPlan.fromJson(data as Map<String, dynamic>);
  }

  /// Vote 'up' ou 'down' ; renvoie les nouveaux totaux du lieu
  Future<Map<String, dynamic>> voteTripPlan(String planId, String poiKey, String vote) async {
    final data = await _client.post(
      Endpoints.tripPlanVotes(planId),
      data: {'poi_key': poiKey, 'vote': vote},
    );
    return data as Map<String, dynamic>;
  }

  Future<TribeTripPlan> finalizeTripPlan(String planId) async {
    final data = await _client.post(Endpoints.tripPlanFinalize(planId));
    return TribeTripPlan.fromJson(data as Map<String, dynamic>);
  }

  /// Ajoute le voyage de tribu finalisé à mes voyages
  Future<Trip> joinTripPlan(String planId, {String? startDate}) async {
    final data = await _client.post(
      Endpoints.tripPlanJoin(planId),
      data: {if (startDate != null) 'start_date': startDate},
    );
    return Trip.fromJson(data as Map<String, dynamic>);
  }

  Future<void> blockUser(String userId) async {
    await _client.post(Endpoints.blockUser(userId));
  }

  Future<void> unblockUser(String userId) async {
    await _client.delete(Endpoints.blockUser(userId));
  }

  /// Voyageurs que j'ai bloqués (user_id, name, pseudo, avatar_emoji, picture)
  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final data = await _client.get(Endpoints.blockedUsers);
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  Future<void> deletePost(String postId) async {
    await _client.delete(Endpoints.communityPost(postId));
  }

  /// Signaler un voyage, une publication ou un commentaire
  Future<void> report({required String targetType, required String targetId, String? reason}) async {
    await _client.post(
      Endpoints.communityReports,
      data: {
        'target_type': targetType,
        'target_id': targetId,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
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
