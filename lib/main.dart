import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'zombies.dart';
part 'world.dart';
part 'profile.dart';
part 'menu.dart';
part 'session.dart';
part 'skins.dart';
part 'music.dart';
part 'survival.dart';
part 'characters.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Profile.i.load();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const DeadlandApp());
  MenuMusic.init();
}

class DeadlandApp extends StatelessWidget {
  const DeadlandApp({super.key});

  @override
  Widget build(BuildContext context) =>
      const DeadlandTestHost(home: MainMenuScreen());
}

/// App shell (theme, RTL, audio unlock) around any [home] screen.
@visibleForTesting
class DeadlandTestHost extends StatelessWidget {
  const DeadlandTestHost({super.key, required this.home});
  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'بقا در مرگ با دست خونین',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Vazirmatn',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFB01818),
          secondary: Color(0xFFE0B050),
          surface: Color(0xFF1A0B0B),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF2A1010),
          contentTextStyle: TextStyle(
            fontFamily: 'Vazirmatn',
            color: Color(0xFFE9DCC0),
          ),
        ),
      ),
      // Menus are Persian (right-to-left); the game screen forces LTR itself.
      // The root Listener unlocks web audio on the first tap (autoplay rules).
      builder: (context, child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => MenuMusic.userGesture(),
        child: Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
      home: home,
    );
  }
}

// ---------------------------------------------------------------------------
// Tuning
// ---------------------------------------------------------------------------

/// Background image size and the y-coordinate of the road surface in it.
const double _bgW = 1360, _bgH = 768, _groundY = 604;

/// Walk sprite sheet: 8 walk frames in one row (168 x 300 each).
const int _frameCount = 8;
const int _idleFrame = 7;
const double _walkFps = 10;
const double _speed = 150; // background pixels per second
const double _playerH = 150; // player height in background pixels

/// Pose sheet (survivor_poses.png): 4 cells of 260 x 300, feet on bottom edge,
/// body centre at x = 90 inside each cell.
const double _poseCellW = 260, _poseCellH = 300, _poseAnchorX = 90;

enum Pose { aim, crouchAim, crouchLow, jump }

/// Muzzle position of the rifle in each pose cell (cell pixels).
const Map<Pose, Offset> _poseMuzzle = {
  Pose.aim: Offset(247, 62),
  Pose.crouchAim: Offset(249, 145),
  Pose.crouchLow: Offset(187, 247),
  Pose.jump: Offset(204, 209),
};

/// Jump physics (background pixels).
const double _gravity = 2600;
const double _jumpVelocity = 800; // ~123 px high

const int _shotVoices = 7; // overlapping AK gunshot channels

// ---------------------------------------------------------------------------
// Simple particles
// ---------------------------------------------------------------------------

class _Bullet {
  _Bullet(this.x, this.y, this.vx, this.vy, this.damage, this.pierce);
  double x, y, vx, vy;
  double prevX = 0, prevY = 0;
  double damage;
  int pierce; // extra zombies this round can pass through
  final Set<_Zombie> hit = {};
  bool dead = false;
}

class _Shell {
  _Shell(this.x, this.y, this.vx, this.vy, this.spin, {this.big = false});
  double x, y, vx, vy, angle = 0, spin, life = 2.2;
  int bounces = 0;
  final bool big; // .50 AE casing
}

class _Spark {
  _Spark(this.x, this.y, this.vx, this.vy, this.life);
  double x, y, vx, vy, life;
  final double maxLife = 0.35;
}

class _Smoke {
  _Smoke(this.x, this.y, this.vx, this.vy);
  double x, y, vx, vy, life = 0.7;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

/// The one continuous survival world. Loads [Profile.survivor] (creating a
/// fresh normal-difficulty survivor if there is none) and keeps it saved.
class DemoScreen extends StatefulWidget {
  const DemoScreen({super.key});

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final math.Random _rng = math.Random();

  // Audio
  final AudioPlayer _steps = AudioPlayer();
  final List<AudioPlayer> _shots = List.generate(
    _shotVoices,
    (_) => AudioPlayer(),
  );
  int _shotVoice = 0;
  final AudioPlayer _reloadSfx = AudioPlayer();
  final AudioPlayer _stepsMetro = AudioPlayer();
  final _WorldAudio _wa = _WorldAudio();

  final AudioPlayer _forestLoop = AudioPlayer();
  bool _forestLoopOn = false, _forestReady = false;

  // Playable character
  final HeroSpec _hero = HeroSpec.of(Profile.i.hero);

  // Images
  ui.Image? _sheet, _poses, _rifle, _posesDe, _pistol;

  // Weapon skins (equipped at mission start)
  final WeaponSkin _skinAk = Profile.i.skinFor(Weapon.ak);
  final WeaponSkin _skinDe = Profile.i.skinFor(Weapon.deagle);
  WeaponSkin _skinOf(Weapon w) => w == Weapon.ak ? _skinAk : _skinDe;

  // Weapons
  Weapon _weapon = Weapon.ak;
  final List<int> _mags = [_GunSpec.ak.mag, _GunSpec.deagle.mag];
  final List<int> _reserves = [
    (_GunSpec.ak.startReserve * Profile.i.ammoMul).round(),
    (_GunSpec.deagle.startReserve * Profile.i.ammoMul).round(),
  ];
  double _switchLeft = 0;
  _GunSpec get _gun => _GunSpec.of(_weapon);
  int get _ammo => _mags[_weapon.index];
  set _ammo(int v) => _mags[_weapon.index] = v;
  int get _reserve => _reserves[_weapon.index];
  set _reserve(int v) => _reserves[_weapon.index] = v;

  // Areas / travel
  Area _area = Area.city;
  double _travelT = -1; // >= 0 while travelling
  _Door _travelDoor = _cityDoors.first;
  bool _swapped = false;
  double _fade = 0;
  bool _btnUse = false;
  bool _prevUse = false, _prevSwapKey = false;
  final List<_Lamp> _lamps = [];
  final List<_Drip> _drips = [];
  double _dripIn = 0.5;
  double _metroAmbIn = 2;
  double _flickerIn = 3;

  // Player state
  double _x = 420; // background coordinates
  double _y = 0; // height above ground (positive = up)
  double _vy = 0;
  double _vx = 0; // horizontal velocity (heroes accelerate differently)
  bool _grounded = true;
  bool _crouching = false;
  bool _facingRight = true;
  int _dir = 0; // -1, 0, 1
  double _animTime = 0;
  double _clock = 0;

  /// Player height in background px for the current area.
  double get _heroH => _playerH * _actorScale;
  int _frame = _idleFrame;
  Duration _last = Duration.zero;

  // Weapon state
  double _fireCooldown = 0;
  double _reloadLeft = 0;
  double _flash = 0; // muzzle flash timer
  double _recoil = 0; // 0..1 kick
  double _shake = 0;
  double _lastShot = -10;
  int _shotsInBurst = 0;

  // Zombies / survival
  final _ZombieAudio _za = _ZombieAudio();
  ui.Image? _zWalkImg, _zSporeImg;
  final List<_Zombie> _zombies = [];
  final List<_Gore> _gore = [];
  final List<_Decal> _decals = [];
  final List<_SporeCloud> _clouds = [];
  final List<_FloatText> _texts = [];
  final List<_Pickup> _pickups = [];
  final List<_Ash> _ash = [];
  late final double _maxHp = Profile.i.maxHp + _hero.hpBonus;
  late double _hp = _maxHp;
  double _hurt = 0; // red damage vignette 0..1
  double _poison = 0; // green spore vignette 0..1
  double _invuln = 0;
  int _wave = 0;
  int _toSpawn = 0;
  double _spawnIn = 0;
  double _waveBreak = 10; // countdown to the next wave
  double _banner = 0;
  String _bannerText = '';
  String _bannerSub = '';
  int _kills = 0, _headshots = 0, _score = 0;
  bool _dead = false;
  double _deadT = 0;

  // Session / menus
  bool _paused = false;
  bool _prevPauseKey = false;
  int _coinsEarned = 0;
  double _ambientIn = 3; // next distant groan
  late final AppLifecycleListener _life;

  // Survival (see survival.dart)
  Difficulty _diff = Difficulty.normal;
  bool _loaded = false;
  double _hunger = 85, _thirst = 85, _infection = 0, _leg = 0;
  int _bleed = 0;
  double _bleedClot = 0, _bleedDrip = 0;
  final Map<Item, int> _inv = {for (final i in Item.values) i: 0};
  double _worldTime = 0;
  int _day = 1;
  final Map<String, double> _spotReady = {};
  double _pumpReady = 0;
  double _coinFrac = 0;
  double _useCd = 0;
  double _warnIn = 6;
  double _saveIn = 10;
  _Spot? _searching;
  double _searchT = 0;
  String _deathCause = '';
  final List<String> _deathLosses = [];
  int _killsAtStart = 0;
  double _fullWarnAt = -10;
  String _notice = '';
  Color _noticeColor = _mBone;
  double _noticeT = 0;
  final List<bool> _prevItemKeys = List.filled(ItemCat.values.length, false);
  bool _bagOpen = false, _prevBagKey = false;
  double _useFx = 0; // item being used rises from the hands
  Item _useFxItem = Item.food;
  double _sugarT = 0; // chocolate energy boost
  final Map<Item, ui.Image> _itemImgs = {};
  ui.Image? _ammoImg;

  // Forest weather
  final List<_RainDrop> _rain = [];
  double _lightning = 0, _boltIn = 6, _thunderIn = 0;
  final List<Offset> _bolt = [];
  double _gust = 0; // wind strength used by ash / spores

  final List<_Bullet> _bullets = [];
  final List<_Shell> _shells = [];
  final List<_Spark> _sparks = [];
  final List<_Smoke> _smoke = [];

  // On-screen buttons
  bool _btnLeft = false, _btnRight = false, _btnFire = false;
  bool _btnJump = false, _crouchToggle = false;
  bool _prevJumpInput = false, _prevReloadKey = false, _prevCrouchKey = false;
  bool _prevFireInput = false;

  @override
  void initState() {
    super.initState();
    MenuMusic.enterGame();
    _loadImages();
    _steps.setReleaseMode(ReleaseMode.stop);
    _steps.setVolume(0.55 * Profile.i.sfxVolume);
    _steps.setSource(AssetSource('audio/footstep.wav'));
    for (final p in _shots) {
      p.setReleaseMode(ReleaseMode.stop);
      p.setVolume(0.9 * Profile.i.sfxVolume);
      p.setSource(AssetSource('audio/ak47_shot.wav'));
    }
    _reloadSfx.setReleaseMode(ReleaseMode.stop);
    _reloadSfx.setVolume(0.9 * Profile.i.sfxVolume);
    _reloadSfx.setSource(AssetSource('audio/ak47_reload.wav'));
    _stepsMetro.setReleaseMode(ReleaseMode.stop);
    _stepsMetro.setVolume(0.6 * Profile.i.sfxVolume);
    _stepsMetro.setSource(AssetSource('audio/footstep_metro.mp3'));
    _initLamps();
    _initRain();
    var save = Profile.i.survivor;
    if (save == null) {
      Profile.i.newSurvivor(Difficulty.normal, Area.city);
      save = Profile.i.survivor!;
    }
    _loadSave(save);
    _killsAtStart = _kills;
    _loaded = true;
    _boltIn = 3 + _rng.nextDouble() * 4;
    _bannerText = _area.title;
    _bannerSub = 'DAY $_day  ·  ${_clockText(_worldTime)}';
    _banner = 3;
    Profile.i.totalGames++;
    Profile.i.save();
    _forestLoop.setReleaseMode(ReleaseMode.loop);
    _forestLoop.setVolume(0.55 * Profile.i.ambientVolume);
    _forestLoop.setSource(AssetSource('audio/forest_rain.mp3')).then((_) {
      _forestReady = true;
      if (mounted) _syncForestLoop();
    });
    // Save when the app goes to the background and pause the game.
    _life = AppLifecycleListener(
      onHide: () {
        if (!mounted) return;
        _autosave();
        if (!_dead && !_paused) _setPaused(true);
        _forestLoop.pause();
        _forestLoopOn = false;
      },
    );
    for (var i = 0; i < 70; i++) {
      _ash.add(
        _Ash(
          _rng.nextDouble() * _bgW,
          _rng.nextDouble() * _bgH,
          1 + _rng.nextDouble() * 2.2,
          0.5 + _rng.nextDouble(),
          _rng.nextDouble() * 6.28,
        ),
      );
    }
    if (const bool.fromEnvironment('ZDEBUG')) {
      // Screenshot/debug helper: place a few zombies on screen immediately.
      _waveBreak = 999;
      _zombies.addAll([
        _Zombie(ZType.walker, 640, _rng)..facingRight = false,
        _Zombie(ZType.spore, 820, _rng)..facingRight = false,
        _Zombie(ZType.walker, 230, _rng)..facingRight = true,
      ]);
      _zombies[0].hp = 55;
      _zombies[0].ghostHp = 80;
      _zombies[1].hp = 160;
      _clouds.add(_SporeCloud(980, 520, 60, 99, 1));
    }
    _ticker = createTicker(_tick)..start();
  }

  Future<ui.Image> _load(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  Future<void> _loadImages() async {
    final sheet = await _load(_hero.walkSheet);
    final poses = await _load(_hero.posesFor(_skinAk));
    final rifle = await _load(_skinAk.sprite);
    final zWalk = await _load('assets/images/zombie_walk.png');
    final zSpore = await _load('assets/images/mushroom_walk.png');
    final posesDe = await _load(_hero.posesFor(_skinDe));
    final pistol = await _load(_skinDe.sprite);
    final items = <Item, ui.Image>{
      for (final i in Item.values) i: await _load(ItemInfo.of(i).asset),
    };
    final ammo = await _load(_ammoAsset);
    if (!mounted) return;
    _itemImgs.addAll(items);
    _ammoImg = ammo;
    setState(() {
      _sheet = sheet;
      _poses = poses;
      _rifle = rifle;
      _posesDe = posesDe;
      _pistol = pistol;
      _zWalkImg = zWalk;
      _zSporeImg = zSpore;
    });
  }

  // -------------------------------------------------------------------------
  // Game loop
  // -------------------------------------------------------------------------

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final pauseKey =
        pressed.contains(LogicalKeyboardKey.escape) ||
        pressed.contains(LogicalKeyboardKey.keyP);
    if (pauseKey && !_prevPauseKey && !_dead) _setPaused(!_paused);
    _prevPauseKey = pauseKey;
    if (_paused) return;

    _clock += dt;

    final travelling = _travelT >= 0;
    if (_dead || travelling) {
      _btnLeft = _btnRight = _btnFire = _btnJump = _btnUse = false;
      _crouchToggle = false;
      if (_dead) _deadT += dt;
    }
    if (travelling) _updateTravel(dt);
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    bool k(LogicalKeyboardKey key) =>
        !_dead && !travelling && keys.contains(key);

    final left =
        _btnLeft ||
        k(LogicalKeyboardKey.arrowLeft) ||
        k(LogicalKeyboardKey.keyA);
    final right =
        _btnRight ||
        k(LogicalKeyboardKey.arrowRight) ||
        k(LogicalKeyboardKey.keyD);
    final jumpIn =
        _btnJump ||
        k(LogicalKeyboardKey.arrowUp) ||
        k(LogicalKeyboardKey.keyW) ||
        k(LogicalKeyboardKey.space);
    final crouchKey =
        k(LogicalKeyboardKey.arrowDown) ||
        k(LogicalKeyboardKey.keyS) ||
        k(LogicalKeyboardKey.controlLeft) ||
        k(LogicalKeyboardKey.keyC);
    final fireIn =
        _btnFire ||
        k(LogicalKeyboardKey.keyF) ||
        k(LogicalKeyboardKey.keyJ) ||
        k(LogicalKeyboardKey.enter);
    final reloadKey = k(LogicalKeyboardKey.keyR);
    final useIn = _btnUse || k(LogicalKeyboardKey.keyE);
    final swapKey =
        k(LogicalKeyboardKey.keyQ) ||
        k(LogicalKeyboardKey.tab) ||
        k(LogicalKeyboardKey.digit1) ||
        k(LogicalKeyboardKey.digit2);
    if (swapKey && !_prevSwapKey) {
      if (k(LogicalKeyboardKey.digit1)) {
        _selectWeapon(Weapon.ak);
      } else if (k(LogicalKeyboardKey.digit2)) {
        _selectWeapon(Weapon.deagle);
      } else {
        _switchWeapon();
      }
    }
    _prevSwapKey = swapKey;
    if (useIn && !_prevUse) _interact();
    _prevUse = useIn;

    // Quick-use groups: keys 3..7 (food, drink, wound care, medkit, pills).
    final bagKey = k(LogicalKeyboardKey.keyB) || k(LogicalKeyboardKey.keyI);
    if (bagKey && !_prevBagKey) _bagOpen = !_bagOpen;
    _prevBagKey = bagKey;
    const itemKeys = [
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
    ];
    for (var i = 0; i < itemKeys.length; i++) {
      final down = k(itemKeys[i]);
      if (down && !_prevItemKeys[i]) _useCategory(ItemCat.values[i]);
      _prevItemKeys[i] = down;
    }

    // A crouch key press releases the touch toggle so both inputs agree.
    if (crouchKey && !_prevCrouchKey) _crouchToggle = false;
    _prevCrouchKey = crouchKey;

    final dir = (right ? 1 : 0) - (left ? 1 : 0);
    final wantCrouch = (crouchKey || _crouchToggle) && _grounded;

    // ---- Jump ----
    if (jumpIn && !_prevJumpInput && _grounded) {
      _vy =
          _jumpVelocity *
          math.sqrt(_actorScale) *
          _hero.jumpMul *
          (_leg > 0 ? 0.8 : 1.0);
      _cancelSearch(silent: true);
      _grounded = false;
      _crouchToggle = false;
      _stopSteps();
    }
    _prevJumpInput = jumpIn;

    if (!_grounded) {
      _vy -= _gravity * dt;
      _y += _vy * dt;
      if (_y <= 0) {
        _y = 0;
        _vy = 0;
        _grounded = true;
        _shake = math.max(_shake, 0.25);
        _playStep(); // landing thud
      }
    }

    _crouching = wantCrouch;

    // ---- Movement ----
    if (dir != 0) _facingRight = dir > 0;
    final canWalk = !_crouching;
    final moving = dir != 0 && canWalk;
    {
      final airControl = _grounded ? 1.0 : 0.9;
      final target = moving
          ? dir * _speed * _actorScale * _moveMul * airControl
          : 0.0;
      // Heavier heroes take a moment to reach top speed and to stop.
      final accel = 1700 * _hero.accelMul * (_grounded ? 1.0 : 0.6) * dt;
      if ((target - _vx).abs() <= accel) {
        _vx = target;
      } else {
        _vx += accel * (target > _vx ? 1 : -1);
      }
      final nx = (_x + _vx * dt).clamp(60.0, _bgW - 60.0);
      if (nx == _x && _vx != 0 && (nx <= 60 || nx >= _bgW - 60)) _vx = 0;
      _x = nx;
    }

    if (moving && _grounded) {
      if (_dir == 0) _animTime = 0; // start cycle on a foot contact
      final prev = _frame;
      _animTime += dt;
      final fps = _hero.walkFps * (_leg > 0 ? 0.75 : 1.0) * (_walkFps / 10);
      _frame = (_animTime * fps).floor() % _frameCount;
      if ((_frame == 0 || _frame == 4) && (prev != _frame || _dir == 0)) {
        _playStep();
      }
      _dir = dir;
    } else {
      if (_dir != 0) _stopSteps();
      _frame = _idleFrame;
      _dir = 0;
    }

    // ---- Weapon ----
    if (reloadKey && !_prevReloadKey) _startReload();
    _prevReloadKey = reloadKey;

    _fireCooldown -= dt;
    if (_switchLeft > 0) _switchLeft -= dt;
    final trigger = _gun.auto ? fireIn : (fireIn && !_prevFireInput);
    if (_reloadLeft > 0) {
      _reloadLeft -= dt;
      if (_reloadLeft <= 0) {
        final need = _gun.mag - _ammo;
        final take = math.min(need, _reserve);
        _ammo += take;
        _reserve -= take;
        _reloadLeft = 0;
      }
    } else if (_switchLeft > 0) {
      // Drawing the weapon.
    } else if (trigger && _fireCooldown <= 0) {
      if (_ammo > 0) {
        _fire();
        _fireCooldown += _gun.interval;
        if (_fireCooldown < 0) _fireCooldown = 0;
      } else if (!_prevFireInput) {
        _startReload();
      }
    }
    if (!fireIn) {
      _shotsInBurst = 0;
      if (_fireCooldown < 0) _fireCooldown = 0;
    }
    _prevFireInput = fireIn;

    _flash = math.max(0, _flash - dt);
    _recoil = math.max(0, _recoil - dt * 9);
    _shake = math.max(0, _shake - dt * 3);

    _updateParticles(dt);
    _updateZombies(dt);
    _updateWorld(dt);
    _updateEnvironment(dt);
    _updateSurvival(dt);
    if (_area == Area.forest) _updateForest(dt);
    setState(() {});
  }

  void _startReload() {
    if (_reloadLeft > 0 || _switchLeft > 0) return;
    if (_ammo == _gun.mag || _reserve == 0) return;
    _reloadLeft = _reloadTime;
    if (_weapon == Weapon.ak) {
      _reloadSfx.stop().then((_) => _reloadSfx.resume());
    } else {
      _wa.deagleReload.play(_clock);
    }
  }

  void _refresh() => setState(() {});

  double get _reloadTime => _gun.reload * Profile.i.reloadMul * _hero.reloadMul;

  void _switchWeapon() =>
      _selectWeapon(_weapon == Weapon.ak ? Weapon.deagle : Weapon.ak);

  void _selectWeapon(Weapon w) {
    if (w == _weapon || _dead || _travelT >= 0) return;
    // Cancel a reload in progress.
    _reloadLeft = 0;
    _reloadSfx.stop();
    _wa.deagleReload.stopAll();
    _weapon = w;
    _switchLeft = 0.35;
    _shotsInBurst = 0;
    _wa.weaponSwitch.play(_clock, rate: w == Weapon.deagle ? 1.05 : 0.9);
    _texts.add(
      _FloatText(
        _x,
        _groundY - _y - _heroH - 25,
        _gun.shortName,
        const Color(0xFFD9C9A3),
        big: true,
      ),
    );
  }

  /// Current visual pose; null means "walk sheet + carried rifle".
  Pose? get _pose {
    if (!_grounded) return Pose.jump;
    if (_crouching) {
      final aiming = _clock - _lastShot < 0.8 && _reloadLeft <= 0;
      return aiming ? Pose.crouchAim : Pose.crouchLow;
    }
    if (_dir != 0) return null;
    return Pose.aim;
  }

  /// Muzzle and ejection-port positions in background coordinates.
  (Offset muzzle, Offset port) _gunPoints() {
    final k = _heroH / _poseCellH; // cell px -> bg px
    final s = _facingRight ? 1.0 : -1.0;
    final feetY = _groundY - _y;
    final pose = _pose;
    if (pose != null) {
      final pistol = _weapon == Weapon.deagle;
      final m = _hero.muzzle(_weapon)[pose]!;
      final muzzle = Offset(
        _x + (m.dx - _poseAnchorX) * k * s,
        feetY - (_poseCellH - m.dy) * k,
      );
      // Ejection port: ~60% back along the rifle / on top of the slide.
      final port = pistol
          ? Offset(muzzle.dx - 26 * k * s, muzzle.dy - 2 * k)
          : Offset(muzzle.dx - 75 * k * s, muzzle.dy + 4 * k);
      return (muzzle, port);
    }
    final g = _CarryGeom.of(_frame, _weapon);
    final muzzle = Offset(
      _x + g.muzzle.dx * k * s,
      feetY - (_poseCellH - g.muzzle.dy) * k,
    );
    final port = Offset(
      _x + g.port.dx * k * s,
      feetY - (_poseCellH - g.port.dy) * k,
    );
    return (muzzle, port);
  }

  void _fire() {
    final gun = _gun;
    _ammo--;
    _lastShot = _clock;
    _shotsInBurst++;
    _flash = gun.flash;
    _recoil = gun.recoil * _hero.recoilMul;
    _shake = math.max(_shake, gun.shake * _hero.recoilMul);
    _cancelSearch(silent: true);

    final (muzzle, port) = _gunPoints();
    final s = _facingRight ? 1.0 : -1.0;

    // Spread grows during sustained fire (full-auto AK / rapid Deagle).
    final spread =
        (gun.baseSpread + math.min(_shotsInBurst, 10) * gun.spreadGrow) *
        (_crouching ? 0.5 : 1.0) *
        _hero.spreadMul *
        _aimPenalty;
    var angle = (_rng.nextDouble() - 0.5) * 2 * spread;
    if (_pose == null) angle += 0.12; // carried low while walking
    final vx = math.cos(angle) * gun.bulletSpeed * s;
    final vy = math.sin(angle) * gun.bulletSpeed;
    _bullets.add(
      _Bullet(
          muzzle.dx,
          muzzle.dy,
          vx,
          vy,
          gun.damage * Profile.i.damageMul(_weapon),
          gun.pierce,
        )
        ..prevX = muzzle.dx
        ..prevY = muzzle.dy,
    );

    // Brass casing ejected up and backwards.
    final pistol = _weapon == Weapon.deagle;
    _shells.add(
      _Shell(
        port.dx,
        port.dy,
        (-60 - _rng.nextDouble() * 90) * s * (pistol ? 0.8 : 1),
        (-260 - _rng.nextDouble() * 120) * (pistol ? 1.15 : 1),
        (10 + _rng.nextDouble() * 15) * s,
        big: pistol,
      ),
    );

    if (pistol) {
      _wa.deagleShot.play(_clock, rate: 0.96 + _rng.nextDouble() * 0.08);
      // Echo off tiled walls underground.
      if (_area == Area.metro) {
        _wa.shotTail.play(_clock, volume: 0.9, minGap: 0.12);
      }
      for (var i = 0; i < 4; i++) {
        _smoke.add(
          _Smoke(
            muzzle.dx,
            muzzle.dy,
            (30 + _rng.nextDouble() * 50) * s,
            -25 - _rng.nextDouble() * 35,
          ),
        );
      }
      return;
    }
    if (_area == Area.metro) {
      _wa.shotTail.play(_clock, volume: 0.55, rate: 1.15, minGap: 0.25);
    }

    for (var i = 0; i < 3; i++) {
      _smoke.add(
        _Smoke(
          muzzle.dx,
          muzzle.dy,
          (20 + _rng.nextDouble() * 40) * s,
          -20 - _rng.nextDouble() * 30,
        ),
      );
    }

    final p = _shots[_shotVoice];
    _shotVoice = (_shotVoice + 1) % _shots.length;
    p.stop().then((_) => p.resume());
  }

  void _updateParticles(double dt) {
    for (final b in _bullets) {
      b.prevX = b.x;
      b.prevY = b.y;
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      // Zombie hits: nearest zombie along the bullet path takes the round.
      _Zombie? best;
      var bestD = double.infinity;
      for (final z in _zombies) {
        if (!z.alive || b.hit.contains(z)) continue;
        final r = z.rect.inflate(2);
        if (_segmentHitsRect(b.prevX, b.prevY, b.x, b.y, r)) {
          final d = (z.x - b.prevX).abs();
          if (d < bestD) {
            bestD = d;
            best = z;
          }
        }
      }
      if (best != null) {
        final r = best.rect;
        final hy = b.y.clamp(r.top, r.bottom).toDouble();
        b.hit.add(best);
        _hitZombie(
          best,
          b.vx > 0 ? 1.0 : -1.0,
          hy,
          hy < best.headBottom,
          b.damage,
        );
        if (b.pierce > 0) {
          // .50 AE punches straight through.
          b.pierce--;
          b.damage *= 0.65;
        } else {
          b.dead = true;
        }
        continue;
      }
      if (b.y >= _groundY) {
        b.dead = true;
        _spawnSparks(b.x, _groundY, 0, const Color(0xFFC8B48A));
      } else if (b.x < -50 || b.x > _bgW + 50 || b.y < -50) {
        b.dead = true;
      }
    }
    _bullets.removeWhere((b) => b.dead);

    for (final s in _shells) {
      s.vy += 1500 * dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.angle += s.spin * dt;
      s.life -= dt;
      if (s.y >= _groundY - 1 && s.vy > 0) {
        s.y = _groundY - 1;
        s.bounces++;
        if (s.bounces == 1) {
          _wa.shellDrop.play(
            _clock,
            volume: s.big ? 0.55 : 0.22,
            pan: _panFor(s.x),
            rate: (s.big ? 0.9 : 1.25) + _rng.nextDouble() * 0.15,
            minGap: 0.07,
          );
        }
        s.vy = -s.vy * 0.35;
        s.vx *= 0.5;
        s.spin *= 0.5;
        if (s.bounces > 3) {
          s.vy = 0;
          s.vx = 0;
          s.spin = 0;
        }
      }
    }
    _shells.removeWhere((s) => s.life <= 0);
    if (_shells.length > 40) _shells.removeRange(0, _shells.length - 40);

    for (final p in _sparks) {
      p.vy += 900 * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt;
    }
    _sparks.removeWhere((p) => p.life <= 0);

    for (final p in _smoke) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vx *= 0.96;
      p.life -= dt;
    }
    _smoke.removeWhere((p) => p.life <= 0);
  }

  void _spawnSparks(double x, double y, double dirX, Color c) {
    for (var i = 0; i < 7; i++) {
      final a = -math.pi / 2 + (_rng.nextDouble() - 0.5) * 2.2 + dirX * 0.6;
      final sp = 120 + _rng.nextDouble() * 260;
      _sparks.add(
        _Spark(
          x,
          y,
          math.cos(a) * sp,
          math.sin(a) * sp,
          0.2 + _rng.nextDouble() * 0.15,
        ),
      );
    }
  }

  static bool _segmentHitsRect(
    double x0,
    double y0,
    double x1,
    double y1,
    Rect r,
  ) {
    const steps = 6;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      if (r.contains(Offset(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t))) {
        return true;
      }
    }
    return false;
  }

  void _playStep() {
    final p = _area == Area.metro ? _stepsMetro : _steps;
    p.stop().then((_) => p.resume());
  }

  void _stopSteps() {
    _steps.stop();
    _stepsMetro.stop();
  }

  @override
  void dispose() {
    // Leaving the game always keeps the world: save where we are.
    if (_loaded && !_dead) {
      Profile.i.totalKills += _kills - _killsAtStart;
      _killsAtStart = _kills;
      _writeSave();
      Profile.i.save();
    }
    _life.dispose();
    _forestLoop.dispose();
    MenuMusic.leaveGame();
    _ticker.dispose();
    _steps.dispose();
    for (final p in _shots) {
      p.dispose();
    }
    _reloadSfx.dispose();
    _stepsMetro.dispose();
    _wa.dispose();
    _za.dispose();
    _posesDe?.dispose();
    _pistol?.dispose();
    _zWalkImg?.dispose();
    _zSporeImg?.dispose();
    _sheet?.dispose();
    _poses?.dispose();
    _rifle?.dispose();
    for (final i in _itemImgs.values) {
      i.dispose();
    }
    _ammoImg?.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------

  Widget _holdButton({
    required Widget child,
    required bool pressed,
    required ValueChanged<bool> onChanged,
    double size = 72,
    Color accent = const Color(0xFFB8A27A),
  }) {
    return Listener(
      onPointerDown: (_) => onChanged(true),
      onPointerUp: (_) => onChanged(false),
      onPointerCancel: (_) => onChanged(false),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: pressed ? 0.72 : 0.45),
          border: Border.all(
            color: accent.withValues(alpha: pressed ? 1 : 0.7),
            width: 2,
          ),
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _icon(IconData i, [double size = 40]) =>
      Icon(i, size: size, color: const Color(0xFFD9C9A3));

  Widget _label(String t) => Text(
    t,
    style: const TextStyle(
      color: Color(0xFFD9C9A3),
      fontSize: 11,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.5,
    ),
  );

  Widget _hud() {
    final reloading = _reloadLeft > 0;
    final gun = _gun;
    final other = _GunSpec.of(_weapon == Weapon.ak ? Weapon.deagle : Weapon.ak);
    final otherIdx = _weapon == Weapon.ak ? 1 : 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        _gunPanel(reloading, gun),
        const SizedBox(height: 6),
        // Secondary weapon slot - tap to swap.
        GestureDetector(
          onTapDown: (_) => _switchWeapon(),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFFB8A27A).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.swap_horiz,
                  size: 16,
                  color: Color(0xFFB8A27A),
                ),
                const SizedBox(width: 6),
                Opacity(
                  opacity: 0.7,
                  child: Image.asset(
                    _skinOf(
                      _weapon == Weapon.ak ? Weapon.deagle : Weapon.ak,
                    ).sprite,
                    width: other.hudWidth * 0.6,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${other.shortName}  ${_mags[otherIdx]}/${_reserves[otherIdx]}',
                  style: const TextStyle(
                    color: Color(0xFFB8A27A),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _gunPanel(bool reloading, _GunSpec gun) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 14, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFB8A27A).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 70,
            child: Center(
              child: Image.asset(
                _skinOf(_weapon).sprite,
                width: gun.hudWidth,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _label(gun.name),
              const SizedBox(height: 2),
              if (reloading)
                SizedBox(
                  width: 90,
                  height: 22,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('RELOADING'),
                      const SizedBox(height: 3),
                      LinearProgressIndicator(
                        value: 1 - _reloadLeft / _reloadTime,
                        minHeight: 4,
                        backgroundColor: Colors.white12,
                        color: const Color(0xFFE0B050),
                      ),
                    ],
                  ),
                )
              else
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$_ammo',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: _ammo <= (gun.mag / 6).ceil()
                              ? const Color(0xFFE05A3A)
                              : const Color(0xFFF1E4C3),
                        ),
                      ),
                      TextSpan(
                        text: ' / $_reserve',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFFB8A27A),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shakeOff = _shake > 0 && Profile.i.screenShake
        ? Offset(
            (_rng.nextDouble() - 0.5) * 6 * _shake,
            (_rng.nextDouble() - 0.5) * 6 * _shake,
          )
        : Offset.zero;
    final bs = Profile.i.buttonScale;
    final bo = Profile.i.buttonOpacity;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_dead) {
          _toMenu();
        } else {
          _setPaused(!_paused);
        }
      },
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Transform.translate(
                offset: shakeOff,
                child: Transform.scale(
                  scale: 1.02,
                  child: CustomPaint(
                    foregroundPainter: _WorldPainter(state: this),
                    child: Image.asset(
                      _area.background,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.medium,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/ui/blood_hand.png',
                                  height: 24,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'بقا در مرگ',
                                  style: TextStyle(
                                    color: Color(0xFFC02020),
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    shadows: [Shadow(blurRadius: 6)],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _healthBar(),
                            _survivalHud(),
                            const SizedBox(height: 4),
                            Text(
                              '${_area.title}   ·   '
                              'KILLS $_kills   HEADSHOTS $_headshots   '
                              'SCORE $_score',
                              style: const TextStyle(
                                color: Color(0xFFB8A27A),
                                fontSize: 10.5,
                                letterSpacing: 1.3,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(blurRadius: 4)],
                              ),
                            ),
                            _worldHud(),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: _pauseButton(),
                      ),
                      Align(alignment: Alignment.topRight, child: _hud()),
                      if (_banner > 0 && !_dead) _waveBanner(),
                      if (_noticeT > 0 && !_dead)
                        Align(
                          alignment: const Alignment(0, -0.12),
                          child: _noticeBanner(),
                        ),
                      // Backpack quick bar (bottom centre).
                      if (!_dead)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Opacity(
                            opacity: bo,
                            child: Transform.scale(
                              scale: bs.clamp(0.8, 1.0),
                              alignment: Alignment.bottomCenter,
                              child: _quickbar(),
                            ),
                          ),
                        ),
                      if (_bagOpen && !_dead)
                        Align(
                          alignment: const Alignment(0, 0.25),
                          child: _bagPanel(),
                        ),
                      if (_target case final t?)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 62),
                            child: _interactButton(t),
                          ),
                        ),
                      // Movement (left side)
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Opacity(
                          opacity: bo,
                          child: Transform.scale(
                            scale: bs,
                            alignment: Alignment.bottomLeft,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _holdButton(
                                  pressed: _btnLeft,
                                  onChanged: (v) => _btnLeft = v,
                                  child: _icon(Icons.chevron_left, 44),
                                ),
                                const SizedBox(width: 14),
                                _holdButton(
                                  pressed: _btnRight,
                                  onChanged: (v) => _btnRight = v,
                                  child: _icon(Icons.chevron_right, 44),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Actions (right side)
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Opacity(
                          opacity: bo,
                          child: Transform.scale(
                            scale: bs,
                            alignment: Alignment.bottomRight,
                            child: SizedBox(
                              width: 230,
                              height: 170,
                              child: Stack(
                                children: [
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: _holdButton(
                                      size: 92,
                                      pressed: _btnFire,
                                      accent: const Color(0xFFE05A3A),
                                      onChanged: (v) => _btnFire = v,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _icon(Icons.gps_fixed, 34),
                                          _label('FIRE'),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 104,
                                    bottom: 0,
                                    child: _holdButton(
                                      size: 64,
                                      pressed: _crouchToggle,
                                      onChanged: (v) {
                                        if (v) _crouchToggle = !_crouchToggle;
                                      },
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _icon(
                                            Icons.keyboard_double_arrow_down,
                                            26,
                                          ),
                                          _label('CROUCH'),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 14,
                                    bottom: 102,
                                    child: _holdButton(
                                      size: 64,
                                      pressed: _btnJump,
                                      onChanged: (v) => _btnJump = v,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _icon(
                                            Icons.keyboard_double_arrow_up,
                                            26,
                                          ),
                                          _label('JUMP'),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 96,
                                    bottom: 84,
                                    child: _holdButton(
                                      size: 52,
                                      pressed: _reloadLeft > 0,
                                      onChanged: (v) {
                                        if (v) _startReload();
                                      },
                                      child: _icon(Icons.autorenew, 26),
                                    ),
                                  ),
                                  Positioned(
                                    right: 166,
                                    bottom: 104,
                                    child: _holdButton(
                                      size: 52,
                                      pressed: _switchLeft > 0,
                                      onChanged: (v) {
                                        if (v) _switchWeapon();
                                      },
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _icon(Icons.swap_horiz, 22),
                                          _label('GUN'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_fade > 0 && !_paused)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.black.withValues(
                        alpha: _fade.clamp(0.0, 1.0),
                      ),
                    ),
                  ),
                ),
              if (_dead && _deadT > 1.2) Positioned.fill(child: _gameOver()),
              if (_paused) Positioned.fill(child: _pauseMenu()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _healthBar() {
    final frac = (_hp / _maxHp).clamp(0.0, 1.0);
    final c = frac > 0.5
        ? const Color(0xFF6CC04A)
        : frac > 0.25
        ? const Color(0xFFE0C040)
        : const Color(0xFFD03020);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.favorite,
          size: 18,
          color: c,
          shadows: const [Shadow(blurRadius: 4)],
        ),
        const SizedBox(width: 6),
        Container(
          width: 180,
          height: 14,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: const Color(0xFFB8A27A).withValues(alpha: 0.6),
            ),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: frac,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color.lerp(c, Colors.white, 0.3)!, c],
                    ),
                  ),
                ),
              ),
              if (_poison > 0.05)
                Container(
                  color: const Color(
                    0xFF9AC030,
                  ).withValues(alpha: 0.35 * _poison),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${_hp.ceil()}',
          style: TextStyle(
            color: c,
            fontWeight: FontWeight.w900,
            fontSize: 14,
            shadows: const [Shadow(blurRadius: 4)],
          ),
        ),
      ],
    );
  }

  Widget _waveBanner() {
    final t = _banner;
    final a = t > 2.6 ? (3 - t) / 0.4 : (t < 0.6 ? t / 0.6 : 1.0);
    return Align(
      alignment: const Alignment(0, -0.45),
      child: IgnorePointer(
        child: Opacity(
          opacity: a.clamp(0.0, 1.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _bannerText,
                style: const TextStyle(
                  color: Color(0xFFE05A3A),
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 8,
                  shadows: [Shadow(blurRadius: 10), Shadow(blurRadius: 3)],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _bannerSub,
                style: const TextStyle(
                  color: Color(0xFFD9C9A3),
                  fontSize: 13,
                  letterSpacing: 3,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(blurRadius: 6)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Re-opens the survival world from the last save (used after passing out).
  void _restart() {
    Navigator.of(context).pushReplacement(_fadeRoute(const DemoScreen()));
  }
}

// ---------------------------------------------------------------------------
// Carried-rifle geometry for the walk sheet (cell pixels, x relative to body
// centre, y from top of the 300 px tall cell).
// ---------------------------------------------------------------------------

class _CarryGeom {
  const _CarryGeom(
    this.grip,
    this.muzzle,
    this.port,
    this.angle,
    this.length,
    this.gripFx,
    this.gripFy,
  );
  final Offset grip; // where the pistol grip sits (front hand)
  final Offset muzzle;
  final Offset port;
  final double angle;

  /// Weapon length in cell pixels and sprite grip point (fractions).
  final double length, gripFx, gripFy;

  static _CarryGeom of(int frame, [Weapon weapon = Weapon.ak]) {
    // Small per-frame bob so the weapon moves with the arm swing.
    final bob = math.sin(frame / _frameCount * math.pi * 4) * 3;
    final pistol = weapon == Weapon.deagle;
    final grip = Offset(pistol ? 8 : 0, (pistol ? 160 : 166) + bob);
    final angle = pistol ? 0.35 : 0.12; // muzzle down (low ready)
    final length = pistol ? 46.0 : 150.0;
    final gripFx = pistol ? 0.24 : 0.28;
    final gripFy = pistol ? 0.62 : 0.5;
    final aspect = pistol ? 169 / 300 : 101 / 360;
    Offset along(double fx, double fy) {
      final lx = (fx - gripFx) * length;
      final ly = (fy - gripFy) * length * aspect;
      return Offset(
        grip.dx + lx * math.cos(angle) - ly * math.sin(angle),
        grip.dy + lx * math.sin(angle) + ly * math.cos(angle),
      );
    }

    return _CarryGeom(
      grip,
      pistol ? along(1.0, 0.14) : along(1.0, 0.23),
      pistol ? along(0.4, 0.05) : along(0.45, 0.2),
      angle,
      length,
      gripFx,
      gripFy,
    );
  }
}

// ---------------------------------------------------------------------------
// Painter: survivor, rifle, bullets, effects – mapped with BoxFit.cover math
// so everything stays on the road at any screen size.
// ---------------------------------------------------------------------------

class _WorldPainter extends CustomPainter {
  _WorldPainter({required this.state});
  final _DemoScreenState state;

  @override
  void paint(Canvas canvas, Size size) {
    final st = state;
    final scale = math.max(size.width / _bgW, size.height / _bgH);
    final ox = (size.width - _bgW * scale) / 2;
    final oy = (size.height - _bgH * scale) / 2;
    Offset w(double x, double y) => Offset(ox + x * scale, oy + y * scale);

    // ---- Area props ----
    if (st._area == Area.forest) _paintFog(canvas, st, w, scale, front: false);
    if (st._area == Area.city) {
      _paintMetroEntrance(canvas, st, w, scale);
      _paintForestSign(canvas, st, w, scale);
    }
    if (st._area == Area.forest) _paintPump(canvas, st, w, scale);
    _paintSpots(canvas, st, w, scale);
    _paintDoorPrompt(canvas, st, w, scale);

    // ---- Ground decals, pickups, zombies (behind the player) ----
    _paintDecals(canvas, st, w, scale);
    _paintPickups(canvas, st, w, scale);

    // Actors are drawn into one layer that gets the area's colour grade and
    // light direction, so the sprites sit *inside* the painted scene instead
    // of looking pasted on top of it.
    final full = Offset.zero & size;
    canvas.saveLayer(
      full,
      Paint()..colorFilter = ColorFilter.matrix(_gradeMatrix(st._area)),
    );
    for (final z in st._zombies.where((z) => !z.alive)) {
      _paintZombie(canvas, st, z, w, scale);
    }
    for (final z in st._zombies.where((z) => z.alive)) {
      _paintZombie(canvas, st, z, w, scale);
    }

    // ---- Player ----
    final pistolMode = st._weapon == Weapon.deagle;
    final sheet = st._sheet;
    final poses = pistolMode ? st._posesDe : st._poses;
    final rifle = pistolMode ? st._pistol : st._rifle;
    if (sheet != null && poses != null && rifle != null) {
      final k = st._heroH / _poseCellH * scale; // cell px -> screen px
      final feet = w(st._x, _groundY - st._y);
      final ground = w(st._x, _groundY);
      final sdir = st._facingRight ? 1.0 : -1.0;
      final recoilPx = st._recoil * 4 * k;
      // Weapon draw: lower the gun briefly while switching.
      final drawDip = st._switchLeft > 0 ? st._switchLeft / 0.35 : 0.0;

      // Shadow shrinks while airborne.
      final air = (st._y / 130).clamp(0.0, 1.0);
      canvas.drawOval(
        Rect.fromCenter(
          center: ground.translate(0, -2 * scale),
          width: 80 * scale * _actorScale * (1 - 0.45 * air),
          height: 10 * scale * _actorScale * (1 - 0.3 * air),
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.45 * (1 - 0.5 * air)),
      );

      canvas.save();
      canvas.translate(feet.dx - recoilPx * sdir, feet.dy);
      if (!st._facingRight) canvas.scale(-1, 1);
      if (st._dead) {
        // Collapse backwards.
        final t = (st._deadT / 0.6).clamp(0.0, 1.0);
        canvas.rotate(-t * math.pi / 2 * 0.92);
      }
      final pose = st._pose;
      final paint = Paint()..filterQuality = FilterQuality.medium;
      if (st._invuln > 0 && ((st._invuln * 20).floor()).isEven) {
        paint.colorFilter = const ColorFilter.mode(
          Color(0x88FF3020),
          BlendMode.srcATop,
        );
      }
      if (pose == null) {
        // Walk cycle + rifle carried at low ready.
        final fw = sheet.width / _frameCount;
        final fh = sheet.height.toDouble();
        final h = _poseCellH * k;
        final wd = h * fw / fh;
        canvas.drawImageRect(
          sheet,
          Rect.fromLTWH(st._frame * fw, 0, fw, fh),
          Rect.fromLTWH(-wd / 2, -h, wd, h),
          paint,
        );
        final g = _CarryGeom.of(st._frame, st._weapon);
        canvas.save();
        canvas.translate(
          g.grip.dx * k,
          -(_poseCellH - g.grip.dy) * k + drawDip * 18 * k,
        );
        canvas.rotate(g.angle + drawDip * 0.6);
        final rl = g.length * k;
        final rh = rl * rifle.height / rifle.width;
        canvas.drawImageRect(
          rifle,
          Rect.fromLTWH(0, 0, rifle.width.toDouble(), rifle.height.toDouble()),
          Rect.fromLTWH(-g.gripFx * rl, -g.gripFy * rh, rl, rh),
          paint,
        );
        canvas.restore();
      } else {
        final breath = (pose == Pose.aim || pose == Pose.crouchLow)
            ? 0.006 * math.sin(st._clock * 2.4)
            : 0.0;
        final i = pose.index;
        // Heavy .50 AE muzzle climb: tilt the whole aim pose back a bit.
        final climb = pistolMode ? -st._recoil * 0.035 : 0.0;
        canvas.save();
        canvas.rotate(climb - drawDip * 0.05);
        canvas.drawImageRect(
          poses,
          Rect.fromLTWH(i * _poseCellW, 0, _poseCellW, _poseCellH),
          Rect.fromLTWH(
            -_poseAnchorX * k,
            -_poseCellH * k * (1 + breath),
            _poseCellW * k,
            _poseCellH * k * (1 + breath),
          ),
          paint,
        );
        canvas.restore();
      }
      canvas.restore();
    }

    _paintActorLight(canvas, full, st, w);
    canvas.restore();
    _paintUseFx(canvas, st, w, scale);

    // ---- Muzzle flash (full brightness, above the graded actors) ----
    if (st._flash > 0 && st._sheet != null) {
      final sdir = st._facingRight ? 1.0 : -1.0;
      final (m, _) = st._gunPoints();
      final mp = w(m.dx - st._recoil * 4 * st._heroH / _poseCellH * sdir, m.dy);
      _paintFlash(canvas, mp, sdir, scale, st);
    }

    // ---- Smoke ----
    for (final p in st._smoke) {
      final a = (p.life / 0.7).clamp(0.0, 1.0);
      canvas.drawCircle(
        w(p.x, p.y),
        (6 + (1 - a) * 14) * scale,
        Paint()..color = const Color(0xFFBDB6A6).withValues(alpha: 0.18 * a),
      );
    }

    // ---- Bullets (tracers) ----
    for (final b in st._bullets) {
      final head = w(b.x, b.y);
      final tail = w(b.x - b.vx * 0.022, b.y - b.vy * 0.022);
      canvas.drawLine(
        tail,
        head,
        Paint()
          ..shader = ui.Gradient.linear(tail, head, [
            st._skinOf(st._weapon).tracer.withValues(alpha: 0),
            st._skinOf(st._weapon).tracer,
          ])
          ..strokeWidth = 2.2 * scale
          ..strokeCap = StrokeCap.round,
      );
    }

    // ---- Shell casings ----
    for (final s in st._shells) {
      final a = (s.life / 0.5).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(ox + s.x * scale, oy + s.y * scale);
      canvas.rotate(s.angle);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: (s.big ? 6 : 7) * scale,
          height: (s.big ? 4.2 : 3) * scale,
        ),
        Paint()..color = const Color(0xFFD4A64A).withValues(alpha: a),
      );
      canvas.restore();
    }

    // ---- Sparks ----
    for (final p in st._sparks) {
      final a = (p.life / p.maxLife).clamp(0.0, 1.0);
      final pos = w(p.x, p.y);
      canvas.drawLine(
        pos,
        pos - Offset(p.vx, p.vy) * 0.015 * scale,
        Paint()
          ..color = const Color(0xFFFFD27A).withValues(alpha: a)
          ..strokeWidth = 1.6 * scale,
      );
    }

    _paintGore(canvas, st, w, scale);
    _paintClouds(canvas, st, w, scale);
    for (final z in st._zombies.where((z) => z.alive)) {
      _paintZombieBar(canvas, st, z, w, scale);
    }
    if (st._area == Area.metro) {
      _paintDrips(canvas, st, w, scale);
      _paintMetroLighting(canvas, size, st, w, scale);
    }
    if (st._area == Area.forest) {
      _paintFog(canvas, st, w, scale, front: true);
      _paintRain(canvas, st, w, scale);
    }
    if (st._area.surface) _paintDarkness(canvas, size, st, w, scale);
    _paintTexts(canvas, st, w, scale);
    if (st._area == Area.city) _paintAsh(canvas, st, w, scale);
    _paintVignettes(canvas, size, st);

    // ---- Screen flash from shots ----
    if (st._flash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFFFFC870).withValues(alpha: 0.06),
      );
    }
  }

  void _paintFlash(
    Canvas canvas,
    Offset p,
    double dir,
    double scale,
    _DemoScreenState st,
  ) {
    final big = st._weapon == Weapon.deagle ? 1.4 : 1.0;
    final len = (34 + st._rng.nextDouble() * 18) * scale * big;
    final glow = Paint()
      ..shader = ui.Gradient.radial(p, len * 1.3, [
        const Color(0xAAFFD27A),
        const Color(0x00FF8A2A),
      ]);
    canvas.drawCircle(p, len * 1.3, glow);

    final path = Path();
    final spikes = 7;
    for (var i = 0; i < spikes * 2; i++) {
      final a = i * math.pi / spikes;
      var r = i.isEven
          ? len * (0.35 + st._rng.nextDouble() * 0.25)
          : len * 0.12;
      // Elongate forward.
      final cx = math.cos(a), cy = math.sin(a);
      final fwd = cx * dir > 0 ? 1.0 + 1.4 * (cx * dir) : 1.0;
      r *= fwd;
      final pt = p + Offset(cx * r, cy * r * 0.7);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = const Color(0xFFFFB347));
    canvas.drawCircle(
      p + Offset(6 * scale * dir, 0),
      len * 0.16,
      Paint()..color = const Color(0xFFFFF8E0),
    );
  }

  // -------------------------------------------------------------------------
  // Zombies
  // -------------------------------------------------------------------------

  void _paintZombie(
    Canvas canvas,
    _DemoScreenState st,
    _Zombie z,
    Offset Function(double, double) w,
    double scale,
  ) {
    final img = z.type == ZType.walker ? st._zWalkImg : st._zSporeImg;
    if (img == null) return;
    const cellW = 200.0, cellH = 300.0;
    final k = z.height / (cellH - 4) * scale; // cell px -> screen px
    final face = z.facingRight ? 1.0 : -1.0;
    final feet = w(z.x + z.lunge * face, _groundY);

    var alpha = 1.0;
    if (!z.alive) alpha = (1 - (z.deathT - 6) / 2).clamp(0.0, 1.0);
    if (alpha <= 0) return;

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: feet.translate(0, -2 * scale),
        width: (z.alive ? 70 : 110) * scale * _actorScale,
        height: 9 * scale * _actorScale,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.4 * alpha),
    );

    canvas.save();
    canvas.translate(feet.dx, feet.dy);
    if (z.alive) {
      // Shamble bob + lean, attack tilt, stagger recoil.
      final bob = (math.sin(z.anim * z.spec.fps * math.pi / 2) * 1.5) * scale;
      canvas.translate(0, -bob.abs());
      var rot = z.tilt * face + 0.03 * face;
      if (z.stagger > 0) rot -= 0.12 * face * (z.stagger / 0.25);
      canvas.rotate(rot);
    } else {
      // Topple over away from the shot, with a little bounce on impact.
      final t = (z.deathT / 0.55).clamp(0.0, 1.0);
      final ease = t * t;
      var ang = ease * math.pi / 2 * 0.96;
      if (t >= 1) {
        final b = (z.deathT - 0.55);
        if (b < 0.25) ang -= math.sin(b / 0.25 * math.pi) * 0.08;
      }
      // Knees buckle first: sink a bit before falling.
      final sink = math.min(z.deathT / 0.2, 1.0) * 10 * scale;
      canvas.translate(0, -sink * (1 - ease) + sink * 0.3);
      canvas.rotate(ang * z.fallDir);
    }
    canvas.scale(face, 1);

    final frame = z.alive ? z.frame : 2;
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (z.flash > 0) {
      paint.colorFilter = const ColorFilter.mode(
        Color(0xCCFFFFFF),
        BlendMode.srcATop,
      );
    } else if (!z.alive) {
      paint.colorFilter = ColorFilter.mode(
        Colors.black.withValues(alpha: 0.25),
        BlendMode.srcATop,
      );
    } else if (z.state == ZState.attack && z.attackT < z.spec.windup) {
      // Eyes "flare" during the wind-up: faint red tint.
      paint.colorFilter = ColorFilter.mode(
        const Color(0xFFFF2010).withValues(alpha: 0.18),
        BlendMode.srcATop,
      );
    }
    if (alpha < 1) {
      paint.color = Colors.white.withValues(alpha: alpha);
    }
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(frame * cellW, 0, cellW, cellH),
      Rect.fromLTWH(-cellW / 2 * k, -(cellH - 2) * k, cellW * k, cellH * k),
      paint,
    );

    // Spore zombie: pulsing bioluminescent glow on the cap.
    if (z.type == ZType.spore && z.alive) {
      final pulse = 0.5 + 0.5 * math.sin(st._clock * 3 + z.speedMul * 10);
      final c = Offset(10 * k, -(cellH - 50) * k);
      canvas.drawCircle(
        c,
        46 * k,
        Paint()
          ..shader = ui.Gradient.radial(c, 46 * k, [
            _sporeGlow.withValues(alpha: 0.10 + 0.12 * pulse),
            _sporeGlow.withValues(alpha: 0),
          ]),
      );
    }
    canvas.restore();
  }

  void _paintZombieBar(
    Canvas canvas,
    _DemoScreenState st,
    _Zombie z,
    Offset Function(double, double) w,
    double scale,
  ) {
    final face = z.facingRight ? 1.0 : -1.0;
    final maxHp = st._zMaxHp(z);
    final frac = (z.hp / maxHp).clamp(0.0, 1.0);
    final ghost = (z.ghostHp / maxHp).clamp(0.0, 1.0);
    final top = w(z.x + z.lunge * face, z.top - 16);
    final bw = (z.type == ZType.walker ? 58.0 : 72.0) * scale;
    final bh = 6.5 * scale;
    final r = Rect.fromCenter(center: top, width: bw, height: bh);

    // Name plate
    final tp = TextPainter(
      text: TextSpan(
        text: z.spec.name,
        style: TextStyle(
          color: z.spec.barColor,
          fontSize: 8.5 * scale,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2 * scale,
          shadows: const [Shadow(blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(r.left, r.top - tp.height - 1.5 * scale));
    // HP number
    final hpTp = TextPainter(
      text: TextSpan(
        text: '${z.hp.ceil()}',
        style: TextStyle(
          color: const Color(0xFFF1E4C3),
          fontSize: 8 * scale,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    hpTp.paint(
      canvas,
      Offset(r.right + 4 * scale, r.center.dy - hpTp.height / 2),
    );

    // Frame
    final outer = RRect.fromRectAndRadius(
      r.inflate(1.6 * scale),
      Radius.circular(2.5 * scale),
    );
    canvas.drawRRect(outer, Paint()..color = const Color(0xE6000000));
    canvas.drawRRect(
      outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 * scale
        ..color = (z.barPulse > 0 ? Colors.white : z.spec.barColor).withValues(
          alpha: z.barPulse > 0 ? 0.9 : 0.55,
        ),
    );
    canvas.drawRect(r, Paint()..color = const Color(0xFF2A1212));
    // Trailing damage
    if (ghost > frac) {
      canvas.drawRect(
        Rect.fromLTWH(r.left, r.top, r.width * ghost, r.height),
        Paint()..color = const Color(0xFFFFE6A0),
      );
    }
    // Health: green -> yellow -> red gradient by remaining HP
    final hc = frac > 0.5
        ? Color.lerp(
            const Color(0xFFE0C040),
            const Color(0xFF6CC04A),
            (frac - 0.5) * 2,
          )!
        : Color.lerp(
            const Color(0xFFD03020),
            const Color(0xFFE0C040),
            frac * 2,
          )!;
    final hr = Rect.fromLTWH(r.left, r.top, r.width * frac, r.height);
    canvas.drawRect(
      hr,
      Paint()
        ..shader = ui.Gradient.linear(
          hr.topLeft,
          hr.bottomLeft,
          [
            Color.lerp(hc, Colors.white, 0.35)!,
            hc,
            Color.lerp(hc, Colors.black, 0.35)!,
          ],
          [0, 0.45, 1],
        ),
    );
    // Segment ticks every 25 HP
    final ticks = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..strokeWidth = 1 * scale;
    for (var hp = 25.0; hp < maxHp; hp += 25) {
      final x = r.left + r.width * hp / maxHp;
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), ticks);
    }
  }

  // -------------------------------------------------------------------------
  // Effects
  // -------------------------------------------------------------------------

  void _paintDecals(
    Canvas canvas,
    _DemoScreenState st,
    Offset Function(double, double) w,
    double scale,
  ) {
    for (final d in st._decals) {
      final a = (d.life / 3).clamp(0.0, 1.0);
      final c = w(d.x, _groundY + 3);
      canvas.drawOval(
        Rect.fromCenter(center: c, width: d.w * scale, height: 7 * scale),
        Paint()..color = d.color.withValues(alpha: 0.85 * a),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(d.w * 0.3 * scale, 1 * scale),
          width: d.w * 0.4 * scale,
          height: 4 * scale,
        ),
        Paint()..color = d.color.withValues(alpha: 0.7 * a),
      );
    }
  }

  void _paintPickups(
    Canvas canvas,
    _DemoScreenState st,
    Offset Function(double, double) w,
    double scale,
  ) {
    for (final p in st._pickups) {
      if (p.life < 3 && ((p.life * 6).floor()).isEven) continue; // blink out
      final drop = p.age < 0.4 ? (1 - p.age / 0.4) * 40 : 0.0;
      final bob = math.sin(p.age * 3) * 2;
      final c = w(p.x, _groundY - 12 - drop - bob.abs());
      // Glow
      canvas.drawCircle(
        c,
        26 * scale,
        Paint()
          ..shader = ui.Gradient.radial(c, 26 * scale, [
            p.item == null
                ? const Color(0x55FFD060)
                : ItemInfo.of(p.item!).color.withValues(alpha: 0.33),
            const Color(0x00000000),
          ]),
      );
      final img = p.item == null ? st._ammoImg : st._itemImgs[p.item];
      if (img == null) continue;
      // Sprite lying on the ground with a contact shadow, tinted to the
      // area's light so it belongs to the scene.
      final sz = 30 * scale * _actorScale;
      final ground = w(p.x, _groundY);
      canvas.drawOval(
        Rect.fromCenter(
          center: ground.translate(0, -1.5 * scale),
          width: sz * 0.95,
          height: sz * 0.18,
        ),
        Paint()..color = Colors.black.withValues(alpha: 0.45),
      );
      final dst = Rect.fromCenter(
        center: Offset(c.dx, c.dy + 13 * scale - sz / 2),
        width: sz,
        height: sz,
      );
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        dst,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..colorFilter = ColorFilter.matrix(_gradeMatrix(st._area)),
      );
      // Small glint so pickups are easy to spot.
      final glint = (math.sin(p.age * 4) + 1) / 2;
      canvas.drawCircle(
        dst.topCenter.translate(sz * 0.18, sz * 0.2),
        1.6 * scale * (0.5 + glint),
        Paint()..color = Colors.white.withValues(alpha: 0.35 + 0.5 * glint),
      );
    }
  }

  void _paintGore(
    Canvas canvas,
    _DemoScreenState st,
    Offset Function(double, double) w,
    double scale,
  ) {
    for (final g in st._gore) {
      final a = (g.life / (g.float ? g.maxLife : 0.6)).clamp(0.0, 1.0);
      final p = w(g.x, g.y);
      if (g.float) {
        canvas.drawCircle(
          p,
          g.size * 2.4 * scale,
          Paint()..color = g.color.withValues(alpha: 0.12 * a),
        );
        canvas.drawCircle(
          p,
          g.size * 0.7 * scale,
          Paint()..color = g.color.withValues(alpha: 0.9 * a),
        );
      } else if (g.landed) {
        canvas.drawOval(
          Rect.fromCenter(
            center: p,
            width: g.size * 2.6 * scale,
            height: g.size * 0.9 * scale,
          ),
          Paint()..color = g.color.withValues(alpha: 0.8 * a),
        );
      } else {
        canvas.drawLine(
          p,
          p - Offset(g.vx, g.vy) * 0.012 * scale,
          Paint()
            ..color = g.color.withValues(alpha: a)
            ..strokeWidth = g.size * scale
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  void _paintClouds(
    Canvas canvas,
    _DemoScreenState st,
    Offset Function(double, double) w,
    double scale,
  ) {
    for (final c in st._clouds) {
      final fadeIn = ((c.maxLife - c.life) / 0.3).clamp(0.0, 1.0);
      final a = math.min(fadeIn, (c.life / 1.5).clamp(0.0, 1.0));
      for (var i = 0; i < 5; i++) {
        final ang = c.seed + i * 1.256 + st._clock * 0.4;
        final off = Offset(math.cos(ang), math.sin(ang) * 0.6) * c.radius * 0.4;
        final p = w(c.x + off.dx, c.y + off.dy);
        final rad =
            c.radius * (0.7 + 0.15 * math.sin(st._clock * 2 + i)) * scale;
        canvas.drawCircle(
          p,
          rad,
          Paint()
            ..shader = ui.Gradient.radial(
              p,
              rad,
              [
                const Color(0xFFB8D24A).withValues(alpha: 0.32 * a),
                const Color(0xFF6A8A20).withValues(alpha: 0.14 * a),
                const Color(0x00000000),
              ],
              [0, 0.55, 1],
            ),
        );
      }
    }
  }

  void _paintTexts(
    Canvas canvas,
    _DemoScreenState st,
    Offset Function(double, double) w,
    double scale,
  ) {
    for (final t in st._texts) {
      final a = (t.life / 0.4).clamp(0.0, 1.0);
      final pop = t.big
          ? 1 + 0.4 * ((t.life - 0.75) / 0.15).clamp(0.0, 1.0)
          : 1.0;
      final tp = TextPainter(
        text: TextSpan(
          text: t.text,
          style: TextStyle(
            color: t.color.withValues(alpha: a),
            fontSize: (t.big ? 15 : 11) * scale * pop,
            fontWeight: FontWeight.w900,
            letterSpacing: t.big ? 1.5 : 0,
            shadows: [
              Shadow(
                blurRadius: 3,
                color: Colors.black.withValues(alpha: a),
                offset: const Offset(1, 1),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final p = w(t.x, t.y);
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _paintAsh(
    Canvas canvas,
    _DemoScreenState st,
    Offset Function(double, double) w,
    double scale,
  ) {
    final paint = Paint();
    for (final a in st._ash) {
      final flick = 0.35 + 0.25 * math.sin(st._clock * 2 + a.phase);
      paint.color = const Color(0xFFCFC6B4).withValues(alpha: flick);
      canvas.drawCircle(w(a.x, a.y), a.size * 0.6 * scale, paint);
    }
  }

  void _paintVignettes(Canvas canvas, Size size, _DemoScreenState st) {
    final rect = Offset.zero & size;
    final c = rect.center;
    final rad = size.longestSide * 0.7;
    // Constant moody vignette
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          rad,
          [
            const Color(0x00000000),
            const Color(0x00000000),
            const Color(0x88000000),
          ],
          [0, 0.6, 1],
        ),
    );
    // Low HP heartbeat
    final low = st._hp < 35 && !st._dead
        ? (1 - st._hp / 35) * (0.5 + 0.5 * math.sin(st._clock * 7).abs())
        : 0.0;
    final hurt = math.max(st._hurt, low * 0.7);
    if (hurt > 0) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            rad,
            [
              const Color(0x00000000),
              const Color(0xFF8A0000).withValues(alpha: 0.65 * hurt),
            ],
            [0.45, 1],
          ),
      );
    }
    if (st._poison > 0) {
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            rad,
            [
              const Color(0xFF9AC030).withValues(alpha: 0.08 * st._poison),
              const Color(0xFF4A6A10).withValues(alpha: 0.6 * st._poison),
            ],
            [0.3, 1],
          ),
      );
    }
    if (st._dead) {
      final t = (st._deadT / 1.5).clamp(0.0, 1.0);
      canvas.drawRect(
        rect,
        Paint()..color = const Color(0xFF200000).withValues(alpha: 0.6 * t),
      );
    }
  }

  @override
  bool shouldRepaint(_WorldPainter old) => true;
}
