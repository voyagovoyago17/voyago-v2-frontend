import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../models/auth_user.dart';

class SecureStorageService {
  static const String _keySessionToken = 'voyago_session_token';
  static const String _keyUserId = 'voyago_user_id';
  static const String _keyTenantId = 'voyago_tenant_id';
  static const String _keyAuthUser = 'voyago_auth_user';
  static const String _keyGuestUserId = 'voyago_guest_user_id';
  static const String _defaultTenantId = 'default';

  static SecureStorageService? _instance;
  late final FlutterSecureStorage _storage;

  SecureStorageService._() {
    _storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
        resetOnError: true,
      ),
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      ),
    );
  }

  static SecureStorageService get instance {
    _instance ??= SecureStorageService._();
    return _instance!;
  }

  // --- SESSION TOKEN ---
  Future<String?> getSessionToken() async {
    try {
      return await _storage.read(key: _keySessionToken);
    } catch (_) {
      return null;
    }
  }

  Future<void> setSessionToken(String token) async {
    await _storage.write(key: _keySessionToken, value: token);
  }

  Future<void> clearSessionToken() async {
    await _storage.delete(key: _keySessionToken);
  }

  // --- USER ID ---
  Future<String?> getUserId() async {
    try {
      return await _storage.read(key: _keyUserId);
    } catch (_) {
      return null;
    }
  }

  Future<void> setUserId(String userId) async {
    await _storage.write(key: _keyUserId, value: userId);
  }

  Future<void> clearUserId() async {
    await _storage.delete(key: _keyUserId);
  }

  // --- TENANT ID ---
  Future<String> getTenantId() async {
    try {
      final tenant = await _storage.read(key: _keyTenantId);
      return tenant ?? _defaultTenantId;
    } catch (_) {
      return _defaultTenantId;
    }
  }

  Future<void> setTenantId(String tenantId) async {
    await _storage.write(key: _keyTenantId, value: tenantId);
  }

  Future<void> clearTenantId() async {
    await _storage.delete(key: _keyTenantId);
  }

  // --- GUEST USER ID ---
  Future<String?> getGuestUserId() async {
    try {
      return await _storage.read(key: _keyGuestUserId);
    } catch (_) {
      return null;
    }
  }

  Future<void> setGuestUserId(String guestId) async {
    await _storage.write(key: _keyGuestUserId, value: guestId);
  }

  // --- AUTH USER CACHE ---
  Future<AuthUser?> getAuthUser() async {
    try {
      final jsonStr = await _storage.read(key: _keyAuthUser);
      if (jsonStr == null || jsonStr.isEmpty) return null;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return AuthUser.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> setAuthUser(AuthUser user) async {
    final jsonStr = jsonEncode(user.toJson());
    await _storage.write(key: _keyAuthUser, value: jsonStr);
  }

  Future<void> clearAuthUser() async {
    await _storage.delete(key: _keyAuthUser);
  }

  // --- CLEAR ALL AUTH CREDENTIALS ---
  Future<void> clearAuth() async {
    await Future.wait([
      clearSessionToken(),
      clearUserId(),
      clearAuthUser(),
    ]);
  }

  // --- CLEAR SESSION LIÉE AU BACKEND (changement local <-> prod) ---
  Future<void> clearBackendSession() async {
    await Future.wait([
      clearAuth(),
      clearTenantId(),
      _storage.delete(key: _keyGuestUserId),
    ]);
  }

  // --- CLEAR COMPLETE STORAGE ---
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
