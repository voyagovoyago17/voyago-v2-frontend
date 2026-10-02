import 'trip.dart';

class CommunityPost {
  final String id;
  final String circleId;
  final String userId;
  final String content;
  final String? tripId;
  final String? poiTitle;
  final String? poiCity;
  final String? poiCountry;
  final List<String> imageUrls;
  final int likesCount;
  final List<String> likedBy;
  final int commentsCount;
  final DateTime createdAt;
  final Map<String, dynamic>? author;
  final Trip? trip;

  const CommunityPost({
    required this.id,
    required this.circleId,
    required this.userId,
    required this.content,
    this.tripId,
    this.poiTitle,
    this.poiCity,
    this.poiCountry,
    this.imageUrls = const [],
    this.likesCount = 0,
    this.likedBy = const [],
    this.commentsCount = 0,
    required this.createdAt,
    this.author,
    this.trip,
  });

  factory CommunityPost.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }

    Trip? parsedTrip;
    if (json['trip'] != null && json['trip'] is Map<String, dynamic>) {
      try {
        parsedTrip = Trip.fromJson(json['trip'] as Map<String, dynamic>);
      } catch (_) {}
    }

    return CommunityPost(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      circleId: json['circle_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      tripId: json['trip_id']?.toString(),
      poiTitle: json['poi_title']?.toString(),
      poiCity: json['poi_city']?.toString(),
      poiCountry: json['poi_country']?.toString(),
      imageUrls: parseList(json['image_urls']),
      likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
      likedBy: parseList(json['liked_by']),
      commentsCount: (json['comments_count'] as num?)?.toInt() ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      author: json['author'] as Map<String, dynamic>?,
      trip: parsedTrip,
    );
  }

  bool isLikedBy(String? myUserId) {
    if (myUserId == null || myUserId.isEmpty) return false;
    return likedBy.contains(myUserId);
  }

  String get authorName => author?['name']?.toString() ?? 'Explorateur';
  String? get authorPseudo => author?['pseudo']?.toString();
  String get authorDisplayName =>
      (authorPseudo != null && authorPseudo!.isNotEmpty) ? authorPseudo! : authorName;
  String get authorEmoji => author?['avatar_emoji']?.toString() ?? '🧭';
  String? get authorPicture => author?['picture']?.toString();
  bool get authorIsPro => author?['is_pro'] as bool? ?? false;

  CommunityPost copyWith({
    int? likesCount,
    List<String>? likedBy,
  }) {
    return CommunityPost(
      id: id,
      circleId: circleId,
      userId: userId,
      content: content,
      tripId: tripId,
      poiTitle: poiTitle,
      poiCity: poiCity,
      poiCountry: poiCountry,
      imageUrls: imageUrls,
      likesCount: likesCount ?? this.likesCount,
      likedBy: likedBy ?? this.likedBy,
      createdAt: createdAt,
      author: author,
      trip: trip,
    );
  }
}
