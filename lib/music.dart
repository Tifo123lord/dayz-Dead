part of 'main.dart';

// ---------------------------------------------------------------------------
// Menu music: looping soundtrack for every menu screen.
// - Fades in on the menus, fades out when a mission starts, fades back in
//   when the player returns to the menus.
// - Track, volume, on/off and playlist mode are saved in the profile.
// - Browsers block audio until the first user gesture, so [userGesture] is
//   called from a root Listener to start playback on the first tap.
// ---------------------------------------------------------------------------

class MusicTrack {
  const MusicTrack(this.title, this.mood, this.asset, this.credit);
  final String title, mood, asset, credit;
}

/// All tracks are CC0 (public domain) from OpenGameArt.org.
const List<MusicTrack> menuTracks = [
  MusicTrack(
    'ویرانه‌ی خاموش',
    'غمگین و حماسی',
    'audio/music/menu_tragic.mp3',
    'Tragic Ambient Main Menu — brandon75689 (CC0)',
  ),
  MusicTrack(
    'وحشت شبانه',
    'تاریک و ترسناک',
    'audio/music/menu_dread.mp3',
    'Ambient Horror Track 01 — Cleyton Kauffman (CC0)',
  ),
  MusicTrack(
    'سرزمین سوخته',
    'فضای آخرالزمانی',
    'audio/music/menu_wasteland.mp3',
    'Post Apocalyptic Wastelands — Juhani Junkala (CC0)',
  ),
];

class MenuMusic {
  MenuMusic._();

  static final AudioPlayer _player = AudioPlayer(playerId: 'menu_music');
  static final ValueNotifier<int> current = ValueNotifier<int>(0);
  static final ValueNotifier<bool> playing = ValueNotifier<bool>(false);

  /// Bumped whenever on/off or settings change (for UI rebuilds).
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static Listenable get listenable =>
      Listenable.merge([current, playing, revision]);

  static bool _unlocked = !kIsWeb; // web needs a user gesture first
  static bool _ready = false;
  static int _gameDepth = 0; // > 0 while a mission screen is alive
  static double _vol = 0; // current (faded) volume 0..1
  static Timer? _fade;
  static int _loadedTrack = -1;
  static StreamSubscription<void>? _doneSub;
  static bool _background = false;
  static AppLifecycleListener? _life;

  static Profile get _p => Profile.i;

  static double get _targetVolume => _p.musicOn ? _p.musicVolume * 0.85 : 0;

  static bool get _shouldPlay =>
      _unlocked &&
      !_background &&
      _gameDepth == 0 &&
      _p.musicOn &&
      _p.musicVolume > 0;

  /// Called once from main() after the profile is loaded.
  static Future<void> init() async {
    if (_ready) return;
    _ready = true;
    current.value = _p.musicTrack.clamp(0, menuTracks.length - 1);
    try {
      await _player.setPlayerMode(PlayerMode.mediaPlayer);
      await _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.game,
            contentType: AndroidContentType.music,
            audioFocus: AndroidAudioFocus.none,
          ),
        ),
      );
    } catch (_) {}
    _doneSub = _player.onPlayerComplete.listen((_) => _onTrackDone());
    // Pause when the app is minimised, resume when it comes back.
    _life = AppLifecycleListener(
      onHide: () {
        _background = true;
        _fade?.cancel();
        _player.pause().catchError((_) {});
        playing.value = false;
      },
      onShow: () {
        _background = false;
        _refresh();
      },
    );
    _refresh();
  }

  /// First tap / key press anywhere in the app (unlocks audio on the web).
  static void userGesture() {
    if (_unlocked) return;
    _unlocked = true;
    _refresh();
  }

  static void enterGame() {
    _gameDepth++;
    _refresh();
  }

  static void leaveGame() {
    _gameDepth = math.max(0, _gameDepth - 1);
    _refresh();
  }

  /// Applies the latest settings (volume / on-off / track).
  static void settingsChanged() {
    revision.value++;
    final t = _p.musicTrack.clamp(0, menuTracks.length - 1);
    if (t != current.value) {
      selectTrack(t);
      return;
    }
    _refresh();
  }

  static Future<void> selectTrack(int i) async {
    i = i % menuTracks.length;
    _p.musicTrack = i;
    current.value = i;
    revision.value++;
    _p.save();
    if (!_shouldPlay) {
      _loadedTrack = -1; // load the new one next time we play
      _refresh();
      return;
    }
    // Quick cross-fade: fade out, swap, fade in.
    await _fadeTo(0, 350);
    await _load(i, restart: true);
    _fadeTo(_targetVolume, 900);
  }

  static void next() => selectTrack(current.value + 1);
  static void previous() =>
      selectTrack((current.value - 1 + menuTracks.length) % menuTracks.length);

  static void toggle() {
    _p.musicOn = !_p.musicOn;
    _p.save();
    revision.value++;
    _refresh();
  }

  static Future<void> _onTrackDone() async {
    // Only fires in playlist mode (single-track mode loops natively).
    if (!_p.musicPlaylist) return;
    final n = (current.value + 1) % menuTracks.length;
    _p.musicTrack = n;
    current.value = n;
    _p.save();
    if (_shouldPlay) {
      await _load(n, restart: true);
      _fadeTo(_targetVolume, 1200);
    }
  }

  static Future<void> _load(int i, {bool restart = false}) async {
    try {
      await _player.setReleaseMode(
        _p.musicPlaylist ? ReleaseMode.release : ReleaseMode.loop,
      );
      if (_loadedTrack != i || restart) {
        await _player.stop();
        await _player.setVolume(_vol);
        await _player.play(AssetSource(menuTracks[i].asset), volume: _vol);
        _loadedTrack = i;
      } else {
        await _player.resume();
      }
      playing.value = true;
    } catch (_) {
      playing.value = false;
    }
  }

  static Future<void> _refresh() async {
    if (!_ready) return;
    if (_shouldPlay) {
      final t = current.value;
      if (!playing.value || _loadedTrack != t) {
        await _load(t, restart: _loadedTrack != t);
      } else {
        // Release mode might have changed (playlist toggle).
        try {
          await _player.setReleaseMode(
            _p.musicPlaylist ? ReleaseMode.release : ReleaseMode.loop,
          );
        } catch (_) {}
      }
      _fadeTo(_targetVolume, 1400);
    } else if (playing.value) {
      await _fadeTo(0, _gameDepth > 0 ? 700 : 400);
      if (!_shouldPlay) {
        try {
          await _player.pause();
        } catch (_) {}
        playing.value = false;
      }
    }
  }

  static Future<void> _fadeTo(double target, int ms) {
    _fade?.cancel();
    final done = Completer<void>();
    final start = _vol;
    const stepMs = 50;
    final steps = math.max(1, ms ~/ stepMs);
    var i = 0;
    _fade = Timer.periodic(const Duration(milliseconds: stepMs), (t) {
      i++;
      final k = (i / steps).clamp(0.0, 1.0);
      _vol = start + (target - start) * k;
      _player.setVolume(_vol).catchError((_) {});
      if (k >= 1) {
        t.cancel();
        if (!done.isCompleted) done.complete();
      }
    });
    // Safety: never wait forever if the timer gets cancelled by a new fade.
    Future<void>.delayed(Duration(milliseconds: ms + 200), () {
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }

  static void dispose() {
    _fade?.cancel();
    _doneSub?.cancel();
    _life?.dispose();
    _player.dispose();
  }
}

/// Compact "now playing" widget for the main menu.
class MusicBadge extends StatelessWidget {
  const MusicBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MenuMusic.listenable,
      builder: (context, _) {
        final t = MenuMusic.current.value;
        final on = Profile.i.musicOn;
        final track = menuTracks[t];
        return Container(
          padding: const EdgeInsets.fromLTRB(4, 2, 10, 2),
          decoration: BoxDecoration(
            color: _mPanel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x99B01818)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _btn(
                on ? Icons.music_note : Icons.music_off,
                on ? 'قطع موسیقی' : 'پخش موسیقی',
                () {
                  MenuMusic.userGesture();
                  MenuMusic.toggle();
                },
                color: on ? _mGold : _mSand,
              ),
              _btn(Icons.skip_next, 'آهنگ بعدی', () {
                MenuMusic.userGesture();
                if (!Profile.i.musicOn) MenuMusic.toggle();
                MenuMusic.next();
              }),
              const SizedBox(width: 2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Text(
                  on ? track.title : 'موسیقی خاموش',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: on ? _mBone : _mSand,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (on) ...[const SizedBox(width: 6), const _EqBars()],
            ],
          ),
        );
      },
    );
  }

  Widget _btn(
    IconData i,
    String tip,
    VoidCallback onTap, {
    Color color = _mBone,
  }) => IconButton(
    tooltip: tip,
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    iconSize: 19,
    onPressed: onTap,
    icon: Icon(i, color: color),
  );
}

/// Tiny animated equaliser bars shown while music plays.
class _EqBars extends StatefulWidget {
  const _EqBars();

  @override
  State<_EqBars> createState() => _EqBarsState();
}

class _EqBarsState extends State<_EqBars> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: MenuMusic.playing,
      builder: (_, p, _) => AnimatedBuilder(
        animation: _c,
        builder: (_, _) {
          return SizedBox(
            width: 16,
            height: 14,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < 4; i++)
                  Container(
                    width: 2.6,
                    height: p
                        ? 3 +
                              11 *
                                  (0.5 +
                                          0.5 *
                                              math.sin(
                                                _c.value * math.pi * 2 * 2 +
                                                    i * 1.7,
                                              ))
                                      .abs()
                        : 3,
                    color: _mBlood,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
