/// Screenshots of the phase games screen (B23) at the three sizes, on the
/// sample questions. A stand-in until B24's set picker; U18 does the look.
///
/// - `phase-games_new_<size>`: "New corrections" tapped on home: Choose a
///   correction and Repair the sentence with their counts.
/// - `phase-games_recall_<size>`: "Recall" tapped on home: the four recall
///   games with their counts.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/data/question_loader.dart';
import 'package:spanish_companion_games/models/question_parser.dart';
import 'package:spanish_companion_games/screens/home_screen.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';

import 'golden_helpers.dart';

void main() {
  late ParsedQuestions sample;

  setUpAll(() async {
    await setUpGoldens();
    await rootBundle.loadString(sampleQuestionsAsset);
    sample = await loadQuestionsFromAsset();
  });

  Future<void> openPhase(
    WidgetTester tester,
    ScreenSize size,
    int phase,
  ) async {
    setScreenSize(tester, size);
    await tester.pumpWidget(
      _App(child: HomeScreen(source: () async => sample)),
    );
    await settle(tester);
    final card = find.byKey(ValueKey('phase-card-$phase'));
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await settle(tester);
  }

  for (final size in ScreenSize.values) {
    testWidgets('phase games, new corrections, ${size.name}', (tester) async {
      await openPhase(tester, size, 1);
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName('phase-games', 'new', size)),
      );
    });

    testWidgets('phase games, recall, ${size.name}', (tester) async {
      await openPhase(tester, size, 2);
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName('phase-games', 'recall', size)),
      );
    });
  }
}

/// The app's theme around [child], without the debug banner.
class _App extends StatelessWidget {
  const _App({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme(FormFactor.phone),
      builder: (context, child) => Theme(
        data: appTheme(FormFactor.of(context)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: child,
    );
  }
}
