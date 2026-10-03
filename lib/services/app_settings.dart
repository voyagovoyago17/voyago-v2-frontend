import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Comment le téléphone se manifeste à chaque notification.
enum NotifMode {
  sound('sound', 'Son + vibration'),
  vibrate('vibrate', 'Vibration seule'),
  silent('silent', 'Silencieux');

  const NotifMode(this.value, this.label);
  final String value;
  final String label;

  static NotifMode fromValue(String? v) => NotifMode.values.firstWhere((m) => m.value == v, orElse: () => NotifMode.sound);
}

/// App ouverte au moment de « Y aller ».
enum NavApp {
  ask('ask', 'Demander à chaque fois'),
  voyagooo('voyagooo', 'Voyagooo (sur la carte)'),
  google('google', 'Google Maps'),
  waze('waze', 'Waze'),
  apple('apple', 'Plans (Apple)');

  const NavApp(this.value, this.label);
  final String value;
  final String label;

  static NavApp fromValue(String? v) => NavApp.values.firstWhere((a) => a.value == v, orElse: () => NavApp.ask);
}

/// Réglages gardés sur le téléphone : volume du son, mode de notification, navigation.
class AppSettings {
  final NotifMode notifMode;

  /// Volume du son Voyagooo dans l'app (0 à 1)
  final double soundVolume;
  final NavApp navApp;
  final bool avoidTolls;
  final bool avoidFerries;
  final bool avoidFreeways;

  const AppSettings({
    this.notifMode = NotifMode.sound,
    this.soundVolume = 0.8,
    this.navApp = NavApp.ask,
    this.avoidTolls = false,
    this.avoidFerries = false,
    this.avoidFreeways = false,
  });

  AppSettings copyWith({
    NotifMode? notifMode,
    double? soundVolume,
    NavApp? navApp,
    bool? avoidTolls,
    bool? avoidFerries,
    bool? avoidFreeways,
  }) =>
      AppSettings(
        notifMode: notifMode ?? this.notifMode,
        soundVolume: soundVolume ?? this.soundVolume,
        navApp: navApp ?? this.navApp,
        avoidTolls: avoidTolls ?? this.avoidTolls,
        avoidFerries: avoidFerries ?? this.avoidFerries,
        avoidFreeways: avoidFreeways ?? this.avoidFreeways,
      );
}

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  /// Dernière valeur connue, lisible hors widgets (sons, liens de navigation)
  static AppSettings current = const AppSettings();

  static const _prefix = 'settings.';

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _set(AppSettings(
        notifMode: NotifMode.fromValue(p.getString('${_prefix}notif_mode')),
        soundVolume: p.getDouble('${_prefix}sound_volume') ?? 0.8,
        navApp: NavApp.fromValue(p.getString('${_prefix}nav_app')),
        avoidTolls: p.getBool('${_prefix}avoid_tolls') ?? false,
        avoidFerries: p.getBool('${_prefix}avoid_ferries') ?? false,
        avoidFreeways: p.getBool('${_prefix}avoid_freeways') ?? false,
      ));
    } catch (_) {}
  }

  void _set(AppSettings s) {
    current = s;
    if (mounted) state = s;
  }

  Future<void> update(AppSettings s) async {
    _set(s);
    try {
      final p = await SharedPreferences.getInstance();
      await Future.wait([
        p.setString('${_prefix}notif_mode', s.notifMode.value),
        p.setDouble('${_prefix}sound_volume', s.soundVolume),
        p.setString('${_prefix}nav_app', s.navApp.value),
        p.setBool('${_prefix}avoid_tolls', s.avoidTolls),
        p.setBool('${_prefix}avoid_ferries', s.avoidFerries),
        p.setBool('${_prefix}avoid_freeways', s.avoidFreeways),
      ]);
    } catch (_) {}
  }
}

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) => AppSettingsNotifier());
