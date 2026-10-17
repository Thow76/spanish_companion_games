/// Screenshots of the home screen as it is now, loaded from the sample
/// questions, at the three sizes. UI spec section 11.
@Tags(['golden'])
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/data/question_loader.dart';
import 'package:spanish_companion_games/main.dart';

import 'golden_helpers.dart';

void main() {
  setUpAll(() async {
    await setUpGoldens();
    // Load the sample file once here, outside the fake-async test zone. The
    // asset bundle caches it, so the app's own load finishes straight away.
    await rootBundle.loadString(sampleQuestionsAsset);
  });

  for (final size in ScreenSize.values) {
    testWidgets('home, loaded, ${size.name}', (tester) async {
      setScreenSize(tester, size);

      await tester.pumpWidget(const SpanishGamesApp());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(SpanishGamesApp),
        matchesGoldenFile(goldenName('home', 'loaded', size)),
      );
    });
  }
}
