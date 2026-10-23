import 'package:flutter/material.dart' hide Hero;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deadland/main.dart';

/// Renders every screen on small landscape phones and fails on any layout
/// overflow (release builds hide those, debug tests catch them).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Silence the audio plugin: every method call just succeeds.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final ch in [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(ch), (_) async => 1);
    }
    SharedPreferences.setMockInitialValues({'coins': 5000});
    await Profile.i.load();
  });

  const sizes = [Size(640, 360), Size(740, 360), Size(915, 412)];

  Future<void> pumpAt(WidgetTester tester, Size s, Widget home) async {
    tester.view.physicalSize = s;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(DeadlandTestHost(home: home));
    await tester.pump(const Duration(milliseconds: 500));
  }

  for (final s in sizes) {
    final tag = '${s.width.toInt()}x${s.height.toInt()}';
    testWidgets('main menu $tag', (t) => pumpAt(t, s, const MainMenuScreen()));
    testWidgets(
      'new survivor $tag',
      (t) => pumpAt(t, s, const NewSurvivorScreen()),
    );
    testWidgets('shop $tag', (t) => pumpAt(t, s, const ShopScreen()));
    testWidgets('characters $tag', (t) async {
      for (final h in Hero.values) {
        Profile.i.hero = h;
        await pumpAt(t, s, const CharacterScreen());
      }
      Profile.i.hero = Hero.arash;
    });
    testWidgets('settings $tag', (t) => pumpAt(t, s, const SettingsScreen()));

    testWidgets('shop skins tab $tag', (t) async {
      await pumpAt(t, s, const ShopScreen());
      await t.tap(find.text('اسکین سلاح'));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(find.text('DESERT EAGLE').first);
      await t.pump(const Duration(milliseconds: 300));
    });

    for (final h in Hero.values) {
      testWidgets('game hud / bag / pause / pass-out ${h.name} $tag', (
        t,
      ) async {
        Profile.i.hero = h;
        Profile.i.newSurvivor(Difficulty.normal, Area.city);
        Profile.i.survivor!
          ..bleed = 3
          ..infection = 60
          ..leg = 40
          ..hunger = 10
          ..thirst = 10;
        await pumpAt(t, s, const DemoScreen());
        await t.pump(const Duration(milliseconds: 100));
        // Backpack
        await t.tap(find.text('BAG'));
        await t.pump(const Duration(milliseconds: 100));
        await t.tap(find.text('BAG'));
        await t.pump(const Duration(milliseconds: 100));
        // Pause
        await t.tap(find.byIcon(Icons.pause));
        await t.pump(const Duration(milliseconds: 100));
        await t.tap(find.text('ادامه'));
        await t.pump(const Duration(milliseconds: 100));
        // Bleed out -> pass-out screen. Close the first world first (it
        // saves its own state on dispose), then lower the saved health.
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 2));
        Profile.i.survivor!
          ..hp = 0.5
          ..bleed = 3;
        await pumpAt(t, s, const DemoScreen());
        for (var i = 0; i < 40; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('از هوش رفتی'), findsOneWidget);
        // Leave the screen so tickers / timers are disposed.
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 2));
        Profile.i.hero = Hero.arash;
      });
    }
  }
}
