import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

  Future<void> _play(String asset, {Duration minGap = const Duration(seconds: 2)}) async {
    if (kIsWeb) return;
    final now = DateTime.now();
    if (now.difference(_last) < minGap) return;
    _last = now;
    try {
      final player = _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      await player.setAudioContext(_context);
      await player.play(AssetSource(asset), volume: 0.9);
    } catch (e) {
      debugPrint('Son non joué : $e');
    }
  }

  /// Notification reçue app ouverte : son signature + légère vibration
  Future<void> notification() async {
    HapticFeedback.mediumImpact();
    await _play('sounds/voyagooo.wav');
  }

  /// Pépite ramassée
  Future<void> gem() => _play('sounds/gem.wav', minGap: const Duration(milliseconds: 500));
}
