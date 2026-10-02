import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api.dart';
import '../models/community_circle.dart';
import '../models/community_post.dart';
import '../models/feed_item.dart';
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

/// État du fil d'actualité (voyages visibles + publications de mes cercles)
class HomeFeedState {
  final List<FeedItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final String? nextBefore;
  final Object? error;

  const HomeFeedState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.nextBefore,
    this.error,
  });

  bool get hasMore => nextBefore != null;

  HomeFeedState copyWith({
    List<FeedItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    String? nextBefore,
    bool clearNextBefore = false,
    Object? error,
    bool clearError = false,
  }) {
    return HomeFeedState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      nextBefore: clearNextBefore ? null : (nextBefore ?? this.nextBefore),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class HomeFeedNotifier extends StateNotifier<HomeFeedState> {
  final CommunityApi _api;

  HomeFeedNotifier(this._api) : super(const HomeFeedState(isLoading: true)) {
    refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await _api.getHomeFeed();
      state = HomeFeedState(items: page.items, nextBefore: page.nextBefore);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _api.getHomeFeed(before: state.nextBefore);
      final known = state.items.map((i) => i.key).toSet();
      state = state.copyWith(
        items: [...state.items, ...page.items.where((i) => !known.contains(i.key))],
        isLoadingMore: false,
        nextBefore: page.nextBefore,
        clearNextBefore: page.nextBefore == null,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void _replace(String key, FeedItem Function(FeedItem) update) {
    state = state.copyWith(
      items: [for (final i in state.items) i.key == key ? update(i) : i],
    );
  }

  /// Like immédiat à l'écran, puis synchronisé avec le serveur (annulé en cas d'erreur)
  Future<void> toggleLike(FeedItem item) async {
    final liked = !item.likedByMe;
    _replace(item.key, (i) => i.copyWith(likedByMe: liked, likes: (i.likes + (liked ? 1 : -1)).clamp(0, 1 << 30)));
    try {
      if (item.isTrip) {
        final res = await _api.likeTrip(item.id);
        _replace(item.key, (i) => i.copyWith(
              likedByMe: res['liked'] as bool? ?? liked,
              likes: (res['likes'] as num?)?.toInt() ?? i.likes,
            ));
      } else {
        final res = await _api.toggleLikePost(item.id);
        _replace(item.key, (i) => i.copyWith(
              likedByMe: res['liked'] as bool? ?? liked,
              likes: (res['likes_count'] as num?)?.toInt() ?? i.likes,
            ));
      }
    } catch (_) {
      _replace(item.key, (_) => item);
    }
  }

  void setCommentsCount(String key, int count) {
    _replace(key, (i) => i.copyWith(commentsCount: count));
  }

  void remove(String key) {
    state = state.copyWith(items: state.items.where((i) => i.key != key).toList());
  }
}

/// Fil d'actualité ; recréé quand le voyageur connecté change
final homeFeedProvider = StateNotifierProvider<HomeFeedNotifier, HomeFeedState>((ref) {
  ref.watch(currentUserProvider.select((u) => u?.userId));
  return HomeFeedNotifier(ref.watch(communityApiProvider));
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
    // Le fil inclut les publications des cercles rejoints
    _ref.read(homeFeedProvider.notifier).refresh();
  }

  Future<void> leaveCircle(String circleId) async {
    await _api.leaveCircle(circleId);
    _ref.invalidate(communityCirclesProvider);
    _ref.invalidate(circleDetailProvider(circleId));
    _ref.read(homeFeedProvider.notifier).refresh();
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
    _ref.read(homeFeedProvider.notifier).refresh();
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
    _ref.read(homeFeedProvider.notifier).refresh();
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
    _ref.read(homeFeedProvider.notifier).refresh();
    return post;
  }

  /// Supprime une publication (auteur, créateur/admin du cercle)
  Future<void> deletePost({required String postId, required String circleId}) async {
    await _api.deletePost(postId);
    _ref.invalidate(circlePostsProvider(circleId));
    _ref.invalidate(circleDetailProvider(circleId));
    _ref.read(homeFeedProvider.notifier).remove('post:$postId');
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
