import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api.dart';
import '../models/community_circle.dart';
import '../models/community_post.dart';
import 'auth_provider.dart';
import 'trips_provider.dart';

final communityApiProvider = Provider<CommunityApi>((ref) => CommunityApi());

// =========================================================================
// 1. FLUX PUBLIC EXISTANT (PRÉSERVÉ À 100%)
// =========================================================================

/// Provider pour le flux public communautaire
final communityFeedProvider = FutureProvider<List<CommunityTripItem>>((ref) async {
  final api = ref.watch(communityApiProvider);
  return api.getPublicFeed();
});

// =========================================================================
// 2. ÉTAT ET FILTRES DES CERCLES / COMMUNAUTÉS
// =========================================================================

/// Filtre par catégorie ('all', 'culture', 'adventure', 'nature', 'food')
final selectedCircleCategoryProvider = StateProvider<String>((ref) => 'all');

/// Recherche textuelle pour les cercles
final circleSearchQueryProvider = StateProvider<String>((ref) => '');

/// Provider pour la liste filtrée des cercles
final communityCirclesProvider = FutureProvider<List<CommunityCircle>>((ref) async {
  final api = ref.watch(communityApiProvider);
  final category = ref.watch(selectedCircleCategoryProvider);
  final search = ref.watch(circleSearchQueryProvider);
  final authUser = ref.watch(currentUserProvider);

  return api.getCircles(
    category: category == 'all' ? null : category,
    search: search.trim().isEmpty ? null : search.trim(),
    myUserId: authUser?.userId,
  );
});

/// Détail d'un cercle spécifique (par id ou slug)
final circleDetailProvider = FutureProvider.family<CommunityCircle, String>((ref, circleId) async {
  final api = ref.watch(communityApiProvider);
  final authUser = ref.watch(currentUserProvider);
  return api.getCircleDetail(circleId, userId: authUser?.userId);
});

/// Posts & moments d'un cercle spécifique
final circlePostsProvider = FutureProvider.family<List<CommunityPost>, String>((ref, circleId) async {
  final api = ref.watch(communityApiProvider);
  return api.getCirclePosts(circleId);
});

// =========================================================================
// 3. CONTRÔLEUR D'ACTIONS COMMUNAUTAIRES
// =========================================================================

class CommunityController {
  final Ref _ref;

  CommunityController(this._ref);

  CommunityApi get _api => _ref.read(communityApiProvider);

  Future<void> joinCircle(String circleId) async {
    await _api.joinCircle(circleId);
    _ref.invalidate(communityCirclesProvider);
    _ref.invalidate(circleDetailProvider(circleId));
  }

  Future<void> leaveCircle(String circleId) async {
    await _api.leaveCircle(circleId);
    _ref.invalidate(communityCirclesProvider);
    _ref.invalidate(circleDetailProvider(circleId));
  }

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
    final circle = await _api.createCircle(
      name: name,
      description: description,
      avatarEmoji: avatarEmoji,
      coverImageUrl: coverImageUrl,
      category: category,
      destinationCity: destinationCity,
      destinationCountry: destinationCountry,
      tags: tags,
      isPublic: isPublic,
    );
    _ref.invalidate(communityCirclesProvider);
    return circle;
  }

  /// Rejoint un cercle via son code d'invitation et renvoie l'identifiant du cercle.
  Future<String> joinCircleByCode(String code) async {
    final res = await _api.joinCircleByCode(code);
    final circleId = res['circle_id']?.toString() ?? '';
    _ref.invalidate(communityCirclesProvider);
    if (circleId.isNotEmpty) _ref.invalidate(circleDetailProvider(circleId));
    return circleId;
  }

  Future<String> regenerateInviteCode(String circleId) async {
    final code = await _api.regenerateInviteCode(circleId);
    _ref.invalidate(circleDetailProvider(circleId));
    return code;
  }

  Future<void> shareTripToCircle({
    required String circleId,
    required String tripId,
    String? comment,
  }) async {
    await _api.shareTripToCircle(
      circleId,
      tripId: tripId,
      comment: comment,
    );
    _ref.invalidate(circlePostsProvider(circleId));
    _ref.invalidate(circleDetailProvider(circleId));
    _ref.invalidate(communityCirclesProvider);
    _ref.invalidate(communityFeedProvider);
    // Le partage peut élargir la visibilité du voyage
    _ref.invalidate(tripsProvider);
  }

  Future<CommunityPost> createPost({
    required String circleId,
    required String content,
    String? tripId,
    String? poiTitle,
    String? poiCity,
    String? poiCountry,
    List<String>? imageUrls,
  }) async {
    final post = await _api.createPost(
      circleId,
      content: content,
      tripId: tripId,
      poiTitle: poiTitle,
      poiCity: poiCity,
      poiCountry: poiCountry,
      imageUrls: imageUrls,
    );
    _ref.invalidate(circlePostsProvider(circleId));
    _ref.invalidate(circleDetailProvider(circleId));
    _ref.invalidate(communityCirclesProvider);
    return post;
  }

  Future<void> toggleLikePost({
    required String postId,
    required String circleId,
  }) async {
    await _api.toggleLikePost(postId);
    _ref.invalidate(circlePostsProvider(circleId));
  }
}

final communityControllerProvider = Provider<CommunityController>((ref) {
  return CommunityController(ref);
});
