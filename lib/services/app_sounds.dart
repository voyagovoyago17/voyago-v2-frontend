import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'app_settings.dart';

/// Sons de l'app : signature Voyagooo (notifications) et pépite ramassée.
///
/// Le mode silencieux du téléphone est respecté (catégorie « ambient » sur iOS,
/// usage « notification » sur Android) et un même son n'est pas rejoué en rafale.
class AppSounds {
  AppSounds._();
  static final AppSounds instance = AppSounds._();

  AudioPlayer? _player;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  static final AudioContext _context = AudioContext(
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient, options: const {AVAudioSessionOptions.mixWithOthers}),
    android: const AudioContextAndroid(
      usageType: AndroidUsageType.notification,
      contentType: AndroidContentType.sonification,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
  );

  Future<void> _play(String asset, {Duration minGap = const Duration(seconds: 2), double? volume}) async {
    if (kIsWeb) return;
    final v = volume ?? AppSettingsNotifier.current.soundVolume;
    if (v <= 0) return;
    final now = DateTime.now();
    if (now.difference(_last) < minGap) return;
    _last = now;
    try {
      final player = _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      await player.setAudioContext(_context);
      await player.play(AssetSource(asset), volume: v);
    } catch (e) {
      debugPrint('Son non joué : $e');
    }
  }

  /// Notification reçue app ouverte : son signature et/ou vibration selon les réglages du voyageur
  Future<void> notification({bool sound = true, bool vibrate = true}) async {
    final mode = AppSettingsNotifier.current.notifMode;
    if (vibrate && mode != NotifMode.silent) HapticFeedback.mediumImpact();
    if (sound && mode == NotifMode.sound) await _play('sounds/voyagooo.wav');
  }

  /// Aperçu du son depuis les réglages (au volume choisi)
  Future<void> preview(double volume) => _play('sounds/voyagooo.wav', minGap: Duration.zero, volume: volume);

  /// Pépite ramassée (sauf mode silencieux ; vibration seule = pas de son)
  Future<void> gem() async {
    final mode = AppSettingsNotifier.current.notifMode;
    if (mode != NotifMode.silent) HapticFeedback.heavyImpact();
    if (mode == NotifMode.sound) await _play('sounds/gem.wav', minGap: const Duration(milliseconds: 500));
  }
}
