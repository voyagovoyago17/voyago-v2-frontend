import 'community_post.dart';
import 'trip.dart';

/// Élément du fil d'actualité : un voyage partagé ou une publication de cercle.
class FeedItem {
  final String type; // 'trip' | 'post'
  final String id;
  final DateTime createdAt;
  final Map<String, dynamic> author;
  final Trip? trip;
  final CommunityPost? post;

  /// Cercle de la publication : id, name, slug, avatar_emoji, is_public
  final Map<String, dynamic>? circle;
  final bool likedByMe;
  final int likes;
  final int commentsCount;

  const FeedItem({
    required this.type,
    required this.id,
    required this.createdAt,
    this.author = const {},
    this.trip,
    this.post,
    this.circle,
    this.likedByMe = false,
    this.likes = 0,
    this.commentsCount = 0,
  });

  bool get isTrip => type == 'trip';
  bool get isPost => type == 'post';

  /// Clé unique (un voyage et une publication peuvent partager un identifiant)
  String get key => '$type:$id';

  String get authorId => author['user_id']?.toString() ?? '';
  String get authorDisplayName {
    final pseudo = author['pseudo']?.toString();
    if (pseudo != null && pseudo.isNotEmpty) return pseudo;
    return author['name']?.toString() ?? 'Voyageur';
  }

  String get authorEmoji => author['avatar_emoji']?.toString() ?? '🧭';
  String? get authorPicture => author['picture']?.toString();
  bool get authorIsPro => author['is_pro'] as bool? ?? false;

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? 'trip';
    Trip? trip;
    CommunityPost? post;
    if (type == 'trip' && json['trip'] is Map<String, dynamic>) {
      trip = Trip.fromJson(json['trip'] as Map<String, dynamic>);
    }
    if (type == 'post' && json['post'] is Map<String, dynamic>) {
      post = CommunityPost.fromJson(json['post'] as Map<String, dynamic>);
    }
    return FeedItem(
      type: type,
      id: json['id']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      author: json['author'] is Map<String, dynamic> ? json['author'] as Map<String, dynamic> : const {},
      trip: trip,
      post: post,
      circle: json['circle'] as Map<String, dynamic>?,
      likedByMe: json['liked_by_me'] as bool? ?? false,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
    );
  }

  FeedItem copyWith({bool? likedByMe, int? likes, int? commentsCount}) {
    return FeedItem(
      type: type,
      id: id,
      createdAt: createdAt,
      author: author,
      trip: trip,
      post: post,
      circle: circle,
      likedByMe: likedByMe ?? this.likedByMe,
      likes: likes ?? this.likes,
      commentsCount: commentsCount ?? this.commentsCount,
    );
  }
}

/// Une page du fil d'actualité ; `nextBefore` est null quand il n'y a plus rien à charger.
class FeedPage {
  final List<FeedItem> items;
  final String? nextBefore;

  const FeedPage({required this.items, this.nextBefore});
}
