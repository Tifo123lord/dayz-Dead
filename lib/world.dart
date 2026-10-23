part of 'main.dart';

// ---------------------------------------------------------------------------
// Weapons
// ---------------------------------------------------------------------------

enum Weapon { ak, deagle }

class _GunSpec {
  const _GunSpec({
    required this.name,
    required this.shortName,
    required this.hudAsset,
    required this.hudWidth,
    required this.mag,
    required this.startReserve,
    required this.interval,
    required this.reload,
    required this.auto,
    required this.damage,
    required this.pierce,
    required this.bulletSpeed,
    required this.baseSpread,
    required this.spreadGrow,
    required this.recoil,
    required this.shake,
    required this.flash,
    required this.pickupAmmo,
  });

  final String name, shortName, hudAsset;
  final double hudWidth;
  final int mag, startReserve, pierce, pickupAmmo;
  final double interval, reload, damage, bulletSpeed;
  final double baseSpread, spreadGrow, recoil, shake, flash;
  final bool auto;

  /// AK-47 (7.62 mm): ~600 rounds per minute, 30 round magazine.
  static const ak = _GunSpec(
    name: 'AK-47  7.62',
    shortName: 'AK-47',
    hudAsset: 'assets/images/ak47.png',
    hudWidth: 70,
    mag: 30,
    startReserve: 120,
    interval: 0.1,
    reload: 2.0,
    auto: true,
    damage: 34,
    pierce: 0,
    bulletSpeed: 2600,
    baseSpread: 0.012,
    spreadGrow: 0.006,
    recoil: 1,
    shake: 0.35,
    flash: 0.055,
    pickupAmmo: 30,
  );

  /// IMI Desert Eagle .50 AE: semi-auto, 7 round magazine, huge stopping
  /// power - one round can punch through the first zombie into the next.
  static const deagle = _GunSpec(
    name: 'DESERT EAGLE  .50 AE',
    shortName: 'DESERT EAGLE',
    hudAsset: 'assets/images/deagle.png',
    hudWidth: 58,
    mag: 7,
    startReserve: 35,
    interval: 0.27,
    reload: 2.2,
    auto: false,
    damage: 92,
    pierce: 1,
    bulletSpeed: 3000,
    baseSpread: 0.006,
    spreadGrow: 0.014,
    recoil: 1.8,
    shake: 0.75,
    flash: 0.08,
    pickupAmmo: 7,
  );

  static _GunSpec of(Weapon w) => w == Weapon.ak ? ak : deagle;
}

/// Muzzle position of the Desert Eagle in each pose cell (cell pixels).
const Map<Pose, Offset> _poseMuzzleDe = {
  Pose.aim: Offset(203, 54),
  Pose.crouchAim: Offset(223, 131),
  Pose.crouchLow: Offset(189, 240),
  Pose.jump: Offset(201, 141),
};

// ---------------------------------------------------------------------------
// Areas
// ---------------------------------------------------------------------------

enum Area { city, metro, forest }

/// A passage from one area to another.
class _Door {
  const _Door({
    required this.x,
    required this.to,
    required this.arriveX,
    required this.arriveRight,
    required this.icon,
    required this.button,
    required this.prompt,
    required this.down,
  });
  final double x; // position in this area (background px)
  final Area to;
  final double arriveX; // where you appear in [to]
  final bool arriveRight; // facing direction on arrival
  final IconData icon;
  final String button, prompt;
  final bool down; // arrow points down (stairs) or up
}

const List<_Door> _cityDoors = [
  _Door(
    x: 1190,
    to: Area.metro,
    arriveX: 250,
    arriveRight: true,
    icon: Icons.subway,
    button: 'ENTER',
    prompt: 'ENTER METRO',
    down: true,
  ),
  _Door(
    x: 120,
    to: Area.forest,
    arriveX: 1150,
    arriveRight: false,
    icon: Icons.forest,
    button: 'TRAIL',
    prompt: 'TO BLACKWOOD FOREST',
    down: false,
  ),
];

const List<_Door> _metroDoors = [
  _Door(
    x: 165,
    to: Area.city,
    arriveX: 1120,
    arriveRight: false,
    icon: Icons.stairs,
    button: 'EXIT',
    prompt: 'EXIT TO SURFACE',
    down: false,
  ),
];

const List<_Door> _forestDoors = [
  _Door(
    x: 1270,
    to: Area.city,
    arriveX: 230,
    arriveRight: true,
    icon: Icons.location_city,
    button: 'CITY',
    prompt: 'BACK TO THE CITY',
    down: false,
  ),
];

extension _AreaInfo on Area {
  String get title =>
      const ['RUINED CITY', 'RAVENCROFT METRO', 'BLACKWOOD FOREST'][index];

  /// Persian name used in the menus.
  String get fa => const ['شهر ویران', 'مترو ریونکرافت', 'جنگل بلک‌وود'][index];

  String get subtitle => const [
    'SURFACE  ·  STREET LEVEL',
    'UNDERGROUND  ·  LINE 3',
    'WILDERNESS  ·  HEAVY RAIN',
  ][index];

  String get background => const [
    'assets/images/background.png',
    'assets/images/metro_bg.png',
    'assets/images/forest_bg.png',
  ][index];

  List<_Door> get doors => switch (this) {
    Area.city => _cityDoors,
    Area.metro => _metroDoors,
    Area.forest => _forestDoors,
  };

  /// Safe spot where a new survivor starts / wakes up after passing out.
  double get spawnX => const [420.0, 300.0, 820.0][index];

  /// Surface areas have weather, day / night and open sky.
  bool get surface => this != Area.metro;

  /// Size of people in this area. The forest is framed much wider (huge
  /// pines, distant cabin), so survivors and zombies are drawn bigger there
  /// to match the scale of the props around them.
  double get actorScale => const [1.0, 1.0, 1.32][index];
}

/// Current actor scale (see [_AreaInfo.actorScale]); updated on area change.
double _actorScale = 1.0;

class _Lamp {
  _Lamp(this.x, this.y, this.width, this.color, {this.faulty = false});
  final double x, y, width;
  final Color color;
  final bool faulty; // flickers on its own every few seconds
  double flickerT = 0;
  double level = 1; // current brightness 0..1
}

class _Drip {
  _Drip(this.x, this.y);
  double x, y, vy = 0;
  bool splashed = false;
  double splashT = 0;
}

// ---------------------------------------------------------------------------
// Audio for weapons and environments
// ---------------------------------------------------------------------------

class _WorldAudio {
  final deagleShot = _SfxPool('audio/deagle_shot.mp3', 4, baseVolume: 1.0);
  final deagleReload = _SfxPool('audio/deagle_reload.mp3', 1, baseVolume: 0.9);
  final shotTail = _SfxPool('audio/shot_tail_metro.mp3', 3, baseVolume: 0.7);
  final weaponSwitch = _SfxPool('audio/weapon_switch.mp3', 2, baseVolume: 0.8);
  final shellDrop = _SfxPool('audio/shell_drop.mp3', 4, baseVolume: 0.8);
  final flicker = _SfxPool(
    'audio/light_flicker.mp3',
    2,
    baseVolume: 0.5,
    ambient: true,
  );
  final stairs = _SfxPool('audio/stairs_steps.mp3', 1, baseVolume: 0.9);
  final tunnelWalker = _SfxPool(
    'audio/zombie_groan_echo.mp3',
    2,
    baseVolume: 0.35,
    ambient: true,
  );
  final tunnelSpore = _SfxPool(
    'audio/mushroom_groan_echo.mp3',
    2,
    baseVolume: 0.32,
    ambient: true,
  );
  final groanWalkerEcho = _SfxPool(
    'audio/zombie_groan_echo.mp3',
    3,
    baseVolume: 0.75,
  );
  final groanSporeEcho = _SfxPool(
    'audio/mushroom_groan_echo.mp3',
    3,
    baseVolume: 0.8,
  );
  final eat = _SfxPool('audio/eat.mp3', 1, baseVolume: 0.9);
  final drink = _SfxPool('audio/drink.mp3', 1, baseVolume: 0.9);
  final bandage = _SfxPool('audio/bandage.mp3', 1, baseVolume: 0.9);
  final rummage = _SfxPool('audio/rummage.mp3', 1, baseVolume: 0.9);
  final thunder = _SfxPool(
    'audio/thunder.mp3',
    2,
    baseVolume: 0.9,
    ambient: true,
  );

  void dispose() {
    for (final p in [
      eat,
      drink,
      bandage,
      rummage,
      thunder,
      deagleShot,
      deagleReload,
      shotTail,
      weaponSwitch,
      shellDrop,
      flicker,
      stairs,
      tunnelWalker,
      tunnelSpore,
      groanWalkerEcho,
      groanSporeEcho,
    ]) {
      p.dispose();
    }
  }
}

// ---------------------------------------------------------------------------
// Logic
// ---------------------------------------------------------------------------

extension _WorldLogic on _DemoScreenState {
  void _initLamps() {
    const tube = Color(0xFFDDF5E0);
    _lamps.addAll([
      _Lamp(635, 203, 120, tube),
      _Lamp(660, 266, 110, tube, faulty: true),
      _Lamp(1125, 266, 95, tube),
      _Lamp(1159, 205, 50, tube, faulty: true),
      _Lamp(1296, 313, 85, tube),
      _Lamp(1344, 367, 14, const Color(0xFFFFA040)),
    ]);
  }

  /// Zombie voice pool - groans echo off the tiles underground.
  _SfxPool _groanPool(ZType t) {
    if (_area == Area.metro) {
      return t == ZType.walker ? _wa.groanWalkerEcho : _wa.groanSporeEcho;
    }
    return t == ZType.walker ? _za.groanWalker : _za.groanSpore;
  }

  void _startTravel(_Door door) {
    if (_travelT >= 0 || _dead) return;
    _travelT = 0;
    _travelDoor = door;
    _swapped = false;
    _stopSteps();
    if (door.to == Area.metro || _area == Area.metro) {
      _wa.stairs.play(_clock, rate: door.to == Area.metro ? 1.0 : 1.1);
    } else {
      _za.shuffle.play(_clock, volume: 2.5, rate: 0.8);
    }
  }

  void _updateTravel(double dt) {
    _travelT += dt;
    const fadeOut = 0.7, hold = 0.45, fadeIn = 0.7;
    if (_travelT < fadeOut) {
      _fade = _travelT / fadeOut;
    } else if (_travelT < fadeOut + hold) {
      _fade = 1;
      if (!_swapped) _arrive();
    } else {
      _fade = 1 - (_travelT - fadeOut - hold) / fadeIn;
      if (_fade <= 0) {
        _fade = 0;
        _travelT = -1;
      }
    }
  }

  void _arrive() {
    _swapped = true;
    final door = _travelDoor;
    _area = door.to;
    _actorScale = _area.actorScale;
    _x = door.arriveX;
    _y = 0;
    _vy = 0;
    _grounded = true;
    _facingRight = door.arriveRight;
    _vx = 0;
    _prevUse = true; // a held E / ENTER must not send you straight back
    // The horde follows you: unspent zombies are re-queued for this area.
    final alive = _zombies.where((z) => z.alive).length;
    _zombies.clear();
    if (_waveBreak <= 0) {
      _toSpawn += alive;
      _spawnIn = 2.0;
    }
    _gore.clear();
    _decals.clear();
    _clouds.clear();
    _pickups.clear();
    _bullets.clear();
    _shells.clear();
    _drips.clear();
    _bannerText = _area.title;
    _bannerSub = _area.subtitle;
    _banner = 3;
    _metroAmbIn = 1.5;
    _flickerIn = 1.0;
    _boltIn = 3 + _rng.nextDouble() * 4;
    if (_area == Area.metro) {
      _wa.tunnelWalker.play(_clock, pan: 0.8, rate: 0.7);
    } else {
      _za.distant.play(_clock, pan: -0.5, rate: 0.75);
    }
    _syncForestLoop();
    _autosave();
  }

  /// Environment life: metro lamps, water drips and tunnel ambience.
  void _updateEnvironment(double dt) {
    if (_area != Area.metro) return;

    // Lamps
    for (final l in _lamps) {
      if (l.flickerT > 0) {
        l.flickerT -= dt;
        l.level = _rng.nextDouble() < 0.45
            ? 0.08
            : 0.9 + _rng.nextDouble() * 0.1;
        if (l.flickerT <= 0) l.level = 1;
      } else {
        l.level = 0.94 + 0.06 * math.sin(_clock * 50 + l.x);
      }
    }
    _flickerIn -= dt;
    if (_flickerIn <= 0) {
      _flickerIn = 2.5 + _rng.nextDouble() * 5;
      final faulty = _lamps.where((l) => l.faulty).toList();
      final l = _rng.nextDouble() < 0.75
          ? faulty[_rng.nextInt(faulty.length)]
          : _lamps[_rng.nextInt(_lamps.length - 1)];
      l.flickerT = 0.5 + _rng.nextDouble() * 0.9;
      _wa.flicker.play(
        _clock,
        volume: _volFor(l.x),
        pan: _panFor(l.x),
        rate: 0.9 + _rng.nextDouble() * 0.2,
      );
    }

    // Water dripping from the cracked ceiling.
    _dripIn -= dt;
    if (_dripIn <= 0) {
      _dripIn = 0.25 + _rng.nextDouble() * 0.7;
      const spots = [210.0, 470, 520, 780, 905, 1010, 1240, 1300];
      _drips.add(
        _Drip(spots[_rng.nextInt(spots.length)] + _rng.nextDouble() * 6, 200),
      );
    }
    for (final d in _drips) {
      if (!d.splashed) {
        d.vy += 1400 * dt;
        d.y += d.vy * dt;
        if (d.y >= _groundY + 2) {
          d.y = _groundY + 2;
          d.splashed = true;
        }
      } else {
        d.splashT += dt;
      }
    }
    _drips.removeWhere((d) => d.splashT > 0.35);

    // Distant groans and creaks echoing out of the dark tunnel.
    _metroAmbIn -= dt;
    if (_metroAmbIn <= 0) {
      _metroAmbIn = 5 + _rng.nextDouble() * 7;
      final pan = 0.4 + _rng.nextDouble() * 0.6;
      if (_rng.nextBool()) {
        _wa.tunnelWalker.play(
          _clock,
          pan: pan,
          rate: 0.55 + _rng.nextDouble() * 0.2,
        );
      } else {
        _wa.tunnelSpore.play(
          _clock,
          pan: pan,
          rate: 0.55 + _rng.nextDouble() * 0.2,
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Painting helpers for the environments
// ---------------------------------------------------------------------------

/// Metro entrance on the city street: a stairwell cut into the road with
/// railings and an illuminated "M" sign.
void _paintMetroEntrance(
  Canvas canvas,
  _DemoScreenState st,
  Offset Function(double, double) w,
  double scale,
) {
  const cx = 1190.0;
  const halfW = 62.0;
  // Stairwell cut into the road foundation.
  final pit = Rect.fromPoints(
    w(cx - halfW, _groundY - 1),
    w(cx + halfW, _groundY + 120),
  );
  canvas.drawRect(
    pit,
    Paint()
      ..shader = ui.Gradient.linear(pit.topCenter, pit.bottomCenter, [
        const Color(0xFF2A2620),
        const Color(0xFF050505),
      ]),
  );
  // Steps
  final step = Paint()..color = const Color(0xFF4A443A);
  for (var i = 0; i < 7; i++) {
    final y = _groundY + 6 + i * 15.0;
    final x0 = cx - halfW + 6 + i * 13.0;
    canvas.drawRect(Rect.fromPoints(w(x0, y), w(cx + halfW - 4, y + 3)), step);
  }
  // Glow from the station below.
  final glowC = w(cx + 30, _groundY + 110);
  canvas.drawCircle(
    glowC,
    60 * scale,
    Paint()
      ..shader = ui.Gradient.radial(glowC, 60 * scale, [
        const Color(0x55A8E0B0),
        const Color(0x00000000),
      ]),
  );
  // Railings
  final rail = Paint()
    ..color = const Color(0xFF6A6458)
    ..strokeWidth = 3 * scale
    ..strokeCap = StrokeCap.round;
  for (final x in [cx - halfW, cx + halfW]) {
    canvas.drawLine(w(x, _groundY), w(x, _groundY - 40), rail);
  }
  canvas.drawLine(
    w(cx - halfW, _groundY - 40),
    w(cx + halfW, _groundY - 40),
    rail,
  );
  canvas.drawLine(
    w(cx - halfW, _groundY - 20),
    w(cx + halfW, _groundY - 20),
    rail..strokeWidth = 2 * scale,
  );
  // Sign post
  final post = Paint()
    ..color = const Color(0xFF3A3630)
    ..strokeWidth = 5 * scale;
  canvas.drawLine(w(cx + 78, _groundY), w(cx + 78, _groundY - 135), post);
  final pulse = 0.75 + 0.25 * math.sin(st._clock * 3);
  final flick = (st._clock * 7).floor() % 23 == 0 ? 0.3 : 1.0;
  final signC = w(cx + 78, _groundY - 150);
  canvas.drawCircle(
    signC,
    42 * scale,
    Paint()
      ..shader = ui.Gradient.radial(signC, 42 * scale, [
        const Color(0xFFE03020).withValues(alpha: 0.35 * pulse * flick),
        const Color(0x00000000),
      ]),
  );
  final box = Rect.fromCenter(
    center: signC,
    width: 30 * scale,
    height: 30 * scale,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(box, Radius.circular(4 * scale)),
    Paint()
      ..color = Color.lerp(
        const Color(0xFF401010),
        const Color(0xFFD02818),
        pulse * flick,
      )!,
  );
  final tp = TextPainter(
    text: TextSpan(
      text: 'M',
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.6 + 0.4 * flick),
        fontSize: 20 * scale,
        fontWeight: FontWeight.w900,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, signC - Offset(tp.width / 2, tp.height / 2));
}

/// Floating "[E] ENTER METRO" markers above every passage of the area.
void _paintDoorPrompt(
  Canvas canvas,
  _DemoScreenState st,
  Offset Function(double, double) w,
  double scale,
) {
  final target = st._target;
  for (final door in st._area.doors) {
    _paintOneDoorPrompt(canvas, st, w, scale, door, target?.door == door);
  }
}

void _paintOneDoorPrompt(
  Canvas canvas,
  _DemoScreenState st,
  Offset Function(double, double) w,
  double scale,
  _Door door,
  bool near,
) {
  final bob = math.sin(st._clock * 4 + door.x) * 4;
  final p = w(door.x, _groundY - 205 + bob);
  final a = near ? 1.0 : 0.45;
  final arrow = Path();
  final down = door.down;
  final s = 9 * scale;
  if (down) {
    arrow
      ..moveTo(p.dx - s, p.dy)
      ..lineTo(p.dx + s, p.dy)
      ..lineTo(p.dx, p.dy + s * 1.2)
      ..close();
  } else {
    arrow
      ..moveTo(p.dx - s, p.dy + s * 1.2)
      ..lineTo(p.dx + s, p.dy + s * 1.2)
      ..lineTo(p.dx, p.dy)
      ..close();
  }
  canvas.drawPath(
    arrow,
    Paint()..color = const Color(0xFFE0B050).withValues(alpha: a),
  );
  final tp = TextPainter(
    text: TextSpan(
      text: near ? '${door.prompt}  [E]' : door.prompt,
      style: TextStyle(
        color: const Color(0xFFF1E4C3).withValues(alpha: a),
        fontSize: 9.5 * scale,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5 * scale,
        shadows: const [Shadow(blurRadius: 4)],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - tp.height - 4 * scale));
}

void _paintDrips(
  Canvas canvas,
  _DemoScreenState st,
  Offset Function(double, double) w,
  double scale,
) {
  final drop = Paint()
    ..color = const Color(0xAAB8D8E0)
    ..strokeWidth = 1.6 * scale
    ..strokeCap = StrokeCap.round;
  for (final d in st._drips) {
    if (!d.splashed) {
      canvas.drawLine(w(d.x, d.y - 6), w(d.x, d.y), drop);
    } else {
      final t = d.splashT / 0.35;
      final c = w(d.x, d.y);
      canvas.drawOval(
        Rect.fromCenter(
          center: c,
          width: (4 + t * 18) * scale,
          height: (1 + t * 4) * scale,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 * scale
          ..color = const Color(0xFFB8D8E0).withValues(alpha: 0.6 * (1 - t)),
      );
      for (final side in [-1.0, 1.0]) {
        canvas.drawCircle(
          w(d.x + side * t * 8, d.y - math.sin(t * math.pi) * 8),
          1.1 * scale,
          Paint()..color = const Color(0xFFB8D8E0).withValues(alpha: 1 - t),
        );
      }
    }
  }
}

/// Underground lighting: darkness everywhere except under the tube lights.
void _paintMetroLighting(
  Canvas canvas,
  Size size,
  _DemoScreenState st,
  Offset Function(double, double) w,
  double scale,
) {
  final rect = Offset.zero & size;
  canvas.saveLayer(rect, Paint());
  canvas.drawRect(
    rect,
    Paint()..color = const Color(0xFF020806).withValues(alpha: 0.5),
  );
  for (final l in st._lamps) {
    final c = w(l.x, l.y + 140);
    final r = (l.width + 230) * scale;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..shader = ui.Gradient.radial(c, r, [
          Colors.black.withValues(alpha: 0.85 * l.level),
          Colors.black.withValues(alpha: 0),
        ]),
    );
  }
  canvas.restore();

  // Additive glow + light cone from each tube.
  for (final l in st._lamps) {
    final lc = w(l.x, l.y);
    final gr = (l.width * 0.9 + 20) * scale;
    canvas.drawCircle(
      lc,
      gr,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(lc, gr, [
          l.color.withValues(alpha: 0.35 * l.level),
          l.color.withValues(alpha: 0),
        ]),
    );
    if (l.width < 30) continue;
    final top = l.y + 4;
    final cone = Path()
      ..moveTo(w(l.x - l.width / 2, top).dx, w(0, top).dy)
      ..lineTo(w(l.x + l.width / 2, top).dx, w(0, top).dy)
      ..lineTo(w(l.x + l.width * 1.1 + 60, _groundY).dx, w(0, _groundY).dy)
      ..lineTo(w(l.x - l.width * 1.1 - 60, _groundY).dx, w(0, _groundY).dy)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.linear(w(l.x, top), w(l.x, _groundY), [
          l.color.withValues(alpha: 0.10 * l.level),
          l.color.withValues(alpha: 0),
        ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Making sprites belong to the painted scenes
// ---------------------------------------------------------------------------

/// Colour grade applied to every actor and pickup so the sprites share the
/// palette of the background they stand in: saturation, per-channel gain and
/// a small lift toward the scene's ambient colour.
List<double> _gradeMatrix(Area a) {
  // (saturation, r, g, b gain, lift r, g, b)
  final (sat, gr, gg, gb, lr, lg, lb) = switch (a) {
    Area.city => (0.80, 0.98, 0.90, 0.80, 6.0, 3.0, 0.0),
    Area.metro => (0.72, 0.86, 0.92, 0.84, 0.0, 3.0, 1.0),
    Area.forest => (0.70, 0.82, 0.90, 0.94, 2.0, 6.0, 8.0),
  };
  const lr0 = 0.2126, lg0 = 0.7152, lb0 = 0.0722;
  final s = sat, t = 1 - s;
  List<double> row(
    double gain,
    double rr,
    double gg2,
    double bb,
    double lift,
  ) => [rr * gain, gg2 * gain, bb * gain, 0, lift];
  return [
    ...row(gr, t * lr0 + s, t * lg0, t * lb0, lr),
    ...row(gg, t * lr0, t * lg0 + s, t * lb0, lg),
    ...row(gb, t * lr0, t * lg0, t * lb0 + s, lb),
    0,
    0,
    0,
    1,
    0,
  ];
}

/// Scene light on the actors only (srcATop keeps it inside the sprites):
/// a sky-coloured key light from above / behind, rim light from the
/// brightest part of the background and ground occlusion around the feet.
void _paintActorLight(
  Canvas canvas,
  Rect full,
  _DemoScreenState st,
  Offset Function(double, double) w,
) {
  final top = w(0, _groundY - 175 * _actorScale).dy;
  final feet = w(0, _groundY).dy;
  final night = st._area.surface ? st._nightLevel : 0.0;

  final (Color key, Color rim, double rimX) = switch (st._area) {
    Area.city => (const Color(0xFFE08A48), const Color(0xFFF0A060), 0.62),
    Area.metro => (const Color(0xFFB8E0C0), const Color(0xFFCFEAD0), 0.5),
    Area.forest => (const Color(0xFF8FA8B4), const Color(0xFFE0905A), 0.66),
  };

  // 1) Vertical key light: tinted at head height, dark at the feet.
  canvas.drawRect(
    full,
    Paint()
      ..blendMode = BlendMode.srcATop
      ..shader = ui.Gradient.linear(
        Offset(0, top),
        Offset(0, feet),
        [
          key.withValues(alpha: 0.16 * (1 - night * 0.6)),
          key.withValues(alpha: 0.0),
          Colors.black.withValues(alpha: 0.12),
          Colors.black.withValues(alpha: 0.42),
        ],
        [0, 0.35, 0.75, 1],
      ),
  );

  // 2) Rim light from the glowing part of the sky (sunset / lamp), so the
  //    side of each body that faces it picks up a warm edge.
  final lightPos = w(_bgW * rimX, _groundY - 380);
  canvas.drawRect(
    full,
    Paint()
      ..blendMode = BlendMode.srcATop
      ..shader = ui.Gradient.radial(lightPos, full.width * 0.55, [
        rim.withValues(alpha: 0.13 * (1 - night * 0.7)),
        rim.withValues(alpha: 0.0),
      ]),
  );

  // 3) Lightning in the forest lights the actors as well.
  if (st._area == Area.forest && st._lightning > 0) {
    canvas.drawRect(
      full,
      Paint()
        ..blendMode = BlendMode.srcATop
        ..color = const Color(
          0xFFDDE6FF,
        ).withValues(alpha: 0.4 * st._lightning),
    );
  }

  // 4) Metro: pools of tube light warm whoever stands beneath them.
  if (st._area == Area.metro) {
    for (final l in st._lamps) {
      final c = w(l.x, _groundY - 90);
      final r = (l.width + 120) * (full.width / _bgW);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..blendMode = BlendMode.srcATop
          ..shader = ui.Gradient.radial(c, r, [
            l.color.withValues(alpha: 0.16 * l.level),
            l.color.withValues(alpha: 0),
          ]),
      );
    }
  }
}

/// The item being used rises out of the survivor's hands and fades.
void _paintUseFx(
  Canvas canvas,
  _DemoScreenState st,
  Offset Function(double, double) w,
  double scale,
) {
  if (st._useFx <= 0) return;
  final img = st._itemImgs[st._useFxItem];
  if (img == null) return;
  final t = 1 - st._useFx / 0.9; // 0 -> 1
  final a = (t < 0.15 ? t / 0.15 : 1 - (t - 0.15) / 0.85).clamp(0.0, 1.0);
  final dir = st._facingRight ? 1.0 : -1.0;
  final c = w(
    st._x + 14 * dir * _actorScale,
    _groundY - st._y - st._heroH * (0.62 + 0.18 * t),
  );
  final sz = 30 * scale * _actorScale * (1 + 0.1 * math.sin(t * math.pi));
  canvas.drawImageRect(
    img,
    Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
    Rect.fromCenter(center: c, width: sz, height: sz),
    Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Colors.white.withValues(alpha: a),
  );
}
