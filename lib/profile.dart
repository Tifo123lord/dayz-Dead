part of 'main.dart';

// ---------------------------------------------------------------------------
// Persistent player profile: settings, coins, upgrades, records and the
// permanent survivor save (one continuous world, no chapters / endings).
// ---------------------------------------------------------------------------

/// Upgrades sold in the shop. Every upgrade has [maxLevel] levels.
enum Upgrade { vitality, armor, akDamage, deagleDamage, ammo, reload, medkit }

class UpgradeInfo {
  const UpgradeInfo({
    required this.title,
    required this.desc,
    required this.icon,
    required this.basePrice,
    required this.effect,
  });
  final String title, desc;
  final IconData icon;
  final int basePrice;

  /// Short text describing the bonus at a given level.
  final String Function(int level) effect;

  static const int maxLevel = 5;

  int priceFor(int currentLevel) =>
      (basePrice * math.pow(1.7, currentLevel)).round() ~/ 5 * 5;

  static UpgradeInfo of(Upgrade u) => _upgradeInfo[u]!;
}

final Map<Upgrade, UpgradeInfo> _upgradeInfo = {
  Upgrade.vitality: UpgradeInfo(
    title: 'جان سخت',
    desc: 'حداکثر سلامتی بیشتر',
    icon: Icons.favorite,
    basePrice: 120,
    effect: (l) => '${_fa('${100 + 20 * l}')} جان',
  ),
  Upgrade.armor: UpgradeInfo(
    title: 'جلیقه‌ی ضدگاز',
    desc: 'کاهش آسیبِ گاز گرفتن و سم',
    icon: Icons.shield,
    basePrice: 150,
    effect: (l) => 'کاهش ${_fa('${l * 7}')}٪',
  ),
  Upgrade.akDamage: UpgradeInfo(
    title: 'گلوله‌ی سنگین AK-47',
    desc: 'قدرت تیر کلاش بیشتر',
    icon: Icons.local_fire_department,
    basePrice: 140,
    effect: (l) => 'قدرت +${_fa('${l * 12}')}٪',
  ),
  Upgrade.deagleDamage: UpgradeInfo(
    title: 'گلوله‌ی .50 دزرت ایگل',
    desc: 'قدرت تیر کلت بیشتر',
    icon: Icons.bolt,
    basePrice: 140,
    effect: (l) => 'قدرت +${_fa('${l * 12}')}٪',
  ),
  Upgrade.ammo: UpgradeInfo(
    title: 'کوله‌ی مهمات',
    desc: 'فشنگ بیشتر از هر جعبه‌ی مهمات',
    icon: Icons.inventory_2,
    basePrice: 100,
    effect: (l) => 'فشنگ +${_fa('${l * 25}')}٪',
  ),
  Upgrade.reload: UpgradeInfo(
    title: 'دست‌های سریع',
    desc: 'خشاب‌گذاری سریع‌تر',
    icon: Icons.autorenew,
    basePrice: 110,
    effect: (l) => 'سرعت +${_fa('${l * 8}')}٪',
  ),
  Upgrade.medkit: UpgradeInfo(
    title: 'پزشک میدانی',
    desc: 'جعبه‌ی کمک‌های اولیه درمان بیشتری می‌دهد',
    icon: Icons.medical_services,
    basePrice: 90,
    effect: (l) => 'درمان ${_fa('${35 + l * 10}')}',
  ),
};

enum Difficulty { easy, normal, hard }

extension DifficultyInfo on Difficulty {
  String get title => const ['آسان', 'معمولی', 'سخت'][index];
  double get zombieHp => const [0.8, 1.0, 1.35][index];
  double get zombieDamage => const [0.65, 1.0, 1.45][index];
  double get coinMul => const [0.75, 1.0, 1.6][index];

  /// How fast hunger / thirst drain.
  double get survivalDrain => const [0.7, 1.0, 1.3][index];
  Color get color =>
      const [Color(0xFF7FB85A), Color(0xFFE0B050), Color(0xFFD03020)][index];
}

class Profile {
  Profile._();
  static final Profile i = Profile._();
  SharedPreferences? _prefs;

  // ---- Settings ----
  double sfxVolume = 0.9;
  double ambientVolume = 0.8;
  bool screenShake = true;
  bool damageNumbers = true;
  bool highGore = true;
  bool vibration = true;
  double buttonScale = 1.0;
  double buttonOpacity = 1.0;

  // ---- Music ----
  bool musicOn = true;
  double musicVolume = 0.6;
  int musicTrack = 0;
  bool musicPlaylist = false; // false = loop one track, true = play all

  // ---- Weapon skins ----
  final Set<String> ownedSkins = {'ak_stock', 'de_stock'};
  final Map<Weapon, String> equippedSkins = {
    Weapon.ak: 'ak_stock',
    Weapon.deagle: 'de_stock',
  };

  bool ownsSkin(String id) =>
      ownedSkins.contains(id) || WeaponSkin.byId(id).isDefault;
  WeaponSkin skinFor(Weapon w) {
    final s = WeaponSkin.byId(equippedSkins[w] ?? WeaponSkin.defaultId(w));
    return s.weapon == w ? s : WeaponSkin.byId(WeaponSkin.defaultId(w));
  }

  bool isEquipped(WeaponSkin s) => skinFor(s.weapon).id == s.id;

  /// Buys [s]. Returns false if already owned or not affordable.
  bool buySkin(WeaponSkin s) {
    if (ownsSkin(s.id)) return false;
    if (coins < s.price) return false;
    coins -= s.price;
    ownedSkins.add(s.id);
    save();
    return true;
  }

  /// Equips an owned skin. Returns false if the skin is not owned.
  bool equipSkin(WeaponSkin s) {
    if (!ownsSkin(s.id)) return false;
    equippedSkins[s.weapon] = s.id;
    save();
    return true;
  }

  // ---- Progress ----
  int coins = 0;
  SurvivorSave? survivor; // the one persistent survival world
  final Map<Upgrade, int> levels = {for (final u in Upgrade.values) u: 0};
  final Map<Difficulty, int> bestFree = {
    for (final d in Difficulty.values) d: 0,
  };
  final Map<Difficulty, int> bestWave = {
    for (final d in Difficulty.values) d: 0,
  };
  int totalKills = 0, totalDeaths = 0, totalGames = 0;

  /// Longest survival (in-game days) over all survivors.
  int bestDays = 0;

  /// Selected playable character.
  Hero hero = Hero.arash;

  int level(Upgrade u) => levels[u] ?? 0;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _prefs = p;
      sfxVolume = p.getDouble('sfx') ?? sfxVolume;
      ambientVolume = p.getDouble('amb') ?? ambientVolume;
      screenShake = p.getBool('shake') ?? screenShake;
      damageNumbers = p.getBool('dmgnum') ?? damageNumbers;
      highGore = p.getBool('gore') ?? highGore;
      vibration = p.getBool('vib') ?? vibration;
      buttonScale = p.getDouble('btnScale') ?? buttonScale;
      buttonOpacity = p.getDouble('btnAlpha') ?? buttonOpacity;
      musicOn = p.getBool('musicOn') ?? musicOn;
      musicVolume = p.getDouble('musicVol') ?? musicVolume;
      musicTrack = (p.getInt('musicTrack') ?? 0).clamp(
        0,
        menuTracks.length - 1,
      );
      musicPlaylist = p.getBool('musicList') ?? musicPlaylist;
      ownedSkins.addAll(
        (p.getStringList('skinsOwned') ?? const []).where(
          (id) => weaponSkins.any((s) => s.id == id),
        ),
      );
      for (final w in Weapon.values) {
        final id = p.getString('skin_${w.name}');
        if (id != null) {
          final s = WeaponSkin.byId(id);
          if (s.id == id && s.weapon == w && ownsSkin(id)) {
            equippedSkins[w] = id;
          }
        }
      }
      coins = p.getInt('coins') ?? 0;
      final raw = p.getString('survivor_v1');
      if (raw != null) {
        try {
          survivor = SurvivorSave.fromJson(
            (jsonDecode(raw) as Map).cast<String, dynamic>(),
          );
        } catch (_) {
          survivor = null; // corrupted save: start fresh
        }
      }
      // Old chapter-based progress is no longer used.
      p.remove('story');
      p.remove('storyDone');
      for (final u in Upgrade.values) {
        levels[u] = (p.getInt('up_${u.name}') ?? 0).clamp(
          0,
          UpgradeInfo.maxLevel,
        );
      }
      for (final d in Difficulty.values) {
        bestFree[d] = p.getInt('best_${d.name}') ?? 0;
        bestWave[d] = p.getInt('bestWave_${d.name}') ?? 0;
      }
      totalKills = p.getInt('tKills') ?? 0;
      totalDeaths = p.getInt('tDeaths') ?? 0;
      totalGames = p.getInt('tGames') ?? 0;
      bestDays = p.getInt('bestDays') ?? 0;
      final heroName = p.getString('hero');
      hero = Hero.values.firstWhere(
        (h) => h.name == heroName,
        orElse: () => Hero.arash,
      );
    } catch (_) {
      // Storage unavailable: run with defaults.
    }
  }

  Future<void> save() async {
    final p = _prefs;
    if (p == null) return;
    await p.setDouble('sfx', sfxVolume);
    await p.setDouble('amb', ambientVolume);
    await p.setBool('shake', screenShake);
    await p.setBool('dmgnum', damageNumbers);
    await p.setBool('gore', highGore);
    await p.setBool('vib', vibration);
    await p.setDouble('btnScale', buttonScale);
    await p.setDouble('btnAlpha', buttonOpacity);
    await p.setBool('musicOn', musicOn);
    await p.setDouble('musicVol', musicVolume);
    await p.setInt('musicTrack', musicTrack);
    await p.setBool('musicList', musicPlaylist);
    await p.setStringList('skinsOwned', ownedSkins.toList());
    for (final w in Weapon.values) {
      await p.setString('skin_${w.name}', skinFor(w).id);
    }
    await p.setInt('coins', coins);
    await _writeSurvivor(p);
    for (final u in Upgrade.values) {
      await p.setInt('up_${u.name}', level(u));
    }
    for (final d in Difficulty.values) {
      await p.setInt('best_${d.name}', bestFree[d] ?? 0);
      await p.setInt('bestWave_${d.name}', bestWave[d] ?? 0);
    }
    await p.setInt('tKills', totalKills);
    await p.setInt('tDeaths', totalDeaths);
    await p.setInt('tGames', totalGames);
    await p.setInt('bestDays', bestDays);
    await p.setString('hero', hero.name);
  }

  /// Buys the next level of [u]. Returns false if not affordable / maxed.
  bool buy(Upgrade u) {
    final l = level(u);
    if (l >= UpgradeInfo.maxLevel) return false;
    final price = UpgradeInfo.of(u).priceFor(l);
    if (coins < price) return false;
    coins -= price;
    levels[u] = l + 1;
    save();
    return true;
  }

  Future<void> _writeSurvivor(SharedPreferences p) async {
    final s = survivor;
    if (s == null) {
      await p.remove('survivor_v1');
    } else {
      await p.setString('survivor_v1', jsonEncode(s.toJson()));
    }
  }

  /// Fast path used by the in-game autosave (survivor + coins + stats only).
  Future<void> saveSurvivor() async {
    final p = _prefs;
    if (p == null) return;
    await _writeSurvivor(p);
    await p.setInt('coins', coins);
    await p.setInt('tKills', totalKills);
    await p.setInt('tDeaths', totalDeaths);
    await p.setInt('tGames', totalGames);
    await p.setInt('bestDays', bestDays);
    for (final d in Difficulty.values) {
      await p.setInt('best_${d.name}', bestFree[d] ?? 0);
      await p.setInt('bestWave_${d.name}', bestWave[d] ?? 0);
    }
  }

  /// Starts a brand new survivor (replaces the previous world).
  void newSurvivor(Difficulty d, Area start) {
    survivor = SurvivorSave.fresh(d, start);
    saveSurvivor();
  }

  Future<void> resetProgress() async {
    coins = 0;
    survivor = null;
    for (final u in Upgrade.values) {
      levels[u] = 0;
    }
    for (final d in Difficulty.values) {
      bestFree[d] = 0;
      bestWave[d] = 0;
    }
    totalKills = totalDeaths = totalGames = 0;
    bestDays = 0;
    hero = Hero.arash;
    ownedSkins
      ..clear()
      ..addAll(['ak_stock', 'de_stock']);
    equippedSkins[Weapon.ak] = 'ak_stock';
    equippedSkins[Weapon.deagle] = 'de_stock';
    await save();
  }

  // ---- Derived gameplay values ----
  double get maxHp => 100.0 + 20 * level(Upgrade.vitality);
  double get armor => 0.07 * level(Upgrade.armor);
  double damageMul(Weapon w) =>
      1 +
      0.12 * level(w == Weapon.ak ? Upgrade.akDamage : Upgrade.deagleDamage);
  double get ammoMul => 1 + 0.25 * level(Upgrade.ammo);
  double get reloadMul => 1 - 0.08 * level(Upgrade.reload);
  double get medkitHeal => 35.0 + 10 * level(Upgrade.medkit);
}
