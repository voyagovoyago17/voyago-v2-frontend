import 'dart:io';
import 'package:dio/dio.dart';
import '../core/storage/secure_storage_service.dart';
import '../models/auth_user.dart';
import 'dio_client.dart';
import 'endpoints.dart';

class AuthResponse {
  final AuthUser user;
  final String sessionToken;
  final String tenantId;

  AuthResponse({
    required this.user,
    required this.sessionToken,
    required this.tenantId,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
      sessionToken: json['session_token']?.toString() ?? '',
      tenantId: json['tenant_id']?.toString() ?? 'default',
    );
  }
}

class AuthApi {
  final DioClient _client;
  final SecureStorageService _storage;

  AuthApi({DioClient? client, SecureStorageService? storage})
      : _client = client ?? DioClient.instance,
        _storage = storage ?? SecureStorageService.instance;

  /// Inscription par email
  Future<AuthResponse> signupEmail({
    required String email,
    required String password,
    required String name,
    required String dateOfBirth,
    required String country,
    required String city,
    String? pseudo,
    String? avatarEmoji,
    String? tenantId,
  }) async {
    final payload = {
      'email': email.trim().toLowerCase(),
      'password': password,
      'name': name.trim(),
      'date_of_birth': dateOfBirth,
      'country': country.trim(),
      'city': city.trim(),
      if (pseudo != null && pseudo.trim().isNotEmpty) 'pseudo': pseudo.trim(),
      if (avatarEmoji != null && avatarEmoji.isNotEmpty) 'avatar_emoji': avatarEmoji,
      if (tenantId != null && tenantId.isNotEmpty) 'tenant_id': tenantId,
    };

    final data = await _client.post(Endpoints.signupEmail, data: payload);
    final response = AuthResponse.fromJson(data as Map<String, dynamic>);

    // Persist in secure storage
    await _storage.setSessionToken(response.sessionToken);
    await _storage.setUserId(response.user.userId);
    await _storage.setTenantId(response.tenantId);
    await _storage.setAuthUser(response.user);

    return response;
  }

  /// Connexion par email
  Future<AuthResponse> loginEmail({
    required String email,
    required String password,
  }) async {
    final payload = {
      'email': email.trim().toLowerCase(),
      'password': password,
    };

    final data = await _client.post(Endpoints.loginEmail, data: payload);
    final response = AuthResponse.fromJson(data as Map<String, dynamic>);

    // Persist in secure storage
    await _storage.setSessionToken(response.sessionToken);
    await _storage.setUserId(response.user.userId);
    await _storage.setTenantId(response.tenantId);
    await _storage.setAuthUser(response.user);

    return response;
  }

  /// Connexion Google OAuth
  Future<AuthResponse> loginGoogleSession({
    required String idToken,
    required String name,
    required String email,
    String? picture,
  }) async {
    final payload = {
      'id_token': idToken,
      'name': name,
      'email': email.trim().toLowerCase(),
      if (picture != null) 'picture': picture,
    };

    final data = await _client.post(Endpoints.googleSession, data: payload);
    final response = AuthResponse.fromJson(data as Map<String, dynamic>);

    // Persist in secure storage
    await _storage.setSessionToken(response.sessionToken);
    await _storage.setUserId(response.user.userId);
    await _storage.setTenantId(response.tenantId);
    await _storage.setAuthUser(response.user);

    return response;
  }

  /// Connexion Invité (Guest)
  Future<AuthResponse> loginGuest({String? guestId}) async {
    final payload = {
      if (guestId != null && guestId.isNotEmpty) ...{
        'user_id': guestId,
        'guest_id': guestId,
      },
    };

    final data = await _client.post(Endpoints.guestLogin, data: payload);
    final response = AuthResponse.fromJson(data as Map<String, dynamic>);

    // Persist in secure storage
    await _storage.setSessionToken(response.sessionToken);
    await _storage.setUserId(response.user.userId);
    await _storage.setTenantId(response.tenantId);
    await _storage.setAuthUser(response.user);

    return response;
  }

  /// Demande de réinitialisation de mot de passe (Envoi du code OTP via Resend)
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final data = await _client.post(
      Endpoints.forgotPassword,
      data: {'email': email.trim().toLowerCase()},
    );
    return data as Map<String, dynamic>;
  }

  /// Confirmation de réinitialisation avec code OTP et nouveau mot de passe
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final data = await _client.post(
      Endpoints.resetPassword,
      data: {
        'email': email.trim().toLowerCase(),
        'code': code.trim(),
        'new_password': newPassword,
      },
    );
    return data as Map<String, dynamic>;
  }

  /// Profil à jour depuis le serveur (mis en cache)
  Future<AuthUser> getMe() async {
    final data = await _client.get(Endpoints.me);
    final json = data is Map<String, dynamic> && data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : data as Map<String, dynamic>;
    final user = AuthUser.fromJson(json);
    await _storage.setAuthUser(user);
    return user;
  }

  /// Envoie (ou renvoie) le code de vérification de l'adresse e-mail.
  /// Réponse : sent, email, cooldown_seconds, already_verified, message
  Future<Map<String, dynamic>> sendEmailVerification() async {
    final data = await _client.post(Endpoints.emailVerificationSend);
    return data as Map<String, dynamic>;
  }

  /// Confirme l'adresse avec le code reçu ; renvoie le compte à jour et l'XP gagnée
  Future<({AuthUser user, int xpAwarded})> confirmEmailVerification(String code) async {
    final data = await _client.post(Endpoints.emailVerificationConfirm, data: {'code': code.trim()}) as Map<String, dynamic>;
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    await _storage.setAuthUser(user);
    return (user: user, xpAwarded: (data['xp_awarded'] as num?)?.toInt() ?? 0);
  }

  /// Liste des pays et catalogue des emojis d'avatars
  Future<Map<String, dynamic>> getAuthOptions() async {
    final data = await _client.get(Endpoints.authOptions);
    return data as Map<String, dynamic>;
  }

  /// Mise à jour du profil utilisateur
  Future<AuthUser> updateProfile({
    String? name,
    String? pseudo,
    String? avatarEmoji,
    String? dateOfBirth,
    String? gender,
    String? thermalSensitivity,
    bool? onboardingCompleted,
    String? country,
    String? city,
  }) async {
    final payload = {
      if (name != null) 'name': name.trim(),
      if (pseudo != null) 'pseudo': pseudo.trim(),
      if (avatarEmoji != null) 'avatar_emoji': avatarEmoji,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth.trim(),
      if (gender != null) 'gender': gender.trim(),
      if (thermalSensitivity != null) 'thermal_sensitivity': thermalSensitivity.trim(),
      if (onboardingCompleted != null) 'onboarding_completed': onboardingCompleted,
      if (country != null) 'country': country.trim(),
      if (city != null) 'city': city.trim(),
    };

    final data = await _client.put(Endpoints.updateProfile, data: payload);
    final Map<String, dynamic> userMap;
    if (data is Map<String, dynamic>) {
      userMap = (data['user'] is Map<String, dynamic>)
          ? (data['user'] as Map<String, dynamic>)
          : data;
    } else {
      userMap = <String, dynamic>{};
    }

    final updatedUser = AuthUser.fromJson(userMap);
    await _storage.setAuthUser(updatedUser);
    return updatedUser;
  }

  /// Uploader une photo de profil via UploadThing
  Future<AuthUser> uploadProfilePicture(File imageFile) async {
    final fileName = imageFile.path.split(Platform.pathSeparator).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imageFile.path,
        filename: fileName,
      ),
    });

    final data = await _client.post(
      Endpoints.uploadProfilePicture,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    final Map<String, dynamic> userMap;
    if (data is Map<String, dynamic>) {
      userMap = (data['user'] is Map<String, dynamic>)
          ? (data['user'] as Map<String, dynamic>)
          : data;
    } else {
      userMap = <String, dynamic>{};
    }

    final updatedUser = AuthUser.fromJson(userMap);
    await _storage.setAuthUser(updatedUser);
    return updatedUser;
  }

  /// Supprimer la photo de profil (UploadThing + BD) et revenir à l'avatar emoji
  Future<AuthUser> deleteProfilePicture() async {
    final data = await _client.delete(Endpoints.uploadProfilePicture);
    final Map<String, dynamic> userMap;
    if (data is Map<String, dynamic>) {
      userMap = (data['user'] is Map<String, dynamic>)
          ? (data['user'] as Map<String, dynamic>)
          : data;
    } else {
      userMap = <String, dynamic>{};
    }

    final updatedUser = AuthUser.fromJson(userMap);
    await _storage.setAuthUser(updatedUser);
    return updatedUser;
  }

  /// Déconnexion
  Future<void> logout() async {
    await _storage.clearAuth();
  }
}
