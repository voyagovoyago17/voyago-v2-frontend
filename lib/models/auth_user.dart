enum ThermalSensitivity {
  cold('cold', 'Runs Cold', 'Frileux', 'ac_unit'),
  balanced('balanced', 'Balanced', 'Équilibré', 'checkroom'),
  warm('warm', 'Runs Warm', 'Chaleureux', 'wb_sunny');

  final String value;
  final String label;
  final String labelFr;
  final String iconName;
  const ThermalSensitivity(this.value, this.label, this.labelFr, this.iconName);

  static ThermalSensitivity fromString(String? val) {
    if (val == null) return ThermalSensitivity.balanced;
    for (final s in ThermalSensitivity.values) {
      if (s.value == val.toLowerCase()) return s;
    }
    return ThermalSensitivity.balanced;
  }
}

enum UserGender {
  male('male', 'Homme'),
  female('female', 'Femme'),
  other('other', 'Autre'),
  preferNotToSay('prefer_not_to_say', 'Préfère ne pas dire');

  final String value;
  final String label;
  const UserGender(this.value, this.label);

  static UserGender fromString(String? val) {
    if (val == null) return UserGender.preferNotToSay;
    for (final g in UserGender.values) {
      if (g.value == val.toLowerCase()) return g;
    }
    return UserGender.preferNotToSay;
  }
}

class AuthUser {
  final String userId;
  final String authProvider;
  final String name;
  final String? email;
  final String? picture;
  final String? pseudo;
  final String? avatarEmoji;
  final String? dateOfBirth;
  final UserGender gender;
  final ThermalSensitivity thermalSensitivity;
  final bool onboardingCompleted;
  final String? country;
  final String? city;
  final bool isPro;
  final String? proTier;
  final DateTime? proExpiresAt;

  /// Abonnement Pro réellement valide (même règle que le serveur : 3 jours de grâce
  /// après l'échéance, pas d'échéance = à vie). `isPro` seul ignore l'échéance.
  bool get isProActive {
    if (!isPro) return false;
    final expiresAt = proExpiresAt;
    if (expiresAt == null) return true;
    return expiresAt.add(const Duration(days: 3)).isAfter(DateTime.now());
  }

  const AuthUser({
    required this.userId,
    required this.authProvider,
    required this.name,
    this.email,
    this.picture,
    this.pseudo,
    this.avatarEmoji,
    this.dateOfBirth,
    this.gender = UserGender.preferNotToSay,
    this.thermalSensitivity = ThermalSensitivity.balanced,
    this.onboardingCompleted = false,
    this.country,
    this.city,
    required this.isPro,
    this.proTier,
    this.proExpiresAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      userId: json['user_id']?.toString() ??
          json['userId']?.toString() ??
          json['id']?.toString() ??
          '',
      authProvider:
          json['auth_provider']?.toString() ?? json['authProvider']?.toString() ?? 'email',
      name: json['name']?.toString() ?? 'Voyageur',
      email: json['email']?.toString(),
      picture: json['picture']?.toString(),
      pseudo: json['pseudo']?.toString(),
      avatarEmoji: json['avatar_emoji']?.toString() ?? json['avatarEmoji']?.toString(),
      dateOfBirth: json['date_of_birth']?.toString() ?? json['dateOfBirth']?.toString(),
      gender: UserGender.fromString(json['gender']?.toString()),
      thermalSensitivity: ThermalSensitivity.fromString(
        json['thermal_sensitivity']?.toString() ?? json['thermalSensitivity']?.toString(),
      ),
      onboardingCompleted: json['onboarding_completed'] as bool? ??
          json['onboardingCompleted'] as bool? ??
          false,
      country: json['country']?.toString(),
      city: json['city']?.toString(),
      isPro: json['is_pro'] as bool? ?? json['isPro'] as bool? ?? false,
      proTier: json['pro_tier']?.toString() ?? json['proTier']?.toString(),
      proExpiresAt: json['pro_expires_at'] != null
          ? DateTime.tryParse(json['pro_expires_at'].toString())
          : json['proExpiresAt'] != null
              ? DateTime.tryParse(json['proExpiresAt'].toString())
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'auth_provider': authProvider,
      'name': name,
      if (email != null) 'email': email,
      if (picture != null) 'picture': picture,
      if (pseudo != null) 'pseudo': pseudo,
      if (avatarEmoji != null) 'avatar_emoji': avatarEmoji,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
      'gender': gender.value,
      'thermal_sensitivity': thermalSensitivity.value,
      'onboarding_completed': onboardingCompleted,
      if (country != null) 'country': country,
      if (city != null) 'city': city,
      'is_pro': isPro,
      if (proTier != null) 'pro_tier': proTier,
      if (proExpiresAt != null) 'pro_expires_at': proExpiresAt!.toIso8601String(),
    };
  }

  AuthUser copyWith({
    String? name,
    String? pseudo,
    String? avatarEmoji,
    String? picture,
    bool clearPicture = false,
    String? dateOfBirth,
    UserGender? gender,
    ThermalSensitivity? thermalSensitivity,
    bool? onboardingCompleted,
    String? country,
    String? city,
    bool? isPro,
    String? proTier,
  }) {
    return AuthUser(
      userId: userId,
      authProvider: authProvider,
      name: name ?? this.name,
      email: email,
      picture: clearPicture ? null : (picture ?? this.picture),
      pseudo: pseudo ?? this.pseudo,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      thermalSensitivity: thermalSensitivity ?? this.thermalSensitivity,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      country: country ?? this.country,
      city: city ?? this.city,
      isPro: isPro ?? this.isPro,
      proTier: proTier ?? this.proTier,
      proExpiresAt: proExpiresAt,
    );
  }

  String get displayName => pseudo ?? name;

  String get avatarDisplay => avatarEmoji ?? '🦜';
}
