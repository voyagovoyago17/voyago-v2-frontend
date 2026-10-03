import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'app_settings.dart';

/// Sons de l'app : signature Voyagooo (notifications) et pépite ramassée.
///
/// - Android : joués sur le volume « média » (comme les sons d'un jeu), donc audibles même
///   quand la sonnerie est en vibreur ; la musique en cours baisse un instant.
/// - iOS : l'interrupteur silencieux du téléphone est respecté (catégorie « ambient »).
/// Un même son n'est pas rejoué en rafale.
class AppSounds {
  AppSounds._();
  static final AppSounds instance = AppSounds._();

  AudioPlayer? _player;
  bool _contextSet = false;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  /// Dernière erreur de lecture (affichée par « Écouter » dans les réglages)
  String? lastError;

  static final AudioContext _context = AudioContext(
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient, options: const {AVAudioSessionOptions.mixWithOthers}),
    android: const AudioContextAndroid(
      usageType: AndroidUsageType.media,
      contentType: AndroidContentType.sonification,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
  );

  Future<AudioPlayer> _ready() async {
    final player = _player ??= AudioPlayer(playerId: 'voyagooo_sounds');
    if (!_contextSet) {
      // Un réglage audio refusé par le système ne doit jamais empêcher le son
      try {
        await player.setAudioContext(_context);
      } catch (e) {
        debugPrint('Contexte audio non appliqué : $e');
      }
      await player.setReleaseMode(ReleaseMode.stop);
      _contextSet = true;
    }
    return player;
  }

  /// Prépare le lecteur au lancement : le premier son part sans délai
  Future<void> warmUp() async {
    if (kIsWeb) return;
    try {
      await (await _ready()).setSource(AssetSource('sounds/voyagooo.wav'));
    } catch (e) {
      lastError = '$e';
    }
  }

  /// Renvoie true si le son a été lancé
  Future<bool> _play(String asset, {Duration minGap = const Duration(seconds: 2), double? volume}) async {
    if (kIsWeb) return false;
    final v = volume ?? AppSettingsNotifier.current.soundVolume;
    if (v <= 0) return false;
    final now = DateTime.now();
    if (now.difference(_last) < minGap) return false;
    _last = now;
    try {
      final player = await _ready();
      await player.stop();
      await player.play(AssetSource(asset), volume: v.clamp(0.0, 1.0));
      lastError = null;
      return true;
    } on MissingPluginException catch (e) {
      lastError = 'Module audio absent : réinstalle l’app (rebuild complet) pour activer les sons.';
      debugPrint('Son non joué : $e');
    } catch (e) {
      lastError = '$e';
      debugPrint('Son non joué : $e');
    }
    return false;
  }

  /// Notification reçue app ouverte : son signature et/ou vibration selon les réglages du voyageur
  Future<void> notification({bool sound = true, bool vibrate = true}) async {
    final mode = AppSettingsNotifier.current.notifMode;
    if (vibrate && mode != NotifMode.silent) HapticFeedback.mediumImpact();
    if (sound && mode == NotifMode.sound) await _play('sounds/voyagooo.wav');
  }

  /// Aperçu du son depuis les réglages (au volume choisi)
  Future<bool> preview(double volume) => _play('sounds/voyagooo.wav', minGap: Duration.zero, volume: volume);

  /// Pépite ramassée (sauf mode silencieux ; vibration seule = pas de son)
  Future<void> gem() async {
    final mode = AppSettingsNotifier.current.notifMode;
    if (mode != NotifMode.silent) HapticFeedback.heavyImpact();
    if (mode == NotifMode.sound) await _play('sounds/gem.wav', minGap: const Duration(milliseconds: 500));
  }
}
