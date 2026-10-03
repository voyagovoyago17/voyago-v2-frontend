import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../storage/secure_storage_service.dart';

/// Environnements backend disponibles pour l'application.
enum AppEnvironment {
  local('LOCAL'),
  production('PROD');

  const AppEnvironment(this.label);
  final String label;
}

/// Détermine l'environnement courant et l'URL du backend associée.
///
/// Choix de l'environnement (par ordre de priorité) :
/// 1. `--dart-define=APP_ENV=prod` ou `--dart-define=APP_ENV=local`
/// 2. Sinon : build release → production, debug/profile → local
///
/// `--dart-define=BACKEND_URL=...` surcharge l'URL (ex. IP Wi-Fi locale).
class AppConfig {
  AppConfig._();

  static const String _envDefine = String.fromEnvironment('APP_ENV');
  static const String _backendUrlOverride = String.fromEnvironment('BACKEND_URL');

  // Hôtes Backend
  static const String productionBackendUrl = 'https://api.voyagooo.com';
  // Port NestJS local : 3333
  static const String localNetworkBackendUrl = 'http://192.168.1.81:3333';
  static const String androidEmulatorBackendUrl = 'http://10.0.2.2:3333';
  static const String localhostBackendUrl = 'http://127.0.0.1:3333';

  // false = Tunnel USB adb reverse (recommandé en développement avec câble, insensible au pare-feu/Wi-Fi)
  // true = IP locale Wi-Fi (nécessite d'autoriser le port 3333 dans le pare-feu Windows)
  static const bool useLanIpForDevice = false;

  static bool? _isEmulatorCached;

  /// Détecte automatiquement si l'application s'exécute sur l'émulateur Android officiel (QEMU / Ranchu).
  static bool get isAndroidEmulator {
    if (kIsWeb || !Platform.isAndroid) return false;
    if (_isEmulatorCached != null) return _isEmulatorCached!;
    try {
      final qemu = Process.runSync('getprop', ['ro.kernel.qemu']);
      if (qemu.stdout.toString().trim() == '1') {
        _isEmulatorCached = true;
        return true;
      }
      final hardware = Process.runSync('getprop', ['ro.hardware']);
      final hw = hardware.stdout.toString().trim().toLowerCase();
      if (hw.contains('goldfish') || hw.contains('ranchu')) {
        _isEmulatorCached = true;
        return true;
      }
      final model = Process.runSync('getprop', ['ro.product.model']);
      final m = model.stdout.toString().trim().toLowerCase();
      if (m.contains('sdk') || m.contains('emulator')) {
        _isEmulatorCached = true;
        return true;
      }
    } catch (_) {}
    _isEmulatorCached = false;
    return false;
  }

  static AppEnvironment get environment {
    switch (_envDefine.toLowerCase()) {
      case 'prod':
      case 'production':
        return AppEnvironment.production;
      case 'local':
      case 'dev':
      case 'development':
        return AppEnvironment.local;
    }
    return kReleaseMode ? AppEnvironment.production : AppEnvironment.local;
  }

  static bool get isProduction => environment == AppEnvironment.production;
  static bool get isLocal => environment == AppEnvironment.local;

  static String get backendUrl {
    if (_backendUrlOverride.isNotEmpty) {
      return _backendUrlOverride;
    }
    if (isProduction) {
      return productionBackendUrl;
    }
    if (!kIsWeb && Platform.isAndroid) {
      // 1. Émulateur Android : 10.0.2.2 est l'alias natif du localhost de la machine hôte
      if (isAndroidEmulator) {
        return androidEmulatorBackendUrl;
      }
      // 2. Téléphone physique sur Wi-Fi LAN
      if (useLanIpForDevice) {
        return localNetworkBackendUrl;
      }
      // 3. Téléphone physique sur câble USB (tunnel adb reverse)
      return localhostBackendUrl;
    }
    return localhostBackendUrl;
  }

  static const String _keyLastBackendUrl = 'voyago_last_backend_url';

  /// Une session créée sur un backend (local) n'existe pas sur l'autre (prod) :
  /// si l'URL du backend a changé depuis le dernier lancement, on purge la session.
  static Future<void> ensureSessionMatchesBackend() async {
    final url = backendUrl;
    debugPrint('🌍 [ENV] ${environment.label} -> $url');
    try {
      final prefs = await SharedPreferences.getInstance();
      final previousUrl = prefs.getString(_keyLastBackendUrl);
      if (previousUrl != null && previousUrl != url) {
        debugPrint('🌍 [ENV] Backend changé ($previousUrl -> $url) : session réinitialisée');
        await SecureStorageService.instance.clearBackendSession();
        await Future.wait([
          prefs.remove('session_token'),
          prefs.remove('user_id'),
          prefs.remove('guest_user_id'),
        ]);
      }
      await prefs.setString(_keyLastBackendUrl, url);
    } catch (e) {
      debugPrint('🌍 [ENV] Vérification de session impossible : $e');
    }
  }
}
