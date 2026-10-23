part of 'main.dart';

// ---------------------------------------------------------------------------
// Survival: needs (health / hunger / thirst), injuries (bleeding, infection,
// leg injury), inventory, scavenging, day / night and the permanent save.
// There are no chapters or endings: the world simply continues.
// ---------------------------------------------------------------------------

/// One in-game day in real seconds (24 h). The world starts at 08:00.
const double _dayLength = 360;
const double _startHour = 8;

/// Interaction radii (background px).
const double _doorRange = 95, _spotRange = 62;

// ---- Inventory --------------------------------------------------------------

/// Every supply in the game. The first five keep their original names so old
/// saves load unchanged (`food` = canned beans, `water` = water bottle).
enum Item {
  food,
  water,
  bandage,
  medkit,
  pills,
  tuna,
  chocolate,
  mre,
  soda,
  dirtyWater,
  splint,
}

/// Quick-bar groups (keys 3..7). Tapping a group uses the best item in it.
enum ItemCat { food, drink, wound, medkit, pills }

class ItemInfo {
  const ItemInfo({
    required this.title,
    required this.short,
    required this.asset,
    required this.color,
    required this.max,
    required this.effect,
    required this.cat,
    this.hunger = 0,
    this.thirst = 0,
    this.heal = 0,
    this.infection = 0,
  });
  final String title, short, effect, asset;
  final Color color;
  final int max;
  final ItemCat cat;
  final double hunger, thirst, heal, infection;

  static ItemInfo of(Item i) => _itemInfo[i]!;
}

const Map<Item, ItemInfo> _itemInfo = {
  Item.food: ItemInfo(
    title: 'کنسرو لوبیا',
    short: 'BEANS',
    asset: 'assets/items/beans.png',
    color: Color(0xFFE09A3A),
    max: 8,
    effect: '+۳۵ سیری',
    cat: ItemCat.food,
    hunger: 35,
  ),
  Item.tuna: ItemInfo(
    title: 'کنسرو ماهی تن',
    short: 'TUNA',
    asset: 'assets/items/tuna.png',
    color: Color(0xFF6AA8D0),
    max: 8,
    effect: '+۲۵ سیری · +۵ جان',
    cat: ItemCat.food,
    hunger: 25,
    heal: 5,
  ),
  Item.chocolate: ItemInfo(
    title: 'شکلات انرژی',
    short: 'CHOCOLATE',
    asset: 'assets/items/chocolate.png',
    color: Color(0xFFC0703A),
    max: 8,
    effect: '+۱۵ سیری · سرعت ۳۰ ثانیه',
    cat: ItemCat.food,
    hunger: 15,
  ),
  Item.mre: ItemInfo(
    title: 'جیره‌ی جنگی',
    short: 'MRE',
    asset: 'assets/items/mre.png',
    color: Color(0xFFA8A060),
    max: 4,
    effect: '+۶۰ سیری · +۱۰ آب',
    cat: ItemCat.food,
    hunger: 60,
    thirst: 10,
  ),
  Item.water: ItemInfo(
    title: 'بطری آب',
    short: 'WATER',
    asset: 'assets/items/water.png',
    color: Color(0xFF5AB0E0),
    max: 8,
    effect: '+۴۰ آب',
    cat: ItemCat.drink,
    thirst: 40,
  ),
  Item.soda: ItemInfo(
    title: 'نوشابه‌ی قوطی',
    short: 'SODA',
    asset: 'assets/items/soda.png',
    color: Color(0xFF9BC050),
    max: 8,
    effect: '+۲۵ آب · +۵ سیری',
    cat: ItemCat.drink,
    thirst: 25,
    hunger: 5,
  ),
  Item.dirtyWater: ItemInfo(
    title: 'آب تصفیه‌نشده',
    short: 'DIRTY WATER',
    asset: 'assets/items/dirty_water.png',
    color: Color(0xFF8A9A6A),
    max: 6,
    effect: '+۳۵ آب · +۸ عفونت',
    cat: ItemCat.drink,
    thirst: 35,
    infection: 8,
  ),
  Item.bandage: ItemInfo(
    title: 'باند',
    short: 'BANDAGE',
    asset: 'assets/items/bandage.png',
    color: Color(0xFFE8DCC0),
    max: 8,
    effect: 'قطع خونریزی',
    cat: ItemCat.wound,
    heal: 5,
  ),
  Item.splint: ItemInfo(
    title: 'آتل',
    short: 'SPLINT',
    asset: 'assets/items/splint.png',
    color: Color(0xFFC09060),
    max: 5,
    effect: 'درمان آسیب پا',
    cat: ItemCat.wound,
    heal: 3,
  ),
  Item.medkit: ItemInfo(
    title: 'کیت کمک‌های اولیه',
    short: 'MEDKIT',
    asset: 'assets/items/medkit.png',
    color: Color(0xFFE05050),
    max: 5,
    effect: 'درمان + خونریزی + پا',
    cat: ItemCat.medkit,
  ),
  Item.pills: ItemInfo(
    title: 'آنتی‌بیوتیک',
    short: 'PILLS',
    asset: 'assets/items/pills.png',
    color: Color(0xFFE0A040),
    max: 5,
    effect: '−۶۰ عفونت',
    cat: ItemCat.pills,
    infection: -60,
  ),
};

/// Display order in the backpack.
const List<Item> _bagOrder = [
  Item.food,
  Item.tuna,
  Item.chocolate,
  Item.mre,
  Item.water,
  Item.soda,
  Item.dirtyWater,
  Item.bandage,
  Item.splint,
  Item.medkit,
  Item.pills,
];

const String _ammoAsset = 'assets/items/ammo.png';

class _CatInfo {
  const _CatInfo(this.title, this.key, this.color);
  final String title, key;
  final Color color;
}

const Map<ItemCat, _CatInfo> _catInfo = {
  ItemCat.food: _CatInfo('غذا', '3', Color(0xFFE09A3A)),
  ItemCat.drink: _CatInfo('نوشیدنی', '4', Color(0xFF5AB0E0)),
  ItemCat.wound: _CatInfo('زخم', '5', Color(0xFFE8DCC0)),
  ItemCat.medkit: _CatInfo('درمان', '6', Color(0xFFE05050)),
  ItemCat.pills: _CatInfo('دارو', '7', Color(0xFFE0A040)),
};

// ---- Permanent survivor save -------------------------------------------------

class SurvivorSave {
  SurvivorSave({
    required this.difficulty,
    required this.area,
    required this.x,
    required this.hp,
    required this.hunger,
    required this.thirst,
    required this.infection,
    required this.bleed,
    required this.leg,
    required this.inv,
    required this.mags,
    required this.reserves,
    required this.weapon,
    required this.waveDone,
    required this.kills,
    required this.headshots,
    required this.score,
    required this.deaths,
    required this.worldTime,
    required this.spots,
    required this.pumpReadyAt,
  });

  factory SurvivorSave.fresh(Difficulty d, Area a) => SurvivorSave(
    difficulty: d,
    area: a,
    x: a.spawnX,
    hp: -1, // -1 = full health
    hunger: 85,
    thirst: 85,
    infection: 0,
    bleed: 0,
    leg: 0,
    inv: {
      for (final i in Item.values) i: 0,
      Item.food: 1,
      Item.tuna: 1,
      Item.chocolate: 1,
      Item.water: 2,
      Item.bandage: 2,
      Item.medkit: 1,
    },
    mags: [_GunSpec.ak.mag, _GunSpec.deagle.mag],
    reserves: [
      (_GunSpec.ak.startReserve * Profile.i.ammoMul).round(),
      (_GunSpec.deagle.startReserve * Profile.i.ammoMul).round(),
    ],
    weapon: Weapon.ak,
    waveDone: 0,
    kills: 0,
    headshots: 0,
    score: 0,
    deaths: 0,
    worldTime: 0,
    spots: {},
    pumpReadyAt: 0,
  );

  Difficulty difficulty;
  Area area;
  double x, hp, hunger, thirst, infection, leg, worldTime, pumpReadyAt;
  int bleed, waveDone, kills, headshots, score, deaths;
  final Map<Item, int> inv;
  List<int> mags, reserves;
  Weapon weapon;
  final Map<String, double> spots; // spot id -> worldTime when refilled

  int get day => _dayOf(worldTime);

  Map<String, dynamic> toJson() => {
    'v': 1,
    'diff': difficulty.name,
    'area': area.name,
    'x': x,
    'hp': hp,
    'hunger': hunger,
    'thirst': thirst,
    'inf': infection,
    'bleed': bleed,
    'leg': leg,
    'inv': {for (final e in inv.entries) e.key.name: e.value},
    'mags': mags,
    'res': reserves,
    'weapon': weapon.name,
    'waveDone': waveDone,
    'kills': kills,
    'heads': headshots,
    'score': score,
    'deaths': deaths,
    'time': worldTime,
    'spots': spots,
    'pump': pumpReadyAt,
  };

  factory SurvivorSave.fromJson(Map<String, dynamic> j) {
    double d(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    int n(String k, int def) => (j[k] as num?)?.toInt() ?? def;
    List<int> ints(String k, List<int> def) {
      final l = j[k];
      if (l is! List || l.length != 2) return def;
      return l.map((e) => (e as num).toInt()).toList();
    }

    final invRaw = (j['inv'] as Map?) ?? const {};
    final spotsRaw = (j['spots'] as Map?) ?? const {};
    return SurvivorSave(
      difficulty: Difficulty.values.firstWhere(
        (e) => e.name == j['diff'],
        orElse: () => Difficulty.normal,
      ),
      area: Area.values.firstWhere(
        (e) => e.name == j['area'],
        orElse: () => Area.city,
      ),
      x: d('x', 420),
      hp: d('hp', -1),
      hunger: d('hunger', 80).clamp(0, 100),
      thirst: d('thirst', 80).clamp(0, 100),
      infection: d('inf', 0).clamp(0, 100),
      bleed: n('bleed', 0).clamp(0, 3),
      leg: d('leg', 0),
      inv: {
        for (final i in Item.values)
          i: ((invRaw[i.name] as num?)?.toInt() ?? 0).clamp(
            0,
            ItemInfo.of(i).max,
          ),
      },
      mags: ints('mags', [_GunSpec.ak.mag, _GunSpec.deagle.mag]),
      reserves: ints('res', [
        _GunSpec.ak.startReserve,
        _GunSpec.deagle.startReserve,
      ]),
      weapon: j['weapon'] == 'deagle' ? Weapon.deagle : Weapon.ak,
      waveDone: n('waveDone', 0),
      kills: n('kills', 0),
      headshots: n('heads', 0),
      score: n('score', 0),
      deaths: n('deaths', 0),
      worldTime: d('time', 0),
      spots: {
        for (final e in spotsRaw.entries)
          '${e.key}': (e.value as num).toDouble(),
      },
      pumpReadyAt: d('pump', 0),
    );
  }
}

int _dayOf(double worldTime) =>
    ((worldTime + _startHour / 24 * _dayLength) / _dayLength).floor() + 1;

double _hourOf(double worldTime) =>
    (_startHour + (worldTime % _dayLength) / _dayLength * 24) % 24;

String _clockText(double worldTime) {
  final h = _hourOf(worldTime);
  final hh = h.floor();
  final mm = ((h - hh) * 60).floor();
  return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
}

// ---- Scavenging spots --------------------------------------------------------

class _Spot {
  const _Spot(
    this.id,
    this.area,
    this.x,
    this.label,
    this.fa,
    this.loot, {
    this.refill = 180,
  });
  final String id;
  final Area area;
  final double x;
  final String label, fa;

  /// Weighted loot table. A null item means an ammo bundle.
  final List<(Item?, int)> loot;
  final double refill; // seconds of world time until it can be searched again
}

const List<_Spot> _spots = [
  // Ruined city
  _Spot('city_car', Area.city, 255, 'CAR TRUNK', 'صندوق ماشین', [
    (Item.food, 3),
    (Item.water, 4),
    (Item.soda, 3),
    (null, 4),
    (Item.bandage, 2),
    (Item.chocolate, 2),
  ]),
  _Spot('city_bus', Area.city, 670, 'BUS WRECK', 'اتوبوس واژگون', [
    (Item.food, 2),
    (Item.tuna, 2),
    (Item.bandage, 3),
    (Item.splint, 1),
    (Item.medkit, 1),
    (null, 3),
  ]),
  _Spot('city_taxi', Area.city, 1030, 'OLD CAR', 'ماشین قدیمی', [
    (Item.water, 3),
    (Item.soda, 3),
    (null, 4),
    (Item.pills, 2),
    (Item.chocolate, 3),
  ]),
  // Ravencroft metro
  _Spot('metro_train', Area.metro, 590, 'TRAIN CAR', 'واگن قطار', [
    (null, 5),
    (Item.medkit, 2),
    (Item.bandage, 3),
    (Item.mre, 2),
    (Item.splint, 1),
  ]),
  _Spot('metro_bags', Area.metro, 905, 'SUITCASES', 'چمدان‌ها', [
    (Item.food, 3),
    (Item.tuna, 3),
    (Item.water, 3),
    (Item.soda, 2),
    (Item.pills, 2),
  ]),
  _Spot('metro_bin', Area.metro, 1100, 'TICKET GATE', 'گیت بلیت', [
    (Item.chocolate, 4),
    (Item.soda, 3),
    (Item.bandage, 2),
    (null, 3),
    (Item.pills, 1),
  ]),
  // Blackwood forest
  _Spot('forest_cabin', Area.forest, 400, 'RANGER CABIN', 'کلبه‌ی جنگلبان', [
    (Item.food, 3),
    (Item.mre, 2),
    (Item.bandage, 3),
    (Item.splint, 2),
    (Item.pills, 2),
    (Item.medkit, 1),
  ], refill: 220),
  _Spot('forest_tires', Area.forest, 690, 'TIRE PILE', 'تل لاستیک', [
    (null, 5),
    (Item.dirtyWater, 3),
    (Item.water, 1),
    (Item.tuna, 2),
  ]),
  _Spot('forest_pack', Area.forest, 1120, 'LOST BACKPACK', 'کوله‌ی گمشده', [
    (Item.water, 4),
    (Item.food, 2),
    (Item.mre, 1),
    (Item.chocolate, 2),
    (null, 2),
    (Item.bandage, 2),
  ], refill: 200),
];

/// Hand water pump in the forest: unlimited (but untreated) water.
const double _pumpX = 545;
const double _pumpCooldown = 20;

// ---- Interaction target ---------------------------------------------------------

enum _InteractKind { door, spot, pump }

class _Interact {
  const _Interact(this.kind, this.x, {this.door, this.spot});
  final _InteractKind kind;
  final double x;
  final _Door? door;
  final _Spot? spot;
}

class _RainDrop {
  _RainDrop(this.x, this.y, this.speed, this.len);
  double x, y;
  final double speed, len;
}

// ---------------------------------------------------------------------------
// Logic
// ---------------------------------------------------------------------------

extension _SurvivalLogic on _DemoScreenState {
  // ---- Save / load ------------------------------------------------------

  void _loadSave(SurvivorSave s) {
    _diff = s.difficulty;
    _area = s.area;
    _actorScale = _area.actorScale;
    _x = s.x.clamp(60.0, _bgW - 60.0);
    _hp = s.hp < 0 ? _maxHp : s.hp.clamp(1.0, _maxHp);
    _hunger = s.hunger;
    _thirst = s.thirst;
    _infection = s.infection;
    _bleed = s.bleed;
    _leg = s.leg;
    for (final i in Item.values) {
      _inv[i] = s.inv[i] ?? 0;
    }
    _mags
      ..[0] = s.mags[0].clamp(0, _GunSpec.ak.mag)
      ..[1] = s.mags[1].clamp(0, _GunSpec.deagle.mag);
    _reserves
      ..[0] = math.max(0, s.reserves[0])
      ..[1] = math.max(0, s.reserves[1]);
    _weapon = s.weapon;
    _wave = s.waveDone; // an unfinished wave starts over
    _kills = s.kills;
    _headshots = s.headshots;
    _score = s.score;
    _worldTime = s.worldTime;
    _day = s.day;
    _spotReady
      ..clear()
      ..addAll(s.spots);
    _pumpReady = s.pumpReadyAt;
    _facingRight = _x < _bgW / 2;
  }

  /// Writes the current world into the profile and persists it.
  void _writeSave() {
    final s = Profile.i.survivor;
    if (s == null) return;
    s
      ..difficulty = _diff
      ..area = _area
      ..x = _x
      ..hp = _hp
      ..hunger = _hunger
      ..thirst = _thirst
      ..infection = _infection
      ..bleed = _bleed
      ..leg = _leg
      ..mags = List.of(_mags)
      ..reserves = List.of(_reserves)
      ..weapon = _weapon
      ..waveDone = _wavesCleared
      ..kills = _kills
      ..headshots = _headshots
      ..score = _score
      ..worldTime = _worldTime
      ..pumpReadyAt = _pumpReady;
    s.inv
      ..clear()
      ..addAll(_inv);
    s.spots
      ..clear()
      ..addAll(_spotReady);
    _updateRecords();
    Profile.i.saveSurvivor();
  }

  void _updateRecords() {
    final p = Profile.i;
    if (_score > (p.bestFree[_diff] ?? 0)) p.bestFree[_diff] = _score;
    if (_wave > (p.bestWave[_diff] ?? 0)) p.bestWave[_diff] = _wave;
    if (_day > p.bestDays) p.bestDays = _day;
  }

  /// Save if the run is in a valid (alive) state.
  void _autosave() {
    if (_dead || !_loaded) return;
    _writeSave();
  }

  // ---- Score & coins ----------------------------------------------------

  void _addScore(int n) {
    _score += n;
    _coinFrac += n / 10 * _diff.coinMul;
    final whole = _coinFrac.floor();
    if (whole > 0) {
      _coinFrac -= whole;
      _coinsEarned += whole;
      Profile.i.coins += whole;
    }
  }

  // ---- Day / night ------------------------------------------------------

  double get _hour => _hourOf(_worldTime);

  /// 0 = day, 1 = deep night (21:00 - 05:00) with dusk / dawn transitions.
  double get _nightLevel {
    final h = _hour;
    if (h >= 21 || h < 5) return 1;
    if (h >= 19) return (h - 19) / 2;
    if (h < 7) return 1 - (h - 5) / 2;
    return 0;
  }

  bool get _isNight => _nightLevel > 0.5;

  // ---- Movement modifiers from the body's condition ----------------------

  double get _moveMul =>
      (_leg > 0 ? 0.62 : 1.0) *
      (_hunger < 20 ? 0.88 : 1.0) *
      (_sugarT > 0 ? 1.15 : 1.0) *
      _hero.speedMul;

  double get _aimPenalty =>
      (_thirst < 20 ? 1.35 : 1.0) * (_hunger < 20 ? 1.2 : 1.0);

  // ---- Per frame --------------------------------------------------------

  void _updateSurvival(double dt) {
    if (_noticeT > 0) _noticeT -= dt;
    if (_useCd > 0) _useCd -= dt;
    if (_useFx > 0) _useFx -= dt;
    if (_sugarT > 0) _sugarT -= dt;
    if (_dead) return;

    _worldTime += dt;
    final day = _dayOf(_worldTime);
    if (day != _day) {
      _day = day;
      _bannerText = 'DAY $_day';
      _bannerSub = 'YOU SURVIVED ANOTHER NIGHT';
      _banner = 3;
      _addScore(250);
    }

    // Hunger and thirst. Walking burns more; the infection makes it worse.
    final drain =
        _diff.survivalDrain *
        (_infection > 50 ? 1.5 : 1.0) *
        (_dir != 0 ? 1.35 : 1.0);
    _hunger = math.max(0, _hunger - dt * 0.2 * drain);
    _thirst = math.max(0, _thirst - dt * 0.27 * drain);

    // Infection: small doses fade, a strong infection keeps spreading.
    if (_infection > 0) {
      if (_infection < 35) {
        _infection = math.max(0, _infection - dt * 0.15);
      } else {
        _infection = math.min(100, _infection + dt * 0.08);
      }
    }
    _poison = math.max(_poison, ((_infection - 40) / 60).clamp(0.0, 0.6));

    // Bleeding: drains health and leaves a trail; slowly clots by itself.
    if (_bleed > 0) {
      _drainHp(dt * 0.7 * _bleed, 'خونریزی');
      _bleedClot += dt;
      if (_bleedClot > 50) {
        _bleedClot = 0;
        _bleed--;
        if (_bleed == 0) _notify('خونریزی بند آمد.', const Color(0xFF9BD06A));
      }
      _bleedDrip -= dt;
      if (_bleedDrip <= 0) {
        _bleedDrip = 0.55 / _bleed;
        _gore.add(
          _Gore(
            _x + (_rng.nextDouble() - 0.5) * 16,
            _groundY - _y - _heroH * 0.47,
            (_rng.nextDouble() - 0.5) * 30,
            20,
            1.6 + _rng.nextDouble(),
            _bloodRed,
            0.9,
          ),
        );
      }
    }
    if (_leg > 0) {
      _leg = math.max(0, _leg - dt);
      if (_leg == 0) _notify('پایت بهتر شد.', const Color(0xFF9BD06A));
    }

    if (_hunger <= 0) _drainHp(dt * 0.8, 'گرسنگی');
    if (_thirst <= 0) _drainHp(dt * 1.2, 'تشنگی');
    if (_infection >= 100) _drainHp(dt * 1.0, 'عفونت قارچی');
    if (_dead) return;

    // Natural regeneration only when fed, hydrated and not wounded.
    if (_hunger >= 50 &&
        _thirst >= 50 &&
        _bleed == 0 &&
        _infection < 50 &&
        _hp < _maxHp) {
      _hp = math.min(_maxHp, _hp + dt * 0.5);
    }

    // Periodic warnings.
    _warnIn -= dt;
    if (_warnIn <= 0) {
      _warnIn = 22;
      if (_thirst < 25) {
        _notify(
          _thirst <= 0 ? 'از تشنگی داری می‌میری!' : 'تشنه‌ای! آب بخور.',
          const Color(0xFF5AB0E0),
        );
      } else if (_hunger < 25) {
        _notify(
          _hunger <= 0 ? 'از گرسنگی داری می‌میری!' : 'گرسنه‌ای! چیزی بخور.',
          const Color(0xFFE09A3A),
        );
      } else if (_infection >= 50) {
        _notify('عفونت در حال پخش است — آنتی‌بیوتیک!', const Color(0xFF9BD06A));
      }
    }

    // Searching a container.
    final sp = _searching;
    if (sp != null) {
      if (_dir != 0 || !_grounded || _travelT >= 0) {
        _cancelSearch();
      } else {
        _searchT += dt;
        if (_searchT >= _searchTime) _finishSearch(sp);
      }
    }

    _saveIn -= dt;
    if (_saveIn <= 0) {
      _saveIn = 10;
      _autosave();
    }
  }

  /// Health loss from the body's condition (not from attacks).
  void _drainHp(double amount, String cause) {
    if (_dead) return;
    _hp -= amount;
    if (_hp <= 0) _die(cause);
  }

  /// Extra injuries after a zombie attack lands.
  void _applyInjury(ZType by, double damage) {
    final walker = by == ZType.walker;
    if (_rng.nextDouble() < (walker ? 0.35 : 0.22) && _bleed < 3) {
      _bleed++;
      _bleedClot = 0;
      _notify(
        _bleed == 1 ? 'زخمی شدی — خونریزی!' : 'خونریزی شدیدتر شد!',
        const Color(0xFFE05050),
      );
    }
    if (!walker) {
      _infection = math.min(100, _infection + 14);
      if (_infection >= 35 && _infection - 14 < 35) {
        _notify('آلوده به اسپور قارچ شدی!', const Color(0xFF9BD06A));
      }
    }
    if (_leg <= 0 && _rng.nextDouble() < (walker ? 0.07 : 0.25)) {
      _leg = 75;
      _notify('پایت آسیب دید — لنگ می‌زنی!', const Color(0xFFE0B050));
    }
  }

  void _die(String cause) {
    if (_dead) return;
    _hp = 0;
    _dead = true;
    _deadT = 0;
    _deathCause = cause;
    _searching = null;
    _stopSteps();
    _syncForestLoop();
    _za.attack.play(_clock, volume: 1, rate: 0.8);
    final p = Profile.i;
    p.totalDeaths++;
    p.totalKills += _kills - _killsAtStart;
    _killsAtStart = _kills;

    // Penalty: half of every supply (rounded up) and half the spare ammo is
    // lost. Everything else - upgrades, coins, skins, the world - is kept.
    _deathLosses.clear();
    for (final i in Item.values) {
      final n = _inv[i] ?? 0;
      final lost = (n + 1) ~/ 2;
      if (lost > 0) {
        _inv[i] = n - lost;
        _deathLosses.add('${_fa('$lost')} ${ItemInfo.of(i).title}');
      }
    }
    for (var w = 0; w < 2; w++) {
      final lost = _reserves[w] ~/ 2;
      if (lost > 0) {
        _reserves[w] -= lost;
        _deathLosses.add('${_fa('$lost')} فشنگ ${w == 0 ? '7.62' : '.50'}');
      }
    }

    // The survivor wakes up again in the safe spot of this area.
    final s = p.survivor;
    _writeSave();
    if (s != null) {
      s
        ..hp = _maxHp * 0.6
        ..hunger = math.max(_hunger, 55)
        ..thirst = math.max(_thirst, 55)
        ..infection = 0
        ..bleed = 0
        ..leg = 0
        ..x = _area.spawnX
        ..deaths = s.deaths + 1
        ..worldTime = _worldTime + _dayLength / 8; // 3 hours unconscious
      p.saveSurvivor();
    }
  }

  // ---- Notifications ----------------------------------------------------

  void _notify(String text, [Color color = _mBone]) {
    _notice = text;
    _noticeColor = color;
    _noticeT = 2.6;
  }

  // ---- Items ------------------------------------------------------------

  /// Items of a quick-bar group the survivor carries, in bag order.
  List<Item> _itemsIn(ItemCat c) => [
    for (final i in _bagOrder)
      if (ItemInfo.of(i).cat == c && (_inv[i] ?? 0) > 0) i,
  ];

  int _countIn(ItemCat c) => _itemsIn(c).fold(0, (a, i) => a + _inv[i]!);

  /// Picks the most sensible item of the group for the current condition.
  Item? _bestIn(ItemCat c) {
    final have = _itemsIn(c);
    if (have.isEmpty) return null;
    double score(Item i) {
      final f = ItemInfo.of(i);
      switch (c) {
        case ItemCat.food:
          final need = 100 - _hunger;
          // Fill the need without wasting a big ration.
          var s = -(need - f.hunger).abs();
          if (i == Item.tuna && _hp < _maxHp) s += 8;
          return s;
        case ItemCat.drink:
          final need = 100 - _thirst;
          var s = -(need - f.thirst).abs();
          if (i == Item.dirtyWater) s -= 30; // only when nothing else is left
          return s;
        case ItemCat.wound:
          if (i == Item.bandage) return _bleed > 0 ? 10 : 0;
          return _leg > 0 ? (_bleed > 0 ? 5 : 20) : -5;
        case ItemCat.medkit:
        case ItemCat.pills:
          return 0;
      }
    }

    have.sort((a, b) => score(b).compareTo(score(a)));
    return have.first;
  }

  void _useCategory(ItemCat c) {
    final it = _bestIn(c);
    if (it == null) {
      _notify('${_catInfo[c]!.title} نداری.', const Color(0xFFB8A27A));
      return;
    }
    _useItem(it);
  }

  void _useItem(Item it) {
    if (_dead || _paused || _useCd > 0 || _travelT >= 0) return;
    final info = ItemInfo.of(it);
    if ((_inv[it] ?? 0) <= 0) {
      _notify('${info.title} نداری.', const Color(0xFFB8A27A));
      return;
    }
    String? float;
    switch (info.cat) {
      case ItemCat.food:
        if (_hunger >= 97) return _notify('سیر هستی.');
        _hunger = math.min(100, _hunger + info.hunger);
        _thirst = math.min(100, _thirst + info.thirst);
        if (info.heal > 0) _hp = math.min(_maxHp, _hp + info.heal);
        if (it == Item.chocolate) {
          _sugarT = 30;
          _notify('انرژی گرفتی! ۳۰ ثانیه سریع‌تر می‌دوی.', info.color);
        }
        _wa.eat.play(_clock, rate: 0.95 + _rng.nextDouble() * 0.1);
        float = '+${info.hunger.round()} FOOD';
      case ItemCat.drink:
        if (_thirst >= 97) return _notify('تشنه نیستی.');
        _thirst = math.min(100, _thirst + info.thirst);
        _hunger = math.min(100, _hunger + info.hunger);
        if (info.infection > 0) {
          _infection = math.min(100, _infection + info.infection);
          _notify('آب آلوده بود — کمی عفونت گرفتی.', info.color);
        }
        _wa.drink.play(
          _clock,
          rate: (it == Item.soda ? 1.12 : 0.95) + _rng.nextDouble() * 0.1,
        );
        float = '+${info.thirst.round()} WATER';
      case ItemCat.wound:
        if (it == Item.bandage) {
          if (_bleed == 0) return _notify('خونریزی نداری.');
          _bleed = 0;
          float = 'BLEEDING STOPPED';
        } else {
          if (_leg <= 0) return _notify('پایت آسیبی ندیده.');
          _leg = 0;
          float = 'LEG SPLINTED';
        }
        _hp = math.min(_maxHp, _hp + info.heal);
        _wa.bandage.play(_clock, rate: it == Item.splint ? 0.85 : 1.0);
      case ItemCat.medkit:
        if (_hp >= _maxHp - 0.5 && _bleed == 0 && _leg <= 0) {
          return _notify('به درمان نیازی نداری.');
        }
        final heal = math.min(Profile.i.medkitHeal, _maxHp - _hp);
        _hp += heal;
        _bleed = 0;
        _leg = 0;
        _wa.bandage.play(_clock, rate: 0.9);
        float = '+${heal.round()} HP';
      case ItemCat.pills:
        if (_infection <= 0.5) return _notify('عفونت نداری.');
        _infection = math.max(0, _infection + info.infection);
        _wa.drink.play(_clock, rate: 1.3, volume: 0.6);
        float = '-60 INFECTION';
    }
    _inv[it] = (_inv[it] ?? 1) - 1;
    _useCd = 0.6;
    _useFx = 0.9;
    _useFxItem = it;
    _texts.add(
      _FloatText(_x, _groundY - _y - _heroH - 25, float, info.color, big: true),
    );
  }

  /// Adds an item to the backpack. Returns false if that stack is full.
  bool _giveItem(Item it, [int n = 1]) {
    final have = _inv[it] ?? 0;
    final max = ItemInfo.of(it).max;
    if (have >= max) return false;
    _inv[it] = math.min(max, have + n);
    return true;
  }

  /// Ammo bundle: rounds for the weapon in hand plus a few for the other.
  String _giveAmmo({double mul = 1}) {
    final m = Profile.i.ammoMul * mul;
    final cur = (_gun.pickupAmmo * m).round();
    _reserve += cur;
    final o = _weapon == Weapon.ak ? 1 : 0;
    _reserves[o] += ((o == 1 ? 3 : 10) * m).round();
    return '+$cur ${_weapon == Weapon.ak ? '7.62' : '.50 AE'}';
  }

  /// Walks over a dropped pickup. Returns true if it was collected.
  bool _collectPickup(_Pickup p) {
    final it = p.item;
    if (it == null) {
      final t = _giveAmmo();
      _texts.add(
        _FloatText(
          _x,
          _groundY - _heroH - 20,
          t,
          const Color(0xFFE0B050),
          big: true,
        ),
      );
      return true;
    }
    final info = ItemInfo.of(it);
    if (!_giveItem(it)) {
      if (_clock - _fullWarnAt > 3) {
        _fullWarnAt = _clock;
        _notify('کوله پر است: ${info.title}', const Color(0xFFB8A27A));
      }
      return false;
    }
    _texts.add(
      _FloatText(
        _x,
        _groundY - _heroH - 20,
        '+1 ${info.short}',
        info.color,
        big: true,
      ),
    );
    return true;
  }

  /// Weighted random drop from a dead zombie (or null for nothing).
  (bool, Item?)? _rollZombieLoot() {
    if (_rng.nextDouble() > 0.6) return null;
    final table = <(Item?, double)>[
      (null, _reserve < 30 ? 60 : 30),
      (Item.food, _hunger < 30 ? 9 : 4),
      (Item.tuna, _hunger < 30 ? 7 : 3),
      (Item.chocolate, 5),
      (Item.mre, _hunger < 30 ? 3 : 1),
      (Item.water, _thirst < 30 ? 12 : 6),
      (Item.soda, _thirst < 30 ? 7 : 4),
      (Item.bandage, _bleed > 0 ? 14 : 6),
      (Item.splint, _leg > 0 ? 8 : 2),
      (Item.medkit, _hp < 40 ? 11 : 5),
      (Item.pills, _infection > 40 ? 8 : 3),
    ];
    final total = table.fold<double>(0, (a, e) => a + e.$2);
    var r = _rng.nextDouble() * total;
    for (final e in table) {
      r -= e.$2;
      if (r <= 0) return (true, e.$1);
    }
    return (true, null);
  }

  // ---- Interaction (doors, containers, water pump) -----------------------

  _Interact? get _target {
    if (_dead || _travelT >= 0) return null;
    _Interact? best;
    var bestD = double.infinity;
    void consider(_Interact i, double range) {
      final d = (i.x - _x).abs();
      if (d < range && d < bestD) {
        bestD = d;
        best = i;
      }
    }

    for (final d in _area.doors) {
      consider(_Interact(_InteractKind.door, d.x, door: d), _doorRange);
    }
    for (final s in _spots) {
      if (s.area != _area) continue;
      consider(_Interact(_InteractKind.spot, s.x, spot: s), _spotRange);
    }
    if (_area == Area.forest) {
      consider(const _Interact(_InteractKind.pump, _pumpX), _spotRange);
    }
    return best;
  }

  double _spotLeft(_Spot s) =>
      math.max(0, (_spotReady[s.id] ?? 0) - _worldTime);

  double get _searchTime => 1.6;

  void _interact() {
    final t = _target;
    if (t == null || !_grounded) return;
    switch (t.kind) {
      case _InteractKind.door:
        _cancelSearch(silent: true);
        _startTravel(t.door!);
      case _InteractKind.spot:
        final s = t.spot!;
        if (_searching != null) return;
        final left = _spotLeft(s);
        if (left > 0) {
          _notify(
            '${s.fa} خالی است — ${_fa('${left.ceil()}')} ثانیه تا پر شدن.',
            const Color(0xFFB8A27A),
          );
          return;
        }
        _searching = s;
        _searchT = 0;
        _crouchToggle = false;
        _stopSteps();
        _wa.rummage.play(_clock, rate: 0.95 + _rng.nextDouble() * 0.1);
      case _InteractKind.pump:
        _usePump();
    }
  }

  void _cancelSearch({bool silent = false}) {
    if (_searching == null) return;
    _searching = null;
    _searchT = 0;
    _wa.rummage.stopAll();
    if (!silent) _notify('جستجو قطع شد.', const Color(0xFFB8A27A));
  }

  void _finishSearch(_Spot s) {
    _searching = null;
    _searchT = 0;
    _spotReady[s.id] = _worldTime + s.refill;
    final rolls = 2 + (_rng.nextDouble() < 0.4 ? 1 : 0);
    final total = s.loot.fold<int>(0, (a, e) => a + e.$2);
    final got = <String>[];
    var full = false;
    for (var k = 0; k < rolls; k++) {
      var r = _rng.nextInt(total);
      Item? pick;
      var ammo = false;
      for (final e in s.loot) {
        r -= e.$2;
        if (r < 0) {
          pick = e.$1;
          ammo = e.$1 == null;
          break;
        }
      }
      if (ammo) {
        got.add(_giveAmmo(mul: 0.8));
      } else if (pick != null) {
        if (_giveItem(pick)) {
          got.add('+1 ${ItemInfo.of(pick).short}');
        } else {
          full = true;
        }
      }
    }
    _addScore(40);
    for (var i = 0; i < got.length; i++) {
      _texts.add(
        _FloatText(
          _x,
          _groundY - _heroH - 25 - i * 18,
          got[i],
          const Color(0xFFE9DCC0),
          big: true,
        )..life = 1.4,
      );
    }
    _notify(
      got.isEmpty
          ? (full ? '${s.fa}: کوله پر است!' : '${s.fa}: چیزی پیدا نشد.')
          : '${s.fa} گشته شد${full ? ' (کوله پر شد)' : ''}.',
      const Color(0xFFE0B050),
    );
    _za.shuffle.play(_clock, volume: 2, rate: 1.6);
    _autosave();
  }

  void _usePump() {
    final left = _pumpReady - _worldTime;
    if (left > 0) {
      _notify(
        'پمپ هنوز آب ندارد — ${_fa('${left.ceil()}')} ثانیه.',
        const Color(0xFFB8A27A),
      );
      return;
    }
    if (_thirst < 95) {
      _thirst = math.min(100, _thirst + 30);
      _infection = math.min(100, _infection + 5); // untreated water
      _wa.drink.play(_clock, rate: 0.9);
      _texts.add(
        _FloatText(
          _x,
          _groundY - _heroH - 25,
          '+30 WATER',
          const Color(0xFF5AB0E0),
          big: true,
        ),
      );
      _notify('آب تصفیه‌نشده نوشیدی (کمی عفونت).', const Color(0xFF5AB0E0));
    } else if (_giveItem(Item.dirtyWater)) {
      _wa.drink.play(_clock, rate: 1.2, volume: 0.6);
      _notify('یک شیشه آب تصفیه‌نشده پر کردی.', const Color(0xFF8A9A6A));
    } else {
      _notify('بطری‌هایت پر است.', const Color(0xFFB8A27A));
      return;
    }
    _pumpReady = _worldTime + _pumpCooldown;
  }

  // ---- Forest weather ---------------------------------------------------

  void _initRain() {
    for (var i = 0; i < 140; i++) {
      _rain.add(
        _RainDrop(
          _rng.nextDouble() * (_bgW + 200),
          _rng.nextDouble() * _groundY,
          700 + _rng.nextDouble() * 400,
          14 + _rng.nextDouble() * 14,
        ),
      );
    }
  }

  void _updateForest(double dt) {
    for (final d in _rain) {
      d.y += d.speed * dt;
      d.x -= d.speed * 0.22 * dt;
      if (d.y > _groundY + 30) {
        d.y = -20 - _rng.nextDouble() * 80;
        d.x = _rng.nextDouble() * (_bgW + 200);
      }
    }
    // Lightning and thunder.
    _lightning = math.max(0, _lightning - dt * 2.6);
    _boltIn -= dt;
    if (_boltIn <= 0) {
      _boltIn = 12 + _rng.nextDouble() * 18;
      _lightning = 1;
      _thunderIn = 0.35 + _rng.nextDouble() * 1.2;
      _bolt
        ..clear()
        ..add(Offset(200 + _rng.nextDouble() * 960, 0));
      while (_bolt.last.dy < 260 + _rng.nextDouble() * 80) {
        final l = _bolt.last;
        _bolt.add(
          Offset(
            l.dx + (_rng.nextDouble() - 0.5) * 70,
            l.dy + 25 + _rng.nextDouble() * 30,
          ),
        );
      }
    }
    if (_lightning > 0.55 && _lightning < 0.62 && _rng.nextBool()) {
      _lightning = 0.9; // double flash
    }
    if (_thunderIn > 0) {
      _thunderIn -= dt;
      if (_thunderIn <= 0) {
        _wa.thunder.play(
          _clock,
          pan: (_rng.nextDouble() - 0.5) * 1.2,
          rate: 0.85 + _rng.nextDouble() * 0.3,
        );
      }
    }
  }

  void _syncForestLoop() {
    final want = _forestReady && _area == Area.forest && !_dead && !_paused;
    if (want && !_forestLoopOn) {
      _forestLoopOn = true;
      _forestLoop.setVolume(0.55 * Profile.i.ambientVolume);
      _forestLoop.resume();
    } else if (!want && _forestLoopOn) {
      _forestLoopOn = false;
      _forestLoop.pause();
    }
  }

  // ---- HUD --------------------------------------------------------------

  Widget _statBar(
    IconData icon,
    double frac,
    Color c,
    String value, {
    double width = 150,
    bool warn = false,
  }) {
    final blink = warn && (_clock * 3).floor().isEven;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: blink ? Colors.white : c,
            shadows: const [Shadow(blurRadius: 4)],
          ),
          const SizedBox(width: 6),
          Container(
            width: width,
            height: 9,
            padding: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: (warn ? c : const Color(0xFFB8A27A)).withValues(
                  alpha: 0.6,
                ),
              ),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: frac.clamp(0.0, 1.0),
                child: Container(color: c),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              shadows: const [Shadow(blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(IconData icon, String text, Color c) => Container(
    margin: const EdgeInsets.only(right: 5, top: 5),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: c.withValues(alpha: 0.8)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: c),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            color: c,
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ],
    ),
  );

  Widget _survivalHud() {
    final chips = <Widget>[
      if (_bleed > 0)
        _statusChip(
          Icons.bloodtype,
          'BLEEDING${'!' * _bleed}',
          const Color(0xFFE05050),
        ),
      if (_infection >= 1)
        _statusChip(
          Icons.coronavirus,
          'INFECTED ${_infection.round()}%',
          const Color(0xFF9BD06A),
        ),
      if (_leg > 0)
        _statusChip(
          Icons.personal_injury,
          'LEG INJURY',
          const Color(0xFFE0B050),
        ),
      if (_hunger < 25)
        _statusChip(
          Icons.restaurant,
          _hunger <= 0 ? 'STARVING' : 'HUNGRY',
          const Color(0xFFE09A3A),
        ),
      if (_thirst < 25)
        _statusChip(
          Icons.local_drink,
          _thirst <= 0 ? 'DEHYDRATED' : 'THIRSTY',
          const Color(0xFF5AB0E0),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _statBar(
          Icons.restaurant,
          _hunger / 100,
          const Color(0xFFE09A3A),
          '${_hunger.ceil()}',
          warn: _hunger < 25,
        ),
        _statBar(
          Icons.water_drop,
          _thirst / 100,
          const Color(0xFF5AB0E0),
          '${_thirst.ceil()}',
          warn: _thirst < 25,
        ),
        if (chips.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Wrap(children: chips),
          ),
      ],
    );
  }

  /// Day, clock and wave countdown (replaces the old objective line).
  Widget _worldHud() {
    final night = _isNight && _area != Area.metro;
    final parts = <String>[
      'روز ${_fa('$_day')}',
      _fa(_clockText(_worldTime)),
      _diff.title,
      if (_waveBreak > 0 && !_dead)
        'موج بعد: ${_fa('${_waveBreak.ceil()}')} ث'
      else
        'موج ${_fa('${math.max(_wave, 1)}')}',
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0x88B01818)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              night ? Icons.nightlight_round : Icons.wb_sunny,
              size: 14,
              color: night ? const Color(0xFF8AA8E0) : _mGold,
            ),
            const SizedBox(width: 5),
            Text(
              parts.join('  ·  '),
              style: const TextStyle(
                color: _mGold,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickbar() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final c in ItemCat.values) ...[
          _catSlot(c),
          const SizedBox(width: 6),
        ],
        _bagButton(),
      ],
    );
  }

  /// Dark, worn slot frame used by the quick bar and the backpack grid.
  BoxDecoration _slotDeco(Color accent, {bool active = true}) => BoxDecoration(
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xE0231E18), Color(0xE0100D0A)],
    ),
    borderRadius: BorderRadius.circular(7),
    border: Border.all(
      color: accent.withValues(alpha: active ? 0.8 : 0.3),
      width: 1.5,
    ),
    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
  );

  Widget _itemImage(Item it, double size, {double opacity = 1}) => Opacity(
    opacity: opacity,
    child: Image.asset(
      ItemInfo.of(it).asset,
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    ),
  );

  Widget _catSlot(ItemCat c) {
    final ci = _catInfo[c]!;
    final best = _bestIn(c);
    final n = _countIn(c);
    final has = n > 0;
    // Show the item that would be used; an empty slot shows a faded default.
    final shown = best ?? _bagOrder.firstWhere((i) => ItemInfo.of(i).cat == c);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _useCategory(c),
      onLongPress: () => _bagOpen = true,
      child: Container(
        width: 52,
        height: 52,
        decoration: _slotDeco(ci.color, active: has),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: _itemImage(shown, 36, opacity: has ? 1 : 0.3),
              ),
            ),
            Positioned(
              right: 4,
              bottom: 1,
              child: Text(
                '$n',
                style: const TextStyle(
                  color: Color(0xFFF1E4C3),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(blurRadius: 3), Shadow(blurRadius: 3)],
                ),
              ),
            ),
            Positioned(
              left: 4,
              top: 1,
              child: Text(
                ci.key,
                style: TextStyle(
                  color: ci.color.withValues(alpha: 0.75),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bagButton() => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => _bagOpen = !_bagOpen,
    child: Container(
      width: 52,
      height: 52,
      decoration: _slotDeco(_mGold, active: _bagOpen),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _bagOpen ? Icons.close : Icons.backpack,
            size: 22,
            color: _mGold,
          ),
          const Text(
            'BAG',
            style: TextStyle(
              color: _mGold,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    ),
  );

  /// Full backpack: every supply with its count and effect. Tap to use.
  Widget _bagPanel() {
    final carried = _bagOrder.fold<int>(0, (a, i) => a + (_inv[i] ?? 0));
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: 470,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          color: const Color(0xEE15110D),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xAA8A6A3A), width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 14)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.backpack, color: _mGold, size: 18),
                const SizedBox(width: 6),
                const Text(
                  'کوله‌پشتی',
                  style: TextStyle(
                    color: _mGold,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_fa('$carried')} وسیله',
                  style: const TextStyle(color: _mSand, fontSize: 11),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _bagOpen = false,
                  child: const Icon(Icons.close, color: _mSand, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [for (final it in _bagOrder) _bagCell(it)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bagCell(Item it) {
    final info = ItemInfo.of(it);
    final n = _inv[it] ?? 0;
    final has = n > 0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _useItem(it),
      child: Container(
        width: 86,
        height: 92,
        padding: const EdgeInsets.fromLTRB(4, 3, 4, 3),
        decoration: _slotDeco(info.color, active: has),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Center(child: _itemImage(it, 44, opacity: has ? 1 : 0.28)),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Text(
                      '${_fa('$n')}/${_fa('${info.max}')}',
                      style: const TextStyle(
                        color: Color(0xFFF1E4C3),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(blurRadius: 3)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              info.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: has ? const Color(0xFFF1E4C3) : Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              info.effect,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: info.color.withValues(alpha: has ? 0.9 : 0.4),
                fontSize: 8.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _interactButton(_Interact t) {
    late final IconData icon;
    late final String label;
    var enabled = true;
    switch (t.kind) {
      case _InteractKind.door:
        icon = t.door!.icon;
        label = t.door!.button;
      case _InteractKind.spot:
        final left = _spotLeft(t.spot!);
        icon = Icons.search;
        label = _searching != null
            ? 'SEARCHING'
            : (left > 0 ? 'EMPTY' : 'SEARCH');
        enabled = left <= 0;
      case _InteractKind.pump:
        icon = Icons.water;
        label = _thirst < 95 ? 'DRINK' : 'FILL';
        enabled = _pumpReady - _worldTime <= 0;
    }
    final searching = _searching != null && t.kind == _InteractKind.spot;
    return Opacity(
      opacity: enabled || searching ? 1 : 0.5,
      child: _holdButton(
        size: 72,
        pressed: _btnUse || searching,
        accent: const Color(0xFFE0B050),
        onChanged: (v) => _btnUse = v,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (searching)
              SizedBox(
                width: 62,
                height: 62,
                child: CircularProgressIndicator(
                  value: (_searchT / _searchTime).clamp(0.0, 1.0),
                  strokeWidth: 3,
                  color: const Color(0xFFE0B050),
                  backgroundColor: Colors.white12,
                ),
              ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _icon(icon, 24),
                SizedBox(
                  width: 62,
                  child: FittedBox(fit: BoxFit.scaleDown, child: _label(label)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _noticeBanner() {
    final a = (_noticeT / 0.4).clamp(0.0, 1.0);
    return IgnorePointer(
      child: Opacity(
        opacity: a,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _noticeColor.withValues(alpha: 0.8)),
            ),
            child: Text(
              _notice,
              style: TextStyle(
                color: _noticeColor,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                fontFamily: 'Vazirmatn',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painting: containers, water pump, forest weather, darkness / night
// ---------------------------------------------------------------------------

void _paintSpots(
  Canvas canvas,
  _DemoScreenState st,
  Offset Function(double, double) w,
  double scale,
) {
  final target = st._target;
  for (final s in _spots) {
    if (s.area != st._area) continue;
    final ready = st._spotLeft(s) <= 0;
    final near = target?.spot == s;
    final bob = ready ? math.sin(st._clock * 3 + s.x) * 3 : 0.0;
    final p = w(s.x, _groundY - 70 + bob);
    if (ready) {
      final pulse = 0.6 + 0.4 * math.sin(st._clock * 4 + s.x);
      canvas.drawCircle(
        p,
        18 * scale,
        Paint()
          ..shader = ui.Gradient.radial(p, 18 * scale, [
            const Color(0xFFE0B050).withValues(alpha: 0.45 * pulse),
            const Color(0x00E0B050),
          ]),
      );
      final d = 6 * scale;
      final diamond = Path()
        ..moveTo(p.dx, p.dy - d)
        ..lineTo(p.dx + d, p.dy)
        ..lineTo(p.dx, p.dy + d)
        ..lineTo(p.dx - d, p.dy)
        ..close();
      canvas.drawPath(diamond, Paint()..color = const Color(0xFFF1D27A));
    } else {
      canvas.drawCircle(
        p,
        3 * scale,
        Paint()..color = Colors.white.withValues(alpha: 0.25),
      );
    }
    if (near || ready) {
      final tp = TextPainter(
        text: TextSpan(
          text: ready
              ? (near ? '${s.label}  [E]' : s.label)
              : '${s.label} · EMPTY ${st._spotLeft(s).ceil()}s',
          style: TextStyle(
            color: (ready ? const Color(0xFFF1E4C3) : Colors.white54)
                .withValues(alpha: near ? 1 : 0.6),
            fontSize: 8 * scale,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2 * scale,
            shadows: const [Shadow(blurRadius: 4)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(p.dx - tp.width / 2, p.dy - 22 * scale));
    }
  }

  // Search progress ring above the player.
  if (st._searching != null) {
    final c = w(st._x, _groundY - st._heroH);
    final r = 13 * scale;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * scale
        ..color = Colors.black54,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      math.pi * 2 * (st._searchT / st._searchTime).clamp(0.0, 1.0),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * scale
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFE0B050),
    );
  }
}

/// Old cast-iron hand pump next to the ranger cabin.
void _paintPump(
  Canvas canvas,
  _DemoScreenState st,
  Offset Function(double, double) w,
  double scale,
) {
  const x = _pumpX;
  final iron = Paint()..color = const Color(0xFF3C4448);
  final dark = Paint()..color = const Color(0xFF1E2426);
  // Concrete base + puddle
  canvas.drawOval(
    Rect.fromCenter(
      center: w(x + 14, _groundY + 2),
      width: 70 * scale,
      height: 9 * scale,
    ),
    Paint()..color = const Color(0x664A7090),
  );
  canvas.drawRect(
    Rect.fromPoints(w(x - 16, _groundY - 8), w(x + 16, _groundY)),
    dark,
  );
  // Body
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromPoints(w(x - 8, _groundY - 66), w(x + 8, _groundY - 8)),
      Radius.circular(3 * scale),
    ),
    iron,
  );
  canvas.drawRect(
    Rect.fromPoints(w(x - 10, _groundY - 70), w(x + 10, _groundY - 64)),
    dark,
  );
  // Spout
  canvas.drawRect(
    Rect.fromPoints(w(x + 8, _groundY - 50), w(x + 26, _groundY - 44)),
    iron,
  );
  canvas.drawRect(
    Rect.fromPoints(w(x + 21, _groundY - 44), w(x + 26, _groundY - 38)),
    iron,
  );
  // Handle (moves while pumping)
  final ready = st._pumpReady - st._worldTime <= 0;
  final pumping = !ready && st._pumpReady - st._worldTime > _pumpCooldown - 1.2;
  final ang = pumping ? math.sin(st._clock * 14) * 0.35 : -0.25;
  final pivot = w(x - 6, _groundY - 66);
  canvas.drawLine(
    pivot,
    pivot + Offset(-math.cos(ang) * 40 * scale, math.sin(ang) * 40 * scale),
    Paint()
      ..color = const Color(0xFF2E3436)
      ..strokeWidth = 4 * scale
      ..strokeCap = StrokeCap.round,
  );
  // Water stream
  if (pumping) {
    canvas.drawLine(
      w(x + 23.5, _groundY - 38),
      w(x + 23.5, _groundY),
      Paint()
        ..color = const Color(0xAA9AC8E8)
        ..strokeWidth = 2.5 * scale,
    );
  }
  // Marker
  final near = st._target?.kind == _InteractKind.pump;
  final tp = TextPainter(
    text: TextSpan(
      text: ready
          ? (near ? 'WATER PUMP  [E]' : 'WATER PUMP')
          : 'PUMP · ${(st._pumpReady - st._worldTime).ceil()}s',
      style: TextStyle(
        color: (ready ? const Color(0xFF9AC8E8) : Colors.white54).withValues(
          alpha: near ? 1 : 0.65,
        ),
        fontSize: 8 * scale,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.2 * scale,
        shadows: const [Shadow(blurRadius: 4)],
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final m = w(x, _groundY - 92);
  tp.paint(canvas, Offset(m.dx - tp.width / 2, m.dy - tp.height));
}

/// Wooden trail sign at the west end of the city street.
void _paintForestSign(
  Canvas canvas,
  _DemoScreenState st,
  Offset Function(double, double) w,
  double scale,
) {
  const x = 120.0;
  final wood = Paint()..color = const Color(0xFF5A4028);
  final woodDark = Paint()..color = const Color(0xFF3A2818);
  canvas.drawRect(
    Rect.fromPoints(w(x - 3, _groundY - 120), w(x + 3, _groundY)),
    woodDark,
  );
  final plank = Path()
    ..moveTo(w(x - 52, _groundY - 112).dx, w(0, _groundY - 101).dy)
    ..lineTo(w(x - 40, _groundY - 122).dx, w(0, _groundY - 122).dy)
    ..lineTo(w(x + 40, _groundY - 122).dx, w(0, _groundY - 122).dy)
    ..lineTo(w(x + 40, _groundY - 100).dx, w(0, _groundY - 100).dy)
    ..lineTo(w(x - 40, _groundY - 100).dx, w(0, _groundY - 100).dy)
    ..close();
  canvas.drawPath(plank, wood);
  canvas.drawPath(
    plank,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * scale
      ..color = const Color(0xFF2A1A0E),
  );
  final tp = TextPainter(
    text: TextSpan(
      text: 'BLACKWOOD',
      style: TextStyle(
        color: const Color(0xFFE9DCC0),
        fontSize: 9 * scale,
        fontWeight: FontWeight.w900,
        letterSpacing: 1 * scale,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final c = w(x - 3, _groundY - 111);
  tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
}

void _paintFog(
  Canvas canvas,
  _DemoScreenState st,
  Offset Function(double, double) w,
  double scale, {
  required bool front,
}) {
  final n = front ? 5 : 8;
  for (var i = 0; i < n; i++) {
    final speed = (front ? 14.0 : 7.0) * (1 + i % 3 * 0.4);
    final span = _bgW + 500;
    final x = (i * 233.0 + st._clock * speed) % span - 250;
    final y = front
        ? _groundY + 8 + math.sin(i * 1.7) * 6
        : _groundY - 60 + math.sin(i * 2.3 + st._clock * 0.2) * 25;
    final c = w(x, y);
    final rw = (front ? 300.0 : 380.0) * scale;
    final rh = (front ? 46.0 : 110.0) * scale;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(1, rh / rw);
    canvas.drawCircle(
      Offset.zero,
      rw / 2,
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, rw / 2, [
          const Color(0xFFB8C8CC).withValues(alpha: front ? 0.16 : 0.12),
          const Color(0x00B8C8CC),
        ]),
    );
    canvas.restore();
  }
}

void _paintRain(
  Canvas canvas,
  _DemoScreenState st,
  Offset Function(double, double) w,
  double scale,
) {
  final p = Paint()
    ..color = const Color(0xFFB8C8D8).withValues(alpha: 0.32)
    ..strokeWidth = 1.1 * scale
    ..strokeCap = StrokeCap.round;
  for (final d in st._rain) {
    final a = w(d.x, d.y);
    final b = w(d.x + d.len * 0.22, d.y - d.len);
    canvas.drawLine(a, b, p);
  }
  // Lightning bolt
  if (st._lightning > 0.5 && st._bolt.length > 1) {
    final path = Path()..moveTo(w(st._bolt[0].dx, st._bolt[0].dy).dx, 0);
    for (final o in st._bolt.skip(1)) {
      final q = w(o.dx, o.dy);
      path.lineTo(q.dx, q.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * scale
        ..color = const Color(0x55C8D8FF),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 * scale
        ..color = Colors.white.withValues(alpha: st._lightning),
    );
  }
}

/// Darkness for the surface areas: night time and the forest canopy, with
/// a small pool of light around the survivor. Lightning lifts it.
void _paintDarkness(
  Canvas canvas,
  Size size,
  _DemoScreenState st,
  Offset Function(double, double) w,
  double scale,
) {
  final forest = st._area == Area.forest;
  var dark = st._nightLevel * 0.55 + (forest ? 0.2 : 0);
  dark *= 1 - st._lightning * 0.85;
  if (dark > 0.01) {
    final rect = Offset.zero & size;
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(
      rect,
      Paint()
        ..color = (forest ? const Color(0xFF04080C) : const Color(0xFF050814))
            .withValues(alpha: dark.clamp(0.0, 0.8)),
    );
    final c = w(st._x, _groundY - st._y - st._heroH * 0.53);
    final r = 260 * scale * _actorScale;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..shader = ui.Gradient.radial(c, r, [
          Colors.black.withValues(alpha: 0.75),
          Colors.black.withValues(alpha: 0),
        ]),
    );
    canvas.restore();
  }
  if (forest && st._lightning > 0) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = const Color(
          0xFFDDE6FF,
        ).withValues(alpha: 0.35 * st._lightning),
    );
  }
}
