class CommunityMemberPreview {
  final String userId;
  final String role;
  final String name;
  final String? pseudo;
  final String avatarEmoji;
  final String? picture;
  final bool isPro;

  const CommunityMemberPreview({
    required this.userId,
    required this.role,
    required this.name,
    this.pseudo,
    this.avatarEmoji = '🧭',
    this.picture,
    this.isPro = false,
  });

  factory CommunityMemberPreview.fromJson(Map<String, dynamic> json) {
    return CommunityMemberPreview(
      userId: json['user_id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'explorer',
      name: json['name']?.toString() ?? 'Voyageur',
      pseudo: json['pseudo']?.toString(),
      avatarEmoji: json['avatar_emoji']?.toString() ?? '🧭',
      picture: json['picture']?.toString(),
      isPro: json['is_pro'] as bool? ?? false,
    );
  }

  String get displayName => pseudo != null && pseudo!.isNotEmpty ? pseudo! : name;
}

class CommunityCircle {
  final String id;
  final String name;
  final String slug;
  final String description;
  final String avatarEmoji;
  final String coverImageUrl;
  final String category;
  final String? destinationCity;
  final String? destinationCountry;
  final String creatorId;
  final int membersCount;
  final int tripsCount;
  final int postsCount;
  final bool isPublic;

  /// Code d'invitation d'un cercle privé (renvoyé au créateur et aux admins uniquement)
  final String? inviteCode;
  final List<String> tags;
  final bool isMember;
  final String? myRole;
  final Map<String, dynamic>? creator;
  final List<CommunityMemberPreview> membersSample;
  final DateTime createdAt;

  const CommunityCircle({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    this.avatarEmoji = '🧭',
    required this.coverImageUrl,
    this.category = 'general',
    this.destinationCity,
    this.destinationCountry,
    required this.creatorId,
    this.membersCount = 1,
    this.tripsCount = 0,
    this.postsCount = 0,
    this.isPublic = true,
    this.inviteCode,
    this.tags = const [],
    this.isMember = false,
    this.myRole,
    this.creator,
    this.membersSample = const [],
    required this.createdAt,
  });

  factory CommunityCircle.fromJson(Map<String, dynamic> json) {
    List<String> parseTags(dynamic raw) {
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }

    List<CommunityMemberPreview> parseMembersSample(dynamic raw) {
      if (raw is List) {
        return raw
            .map((e) => CommunityMemberPreview.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    return CommunityCircle(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Cercle Voyagooo',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      avatarEmoji: json['avatar_emoji']?.toString() ?? '🧭',
      coverImageUrl: json['cover_image_url']?.toString() ??
          'https://images.unsplash.com/photo-1488646953014-85cb44e25828?auto=format&fit=crop&w=1200&q=80',
      category: json['category']?.toString() ?? 'general',
      destinationCity: json['destination_city']?.toString(),
      destinationCountry: json['destination_country']?.toString(),
      creatorId: json['creator_id']?.toString() ?? '',
      membersCount: (json['members_count'] as num?)?.toInt() ?? 1,
      tripsCount: (json['trips_count'] as num?)?.toInt() ?? 0,
      postsCount: (json['posts_count'] as num?)?.toInt() ?? 0,
      isPublic: json['is_public'] as bool? ?? true,
      inviteCode: json['invite_code']?.toString(),
      tags: parseTags(json['tags']),
      isMember: json['is_member'] as bool? ?? false,
      myRole: json['my_role']?.toString(),
      creator: json['creator'] as Map<String, dynamic>?,
      membersSample: parseMembersSample(json['members_sample']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  CommunityCircle copyWith({
    bool? isMember,
    int? membersCount,
    int? tripsCount,
    int? postsCount,
    String? myRole,
    String? inviteCode,
  }) {
    return CommunityCircle(
      id: id,
      name: name,
      slug: slug,
      description: description,
      avatarEmoji: avatarEmoji,
      coverImageUrl: coverImageUrl,
      category: category,
      destinationCity: destinationCity,
      destinationCountry: destinationCountry,
      creatorId: creatorId,
      membersCount: membersCount ?? this.membersCount,
      tripsCount: tripsCount ?? this.tripsCount,
      postsCount: postsCount ?? this.postsCount,
      isPublic: isPublic,
      inviteCode: inviteCode ?? this.inviteCode,
      tags: tags,
      isMember: isMember ?? this.isMember,
      myRole: myRole ?? this.myRole,
      creator: creator,
      membersSample: membersSample,
      createdAt: createdAt,
    );
  }

  String get locationDisplay {
    if (destinationCity != null && destinationCountry != null) {
      return '$destinationCity, $destinationCountry';
    }
    return destinationCity ?? destinationCountry ?? 'Monde';
  }

  String get categoryLabel {
    switch (category.toLowerCase()) {
      case 'culture':
        return '🏛️ Culture & Histoire';
      case 'adventure':
        return '⛩️ Aventure & Roadtrip';
      case 'nature':
        return '🌿 Nature & Bivouac';
      case 'food':
      case 'gastronomie':
        return '🍷 Gastronomie';
      case 'beach':
      case 'plage':
        return '🏖️ Plage & Soleil';
      default:
        return '🧭 Exploration';
    }
  }
}
