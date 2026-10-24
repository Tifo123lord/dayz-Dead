part of 'main.dart';

// ---------------------------------------------------------------------------
// Game audio engine
//
// Android: every sound effect goes through a native SoundPool
// (android/.../GameSoundEngine.kt). Clips are decoded once at startup, mixed
// natively with up to 32 voices, never request audio focus (so they can't
// pause each other or the music) and each play is ONE fire-and-forget
// platform message instead of 4-5 MediaPlayer calls.
//
// Web / other platforms: falls back to small audioplayers voice pools.
// ---------------------------------------------------------------------------

class GameAudio {
  GameAudio._();

  static const MethodChannel _ch = MethodChannel('deadland/sfx');

  /// Native SoundPool path (Android app only).
  static final bool native =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// asset path ('assets/audio/x.mp3') -> SoundPool sample id
  static final Map<String, int> _ids = {};
  static Future<void>? _loading;
  static bool _nativeOk = native;

  /// Every short effect used by the game (music + long loops excluded).
  static const List<String> sfxAssets = [
    'assets/audio/ak47_shot.wav',
    'assets/audio/ak47_reload.wav',
    'assets/audio/footstep.wav',
    'assets/audio/footstep_metro.mp3',
    'assets/audio/deagle_shot.mp3',
    'assets/audio/deagle_reload.mp3',
    'assets/audio/shot_tail_metro.mp3',
    'assets/audio/weapon_switch.mp3',
    'assets/audio/shell_drop.mp3',
    'assets/audio/flesh_hit.mp3',
    'assets/audio/zombie_groan.mp3',
    'assets/audio/zombie_attack.mp3',
    'assets/audio/zombie_death.mp3',
    'assets/audio/mushroom_groan.mp3',
    'assets/audio/mushroom_death.mp3',
    'assets/audio/zombie_groan_echo.mp3',
    'assets/audio/mushroom_groan_echo.mp3',
    'assets/audio/light_flicker.mp3',
    'assets/audio/stairs_steps.mp3',
    'assets/audio/eat.mp3',
    'assets/audio/drink.mp3',
    'assets/audio/bandage.mp3',
    'assets/audio/rummage.mp3',
    'assets/audio/thunder.mp3',
  ];

  /// Global audio setup. Must run before any AudioPlayer is created:
  /// players copy the global context when they are created, and the default
  /// (AUDIOFOCUS_GAIN) makes every player steal focus from the others.
  static Future<void> configure() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.game,
            contentType: AndroidContentType.music,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
    } catch (_) {}
  }

  /// Decodes every effect into the native SoundPool (once per app run).
  static Future<void> preload() {
    if (!_nativeOk) return Future.value();
    return _loading ??= () async {
      try {
        final r = await _ch.invokeMapMethod<String, int>('load', sfxAssets);
        if (r != null) _ids.addAll(r);
        if (_ids.isEmpty) _nativeOk = false;
      } catch (_) {
        _nativeOk = false; // no native engine (tests / old build)
      }
    }();
  }

  static bool get useNative => _nativeOk;

  static void _send(String method, [Object? args]) {
    _ch.invokeMethod<void>(method, args).catchError((_) {});
  }

  static void pauseAll() {
    if (_nativeOk) _send('pauseAll');
  }

  static void resumeAll() {
    if (_nativeOk) _send('resumeAll');
  }
}

/// One logical sound with its own voice limit (oldest voice is stolen).
class SfxGroup {
  SfxGroup(this.asset, {this.voices = 2, this.priority = 1}) : id = _nextId++;

  static int _nextId = 1;

  /// Flutter asset key, e.g. 'assets/audio/footstep.wav'.
  final String asset;
  final int voices;
  final int priority;
  final int id;

  // Fallback (web) voices, created lazily.
  List<AudioPlayer>? _players;
  int _next = 0;

  void play({double volume = 1, double pan = 0, double rate = 1}) {
    final v = volume.clamp(0.0, 1.0);
    if (v <= 0.001) return;
    if (GameAudio.useNative) {
      final sid = GameAudio._ids[asset];
      if (sid == null) {
        GameAudio.preload(); // still decoding - skip this one
        return;
      }
      GameAudio._send('play', [sid, id, v, pan, rate, voices, priority, 0]);
      return;
    }
    _fallbackPlay(v, pan, rate);
  }

  void stop() {
    if (GameAudio.useNative) {
      GameAudio._send('stopGroup', id);
      return;
    }
    final ps = _players;
    if (ps == null) return;
    for (final p in ps) {
      p.stop().catchError((_) {});
    }
  }

  void _fallbackPlay(double v, double pan, double rate) {
    final ps = _players ??= List.generate(voices, (_) {
      final p = AudioPlayer();
      p.setReleaseMode(ReleaseMode.stop).catchError((_) {});
      p
          .setSource(AssetSource(asset.replaceFirst('assets/', '')))
          .catchError((_) {});
      return p;
    });
    final p = ps[_next];
    _next = (_next + 1) % ps.length;
    () async {
      try {
        await p.stop();
        await p.setVolume(v);
        if (pan != 0) await p.setBalance(pan.clamp(-1.0, 1.0));
        if (rate != 1) await p.setPlaybackRate(rate);
        await p.resume();
      } catch (_) {}
    }();
  }

  void dispose() {
    stop();
    final ps = _players;
    _players = null;
    if (ps == null) return;
    for (final p in ps) {
      p.dispose().catchError((_) {});
    }
  }
}
