part of 'main.dart';

// ---------------------------------------------------------------------------
// Session flow: pause menu, passing out and waking up again.
// ---------------------------------------------------------------------------

extension _SessionLogic on _DemoScreenState {
  // ---- Pause -------------------------------------------------------------

  void _setPaused(bool v) {
    if (_dead) return;
    _paused = v;
    _btnLeft = _btnRight = _btnFire = _btnJump = _btnUse = false;
    if (v) {
      _stopSteps();
      _autosave();
    }
    _syncForestLoop();
    _refresh();
  }

  void _toMenu() {
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// Waves fully cleared so far (an unfinished wave starts over on load).
  int get _wavesCleared {
    final alive = _zombies.any((z) => z.alive);
    final current = _toSpawn == 0 && !alive && _waveBreak > 0;
    return current ? _wave : math.max(0, _wave - 1);
  }

  // ---- HUD pieces --------------------------------------------------------

  Widget _pauseButton() {
    return GestureDetector(
      onTap: () => _setPaused(true),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.5),
          border: Border.all(color: const Color(0xFFB8A27A), width: 1.5),
        ),
        child: const Icon(Icons.pause, color: Color(0xFFD9C9A3)),
      ),
    );
  }

  // ---- Overlays ----------------------------------------------------------

  Widget _overlayShell({required List<Widget> children, double alpha = 0.72}) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: Colors.black.withValues(alpha: alpha),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      ),
    );
  }

  Widget _pauseMenu() {
    return _overlayShell(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/ui/blood_hand.png', height: 54),
            const SizedBox(width: 10),
            const Text(
              'توقف',
              style: TextStyle(
                color: _mBone,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(blurRadius: 12)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _worldHud(),
        const SizedBox(height: 6),
        Text(
          'روز ${_fa('$_day')} · کشتار ${_fa('$_kills')} · امتیاز ${_fa('$_score')}'
          ' · سکه‌ی این نوبت +${_fa('$_coinsEarned')}',
          style: const TextStyle(color: _mSand, fontSize: 12),
        ),
        const SizedBox(height: 14),
        BloodButton(
          primary: true,
          icon: Icons.play_arrow,
          title: 'ادامه',
          onTap: () => _setPaused(false),
        ),
        const SizedBox(height: 8),
        BloodButton(
          icon: Icons.settings,
          title: 'تنظیمات',
          onTap: () async {
            await Navigator.of(
              context,
            ).push(_fadeRoute(const SettingsScreen()));
            _applyVolumes();
            _refresh();
          },
        ),
        const SizedBox(height: 8),
        BloodButton(
          icon: Icons.home,
          title: 'منوی اصلی',
          subtitle: 'دنیا ذخیره می‌شود؛ از همین‌جا ادامه می‌دهی',
          onTap: _toMenu,
        ),
      ],
    );
  }

  void _applyVolumes() {
    final v = Profile.i.sfxVolume;
    _steps.setVolume(0.55 * v);
    for (final p in _shots) {
      p.setVolume(0.9 * v);
    }
    _reloadSfx.setVolume(0.9 * v);
    _stepsMetro.setVolume(0.6 * v);
    _forestLoop.setVolume(0.55 * Profile.i.ambientVolume);
  }

  Widget _statsRow() {
    Widget cell(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _mBone,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(label, style: const TextStyle(color: _mSand, fontSize: 11)),
        ],
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        cell('روز', _fa('$_day')),
        cell('موج', _fa('$_wave')),
        cell('کشتار', _fa('$_kills')),
        cell('شلیک به سر', _fa('$_headshots')),
        cell('امتیاز', _fa('$_score')),
      ],
    );
  }

  Widget _coinsLine() => Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0x33E0B050),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _mGold),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.monetization_on, color: _mGold, size: 20),
        const SizedBox(width: 6),
        Text(
          '+${_fa('$_coinsEarned')} سکه   ·   موجودی: ${_fa('${Profile.i.coins}')}',
          style: const TextStyle(color: _mGold, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );

  Widget _gameOver() {
    final a = ((_deadT - 1.2) / 0.8).clamp(0.0, 1.0);
    return Opacity(
      opacity: a,
      child: _overlayShell(
        alpha: 0.65,
        children: [
          const Text(
            'از هوش رفتی',
            style: TextStyle(
              color: Color(0xFFC01818),
              fontSize: 48,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(blurRadius: 16)],
            ),
          ),
          Text(
            'علت: $_deathCause',
            style: const TextStyle(color: _mBone, fontSize: 15),
          ),
          const SizedBox(height: 4),
          const Text(
            'سه ساعت بعد در نقطه‌ی امن همین منطقه به هوش می‌آیی. '
            'دنیا، ارتقاها و سکه‌ها حفظ می‌شوند.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _mSand, fontSize: 12.5),
          ),
          if (_deathLosses.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'از دست رفت: ${_deathLosses.join('، ')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFE05A3A),
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          _statsRow(),
          _coinsLine(),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BloodButton(
                  primary: true,
                  width: 200,
                  icon: Icons.bedtime,
                  title: 'به هوش بیا',
                  onTap: _restart,
                ),
                const SizedBox(width: 10),
                BloodButton(
                  width: 200,
                  icon: Icons.storefront,
                  title: 'فروشگاه',
                  onTap: () => Navigator.of(
                    context,
                  ).pushReplacement(_fadeRoute(const ShopScreen())),
                ),
                const SizedBox(width: 10),
                BloodButton(
                  width: 200,
                  icon: Icons.home,
                  title: 'منوی اصلی',
                  onTap: _toMenu,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
