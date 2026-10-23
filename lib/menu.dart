part of 'main.dart';

// ---------------------------------------------------------------------------
// Menu palette
// ---------------------------------------------------------------------------

const Color _mBlood = Color(0xFFB01818);
const Color _mBloodDark = Color(0xFF5A0A0A);
const Color _mBone = Color(0xFFE9DCC0);
const Color _mSand = Color(0xFFB8A27A);
const Color _mGold = Color(0xFFE0B050);
const Color _mPanel = Color(0xCC120808);

// ---------------------------------------------------------------------------
// Shared widgets
// ---------------------------------------------------------------------------

/// Dark ruined-city backdrop with drifting embers and a bloody vignette.
class MenuBackground extends StatefulWidget {
  const MenuBackground({super.key, required this.child, this.image});
  final Widget child;
  final String? image;

  @override
  State<MenuBackground> createState() => _MenuBackgroundState();
}

class _MenuBackgroundState extends State<MenuBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  )..repeat();
  final List<_Ember> _embers = List.generate(40, (i) => _Ember(i));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          widget.image ?? 'assets/images/background.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xCC000000), Color(0x99100000), Color(0xEE000000)],
            ),
          ),
        ),
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) =>
                CustomPaint(painter: _EmberPainter(_embers, _c.value * 20)),
          ),
        ),
        const IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 1.1,
                colors: [Colors.transparent, Color(0xAA3A0000)],
                stops: [0.55, 1],
              ),
            ),
          ),
        ),
        SafeArea(child: widget.child),
      ],
    );
  }
}

class _Ember {
  _Ember(int seed) {
    final r = math.Random(seed * 7919);
    x = r.nextDouble();
    y0 = r.nextDouble();
    speed = 0.015 + r.nextDouble() * 0.04;
    size = 0.8 + r.nextDouble() * 2.2;
    phase = r.nextDouble() * 6.28;
    red = r.nextDouble() < 0.45;
  }
  late double x, y0, speed, size, phase;
  late bool red;
}

class _EmberPainter extends CustomPainter {
  _EmberPainter(this.embers, this.t);
  final List<_Ember> embers;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in embers) {
      final y = (e.y0 - t * e.speed) % 1.0;
      final x = e.x + math.sin(t * 0.8 + e.phase) * 0.02;
      final a = (math.sin(t * 2 + e.phase) * 0.3 + 0.6).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(x * size.width, y * size.height),
        e.size,
        Paint()
          ..color = (e.red ? const Color(0xFFE04020) : const Color(0xFFBFB6A8))
              .withValues(alpha: a * (e.red ? 0.8 : 0.45)),
      );
    }
  }

  @override
  bool shouldRepaint(_EmberPainter old) => true;
}

/// Big bloody title: "بقا در مرگ" with the bloody hand print.
class GameLogo extends StatelessWidget {
  const GameLogo({super.key, this.size = 1});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.rotate(
          angle: -0.18,
          child: Image.asset(
            'assets/ui/blood_hand.png',
            height: 120 * size,
            filterQuality: FilterQuality.medium,
          ),
        ),
        SizedBox(width: 6 * size),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'بقا در مرگ',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontWeight: FontWeight.w900,
                fontSize: 50 * size,
                height: 1.15,
                color: _mBlood,
                shadows: const [
                  Shadow(blurRadius: 18, color: Color(0xFF000000)),
                  Shadow(blurRadius: 4, color: Color(0xFF3A0000)),
                  Shadow(offset: Offset(2, 3), color: Color(0xFF2A0000)),
                ],
              ),
            ),
            Text(
              'با دست خونین',
              style: TextStyle(
                fontFamily: 'Vazirmatn',
                fontWeight: FontWeight.w700,
                fontSize: 21 * size,
                color: _mBone,
                shadows: const [Shadow(blurRadius: 8)],
              ),
            ),
            SizedBox(height: 2 * size),
            Text(
              'SURVIVAL IN DEATH · DEADLAND',
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontSize: 10 * size,
                letterSpacing: 3 * size,
                fontWeight: FontWeight.bold,
                color: _mSand,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A dark, blood-edged menu button.
class BloodButton extends StatefulWidget {
  const BloodButton({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.primary = false,
    this.width = 270,
    this.enabled = true,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool primary, enabled;
  final double width;

  @override
  State<BloodButton> createState() => _BloodButtonState();
}

class _BloodButtonState extends State<BloodButton> {
  bool _down = false, _hover = false;

  @override
  Widget build(BuildContext context) {
    final on = widget.enabled;
    final hot = (_hover || _down) && on;
    return MouseRegion(
      cursor: on ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: on
            ? () {
                Sfx.click();
                widget.onTap();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.96 : (hot ? 1.03 : 1),
          duration: const Duration(milliseconds: 110),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: widget.width,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: widget.primary
                    ? [
                        hot ? const Color(0xFFC22020) : const Color(0xFF9A1414),
                        const Color(0xFF3A0606),
                      ]
                    : [
                        hot ? const Color(0xEE3A1010) : const Color(0xDD1E0A0A),
                        const Color(0xBB0A0505),
                      ],
              ),
              border: Border.all(
                color: on
                    ? (hot ? const Color(0xFFE04030) : const Color(0x99B01818))
                    : Colors.white12,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (widget.primary ? _mBlood : Colors.black).withValues(
                    alpha: hot ? 0.55 : 0.3,
                  ),
                  blurRadius: hot ? 18 : 8,
                ),
              ],
            ),
            child: Opacity(
              opacity: on ? 1 : 0.45,
              child: Row(
                children: [
                  Icon(widget.icon, color: _mBone, size: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: _mBone,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            height: 1.25,
                          ),
                        ),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _mSand,
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left, color: _mSand, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key, required this.coins});
  final int coins;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _mPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _mGold.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on, color: _mGold, size: 20),
          const SizedBox(width: 6),
          Text(
            _fa('$coins'),
            style: const TextStyle(
              color: _mGold,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

/// Header row used by sub-screens: back button, title, coins.
class MenuHeader extends StatelessWidget {
  const MenuHeader({super.key, required this.title, this.icon, this.trailing});
  final String title;
  final IconData? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            tooltip: 'بازگشت',
            onPressed: () {
              Sfx.click();
              Navigator.of(context).maybePop();
            },
            icon: const Icon(Icons.arrow_forward, color: _mBone),
            style: IconButton.styleFrom(
              backgroundColor: _mPanel,
              side: const BorderSide(color: Color(0x99B01818)),
            ),
          ),
          const SizedBox(width: 10),
          if (icon != null) ...[
            Icon(icon, color: _mBlood, size: 28),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: const TextStyle(
              color: _mBone,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(blurRadius: 8)],
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

bool _isLatin(String s) => RegExp(r'[A-Za-z]').hasMatch(s);

/// Persian digits.
String _fa(String s) {
  const en = '0123456789';
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = en.indexOf(ch);
    b.write(i >= 0 ? fa[i] : ch);
  }
  return b.toString();
}

/// Tiny UI sound helper.
class Sfx {
  static final AudioPlayer _p = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  static final AudioPlayer _buy = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop);

  static void click() {
    final v = Profile.i.sfxVolume * 0.6;
    if (v <= 0) return;
    _p.stop().then((_) async {
      try {
        await _p.setVolume(v);
        await _p.play(AssetSource('audio/weapon_switch.mp3'));
      } catch (_) {}
    });
  }

  static final AudioPlayer _eq = AudioPlayer()
    ..setReleaseMode(ReleaseMode.stop);

  static void equip() {
    final v = Profile.i.sfxVolume;
    if (v <= 0) return;
    _eq.stop().then((_) async {
      try {
        await _eq.setVolume(v);
        await _eq.play(AssetSource('audio/deagle_reload.mp3'));
      } catch (_) {}
    });
  }

  static void denied() {
    final v = Profile.i.sfxVolume * 0.7;
    if (v <= 0) return;
    _eq.stop().then((_) async {
      try {
        await _eq.setVolume(v);
        await _eq.play(AssetSource('audio/shell_drop.mp3'));
      } catch (_) {}
    });
  }

  static void buy() {
    final v = Profile.i.sfxVolume;
    if (v <= 0) return;
    _buy.stop().then((_) async {
      try {
        await _buy.setVolume(v);
        await _buy.play(AssetSource('audio/ak47_reload.wav'));
      } catch (_) {}
    });
  }
}

Route<T> _fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: const Duration(milliseconds: 380),
  reverseTransitionDuration: const Duration(milliseconds: 260),
  pageBuilder: (_, _, _) => page,
  transitionsBuilder: (_, a, _, child) =>
      FadeTransition(opacity: a, child: child),
);

// ---------------------------------------------------------------------------
// Main menu
// ---------------------------------------------------------------------------

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(_fadeRoute(page));
    if (mounted) setState(() {});
  }

  void _exit() {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'خروج از بازی',
        text: 'مطمئنی می‌خواهی از بازی خارج شوی؟',
        confirm: 'خروج',
        onConfirm: () => SystemNavigator.pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Profile.i;
    final save = p.survivor;
    final best = p.bestFree.values.fold<int>(0, math.max);
    return Scaffold(
      backgroundColor: Colors.black,
      body: MenuBackground(
        child: LayoutBuilder(
          builder: (context, c) {
            final s = (c.maxHeight / 420).clamp(0.7, 1.25);
            return Stack(
              children: [
                Positioned(top: 10, left: 14, child: CoinBadge(coins: p.coins)),
                const Positioned(top: 8, right: 14, child: MusicBadge()),
                Positioned(
                  bottom: 8,
                  left: 14,
                  child: Text(
                    'v1.2.0',
                    style: TextStyle(
                      color: _mSand.withValues(alpha: 0.5),
                      fontSize: 10,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      flex: 11,
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GameLogo(size: s),
                                SizedBox(height: 18 * s),
                                _statLine(
                                  Icons.dangerous,
                                  'مجموع کشتار: ${_fa('${p.totalKills}')}',
                                ),
                                _statLine(
                                  Icons.emoji_events,
                                  'بهترین امتیاز: ${_fa('$best')}',
                                ),
                                _statLine(
                                  Icons.wb_sunny,
                                  'بیشترین روز زنده ماندن: ${_fa('${p.bestDays}')}',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 9,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (save != null) ...[
                                BloodButton(
                                  primary: true,
                                  icon: Icons.play_arrow,
                                  title: 'ادامه‌ی بقا',
                                  subtitle:
                                      'روز ${_fa('${save.day}')} · ${save.area.fa} · ${save.difficulty.title}',
                                  onTap: () => _open(const DemoScreen()),
                                ),
                                const SizedBox(height: 10),
                              ],
                              BloodButton(
                                primary: save == null,
                                icon: Icons.person_add,
                                title: 'بازمانده‌ی جدید',
                                subtitle: save == null
                                    ? 'شروع بقا در دنیای همیشگی'
                                    : 'دنیای فعلی پاک می‌شود',
                                onTap: () => _open(const NewSurvivorScreen()),
                              ),
                              const SizedBox(height: 10),
                              BloodButton(
                                icon: Icons.groups,
                                title: 'شخصیت‌ها',
                                subtitle:
                                    'انتخاب‌شده: ${HeroSpec.of(p.hero).name}',
                                onTap: () => _open(const CharacterScreen()),
                              ),
                              const SizedBox(height: 10),
                              BloodButton(
                                icon: Icons.storefront,
                                title: 'فروشگاه',
                                subtitle: 'ارتقای تجهیزات و اسکین سلاح‌ها',
                                onTap: () => _open(const ShopScreen()),
                              ),
                              const SizedBox(height: 10),
                              BloodButton(
                                icon: Icons.settings,
                                title: 'تنظیمات',
                                subtitle: 'موسیقی، صدا، کنترل‌ها، گرافیک',
                                onTap: () => _open(const SettingsScreen()),
                              ),
                              if (!kIsWeb) ...[
                                const SizedBox(height: 10),
                                BloodButton(
                                  icon: Icons.power_settings_new,
                                  title: 'خروج',
                                  onTap: _exit,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _statLine(IconData i, String t) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(i, size: 16, color: _mSand),
        const SizedBox(width: 6),
        Text(t, style: const TextStyle(color: _mSand, fontSize: 13)),
      ],
    ),
  );
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.text,
    required this.confirm,
    required this.onConfirm,
  });
  final String title, text, confirm;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A0B0B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _mBlood),
      ),
      title: Text(
        title,
        style: const TextStyle(color: _mBone, fontWeight: FontWeight.w900),
      ),
      content: Text(text, style: const TextStyle(color: _mSand)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('انصراف', style: TextStyle(color: _mSand)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _mBlood),
          onPressed: () {
            Navigator.pop(context);
            onConfirm();
          },
          child: Text(confirm),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// New survivor setup (difficulty + starting area)
// ---------------------------------------------------------------------------

class NewSurvivorScreen extends StatefulWidget {
  const NewSurvivorScreen({super.key});

  @override
  State<NewSurvivorScreen> createState() => _NewSurvivorScreenState();
}

class _NewSurvivorScreenState extends State<NewSurvivorScreen> {
  Difficulty _diff = Profile.i.survivor?.difficulty ?? Difficulty.normal;
  Area _area = Area.city;

  void _start() {
    final old = Profile.i.survivor;
    if (old != null) {
      showDialog<void>(
        context: context,
        builder: (_) => _ConfirmDialog(
          title: 'بازمانده‌ی جدید',
          text:
              'دنیای فعلی (روز ${_fa('${old.day}')}، ${_fa('${old.kills}')} کشتار) '
              'برای همیشه پاک می‌شود. سکه‌ها، ارتقاها و اسکین‌ها باقی می‌مانند.',
          confirm: 'شروع از نو',
          onConfirm: _begin,
        ),
      );
    } else {
      _begin();
    }
  }

  void _begin() {
    Profile.i.newSurvivor(_diff, _area);
    Navigator.of(context).pushReplacement(_fadeRoute(const DemoScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final p = Profile.i;
    return Scaffold(
      backgroundColor: Colors.black,
      body: MenuBackground(
        child: Column(
          children: [
            MenuHeader(
              title: 'بازمانده‌ی جدید',
              icon: Icons.person_add,
              trailing: CoinBadge(coins: p.coins),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'یک دنیای همیشگی: گرسنگی، تشنگی، خونریزی و عفونت را مدیریت کن، '
                      'ماشین‌ها و کلبه‌ها را بگرد و شب‌ها زنده بمان. پایانی در کار نیست.',
                      style: TextStyle(color: _mSand, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    _sectionTitle('درجه‌ی سختی'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (final d in Difficulty.values) ...[
                          Expanded(child: _diffCard(d)),
                          if (d != Difficulty.values.last)
                            const SizedBox(width: 10),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    _sectionTitle('نقطه‌ی شروع'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (final a in Area.values) ...[
                          Expanded(child: _mapCard(a)),
                          if (a != Area.values.last) const SizedBox(width: 10),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: BloodButton(
                        primary: true,
                        icon: Icons.play_arrow,
                        title: 'شروع بقا',
                        subtitle:
                            '${_diff.title} · ${HeroSpec.of(p.hero).name} · ضریب سکه ×${_fa(_diff.coinMul.toString())}',
                        onTap: _start,
                        width: 300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(
      color: _mBone,
      fontWeight: FontWeight.w900,
      fontSize: 16,
    ),
  );

  Widget _diffCard(Difficulty d) {
    final sel = d == _diff;
    final p = Profile.i;
    return GestureDetector(
      onTap: () {
        Sfx.click();
        setState(() => _diff = d);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: sel ? d.color.withValues(alpha: 0.18) : _mPanel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel ? d.color : Colors.white12,
            width: sel ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  [
                    Icons.sentiment_satisfied,
                    Icons.sentiment_neutral,
                    Icons.sentiment_very_dissatisfied,
                  ][d.index],
                  color: d.color,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  d.title,
                  style: TextStyle(
                    color: d.color,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'زامبی: جان ×${_fa('${d.zombieHp}')} · آسیب ×${_fa('${d.zombieDamage}')}',
              style: const TextStyle(color: _mSand, fontSize: 10.5),
            ),
            Text(
              'گرسنگی و تشنگی ×${_fa('${d.survivalDrain}')}',
              style: const TextStyle(color: _mSand, fontSize: 10.5),
            ),
            Text(
              'رکورد: ${_fa('${p.bestFree[d]}')} · موج ${_fa('${p.bestWave[d]}')}',
              style: const TextStyle(color: _mBone, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapCard(Area a) {
    final sel = a == _area;
    return GestureDetector(
      onTap: () {
        Sfx.click();
        setState(() => _area = a);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 84,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel ? _mBlood : Colors.white12,
            width: sel ? 2.5 : 1,
          ),
          image: DecorationImage(
            image: AssetImage(a.background),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: sel ? 0.25 : 0.6),
              BlendMode.darken,
            ),
          ),
        ),
        alignment: AlignmentDirectional.bottomStart,
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            if (sel) const Icon(Icons.check_circle, color: _mBlood, size: 18),
            if (sel) const SizedBox(width: 6),
            Flexible(
              child: Text(
                a.fa,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _mBone,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  shadows: [Shadow(blurRadius: 6)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shop
// ---------------------------------------------------------------------------

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  void _buy(Upgrade u) {
    final p = Profile.i;
    final info = UpgradeInfo.of(u);
    final l = p.level(u);
    if (l >= UpgradeInfo.maxLevel) return;
    final price = info.priceFor(l);
    if (p.buy(u)) {
      Sfx.buy();
      setState(() {});
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF203A18),
            duration: const Duration(milliseconds: 1400),
            content: Text(
              '«${info.title}» به سطح ${_fa('${l + 1}')} ارتقا یافت.',
            ),
          ),
        );
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF4A1010),
            duration: const Duration(milliseconds: 1600),
            content: Text(
              'سکه کافی نیست! ${_fa('${price - p.coins}')} سکه‌ی دیگر لازم است.',
            ),
          ),
        );
    }
  }

  int _tab = 0; // 0 = upgrades, 1 = weapon skins
  Weapon _skinWeapon = Weapon.ak;

  @override
  Widget build(BuildContext context) {
    final p = Profile.i;
    return Scaffold(
      backgroundColor: Colors.black,
      body: MenuBackground(
        child: Column(
          children: [
            MenuHeader(
              title: 'فروشگاه',
              icon: Icons.storefront,
              trailing: CoinBadge(coins: p.coins),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  _tabButton(0, Icons.trending_up, 'ارتقاها'),
                  const SizedBox(width: 8),
                  _tabButton(1, Icons.palette, 'اسکین سلاح'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _tab == 0
                          ? 'ارتقاها دائمی هستند و قدرت تو را بالا می‌برند.'
                          : 'اسکین‌ها ظاهر سلاح را در بازی، دست شخصیت و HUD عوض می‌کنند.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _mSand.withValues(alpha: 0.9),
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: _tab == 0
                    ? KeyedSubtree(
                        key: const ValueKey('up'),
                        child: _upgradesGrid(),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('skins'),
                        child: _skinsTab(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(int i, IconData icon, String label) {
    final sel = _tab == i;
    return GestureDetector(
      onTap: () {
        if (_tab == i) return;
        Sfx.click();
        setState(() => _tab = i);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? _mBlood : _mPanel,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel ? const Color(0xFFE04030) : const Color(0x66B01818),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: sel ? Colors.white : _mSand),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: sel ? Colors.white : _mBone,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _upgradesGrid() {
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 900 ? 4 : (c.maxWidth > 560 ? 3 : 2);
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 158,
          ),
          itemCount: Upgrade.values.length,
          itemBuilder: (_, i) => _upgradeCard(Upgrade.values[i]),
        );
      },
    );
  }

  // ---- Weapon skins ------------------------------------------------------

  Widget _skinsTab() {
    final p = Profile.i;
    final skins = WeaponSkin.forWeapon(_skinWeapon);
    final owned = skins.where((s) => p.ownsSkin(s.id)).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Row(
            children: [
              _weaponChip(Weapon.ak, 'AK-47'),
              const SizedBox(width: 8),
              _weaponChip(Weapon.deagle, 'DESERT EAGLE'),
              const Spacer(),
              Text(
                'مجموعه: ${_fa('$owned')} از ${_fa('${skins.length}')}',
                style: const TextStyle(
                  color: _mSand,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth > 900 ? 3 : (c.maxWidth > 520 ? 3 : 2);
              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 176,
                ),
                itemCount: skins.length,
                itemBuilder: (_, i) => _skinCard(skins[i]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _weaponChip(Weapon w, String label) {
    final sel = _skinWeapon == w;
    final eq = Profile.i.skinFor(w);
    return GestureDetector(
      onTap: () {
        if (sel) return;
        Sfx.click();
        setState(() => _skinWeapon = w);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
        decoration: BoxDecoration(
          color: sel ? const Color(0xFF2A1410) : _mPanel,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: sel ? _mGold : Colors.white12,
            width: sel ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              eq.sprite,
              height: 22,
              filterQuality: FilterQuality.medium,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                color: sel ? _mGold : _mBone,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _skinCard(WeaponSkin s) {
    final p = Profile.i;
    final owned = p.ownsSkin(s.id);
    final equipped = p.isEquipped(s);
    final afford = p.coins >= s.price;
    final rc = s.rarity.color;
    return GestureDetector(
      onTap: () => _openSkin(s),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _mPanel,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: equipped ? _mGold : rc.withValues(alpha: 0.55),
            width: equipped ? 2 : 1.3,
          ),
          boxShadow: [
            if (equipped)
              BoxShadow(color: _mGold.withValues(alpha: 0.25), blurRadius: 12),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _rarityTag(s.rarity),
                const Spacer(),
                if (equipped)
                  const Icon(Icons.check_circle, color: _mGold, size: 18)
                else if (owned)
                  const Icon(Icons.inventory, color: _mSand, size: 16)
                else
                  const Icon(
                    Icons.lock_outline,
                    color: Colors.white38,
                    size: 16,
                  ),
              ],
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: RadialGradient(
                    colors: [rc.withValues(alpha: 0.28), Colors.transparent],
                    radius: 0.8,
                  ),
                ),
                padding: const EdgeInsets.all(6),
                child: Image.asset(
                  s.sprite,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
            Text(
              s.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _mBone,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 30,
              child: _skinActionButton(s, owned, equipped, afford),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rarityTag(SkinRarity r) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
    decoration: BoxDecoration(
      color: r.color.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: r.color.withValues(alpha: 0.8)),
    ),
    child: Text(
      r.title,
      style: TextStyle(
        color: r.color,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _skinActionButton(
    WeaponSkin s,
    bool owned,
    bool equipped,
    bool afford,
  ) {
    if (equipped) {
      return OutlinedButton.icon(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: const BorderSide(color: _mGold),
          disabledForegroundColor: _mGold,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.check, size: 16),
        label: const Text(
          'مجهز شده',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      );
    }
    if (owned) {
      return FilledButton.icon(
        onPressed: () => _equipSkin(s),
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: const Color(0xFF2E5A20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.back_hand, size: 15),
        label: const Text(
          'مجهز کن',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      );
    }
    return FilledButton(
      onPressed: () => _confirmBuySkin(s),
      style: FilledButton.styleFrom(
        padding: EdgeInsets.zero,
        backgroundColor: afford ? _mBlood : const Color(0xFF3A2020),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'خرید',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.monetization_on, size: 14, color: _mGold),
          const SizedBox(width: 3),
          Text(
            _fa('${s.price}'),
            style: TextStyle(
              color: afford ? Colors.white : Colors.white54,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String text, {bool good = true}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: good
              ? const Color(0xFF203A18)
              : const Color(0xFF4A1010),
          duration: const Duration(milliseconds: 1600),
          content: Text(text),
        ),
      );
  }

  void _equipSkin(WeaponSkin s) {
    if (Profile.i.equipSkin(s)) {
      Sfx.equip();
      setState(() {});
      _snack('اسکین «${s.name}» روی ${_gunLabel(s.weapon)} مجهز شد.');
    }
  }

  String _gunLabel(Weapon w) => w == Weapon.ak ? 'AK-47' : 'دزرت ایگل';

  /// Opens the large preview for a skin (works for every state).
  Future<void> _openSkin(WeaponSkin s) async {
    Sfx.click();
    await showDialog<void>(
      context: context,
      builder: (_) => _SkinPreviewDialog(
        skin: s,
        onBuy: () => _confirmBuySkin(s),
        onEquip: () => _equipSkin(s),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _confirmBuySkin(WeaponSkin s) async {
    final p = Profile.i;
    if (p.ownsSkin(s.id)) return;
    if (p.coins < s.price) {
      Sfx.denied();
      _snack(
        'سکه کافی نیست! ${_fa('${s.price - p.coins}')} سکه‌ی دیگر لازم است.',
        good: false,
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A0B0B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: s.rarity.color),
        ),
        title: Text(
          'خرید اسکین «${s.name}»',
          style: const TextStyle(color: _mBone, fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Image.asset(s.sprite, height: 70)),
            const SizedBox(height: 10),
            Text(
              'قیمت: ${_fa('${s.price}')} سکه',
              style: const TextStyle(
                color: _mGold,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'موجودی بعد از خرید: ${_fa('${p.coins - s.price}')} سکه',
              style: const TextStyle(color: _mSand, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف', style: TextStyle(color: _mSand)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _mBlood),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.shopping_cart, size: 18),
            label: const Text('بخر و مجهز کن'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (p.buySkin(s)) {
      p.equipSkin(s);
      Sfx.buy();
      setState(() {});
      _snack('اسکین «${s.name}» خریداری و مجهز شد!');
    } else {
      Sfx.denied();
      _snack('خرید انجام نشد.', good: false);
    }
  }

  Widget _upgradeCard(Upgrade u) {
    final p = Profile.i;
    final info = UpgradeInfo.of(u);
    final l = p.level(u);
    final maxed = l >= UpgradeInfo.maxLevel;
    final price = maxed ? 0 : info.priceFor(l);
    final afford = p.coins >= price;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _mPanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: maxed ? _mGold : const Color(0x66B01818),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _mBloodDark,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(info.icon, color: _mBone, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  info.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _mBone,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            info.desc,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _mSand, fontSize: 11),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < UpgradeInfo.maxLevel; i++)
                Expanded(
                  child: Container(
                    height: 6,
                    margin: const EdgeInsetsDirectional.only(end: 3),
                    decoration: BoxDecoration(
                      color: i < l ? _mBlood : Colors.white12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            maxed
                ? 'حداکثر: ${info.effect(l)}'
                : '${info.effect(l)}  ←  ${info.effect(l + 1)}',
            textDirection: TextDirection.rtl,
            style: const TextStyle(color: _mBone, fontSize: 10.5),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: FilledButton(
              onPressed: maxed ? null : () => _buy(u),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: afford ? _mBlood : const Color(0xFF3A2020),
                disabledBackgroundColor: const Color(0xFF3A3010),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: maxed
                  ? const Text(
                      'تکمیل شد',
                      style: TextStyle(
                        color: _mGold,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'خرید',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.monetization_on,
                          size: 15,
                          color: _mGold,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _fa('$price'),
                          style: TextStyle(
                            color: afford ? Colors.white : Colors.white54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Large skin preview: weapon sprite + survivor holding it + stats.
class _SkinPreviewDialog extends StatefulWidget {
  const _SkinPreviewDialog({
    required this.skin,
    required this.onBuy,
    required this.onEquip,
  });
  final WeaponSkin skin;
  final Future<void> Function() onBuy;
  final void Function() onEquip;

  @override
  State<_SkinPreviewDialog> createState() => _SkinPreviewDialogState();
}

class _SkinPreviewDialogState extends State<_SkinPreviewDialog> {
  int _pose = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.skin;
    final p = Profile.i;
    final owned = p.ownsSkin(s.id);
    final equipped = p.isEquipped(s);
    final rc = s.rarity.color;
    final gun = _GunSpec.of(s.weapon);
    return Dialog(
      backgroundColor: const Color(0xF2140808),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: rc, width: 1.6),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 360),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Survivor holding the skin (tap to cycle poses).
              GestureDetector(
                onTap: () => setState(() => _pose = (_pose + 1) % 4),
                child: Container(
                  width: 150,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: RadialGradient(
                      colors: [rc.withValues(alpha: 0.3), Colors.black54],
                    ),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _PoseCell(
                          asset: HeroSpec.of(p.hero).posesFor(s),
                          cell: _pose,
                        ),
                      ),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: rc.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: rc),
                          ),
                          child: Text(
                            s.rarity.title,
                            style: TextStyle(
                              color: rc,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          gun.shortName,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            color: _mSand,
                            fontSize: 11,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close, color: _mSand),
                        ),
                      ],
                    ),
                    Text(
                      s.name,
                      style: const TextStyle(
                        color: _mBone,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                    Text(
                      s.desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _mSand, fontSize: 12),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Image.asset(
                          s.sprite,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.linear_scale, size: 16, color: s.tracer),
                        const SizedBox(width: 4),
                        const Text(
                          'رنگ رد گلوله‌ی اختصاصی',
                          style: TextStyle(color: _mSand, fontSize: 11),
                        ),
                        const Spacer(),
                        const Text(
                          'فقط ظاهری · بدون تغییر قدرت',
                          style: TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: equipped
                          ? OutlinedButton.icon(
                              onPressed: null,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: _mGold),
                                disabledForegroundColor: _mGold,
                              ),
                              icon: const Icon(Icons.check),
                              label: const Text('مجهز شده'),
                            )
                          : owned
                          ? FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2E5A20),
                              ),
                              onPressed: () {
                                widget.onEquip();
                                setState(() {});
                              },
                              icon: const Icon(Icons.back_hand),
                              label: const Text('مجهز کن'),
                            )
                          : FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: p.coins >= s.price
                                    ? _mBlood
                                    : const Color(0xFF3A2020),
                              ),
                              onPressed: () async {
                                await widget.onBuy();
                                if (mounted) setState(() {});
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'خرید',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.monetization_on,
                                    color: _mGold,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _fa('${s.price}'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '(موجودی: ${_fa('${p.coins}')})',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white60,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws one 260x300 cell of a survivor pose sheet.
class _PoseCell extends StatelessWidget {
  const _PoseCell({required this.asset, required this.cell});
  final String asset;
  final int cell;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // Fit the 260x300 cell; show the full sheet shifted so only one
        // cell is visible.
        final k = math.min(c.maxWidth / 260, (c.maxHeight - 14) / 300);
        final cw = 260 * k, ch = 300 * k;
        return Center(
          child: SizedBox(
            width: cw,
            height: ch,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: cw * 4,
                maxWidth: cw * 4,
                minHeight: ch,
                maxHeight: ch,
                child: Transform.translate(
                  offset: Offset(-cell * cw, 0),
                  child: Image.asset(
                    asset,
                    width: cw * 4,
                    height: ch,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Profile get p => Profile.i;

  void _changed() {
    setState(() {});
    p.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: MenuBackground(
        child: Column(
          children: [
            const MenuHeader(title: 'تنظیمات', icon: Icons.settings),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final wide = c.maxWidth > 640;
                    final left = Column(
                      children: [
                        _musicPanel(),
                        const SizedBox(height: 10),
                        _panel('صدا', Icons.volume_up, [
                          _slider(
                            'افکت‌های صوتی',
                            Icons.music_note,
                            p.sfxVolume,
                            (v) => p.sfxVolume = v,
                          ),
                          _slider(
                            'صدای محیط',
                            Icons.air,
                            p.ambientVolume,
                            (v) => p.ambientVolume = v,
                          ),
                        ]),
                        const SizedBox(height: 10),
                        _panel('گرافیک و جلوه‌ها', Icons.auto_awesome, [
                          _switch(
                            'لرزش صفحه',
                            Icons.vibration,
                            p.screenShake,
                            (v) => p.screenShake = v,
                          ),
                          _switch(
                            'نمایش اعداد آسیب',
                            Icons.onetwothree,
                            p.damageNumbers,
                            (v) => p.damageNumbers = v,
                          ),
                          _switch(
                            'خون و جلوه‌های شدید',
                            Icons.water_drop,
                            p.highGore,
                            (v) => p.highGore = v,
                          ),
                          _switch(
                            'لرزش گوشی (ویبره)',
                            Icons.smartphone,
                            p.vibration,
                            (v) => p.vibration = v,
                          ),
                        ]),
                      ],
                    );
                    final right = Column(
                      children: [
                        _panel('کنترل‌های لمسی', Icons.touch_app, [
                          _slider(
                            'اندازه‌ی دکمه‌ها',
                            Icons.open_in_full,
                            p.buttonScale,
                            (v) => p.buttonScale = v,
                            min: 0.7,
                            max: 1.3,
                          ),
                          _slider(
                            'شفافیت دکمه‌ها',
                            Icons.opacity,
                            p.buttonOpacity,
                            (v) => p.buttonOpacity = v,
                            min: 0.3,
                            max: 1,
                          ),
                        ]),
                        const SizedBox(height: 10),
                        _panel('راهنمای کنترل‌ها', Icons.keyboard, [
                          _help('حرکت', '◀ ▶  /  ← →  یا  A D'),
                          _help('پرش', 'JUMP  /  ↑  W  Space'),
                          _help('نشستن', 'CROUCH  /  ↓  S  C'),
                          _help('شلیک', 'FIRE  /  F  J  Enter'),
                          _help('خشاب‌گذاری', '⟳  /  R'),
                          _help('تعویض سلاح', 'GUN  /  Q  Tab  1  2'),
                          _help('ورود / جستجو / پمپ آب', 'ENTER  /  E'),
                          _help('غذا، آب، باند، کیت، دارو', '3  4  5  6  7'),
                          _help('توقف بازی', '‖  /  Esc  P'),
                        ]),
                        const SizedBox(height: 10),
                        _panel('آمار و داده‌ها', Icons.bar_chart, [
                          _help('بازی‌های انجام‌شده', _fa('${p.totalGames}')),
                          _help('مجموع کشتار', _fa('${p.totalKills}')),
                          _help('تعداد مرگ', _fa('${p.totalDeaths}')),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _confirmReset,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFE05A3A),
                                side: const BorderSide(
                                  color: Color(0xFFE05A3A),
                                ),
                              ),
                              icon: const Icon(Icons.delete_forever),
                              label: const Text('پاک کردن همه‌ی پیشرفت'),
                            ),
                          ),
                        ]),
                      ],
                    );
                    if (!wide) {
                      return Column(
                        children: [left, const SizedBox(height: 10), right],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: left),
                        const SizedBox(width: 12),
                        Expanded(child: right),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _musicPanel() {
    return ListenableBuilder(
      listenable: MenuMusic.listenable,
      builder: (context, _) {
        final cur = MenuMusic.current.value;
        return _panel('موسیقی منو', Icons.library_music, [
          _switch('پخش موسیقی', Icons.music_note, p.musicOn, (v) {
            p.musicOn = v;
            MenuMusic.userGesture();
            MenuMusic.settingsChanged();
          }),
          Opacity(
            opacity: p.musicOn ? 1 : 0.45,
            child: _slider('بلندی موسیقی', Icons.graphic_eq, p.musicVolume, (
              v,
            ) {
              p.musicVolume = v;
              MenuMusic.settingsChanged();
            }),
          ),
          _switch(
            'پخش پشت‌سرهم همه‌ی آهنگ‌ها',
            Icons.queue_music,
            p.musicPlaylist,
            (v) {
              p.musicPlaylist = v;
              MenuMusic.settingsChanged();
            },
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < menuTracks.length; i++) _trackTile(i, i == cur),
        ]);
      },
    );
  }

  Widget _trackTile(int i, bool sel) {
    final t = menuTracks[i];
    final live = sel && p.musicOn && MenuMusic.playing.value;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          MenuMusic.userGesture();
          if (!p.musicOn) {
            p.musicOn = true;
            p.save();
          }
          MenuMusic.selectTrack(i);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? const Color(0x44B01818) : Colors.black26,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: sel ? const Color(0xFFE04030) : Colors.white10,
            ),
          ),
          child: Row(
            children: [
              Icon(
                live
                    ? Icons.volume_up
                    : (sel ? Icons.pause_circle : Icons.play_circle_outline),
                color: sel ? _mGold : _mSand,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      style: TextStyle(
                        color: sel ? _mBone : _mSand,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${t.mood} · ${t.credit}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _mSand.withValues(alpha: 0.7),
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (live) const _EqBars(),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmReset() {
    showDialog<void>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'پاک کردن پیشرفت',
        text:
            'همه‌ی سکه‌ها، ارتقاها، اسکین‌های خریداری‌شده، دنیای بازمانده و رکوردها پاک می‌شوند. این کار برگشت‌پذیر نیست.',
        confirm: 'پاک کن',
        onConfirm: () async {
          await p.resetProgress();
          if (!mounted) return;
          setState(() {});
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('پیشرفت بازی پاک شد.')));
        },
      ),
    );
  }

  Widget _panel(String title, IconData icon, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: _mPanel,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x55B01818)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _mBlood, size: 20),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: _mBone,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const Divider(color: Color(0x33B01818), height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _slider(
    String label,
    IconData icon,
    double value,
    ValueChanged<double> set, {
    double min = 0,
    double max = 1,
  }) {
    final pct = ((value - (min == 0 ? 0 : 0)) * 100).round();
    return Row(
      children: [
        Icon(icon, color: _mSand, size: 18),
        const SizedBox(width: 6),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(color: _mBone, fontSize: 13),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _mBlood,
              inactiveTrackColor: Colors.white12,
              thumbColor: const Color(0xFFE04030),
              overlayColor: _mBlood.withValues(alpha: 0.2),
              trackHeight: 3,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: (v) {
                set(v);
                setState(() {});
              },
              onChangeEnd: (_) {
                _changed();
                Sfx.click();
              },
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '${_fa('$pct')}٪',
            style: const TextStyle(color: _mSand, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _switch(
    String label,
    IconData icon,
    bool value,
    ValueChanged<bool> set,
  ) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Icon(icon, color: _mSand, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: _mBone, fontSize: 13),
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: const Color(0xFFE04030),
            activeTrackColor: _mBloodDark,
            onChanged: (v) {
              set(v);
              Sfx.click();
              _changed();
            },
          ),
        ],
      ),
    );
  }

  Widget _help(String a, String b) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(
          child: Text(a, style: const TextStyle(color: _mSand, fontSize: 12.5)),
        ),
        Text(
          b,
          textDirection: _isLatin(b) ? TextDirection.ltr : TextDirection.rtl,
          style: const TextStyle(
            color: _mBone,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}
