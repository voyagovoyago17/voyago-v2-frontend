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

  /// Pays autorisés (vide = tous)
  final List<String> countries;

  const JoinRules({
    this.minLevel,
    this.minAge,
    this.proOnly = false,
    this.verifiedEmail = false,
    this.maxMembers,
    this.countries = const [],
  });

  factory JoinRules.fromJson(dynamic raw) {
    final json = raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    return JoinRules(
      minLevel: (json['min_level'] as num?)?.toInt(),
      minAge: (json['min_age'] as num?)?.toInt(),
      proOnly: json['pro_only'] == true,
      verifiedEmail: json['verified_email'] == true,
      maxMembers: (json['max_members'] as num?)?.toInt(),
      countries: json['countries'] is List ? (json['countries'] as List).map((e) => e.toString()).toList() : const [],
    );
  }

  /// Envoi au serveur : null retire la condition
  Map<String, dynamic> toJson() => {
        'min_level': minLevel,
        'min_age': minAge,
        'pro_only': proOnly,
        'verified_email': verifiedEmail,
        'max_members': maxMembers,
        'countries': countries,
      };

  bool get isEmpty =>
      minLevel == null && minAge == null && !proOnly && !verifiedEmail && maxMembers == null && countries.isEmpty;

  /// Libellés courts pour la carte du cercle
  List<String> get chips => [
        if (minLevel != null) 'Niv. $minLevel+',
        if (minAge != null) '$minAge ans+',
        if (proOnly) 'Pro',
        if (verifiedEmail) 'E-mail vérifié',
        if (maxMembers != null) '$maxMembers places',
        if (countries.length == 1) '📍 ${countries.first}',
        if (countries.length > 1) '📍 ${countries.length} pays',
      ];

  JoinRules copyWith({
    int? Function()? minLevel,
    int? Function()? minAge,
    bool? proOnly,
    bool? verifiedEmail,
    int? Function()? maxMembers,
    List<String>? countries,
  }) =>
      JoinRules(
        minLevel: minLevel != null ? minLevel() : this.minLevel,
        minAge: minAge != null ? minAge() : this.minAge,
        proOnly: proOnly ?? this.proOnly,
        verifiedEmail: verifiedEmail ?? this.verifiedEmail,
        maxMembers: maxMembers != null ? maxMembers() : this.maxMembers,
        countries: countries ?? this.countries,
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

  /// Membres qui se portent garants (prénom/pseudo + emoji)
  final List<({String userId, String name, String emoji})> vouches;
  final bool iVouched;

  const JoinRequest({
    required this.id,
    required this.status,
    required this.message,
    this.createdAt,
    this.eligible = true,
    this.checks = const [],
    required this.user,
    this.vouches = const [],
    this.iVouched = false,
  });

  factory JoinRequest.fromJson(Map<String, dynamic> json) => JoinRequest(
        id: json['id']?.toString() ?? '',
        status: json['status']?.toString() ?? 'pending',
        message: json['message']?.toString() ?? '',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal(),
        eligible: json['eligible'] != false,
        checks: JoinCheck.listFrom(json['join_checks']),
        user: JoinRequester.fromJson(Map<String, dynamic>.from(json['user'] as Map? ?? const {})),
        vouches: (json['vouches'] as List? ?? [])
            .whereType<Map>()
            .map((v) => (
                  userId: v['user_id']?.toString() ?? '',
                  name: v['name']?.toString() ?? 'Membre',
                  emoji: v['avatar_emoji']?.toString() ?? '🧭',
                ))
            .toList(),
        iVouched: json['i_vouched'] == true,
      );
}

/// Demandes d'un cercle vues par un membre (canDecide = fondateur / admin).
class JoinRequestsPage {
  final List<JoinRequest> requests;
  final String question;
  final bool canDecide;

  const JoinRequestsPage({required this.requests, this.question = '', this.canDecide = false});

  factory JoinRequestsPage.fromJson(Map<String, dynamic> json) => JoinRequestsPage(
        requests: (json['requests'] as List? ?? [])
            .whereType<Map>()
            .map((e) => JoinRequest.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        question: json['join_question']?.toString() ?? '',
        canDecide: json['can_decide'] == true,
      );
}

/// Code d'invitation à usage limité.
class CircleInviteCode {
  final String code;
  final String label;
  final int? maxUses;
  final int uses;
  final DateTime? expiresAt;

  /// 'active' | 'expired' | 'exhausted' | 'revoked'
  final String status;

  const CircleInviteCode({
    required this.code,
    this.label = '',
    this.maxUses,
    this.uses = 0,
    this.expiresAt,
    this.status = 'active',
  });

  factory CircleInviteCode.fromJson(Map<String, dynamic> json) => CircleInviteCode(
        code: json['code']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        maxUses: (json['max_uses'] as num?)?.toInt(),
        uses: (json['uses'] as num?)?.toInt() ?? 0,
        expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? '')?.toLocal(),
        status: json['status']?.toString() ?? 'active',
      );

  bool get isActive => status == 'active';
}

/// Un de mes cercles (menu Paramètres des tribus).
class MyCircle {
  final String id;
  final String name;
  final String avatarEmoji;
  final bool isPublic;
  final bool listed;
  final String myRole;
  final int membersCount;
  final JoinRules joinRules;
  final bool autoApprove;
  final int trialDays;
  final DateTime? trialUntil;
  final int pendingRequestsCount;
  final bool canManage;

  const MyCircle({
    required this.id,
    required this.name,
    this.avatarEmoji = '🧭',
    this.isPublic = true,
    this.listed = true,
    this.myRole = 'explorer',
    this.membersCount = 0,
    this.joinRules = const JoinRules(),
    this.autoApprove = false,
    this.trialDays = 0,
    this.trialUntil,
    this.pendingRequestsCount = 0,
    this.canManage = false,
  });

  factory MyCircle.fromJson(Map<String, dynamic> json) => MyCircle(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Cercle',
        avatarEmoji: json['avatar_emoji']?.toString() ?? '🧭',
        isPublic: json['is_public'] == true,
        listed: json['listed'] != false,
        myRole: json['my_role']?.toString() ?? 'explorer',
        membersCount: (json['members_count'] as num?)?.toInt() ?? 0,
        joinRules: JoinRules.fromJson(json['join_rules']),
        autoApprove: json['auto_approve'] == true,
        trialDays: (json['trial_days'] as num?)?.toInt() ?? 0,
        trialUntil: DateTime.tryParse(json['trial_until']?.toString() ?? '')?.toLocal(),
        pendingRequestsCount: (json['pending_requests_count'] as num?)?.toInt() ?? 0,
        canManage: json['can_manage'] == true,
      );

  String get visibilityLabel => isPublic ? 'Public' : (listed ? 'Privé · sur demande' : 'Secret · sur code');
}

/// Une de mes demandes d'adhésion.
class MyJoinRequest {
  final String id;
  final String circleId;
  final String circleName;
  final String circleEmoji;
  final String status;
  final DateTime? createdAt;
  final int vouchesCount;

  const MyJoinRequest({
    required this.id,
    required this.circleId,
    required this.circleName,
    this.circleEmoji = '🧭',
    this.status = 'pending',
    this.createdAt,
    this.vouchesCount = 0,
  });

  factory MyJoinRequest.fromJson(Map<String, dynamic> json) => MyJoinRequest(
        id: json['id']?.toString() ?? '',
        circleId: json['circle_id']?.toString() ?? '',
        circleName: json['circle_name']?.toString() ?? 'Cercle',
        circleEmoji: json['circle_emoji']?.toString() ?? '🧭',
        status: json['status']?.toString() ?? 'pending',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal(),
        vouchesCount: (json['vouches_count'] as num?)?.toInt() ?? 0,
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

/// Membre d'un cercle (liste complète, réservée aux membres).
class CircleMember {
  final String userId;
  final String role;
  final String name;
  final String? pseudo;
  final String avatarEmoji;
  final String? picture;
  final String? country;
  final bool isPro;
  final bool emailVerified;
  final int level;
  final DateTime? joinedAt;

  const CircleMember({
    required this.userId,
    required this.role,
    required this.name,
    this.pseudo,
    this.avatarEmoji = '🧭',
    this.picture,
    this.country,
    this.isPro = false,
    this.emailVerified = false,
    this.level = 1,
    this.joinedAt,
  });

  factory CircleMember.fromJson(Map<String, dynamic> json) => CircleMember(
        userId: json['user_id']?.toString() ?? '',
        role: json['role']?.toString() ?? 'explorer',
        name: json['name']?.toString() ?? 'Voyageur',
        pseudo: json['pseudo']?.toString(),
        avatarEmoji: json['avatar_emoji']?.toString() ?? '🧭',
        picture: json['picture']?.toString(),
        country: json['country']?.toString(),
        isPro: json['is_pro'] == true,
        emailVerified: json['email_verified'] == true,
        level: (json['level'] as num?)?.toInt() ?? 1,
        joinedAt: DateTime.tryParse(json['joined_at']?.toString() ?? '')?.toLocal(),
      );

  String get displayName => pseudo != null && pseudo!.isNotEmpty ? pseudo! : name;
  bool get isCreator => role == 'creator';
  bool get isAdmin => role == 'admin';

  CircleMember withRole(String newRole) => CircleMember(
        userId: userId,
        role: newRole,
        name: name,
        pseudo: pseudo,
        avatarEmoji: avatarEmoji,
        picture: picture,
        country: country,
        isPro: isPro,
        emailVerified: emailVerified,
        level: level,
        joinedAt: joinedAt,
      );
}

class CircleMembersPage {
  final List<CircleMember> members;
  final int total;
  final int? maxMembers;
  final String? myRole;
  final bool hasMore;

  const CircleMembersPage({required this.members, required this.total, this.maxMembers, this.myRole, this.hasMore = false});

  factory CircleMembersPage.fromJson(Map<String, dynamic> json) => CircleMembersPage(
        members: (json['members'] as List? ?? [])
            .whereType<Map>()
            .map((e) => CircleMember.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        total: (json['total'] as num?)?.toInt() ?? 0,
        maxMembers: (json['max_members'] as num?)?.toInt(),
        myRole: json['my_role']?.toString(),
        hasMore: json['has_more'] == true,
      );
}
