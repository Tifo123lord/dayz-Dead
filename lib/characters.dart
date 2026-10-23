part of 'main.dart';

// ---------------------------------------------------------------------------
// Playable characters. Every hero has his own walk sheet, pose sheets for
// every weapon skin, muzzle geometry and physical / combat traits.
// ---------------------------------------------------------------------------

enum Hero { arash, donald }

class HeroSpec {
  const HeroSpec({
    required this.hero,
    required this.name,
    required this.latinName,
    required this.role,
    required this.bio,
    required this.trait,
    required this.accent,
    required this.walkSheet,
    required this.posesDir,
    required this.muzzleAk,
    required this.muzzleDe,
    this.hpBonus = 0,
    this.armor = 0,
    this.speedMul = 1,
    this.accelMul = 1,
    this.jumpMul = 1,
    this.reloadMul = 1,
    this.recoilMul = 1,
    this.spreadMul = 1,
    this.mass = 1,
    this.walkFps = 10,
  });

  final Hero hero;
  final String name, latinName, role, bio, trait;
  final Color accent;

  /// 8-frame walk sheet (168 x 300 cells, empty hands).
  final String walkSheet;

  /// null = use the skin's own pose sheet (original hero).
  final String? posesDir;

  /// Muzzle position of the rifle / pistol in each pose cell (cell pixels).
  final Map<Pose, Offset> muzzleAk, muzzleDe;

  final double hpBonus; // added to max HP
  final double armor; // extra damage reduction 0..1
  final double speedMul; // top walking speed
  final double accelMul; // how fast he reaches top speed / stops
  final double jumpMul; // take-off velocity
  final double reloadMul; // reload time multiplier (lower = faster)
  final double recoilMul; // visual kick + push-back
  final double spreadMul; // bullet spread
  final double mass; // resistance to knock-back
  final double walkFps;

  /// Pose sheet for [skin] held by this hero.
  String posesFor(WeaponSkin skin) =>
      posesDir == null ? skin.poses : '$posesDir/poses_${skin.id}.png';

  Map<Pose, Offset> muzzle(Weapon w) => w == Weapon.ak ? muzzleAk : muzzleDe;

  static HeroSpec of(Hero h) => h == Hero.arash ? arash : donald;

  static const arash = HeroSpec(
    hero: Hero.arash,
    name: 'آرش',
    latinName: 'ARASH',
    role: 'بازمانده‌ی چابک',
    bio:
        'جوانی که در زیرزمین داروخانه به هوش آمد. سبک، سریع و همیشه در حرکت؛ '
        'خشاب را زودتر از هر کسی عوض می‌کند.',
    trait: 'حرکت سریع‌تر · پرش بلندتر · خشاب‌گذاری سریع',
    accent: Color(0xFF7FA050),
    walkSheet: 'assets/images/survivor_walk.png',
    posesDir: null,
    muzzleAk: _poseMuzzle,
    muzzleDe: _poseMuzzleDe,
    speedMul: 1.0,
    accelMul: 1.1,
    jumpMul: 1.0,
    reloadMul: 0.92,
    recoilMul: 1.0,
    spreadMul: 1.0,
    mass: 1.0,
    walkFps: 10,
  );

  static const donald = HeroSpec(
    hero: Hero.donald,
    name: 'دونالد',
    latinName: 'DONALD',
    role: 'کهنه‌سرباز سنگین',
    bio:
        'سرکارگر بازنشسته‌ی معدن با جلیقه‌ی چرمی پر از فشنگ. کند است، اما مثل '
        'دیوار می‌ایستد؛ پس‌زدن سلاح در دستان او تقریباً حس نمی‌شود.',
    trait: '+۴۰ جان · ۱۰٪ زره · لگد و پخش کمتر · مقاوم در برابر ضربه',
    accent: Color(0xFF4A78B0),
    walkSheet: 'assets/characters/donald/walk.png',
    posesDir: 'assets/characters/donald',
    muzzleAk: {
      Pose.aim: Offset(243, 58),
      Pose.crouchAim: Offset(250, 143),
      Pose.crouchLow: Offset(187, 244),
      Pose.jump: Offset(203, 206),
    },
    muzzleDe: {
      Pose.aim: Offset(212, 50),
      Pose.crouchAim: Offset(239, 128),
      Pose.crouchLow: Offset(197, 246),
      Pose.jump: Offset(227, 138),
    },
    hpBonus: 40,
    armor: 0.10,
    speedMul: 0.86,
    accelMul: 0.8,
    jumpMul: 0.9,
    reloadMul: 1.1,
    recoilMul: 0.65,
    spreadMul: 0.8,
    mass: 1.7,
    walkFps: 9,
  );
}

// ---------------------------------------------------------------------------
// Character select screen
// ---------------------------------------------------------------------------

class CharacterScreen extends StatefulWidget {
  const CharacterScreen({super.key});

  @override
  State<CharacterScreen> createState() => _CharacterScreenState();
}

class _CharacterScreenState extends State<CharacterScreen> {
  late Hero _viewing = Profile.i.hero;
  int _pose = 0;
  Weapon _weapon = Weapon.ak;

  void _select(Hero h) {
    Profile.i.hero = h;
    Profile.i.save();
    Sfx.equip();
    setState(() {});
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF203A18),
          duration: const Duration(milliseconds: 1400),
          content: Text('«${HeroSpec.of(h).name}» انتخاب شد.'),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final spec = HeroSpec.of(_viewing);
    final selected = Profile.i.hero == _viewing;
    final skin = Profile.i.skinFor(_weapon);
    return Scaffold(
      backgroundColor: Colors.black,
      body: MenuBackground(
        child: Column(
          children: [
            MenuHeader(
              title: 'شخصیت‌ها',
              icon: Icons.person,
              trailing: CoinBadge(coins: Profile.i.coins),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Hero list
                    SizedBox(
                      width: 150,
                      child: ListView(
                        children: [
                          for (final h in Hero.values) ...[
                            _heroTile(h),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Big preview
                    GestureDetector(
                      onTap: () => setState(() => _pose = (_pose + 1) % 4),
                      child: Container(
                        width: 190,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: RadialGradient(
                            colors: [
                              spec.accent.withValues(alpha: 0.35),
                              Colors.black54,
                            ],
                          ),
                          border: Border.all(
                            color: spec.accent.withValues(alpha: 0.7),
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: _PoseCell(
                                asset: spec.posesFor(skin),
                                cell: _pose,
                              ),
                            ),
                            Positioned(top: 6, left: 6, child: _weaponToggle()),
                            const Positioned(
                              bottom: 4,
                              left: 0,
                              right: 0,
                              child: Text(
                                'ضربه: تغییر ژست',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: _mSand, fontSize: 9.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: _details(spec, selected)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weaponToggle() {
    return GestureDetector(
      onTap: () => setState(
        () => _weapon = _weapon == Weapon.ak ? Weapon.deagle : Weapon.ak,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _mSand.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.swap_horiz, size: 14, color: _mSand),
            const SizedBox(width: 4),
            Text(
              _GunSpec.of(_weapon).shortName,
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                color: _mBone,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroTile(Hero h) {
    final s = HeroSpec.of(h);
    final viewing = _viewing == h;
    final chosen = Profile.i.hero == h;
    return GestureDetector(
      onTap: () {
        Sfx.click();
        setState(() {
          _viewing = h;
          _pose = 0;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: viewing ? s.accent.withValues(alpha: 0.22) : _mPanel,
          border: Border.all(
            color: viewing ? s.accent : Colors.white12,
            width: viewing ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: _PoseCell(
                asset: s.posesFor(Profile.i.skinFor(Weapon.ak)),
                cell: 0,
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    style: const TextStyle(
                      color: _mBone,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    s.latinName,
                    style: TextStyle(
                      color: s.accent,
                      fontSize: 9,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (chosen)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 12, color: _mGold),
                          SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              'انتخاب‌شده',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: _mGold, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _details(HeroSpec s, bool selected) {
    final p = Profile.i;
    final hp = p.maxHp + s.hpBonus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  s.name,
                  style: const TextStyle(
                    color: _mBone,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: s.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: s.accent),
                ),
                child: Text(
                  s.role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: s.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        Text(
          s.bio,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _mSand, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _stat('جان', '${hp.round()}', hp / 260),
                _stat('سرعت', '${(s.speedMul * 100).round()}٪', s.speedMul),
                _stat('پرش', '${(s.jumpMul * 100).round()}٪', s.jumpMul),
                _stat(
                  'کنترل لگد',
                  '${((2 - s.recoilMul) * 100 - 100).round()}٪+',
                  (2 - s.recoilMul) / 1.5,
                ),
                _stat(
                  'مقاومت ضربه',
                  '×${s.mass.toStringAsFixed(1)}',
                  s.mass / 2,
                ),
                _stat(
                  'خشاب‌گذاری',
                  '${(100 / s.reloadMul).round()}٪',
                  1 / s.reloadMul,
                ),
              ],
            ),
          ),
        ),
        Text(s.trait, style: const TextStyle(color: _mGold, fontSize: 11)),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          height: 40,
          child: selected
              ? OutlinedButton.icon(
                  onPressed: null,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _mGold),
                    disabledForegroundColor: _mGold,
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('انتخاب شده'),
                )
              : FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: _mBlood),
                  onPressed: () => _select(s.hero),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: Text('بازی با ${s.name}'),
                ),
        ),
      ],
    );
  }

  Widget _stat(String label, String value, double frac) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(color: _mBone, fontSize: 12),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: frac.clamp(0.05, 1.0),
                minHeight: 7,
                backgroundColor: Colors.white10,
                color: HeroSpec.of(_viewing).accent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 46,
            child: Text(
              _fa(value),
              textAlign: TextAlign.left,
              style: const TextStyle(
                color: _mSand,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
