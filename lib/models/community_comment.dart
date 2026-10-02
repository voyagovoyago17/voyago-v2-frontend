/// Commentaire sur un voyage partagé ou une publication de cercle.
class CommunityComment {
  final String id;
  final String targetType; // 'trip' | 'post'
  final String targetId;
  final String? parentId;
  final String content;
  final DateTime createdAt;
  final Map<String, dynamic> author;

  /// Le voyageur connecté peut le supprimer (auteur, auteur du contenu ou modérateur du cercle)
  final bool canDelete;

  const CommunityComment({
    required this.id,
    required this.targetType,
    required this.targetId,
    this.parentId,
    required this.content,
    required this.createdAt,
    this.author = const {},
    this.canDelete = false,
  });

  factory CommunityComment.fromJson(Map<String, dynamic> json) {
    return CommunityComment(
      id: json['id']?.toString() ?? '',
      targetType: json['target_type']?.toString() ?? 'trip',
      targetId: json['target_id']?.toString() ?? '',
      parentId: json['parent_id']?.toString(),
      content: json['content']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      author: json['author'] is Map<String, dynamic> ? json['author'] as Map<String, dynamic> : const {},
      canDelete: json['can_delete'] as bool? ?? false,
    );
  }

  String get authorId => author['user_id']?.toString() ?? '';
  String get authorDisplayName {
    final pseudo = author['pseudo']?.toString();
    if (pseudo != null && pseudo.isNotEmpty) return pseudo;
    return author['name']?.toString() ?? 'Voyageur';
  }

  String get authorEmoji => author['avatar_emoji']?.toString() ?? '🧭';
  String? get authorPicture => author['picture']?.toString();
}
