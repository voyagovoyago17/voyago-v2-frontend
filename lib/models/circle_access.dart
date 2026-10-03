// Accès aux cercles privés : conditions, demandes d'adhésion et profils des demandeurs.

/// Une condition d'accès vérifiée pour le voyageur (ok = null si non connecté).
class JoinCheck {
  final String key;
  final String label;
  final bool? ok;
  final String? detail;

  const JoinCheck({required this.key, required this.label, this.ok, this.detail});

  factory JoinCheck.fromJson(Map<String, dynamic> json) => JoinCheck(
        key: json['key']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        ok: json['ok'] as bool?,
        detail: json['detail']?.toString(),
      );

  static List<JoinCheck> listFrom(dynamic raw) => raw is List
      ? raw.whereType<Map>().map((e) => JoinCheck.fromJson(Map<String, dynamic>.from(e))).toList()
      : const [];
}

/// Conditions d'accès d'un cercle (null = pas de condition).
class JoinRules {
  final int? minLevel;
  final int? minAge;
  final bool proOnly;
  final bool verifiedEmail;
  final int? maxMembers;

  const JoinRules({this.minLevel, this.minAge, this.proOnly = false, this.verifiedEmail = false, this.maxMembers});

  factory JoinRules.fromJson(dynamic raw) {
    final json = raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    return JoinRules(
      minLevel: (json['min_level'] as num?)?.toInt(),
      minAge: (json['min_age'] as num?)?.toInt(),
      proOnly: json['pro_only'] == true,
      verifiedEmail: json['verified_email'] == true,
      maxMembers: (json['max_members'] as num?)?.toInt(),
    );
  }

  /// Envoi au serveur : null retire la condition
  Map<String, dynamic> toJson() => {
        'min_level': minLevel,
        'min_age': minAge,
        'pro_only': proOnly,
        'verified_email': verifiedEmail,
        'max_members': maxMembers,
      };

  bool get isEmpty => minLevel == null && minAge == null && !proOnly && !verifiedEmail && maxMembers == null;

  /// Libellés courts pour la carte du cercle
  List<String> get chips => [
        if (minLevel != null) 'Niv. $minLevel+',
        if (minAge != null) '$minAge ans+',
        if (proOnly) 'Pro',
        if (verifiedEmail) 'E-mail vérifié',
        if (maxMembers != null) '$maxMembers places',
      ];

  JoinRules copyWith({
    int? Function()? minLevel,
    int? Function()? minAge,
    bool? proOnly,
    bool? verifiedEmail,
    int? Function()? maxMembers,
  }) =>
      JoinRules(
        minLevel: minLevel != null ? minLevel() : this.minLevel,
        minAge: minAge != null ? minAge() : this.minAge,
        proOnly: proOnly ?? this.proOnly,
        verifiedEmail: verifiedEmail ?? this.verifiedEmail,
        maxMembers: maxMembers != null ? maxMembers() : this.maxMembers,
      );
}

/// Profil d'un voyageur qui demande à rejoindre (vu par le fondateur).
class JoinRequester {
  final String userId;
  final String name;
  final String? pseudo;
  final String avatarEmoji;
  final String? picture;
  final String? country;
  final String? city;
  final int? age;
  final bool isPro;
  final bool emailVerified;
  final DateTime? memberSince;
  final int level;
  final int xp;
  final int tripsCount;
  final int badgesCount;

  const JoinRequester({
    required this.userId,
    required this.name,
    this.pseudo,
    this.avatarEmoji = '🧭',
    this.picture,
    this.country,
    this.city,
    this.age,
    this.isPro = false,
    this.emailVerified = false,
    this.memberSince,
    this.level = 1,
    this.xp = 0,
    this.tripsCount = 0,
    this.badgesCount = 0,
  });

  factory JoinRequester.fromJson(Map<String, dynamic> json) => JoinRequester(
        userId: json['user_id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Voyageur',
        pseudo: json['pseudo']?.toString(),
        avatarEmoji: json['avatar_emoji']?.toString() ?? '🧭',
        picture: json['picture']?.toString(),
        country: json['country']?.toString(),
        city: json['city']?.toString(),
        age: (json['age'] as num?)?.toInt(),
        isPro: json['is_pro'] == true,
        emailVerified: json['email_verified'] == true,
        memberSince: DateTime.tryParse(json['member_since']?.toString() ?? ''),
        level: (json['level'] as num?)?.toInt() ?? 1,
        xp: (json['xp'] as num?)?.toInt() ?? 0,
        tripsCount: (json['trips_count'] as num?)?.toInt() ?? 0,
        badgesCount: (json['badges_count'] as num?)?.toInt() ?? 0,
      );

  String get displayName => pseudo != null && pseudo!.isNotEmpty ? pseudo! : name;

  String? get location => [city, country].where((e) => e != null && e.isNotEmpty).join(', ').ifEmptyNull;
}

class JoinRequest {
  final String id;
  final String status;
  final String message;
  final DateTime? createdAt;
  final bool eligible;
  final List<JoinCheck> checks;
  final JoinRequester user;

  const JoinRequest({
    required this.id,
    required this.status,
    required this.message,
    this.createdAt,
    this.eligible = true,
    this.checks = const [],
    required this.user,
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json) => JoinRequest(
        id: json['id']?.toString() ?? '',
        status: json['status']?.toString() ?? 'pending',
        message: json['message']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal(),
        eligible: json['eligible'] != false,
        checks: JoinCheck.listFrom(json['join_checks']),
        user: JoinRequester.fromJson(Map<String, dynamic>.from(json['user'] as Map? ?? const {})),
      );
}

/// Réponse du serveur à une demande d'adhésion.
class JoinRequestResult {
  /// 'pending' | 'joined' | 'member' | 'refused' (conditions) | 'rejected' (refus récent)
  final String status;
  final String message;
  final List<JoinCheck> checks;

  const JoinRequestResult({required this.status, required this.message, this.checks = const []});

  factory JoinRequestResult.fromJson(Map<String, dynamic> json) => JoinRequestResult(
        status: json['status']?.toString() ?? 'pending',
        message: json['message']?.toString() ?? '',
        checks: JoinCheck.listFrom(json['join_checks']),
      );
}

extension on String {
  String? get ifEmptyNull => isEmpty ? null : this;
}
