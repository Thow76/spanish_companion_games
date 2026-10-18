/// Shared set-up for the screenshot (golden) tests. UI spec section 11.
///
/// The screenshots are for review, not pass/fail comparison: every golden
/// test writes its PNG to `test/goldens/` and never compares it with a
/// reference image. The PNGs are not committed; the `screenshots` workflow
/// makes them on every pull request and uploads them as an artifact.
library;

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

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
