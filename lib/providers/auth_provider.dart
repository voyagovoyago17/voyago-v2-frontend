import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../api/api.dart';
import '../core/storage/secure_storage_service.dart';
import '../models/auth_user.dart';

class AuthState {
  final AuthUser? user;
  final String? token;
  final bool isLoading;
  final String? error;
  final bool sessionLoaded;

  const AuthState({
    this.user,
    this.token,
    this.isLoading = false,
    this.error,
    this.sessionLoaded = false,
  });

  bool get isLoggedIn => user != null && token != null && token!.isNotEmpty;
  bool get isGuest => !isLoggedIn;
  String get userId => user?.userId ?? '';

  AuthState copyWith({
    AuthUser? user,
    String? token,
    bool? isLoading,
    String? error,
    bool? sessionLoaded,
    bool clearUser = false,
    bool clearToken = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      token: clearToken ? null : (token ?? this.token),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      sessionLoaded: sessionLoaded ?? this.sessionLoaded,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthApi _authApi;
  final SecureStorageService _storage;

  AuthNotifier({
    AuthApi? authApi,
    SecureStorageService? storage,
  })  : _authApi = authApi ?? AuthApi(),
        _storage = storage ?? SecureStorageService.instance,
        super(const AuthState()) {
    // Intercepter la déconnexion automatique en cas de 401 Unauthorized
    DioClient.instance.onAuthExpired = () {
      logout();
    };
    loadSession();
  }

  /// Initialise la session au démarrage depuis le stockage chiffré
  Future<void> loadSession() async {
    try {
      final token = await _storage.getSessionToken();
      final userId = await _storage.getUserId();
      final cachedUser = await _storage.getAuthUser();

      if (token != null && token.isNotEmpty && userId != null && userId.isNotEmpty) {
        state = AuthState(
          user: cachedUser ?? AuthUser(
            userId: userId,
            authProvider: 'email',
            name: 'Voyageur',
            isPro: false,
          ),
          token: token,
          sessionLoaded: true,
          isLoading: false,
        );
        // Rafraîchit le compte en arrière-plan (ex. statut « e-mail vérifié »)
        refreshMe();
        return;
      }

      // S'assurer qu'un identifiant invité valide existe
      var guestId = await _storage.getGuestUserId();
      if (guestId == null || guestId.isEmpty || !guestId.startsWith('guest_')) {
        guestId = 'guest_${const Uuid().v4()}';
        await _storage.setGuestUserId(guestId);
      }

      state = const AuthState(sessionLoaded: true, isLoading: false);
    } catch (e) {
      state = AuthState(
        sessionLoaded: true,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Recharge le compte depuis le serveur, sans bloquer ni afficher d'erreur
  Future<void> refreshMe() async {
    try {
      final user = await _authApi.getMe();
      if (state.isLoggedIn) state = state.copyWith(user: user);
    } catch (_) {}
  }

  /// Envoie le code de vérification de l'adresse e-mail
  Future<Map<String, dynamic>> sendEmailVerification() => _authApi.sendEmailVerification();

  /// Confirme l'adresse e-mail ; renvoie l'XP gagnée
  Future<int> confirmEmailVerification(String code) async {
    final res = await _authApi.confirmEmailVerification(code);
    state = state.copyWith(user: res.user);
    return res.xpAwarded;
  }

  /// Connexion Email
  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _authApi.loginEmail(
        email: email,
        password: password,
      );

      state = AuthState(
        user: result.user,
        token: result.sessionToken,
        sessionLoaded: true,
        isLoading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Inscription Email
  Future<void> signup({
    required String name,
    required String email,
    required String password,
    required String dateOfBirth,
    required String country,
    required String city,
    String? pseudo,
    String? avatarEmoji,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _authApi.signupEmail(
        name: name,
        email: email,
        password: password,
        dateOfBirth: dateOfBirth,
        country: country,
        city: city,
        pseudo: pseudo,
        avatarEmoji: avatarEmoji,
      );

      state = AuthState(
        user: result.user,
        token: result.sessionToken,
        sessionLoaded: true,
        isLoading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Connexion Google OAuth
  Future<void> loginGoogle({
    required String idToken,
    required String name,
    required String email,
    String? picture,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _authApi.loginGoogleSession(
        idToken: idToken,
        name: name,
        email: email,
        picture: picture,
      );

      state = AuthState(
        user: result.user,
        token: result.sessionToken,
        sessionLoaded: true,
        isLoading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Connexion Mode Invité (Guest)
  Future<void> loginGuest() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      var guestId = await _storage.getGuestUserId();
      if (guestId == null || guestId.isEmpty || !guestId.startsWith('guest_')) {
        guestId = 'guest_${const Uuid().v4()}';
        await _storage.setGuestUserId(guestId);
      }
      final result = await _authApi.loginGuest(guestId: guestId);

      state = AuthState(
        user: result.user,
        token: result.sessionToken,
        sessionLoaded: true,
        isLoading: false,
      );
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Envoi de code OTP pour mot de passe oublié
  Future<Map<String, dynamic>> forgotPassword(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _authApi.forgotPassword(email);
      state = state.copyWith(isLoading: false);
      return result;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Réinitialisation du mot de passe avec code OTP
  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _authApi.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      state = state.copyWith(isLoading: false);
      return result;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Mise à jour du profil utilisateur
  Future<void> updateProfile([
    Map<String, dynamic>? data,
  ]) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _authApi.updateProfile(
        name: data?['name']?.toString(),
        pseudo: data?['pseudo']?.toString(),
        avatarEmoji: data?['avatar_emoji']?.toString() ?? data?['avatarEmoji']?.toString(),
        dateOfBirth: data?['date_of_birth']?.toString() ?? data?['dateOfBirth']?.toString(),
        gender: data?['gender']?.toString(),
        thermalSensitivity: data?['thermal_sensitivity']?.toString() ?? data?['thermalSensitivity']?.toString(),
        onboardingCompleted: data?['onboarding_completed'] as bool? ?? data?['onboardingCompleted'] as bool?,
        country: data?['country']?.toString(),
        city: data?['city']?.toString(),
      );
      state = state.copyWith(user: updated, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Finalisation de l'onboarding obligatoire (Date de naissance, Genre, Sensibilité thermique)
  Future<void> completeOnboarding({
    required String dateOfBirth,
    required UserGender gender,
    required ThermalSensitivity thermalSensitivity,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _authApi.updateProfile(
        dateOfBirth: dateOfBirth,
        gender: gender.value,
        thermalSensitivity: thermalSensitivity.value,
        onboardingCompleted: true,
      );
      state = state.copyWith(user: updated, isLoading: false);
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Uploader une photo de profil via UploadThing
  Future<AuthUser> uploadProfilePicture(File imageFile) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _authApi.uploadProfilePicture(imageFile);
      state = state.copyWith(user: updated, isLoading: false);
      return updated;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Supprimer la photo de profil et rétablir l'avatar emoji
  Future<AuthUser> deleteProfilePicture() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _authApi.deleteProfilePicture();
      state = state.copyWith(user: updated, isLoading: false);
      return updated;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      rethrow;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  /// Déconnexion complète
  Future<void> logout() async {
    try {
      await _authApi.logout();
    } catch (_) {}
    await _storage.clearAuth();
    state = const AuthState(sessionLoaded: true, isLoading: false);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Provider Principal d'Authentification
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

/// Provider Raccourci pour l'utilisateur courant
final currentUserProvider = Provider<AuthUser?>((ref) {
  return ref.watch(authProvider).user;
});

/// Provider Raccourci pour le statut connecté
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoggedIn;
});
