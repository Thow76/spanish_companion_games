/// Screenshots of the home screen (U4) at the three sizes. UI spec sections
/// 5, 6, 8 and 11.
///
/// - `home_loaded_<size>`: the real app on the sample questions, both phase
///   groups.
/// - `home_loaded-320_phone`: the same at 320×640, the narrowest width the
///   spec covers (section 10: nothing scrolls sideways).
/// - `home_skipped_<size>`: a file where one question was skipped, so the
///   notice shows above the groups; some games have no questions.
/// - `home_error_<size>`: a file that could not be read at all.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/data/question_loader.dart';
import 'package:spanish_companion_games/main.dart';
import 'package:spanish_companion_games/models/question_parser.dart';
import 'package:spanish_companion_games/screens/home_screen.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';

import 'golden_helpers.dart';

void main() {
  late ParsedQuestions sample;

  setUpAll(() async {
    await setUpGoldens();
    // Load the sample file once here, outside the fake-async test zone. The
    // asset bundle caches it, so the app's own load finishes straight away.
    await rootBundle.loadString(sampleQuestionsAsset);
    sample = await loadQuestionsFromAsset();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const SpanishGamesApp());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await settle(tester);
  }

  for (final size in ScreenSize.values) {
    testWidgets('home, loaded, ${size.name}', (tester) async {
      setScreenSize(tester, size);
      await pumpApp(tester);
      await expectLater(
        find.byType(SpanishGamesApp),
        matchesGoldenFile(goldenName('home', 'loaded', size)),
      );
    });

    testWidgets('home, one question skipped, ${size.name}', (tester) async {
      setScreenSize(tester, size);
      // Phase 1 games only, plus one skipped question: the Recall cards
      // show their "No questions yet" state.
      final parsed = ParsedQuestions(
        questions: sample.questions.where((q) => q.game.isPhase1).toList(),
        problems: const [
          QuestionProblem(
            index: 4,
            id: '2026-10-17-005',
            message: '"answers" is missing',
          ),
        ],
      );
      await tester.pumpWidget(
        _App(child: HomeScreen(source: () async => parsed)),
      );
      await settle(tester);
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName('home', 'skipped', size)),
      );
    });

    testWidgets('home, file could not be read, ${size.name}', (tester) async {
      setScreenSize(tester, size);
      await tester.pumpWidget(
        _App(
          child: HomeScreen(
            source: () async => throw const QuestionFileException(
              'The question file is not valid JSON.',
            ),
          ),
        ),
      );
      await settle(tester);
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName('home', 'error', size)),
      );
    });
  }

  testWidgets('home, loaded, 320 wide', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpApp(tester);
    await expectLater(
      find.byType(SpanishGamesApp),
      matchesGoldenFile('home_loaded-320_phone.png'),
    );
  });
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
