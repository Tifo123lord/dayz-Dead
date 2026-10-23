part of 'main.dart';

// ---------------------------------------------------------------------------
// Zombie definitions
// ---------------------------------------------------------------------------

enum ZType { walker, spore }

enum ZState { walk, attack, dying }

/// Static tuning for each zombie type (background pixel units).
class _ZSpec {
  const _ZSpec({
    required this.name,
    required this.maxHp,
    required this.speed,
    required this.height,
    required this.halfW,
    required this.damage,
    required this.reach,
    required this.windup,
    required this.cooldown,
    required this.headFrac,
    required this.headMul,
    required this.fps,
    required this.barColor,
  });

  final String name;
  final double maxHp;
  final double speed;
  final double height; // sprite height on screen in bg pixels
  final double halfW; // hit box half width
  final double damage;
  final double reach;
  final double windup; // seconds from lunge start to the hit
  final double cooldown;
  final double headFrac; // top fraction of the body that counts as head
  final double headMul; // headshot damage multiplier
  final double fps;
  final Color barColor; // accent for the name plate

  static const walker = _ZSpec(
    name: 'WALKER',
    maxHp: 100,
    speed: 40,
    height: 150,
    halfW: 22,
    damage: 12,
    reach: 54,
    windup: 0.45,
    cooldown: 1.1,
    headFrac: 0.2,
    headMul: 2.5,
    fps: 7,
    barColor: Color(0xFFB8A27A),
  );

  static const spore = _ZSpec(
    name: 'SPOREBACK',
    maxHp: 240,
    speed: 27,
    height: 168,
    halfW: 26,
    damage: 18,
    reach: 60,
    windup: 0.65,
    cooldown: 1.6,
    headFrac: 0.3,
    headMul: 2.0,
    fps: 5.5,
    barColor: Color(0xFFE09A3A),
  );

  static _ZSpec of(ZType t) => t == ZType.walker ? walker : spore;
}

class _Zombie {
  _Zombie(this.type, this.x, math.Random rng)
    : spec = _ZSpec.of(type),
      speedMul = 0.85 + rng.nextDouble() * 0.3,
      anim = rng.nextDouble() * 2,
      groanIn = 0.6 + rng.nextDouble() * 3 {
    hp = spec.maxHp;
    ghostHp = hp;
  }

  final ZType type;
  final _ZSpec spec;
  final double speedMul;
  double x;
  double hp = 0;
  double ghostHp = 0; // trailing "damage taken" bar
  double ghostDelay = 0;
  ZState state = ZState.walk;
  bool facingRight = true;
  double anim;
  int frame = 0;
  double attackT = 0;
  bool didHit = false;
  double cooldown = 0;
  double flash = 0; // white hit flash
  double stagger = 0;
  double deathT = 0;
  double groanIn;
  double barPulse = 0; // HP bar highlight after damage
  double fallDir = 1; // direction the corpse falls
  double stepIn = 0; // shuffle sound timer
  double moteIn = 0; // spore mote emission timer

  bool get alive => state != ZState.dying;

  /// Size in the current area (zombies grow with the forest's actor scale).
  double get height => spec.height * _actorScale;
  double get halfW => spec.halfW * _actorScale;
  double get reach => spec.reach * _actorScale;
  double get top => _groundY - height;
  Rect get rect => Rect.fromLTRB(x - halfW, top, x + halfW, _groundY);
  double get headBottom => top + height * spec.headFrac;

  /// Forward lunge offset (bg px) during an attack.
  double get lunge {
    if (state != ZState.attack) return 0;
    final w = spec.windup;
    final k = _actorScale;
    if (attackT < w * 0.6) return -6 * k * (attackT / (w * 0.6)); // rear back
    if (attackT < w) return (-6 + 24 * ((attackT - w * 0.6) / (w * 0.4))) * k;
    final r = ((attackT - w) / 0.35).clamp(0.0, 1.0);
    return 18 * k * (1 - r);
  }

  /// Forward body tilt (radians) during an attack.
  double get tilt {
    if (state != ZState.attack) return 0;
    final w = spec.windup;
    if (attackT < w * 0.6) return -0.08 * (attackT / (w * 0.6));
    if (attackT < w) return -0.08 + 0.26 * ((attackT - w * 0.6) / (w * 0.4));
    final r = ((attackT - w) / 0.35).clamp(0.0, 1.0);
    return 0.18 * (1 - r);
  }
}

// ---------------------------------------------------------------------------
// Effects
// ---------------------------------------------------------------------------

class _Gore {
  _Gore(
    this.x,
    this.y,
    this.vx,
    this.vy,
    this.size,
    this.color,
    this.life, {
    this.float = false,
  });
  double x, y, vx, vy, size, life;
  final Color color;
  final bool float; // floating spore mote (no gravity, drifts with wind)
  bool landed = false;
  late final double maxLife = life;
}

class _Decal {
  _Decal(this.x, this.w, this.color);
  final double x, w;
  final Color color;
  double life = 14;
}

class _SporeCloud {
  _SporeCloud(this.x, this.y, this.radius, this.life, this.seed);
  double x, y, radius, life;
  final double seed;
  late final double maxLife = life;
}

class _FloatText {
  _FloatText(this.x, this.y, this.text, this.color, {this.big = false});
  double x, y;
  final String text;
  final Color color;
  final bool big;
  double life = 0.9;
}

class _Pickup {
  _Pickup(this.x, this.item);
  final double x;
  final Item? item; // null = ammo box
  double life = 20;
  double age = 0;
  bool get med => item == Item.medkit;
}

class _Ash {
  _Ash(this.x, this.y, this.size, this.speed, this.phase);
  double x, y;
  final double size, speed, phase;
}

// ---------------------------------------------------------------------------
// Audio: small round-robin voice pools with volume / pan / pitch per play.
// ---------------------------------------------------------------------------

class _SfxPool {
  _SfxPool(
    String asset,
    int voices, {
    this.baseVolume = 1.0,
    this.ambient = false,
  }) : _players = List.generate(voices, (_) => AudioPlayer()) {
    for (final p in _players) {
      p.setReleaseMode(ReleaseMode.stop);
      p.setVolume(baseVolume);
      p.setSource(AssetSource(asset));
    }
  }

  final List<AudioPlayer> _players;
  final double baseVolume;
  final bool ambient; // follows the "ambient" volume setting
  int _next = 0;
  double lastPlay = -100;

  /// [pan] -1 (left) .. 1 (right); [rate] playback speed (pitch).
  void play(
    double now, {
    double volume = 1,
    double pan = 0,
    double rate = 1,
    double minGap = 0,
  }) {
    if (now - lastPlay < minGap) return;
    lastPlay = now;
    final p = _players[_next];
    _next = (_next + 1) % _players.length;
    final user = ambient ? Profile.i.ambientVolume : Profile.i.sfxVolume;
    final v = (baseVolume * volume * user).clamp(0.0, 1.0);
    if (v <= 0.001) return;
    p.stop().then((_) async {
      try {
        await p.setVolume(v);
        await p.setBalance(pan.clamp(-1.0, 1.0));
        await p.setPlaybackRate(rate);
      } catch (_) {
        // Some platforms do not support balance/rate - play anyway.
      }
      await p.resume();
    });
  }

  void stopAll() {
    for (final p in _players) {
      p.stop();
    }
  }

  void dispose() {
    for (final p in _players) {
      p.dispose();
    }
  }
}

class _ZombieAudio {
  final groanWalker = _SfxPool('audio/zombie_groan.mp3', 3, baseVolume: 0.75);
  final groanSpore = _SfxPool('audio/mushroom_groan.mp3', 3, baseVolume: 0.8);
  final attack = _SfxPool('audio/zombie_attack.mp3', 3, baseVolume: 0.9);
  final deathWalker = _SfxPool('audio/zombie_death.mp3', 2, baseVolume: 0.9);
  final deathSpore = _SfxPool('audio/mushroom_death.mp3', 2, baseVolume: 0.9);
  final hit = _SfxPool('audio/flesh_hit.mp3', 5, baseVolume: 0.7);
  final distant = _SfxPool(
    'audio/zombie_groan.mp3',
    2,
    baseVolume: 0.2,
    ambient: true,
  );
  final distantSpore = _SfxPool(
    'audio/mushroom_groan.mp3',
    2,
    baseVolume: 0.18,
    ambient: true,
  );
  final shuffle = _SfxPool('audio/footstep.wav', 2, baseVolume: 0.3);
  final hurt = _SfxPool('audio/flesh_hit.mp3', 2, baseVolume: 1.0);

  void dispose() {
    for (final p in [
      groanWalker,
      groanSpore,
      attack,
      deathWalker,
      deathSpore,
      hit,
      distant,
      distantSpore,
      shuffle,
      hurt,
    ]) {
      p.dispose();
    }
  }
}

// ---------------------------------------------------------------------------
// Game logic (lives in the same library, so it can use the state's privates)
// ---------------------------------------------------------------------------

const Color _bloodDark = Color(0xFF5A0A0A);
const Color _bloodRed = Color(0xFF8E1414);
const Color _sporeGlow = Color(0xFFC8E05A);
const Color _fungusOrange = Color(0xFFD9782E);

extension _ZombieLogic on _DemoScreenState {
  double _panFor(double x) => ((x - _x) / 650).clamp(-1.0, 1.0);
  double _volFor(double x) => (1 - (x - _x).abs() / 1100).clamp(0.12, 1.0);

  // ---- Waves -------------------------------------------------------------

  void _startWave() {
    _wave++;
    // The world never ends, so the horde size is capped; nights are worse.
    final night = _area.surface && _isNight;
    _toSpawn = math.min(3 + _wave * 2, 22) + (night ? 3 : 0);
    _spawnIn = 0.4;
    final spores = (_toSpawn * _sporeChance).round();
    _bannerText = 'WAVE $_wave';
    _bannerSub = 'WALKERS ${_toSpawn - spores}   ·   SPOREBACKS $spores';
    _banner = 3;
    if (_area == Area.metro) {
      _wa.tunnelWalker.play(_clock, volume: 2.5, pan: -0.6, rate: 0.8);
      _wa.tunnelSpore.play(_clock, volume: 2.5, pan: 0.6, rate: 0.85);
    } else {
      _za.distant.play(_clock, volume: 3, pan: -0.6, rate: 0.8);
      _za.distantSpore.play(_clock, volume: 3, pan: 0.6, rate: 0.85);
    }
  }

  double get _sporeChance =>
      math.min(0.18 + _wave * 0.06 + (_area == Area.forest ? 0.15 : 0), 0.7);

  void _spawnZombie() {
    final sporeChance = _sporeChance;
    // Guarantee at least one spore zombie early in wave one.
    final forceSpore = _wave == 1 && _toSpawn == 2;
    final type = forceSpore || _rng.nextDouble() < sporeChance
        ? ZType.spore
        : ZType.walker;
    final fromLeft = _x > _bgW / 2
        ? _rng.nextDouble() < 0.7
        : _rng.nextDouble() < 0.3;
    final x = fromLeft
        ? -40.0 - _rng.nextDouble() * 60
        : _bgW + 40 + _rng.nextDouble() * 60;
    final z = _Zombie(type, x, _rng)..facingRight = fromLeft;
    z.hp = z.ghostHp = _zMaxHp(z);
    _zombies.add(z);
    _toSpawn--;
    // Arrival groan from off-screen.
    final pool = _groanPool(type);
    pool.play(
      _clock,
      volume: 0.55,
      pan: fromLeft ? -0.9 : 0.9,
      rate: 0.9 + _rng.nextDouble() * 0.2,
    );
  }

  double _zMaxHp(_Zombie z) =>
      z.spec.maxHp *
      (_wave > 3 ? 1 + (math.min(_wave, 18) - 3) * 0.08 : 1) *
      _diff.zombieHp;

  // ---- Damage ------------------------------------------------------------

  void _hitZombie(
    _Zombie z,
    double dir,
    double hy,
    bool head, [
    double power = 34,
  ]) {
    final base = power * (0.9 + _rng.nextDouble() * 0.2);
    final dmg = head ? base * z.spec.headMul : base;
    final heavy = power > 50; // .50 AE knock-back
    z.hp -= dmg;
    z.flash = 0.07;
    z.barPulse = 0.35;
    z.ghostDelay = 0.35;
    z.stagger = z.type == ZType.walker ? (head ? 0.25 : 0.12) : 0.06;
    if (heavy) z.stagger += 0.15;
    z.x += dir * (z.type == ZType.walker ? 4 : 2) * (heavy ? 3.5 : 1);
    _addScore(head ? 15 : 5);

    _za.hit.play(
      _clock,
      volume: _volFor(z.x),
      pan: _panFor(z.x),
      rate: 0.85 + _rng.nextDouble() * 0.35,
      minGap: 0.04,
    );
    _spawnBlood(
      z,
      z.x - dir * z.halfW * 0.6,
      hy,
      dir,
      (head ? 16 : 9) + (heavy ? 10 : 0),
    );
    if (Profile.i.damageNumbers) {
      _texts.add(
        _FloatText(
          z.x + (_rng.nextDouble() - 0.5) * 20,
          hy - 10,
          head ? '${dmg.round()}!' : '${dmg.round()}',
          head ? const Color(0xFFFFD040) : const Color(0xFFF1E4C3),
          big: head,
        ),
      );
    }
    if (head && z.type == ZType.spore) {
      // Shooting the cap shakes spores loose.
      for (var i = 0; i < 6; i++) {
        _gore.add(
          _Gore(
            z.x,
            hy,
            (_rng.nextDouble() - 0.5) * 60,
            -20 - _rng.nextDouble() * 40,
            2 + _rng.nextDouble() * 2,
            _sporeGlow,
            1.6 + _rng.nextDouble(),
            float: true,
          ),
        );
      }
    }
    if (z.hp <= 0) _killZombie(z, dir, head);
  }

  void _spawnBlood(_Zombie z, double x, double y, double dir, int n) {
    if (!Profile.i.highGore) n = (n / 3).ceil();
    final spore = z.type == ZType.spore;
    for (var i = 0; i < n; i++) {
      final a =
          (dir > 0 ? 0.0 : math.pi) +
          (_rng.nextDouble() - 0.5) * 1.6 -
          0.5 * dir.sign * 0;
      final sp = 80 + _rng.nextDouble() * 260;
      final c = spore
          ? (i.isEven
                ? const Color(0xFF7A4A1E)
                : (i % 3 == 0 ? _sporeGlow : _fungusOrange))
          : (i.isEven ? _bloodDark : _bloodRed);
      _gore.add(
        _Gore(
          x,
          y,
          math.cos(a) * sp,
          math.sin(a) * sp - 120,
          1.5 + _rng.nextDouble() * 2.8,
          c,
          0.9 + _rng.nextDouble() * 0.8,
        ),
      );
    }
  }

  void _killZombie(_Zombie z, double dir, bool head) {
    z.state = ZState.dying;
    z.deathT = 0;
    z.hp = 0;
    z.fallDir = dir; // falls away from the shooter
    _kills++;
    if (head) _headshots++;
    _addScore(z.type == ZType.walker ? 100 : 250);
    _texts.add(
      _FloatText(
        z.x,
        z.top - 26,
        head ? 'HEADSHOT' : (z.type == ZType.walker ? '+100' : '+250'),
        head ? const Color(0xFFFF6A3A) : const Color(0xFF9BD06A),
        big: true,
      ),
    );
    final spore = z.type == ZType.spore;
    (spore ? _za.deathSpore : _za.deathWalker).play(
      _clock,
      volume: _volFor(z.x),
      pan: _panFor(z.x),
      rate: 0.9 + _rng.nextDouble() * 0.2,
    );
    _spawnBlood(z, z.x, z.top + z.height * 0.25, dir, 22);
    _decals.add(
      _Decal(
        z.x + dir * 30,
        40 + _rng.nextDouble() * 30,
        spore ? const Color(0xFF4A3A14) : const Color(0xFF3E0606),
      ),
    );
    if (spore) {
      // Bursting caps release a toxic spore cloud.
      _clouds.add(_SporeCloud(z.x, z.top + 40, 70, 6, _rng.nextDouble() * 100));
      for (var i = 0; i < 26; i++) {
        final a = _rng.nextDouble() * math.pi * 2;
        final sp = 20 + _rng.nextDouble() * 90;
        _gore.add(
          _Gore(
            z.x,
            z.top + 30,
            math.cos(a) * sp,
            math.sin(a) * sp - 30,
            1.5 + _rng.nextDouble() * 2.5,
            i.isEven ? _sporeGlow : const Color(0xFFE8D27A),
            2 + _rng.nextDouble() * 2,
            float: true,
          ),
        );
      }
    }
    // Loot (weighted by what the survivor needs most).
    final loot = _rollZombieLoot();
    if (loot != null) {
      _pickups.add(_Pickup(z.x.clamp(60.0, _bgW - 60), loot.$2));
    }
  }

  void _damagePlayer(
    double amount,
    double fromX, {
    bool poison = false,
    ZType? by,
  }) {
    if (_dead) return;
    final armor = (Profile.i.armor + _hero.armor).clamp(0.0, 0.7);
    amount *= _diff.zombieDamage * (1 - armor);
    if (!poison) {
      if (_invuln > 0) return;
      _invuln = 0.45;
      _hurt = 1;
      _shake = math.max(_shake, 0.8);
      _cancelSearch(silent: true);
      final away = _x >= fromX ? 1.0 : -1.0;
      _x = (_x + away * 22 / _hero.mass).clamp(60.0, _bgW - 60.0);
      _vx = 0;
      _za.hurt.play(_clock, volume: 1, rate: 0.75);
      if (Profile.i.vibration && !kIsWeb) HapticFeedback.mediumImpact();
      for (var i = 0; i < 8; i++) {
        final a = -math.pi / 2 + (_rng.nextDouble() - 0.5) * 2;
        _gore.add(
          _Gore(
            _x,
            _groundY - _y - _heroH * 0.6,
            math.cos(a) * 160 + away * 60,
            math.sin(a) * 160,
            2 + _rng.nextDouble() * 2,
            _bloodRed,
            0.8,
          ),
        );
      }
    }
    _hp -= amount;
    if (_hp <= 0) {
      _die(
        poison
            ? 'مسمومیت اسپور'
            : (by == ZType.spore ? 'ضربه‌ی اسپوربک' : 'گاز زامبی'),
      );
      return;
    }
    if (!poison && by != null) _applyInjury(by, amount);
  }

  // ---- Per-frame ---------------------------------------------------------

  void _updateZombies(double dt) {
    // Wave flow
    if (!_dead) {
      if (_waveBreak > 0) {
        _waveBreak -= dt;
        if (_waveBreak <= 0) _startWave();
      } else {
        final alive = _zombies.where((z) => z.alive).length;
        if (_toSpawn > 0) {
          _spawnIn -= dt;
          if (_spawnIn <= 0 && alive < 4 + _wave) {
            _spawnZombie();
            _spawnIn =
                math.max(0.7, 2.6 - _wave * 0.15) *
                (0.6 + _rng.nextDouble() * 0.8);
          }
        } else if (alive == 0) {
          _bannerText = 'WAVE $_wave CLEARED';
          _bannerSub = 'SCAVENGE WHILE YOU CAN...';
          _banner = 3;
          _addScore(100 * math.min(_wave, 15));
          // A longer breather to scavenge, eat and patch up.
          _waveBreak = _area.surface && _isNight ? 14 : 22;
          _autosave();
        }
      }
    }

    final playerFeet = _groundY - _y;
    for (final z in _zombies) {
      z.flash = math.max(0, z.flash - dt);
      z.barPulse = math.max(0, z.barPulse - dt);
      if (z.ghostDelay > 0) {
        z.ghostDelay -= dt;
      } else if (z.ghostHp > z.hp) {
        z.ghostHp = math.max(z.hp, z.ghostHp - _zMaxHp(z) * 0.9 * dt);
      }

      if (z.state == ZState.dying) {
        z.deathT += dt;
        continue;
      }

      final dx = _x - z.x;
      final dist = dx.abs();
      if (z.stagger > 0) z.stagger -= dt;

      // Groans, scheduled per zombie
      z.groanIn -= dt;
      if (z.groanIn <= 0) {
        final close = dist < 260;
        z.groanIn = (close ? 2.2 : 3.5) + _rng.nextDouble() * 4;
        final pool = _groanPool(z.type);
        pool.play(
          _clock,
          volume: _volFor(z.x),
          pan: _panFor(z.x),
          rate: z.type == ZType.walker
              ? 0.85 + _rng.nextDouble() * 0.3
              : 0.75 + _rng.nextDouble() * 0.2,
          minGap: 0.6,
        );
      }

      // Spore zombies shed glowing motes from the cap.
      if (z.type == ZType.spore) {
        z.moteIn -= dt;
        if (z.moteIn <= 0) {
          z.moteIn = 0.18 + _rng.nextDouble() * 0.25;
          _gore.add(
            _Gore(
              z.x + (_rng.nextDouble() - 0.5) * 30,
              z.top + 14 + _rng.nextDouble() * 20,
              (_rng.nextDouble() - 0.5) * 16,
              -8 - _rng.nextDouble() * 14,
              1.2 + _rng.nextDouble() * 1.6,
              _sporeGlow,
              2 + _rng.nextDouble() * 1.5,
              float: true,
            ),
          );
        }
      }

      if (z.state == ZState.walk) {
        if (!_dead) z.facingRight = dx > 0;
        final inReach = dist < z.reach && !_dead;
        if (inReach && z.cooldown <= 0) {
          z.state = ZState.attack;
          z.attackT = 0;
          z.didHit = false;
          _za.attack.play(
            _clock,
            volume: _volFor(z.x),
            pan: _panFor(z.x),
            rate: z.type == ZType.walker
                ? 0.95 + _rng.nextDouble() * 0.2
                : 0.7 + _rng.nextDouble() * 0.15,
            minGap: 0.15,
          );
        } else if (!inReach && z.stagger <= 0) {
          // Don't stack on the zombie in front.
          var blocked = false;
          for (final o in _zombies) {
            if (identical(o, z) || !o.alive) continue;
            final ahead = (o.x - z.x) * (z.facingRight ? 1 : -1);
            if (ahead > 0 &&
                ahead < 34 * _actorScale &&
                (o.x - _x).abs() < dist) {
              blocked = true;
              break;
            }
          }
          final dirSign = _dead
              ? (z.facingRight ? 1.0 : -1.0) * 0.4
              : (dx > 0 ? 1.0 : -1.0);
          final sp =
              z.spec.speed * _actorScale * z.speedMul * (blocked ? 0.25 : 1.0);
          z.x += dirSign * sp * dt;
          z.anim += dt * (blocked ? 0.4 : 1.0);
          z.frame = (z.anim * z.spec.fps * z.speedMul).floor() % 8;
          // Shuffling feet
          z.stepIn -= dt;
          if (z.stepIn <= 0) {
            z.stepIn = 4 / (z.spec.fps * z.speedMul);
            if (dist < 380) {
              _za.shuffle.play(
                _clock,
                volume: _volFor(z.x) * 0.7,
                pan: _panFor(z.x),
                rate: z.type == ZType.walker ? 0.7 : 0.55,
                minGap: 0.22,
              );
            }
          }
        }
        z.cooldown -= dt;
      } else if (z.state == ZState.attack) {
        z.attackT += dt;
        if (!z.didHit && z.attackT >= z.spec.windup) {
          z.didHit = true;
          final inRange =
              (_x - z.x).abs() < z.reach + 14 &&
              playerFeet > _groundY - 55 * _actorScale;
          if (inRange) {
            _damagePlayer(z.spec.damage, z.x, by: z.type);
          }
          if (z.type == ZType.spore) {
            // Slam releases a small spore puff in front.
            final fx = z.x + (z.facingRight ? 30 : -30);
            _clouds.add(
              _SporeCloud(fx, z.top + 50, 42, 2.2, _rng.nextDouble() * 100),
            );
          }
        }
        if (z.attackT >= z.spec.windup + 0.4) {
          z.state = ZState.walk;
          z.cooldown = z.spec.cooldown;
        }
      }
    }
    // Corpses fade away after a while.
    _zombies.removeWhere((z) => z.state == ZState.dying && z.deathT > 8);
  }

  void _updateWorld(double dt) {
    // Wind gusts drive ash and spores.
    _gust =
        0.5 +
        0.35 * math.sin(_clock * 0.37) +
        0.15 * math.sin(_clock * 1.7 + 1);

    _hurt = math.max(0, _hurt - dt * 1.6);
    _invuln = math.max(0, _invuln - dt);
    _banner = math.max(0, _banner - dt);
    _poison = math.max(0, _poison - dt * 0.8);

    // Gore particles
    for (final g in _gore) {
      g.life -= dt;
      if (g.float) {
        g.vx += (_gust * 30 - g.vx) * dt * 0.8;
        g.vy += (-6 - g.vy) * dt * 0.5;
        g.x += g.vx * dt + math.sin(_clock * 2 + g.size * 7) * 8 * dt;
        g.y += g.vy * dt;
      } else if (!g.landed) {
        g.vy += 1100 * dt;
        g.x += g.vx * dt;
        g.y += g.vy * dt;
        if (g.y >= _groundY - 1) {
          g.y = _groundY - 1 + _rng.nextDouble() * 3;
          g.landed = true;
          g.life = math.max(g.life, 3);
        }
      }
    }
    _gore.removeWhere((g) => g.life <= 0);
    if (_gore.length > 450) _gore.removeRange(0, _gore.length - 450);

    for (final d in _decals) {
      d.life -= dt;
    }
    _decals.removeWhere((d) => d.life <= 0);

    // Spore clouds poison the player.
    for (final c in _clouds) {
      c.life -= dt;
      c.x += _gust * 10 * dt;
      c.radius += dt * 6;
      final px = _x, py = _groundY - _y - _heroH * 0.5;
      final d = math.sqrt((px - c.x) * (px - c.x) + (py - c.y) * (py - c.y));
      if (d < c.radius && c.life > 0.3 && !_dead) {
        _poison = math.min(1, _poison + dt * 2.2);
        _infection = math.min(100, _infection + dt * 4);
        _damagePlayer(7 * dt, c.x, poison: true);
      }
    }
    _clouds.removeWhere((c) => c.life <= 0);

    for (final t in _texts) {
      t.life -= dt;
      t.y -= 40 * dt;
    }
    _texts.removeWhere((t) => t.life <= 0);

    // Pickups
    for (final p in _pickups) {
      p.life -= dt;
      p.age += dt;
      if (!_dead &&
          (p.x - _x).abs() < 34 * _actorScale &&
          _y < 30 &&
          p.age > 0.4) {
        if (_collectPickup(p)) {
          p.life = 0;
          _za.shuffle.play(_clock, volume: 2, rate: 1.6);
        }
      }
    }
    _pickups.removeWhere((p) => p.life <= 0);

    if (_area == Area.metro) return; // underground: no ash, tunnel ambience

    // Ash drifting on the wind
    for (final a in _ash) {
      a.x += (25 + 70 * _gust) * a.speed * dt;
      a.y += (14 + math.sin(_clock * 1.3 + a.phase) * 18) * a.speed * dt;
      if (a.x > _bgW + 10) a.x = -10;
      if (a.y > _groundY + 120) {
        a.y = -10;
        a.x = _rng.nextDouble() * _bgW;
      }
    }

    // Distant horde: random far-away groans panned around the city.
    _ambientIn -= dt;
    if (_ambientIn <= 0) {
      _ambientIn = 4 + _rng.nextDouble() * 7;
      final pan = (_rng.nextDouble() - 0.5) * 1.8;
      if (_rng.nextBool()) {
        _za.distant.play(
          _clock,
          pan: pan,
          rate: 0.62 + _rng.nextDouble() * 0.2,
        );
      } else {
        _za.distantSpore.play(
          _clock,
          pan: pan,
          rate: 0.6 + _rng.nextDouble() * 0.2,
        );
      }
    }
  }
}
