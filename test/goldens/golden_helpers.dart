/// Shared set-up for the screenshot (golden) tests. UI spec section 11.
///
/// The screenshots are for review, not pass/fail comparison: every golden
/// test writes its PNG to `test/goldens/` and never compares it with a
/// reference image. The `screenshots` workflow makes them on every pull
/// request, commits them to the PR branch (so they show in Files changed)
/// and also uploads them as an artifact. Never commit them by hand.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/widgets/game_icon.dart';

/// The three screenshot sizes, at device pixel ratio 1.
enum ScreenSize {
  phone(Size(390, 844)),
  landscape(Size(844, 390)),
  laptop(Size(1280, 800));

  const ScreenSize(this.size);

  final Size size;
}

/// Call first in `setUpAll` of every golden test file.
///
/// Makes every golden write its PNG instead of comparing, so the tests pass
/// with or without `--update-goldens` and a plain `flutter test` still works.
Future<void> setUpGoldens() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  autoUpdateGoldenFiles = true;
  await loadAppFonts();
  await precacheGameIcons();
}

/// Loads the six game icon SVGs into flutter_svg's cache outside the
/// fake-async test zone, so they are drawn in the screenshots instead of
/// still loading.
Future<void> precacheGameIcons() async {
  for (final game in GameIcon.games) {
    final loader = SvgAssetLoader(GameIcon.assetPath(game));
    await svg.cache.putIfAbsent(
      loader.cacheKey(null),
      () => loader.loadBytes(null),
    );
  }
}

/// Lets real asynchronous work (asset and SVG loading) finish, then settles
/// the frame. Call before taking a screenshot.
Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pumpAndSettle();
}

/// Loads every font registered in the app's font manifest (Sora, DM Sans,
/// Material Icons, Cupertino Icons), so screenshots show real text and icons
/// instead of the test font's boxes.
///
/// Since U1 the app's theme names Sora and DM Sans for every text style, so
/// there is no stand-in for Roboto any more: any text still asking for a
/// font that is not bundled shows as boxes, which makes it easy to spot.
Future<void> loadAppFonts() async {
  final manifest =
      jsonDecode(await rootBundle.loadString('FontManifest.json'))
          as List<dynamic>;
  for (final entry in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(entry['family'] as String);
    for (final font
        in (entry['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

/// Sets the test window to [screen] at device pixel ratio 1 for this test.
void setScreenSize(WidgetTester tester, ScreenSize screen) {
  tester.view.physicalSize = screen.size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// File name for a screenshot: `<screen>_<state>_<phone|landscape|laptop>.png`.
String goldenName(String screen, String state, ScreenSize size) =>
    '${screen}_${state}_${size.name}.png';
