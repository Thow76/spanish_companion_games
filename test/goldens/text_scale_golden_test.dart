/// Screenshots at 200% text size (U10, UI spec section 10: works at 200%
/// text scale with no clipped text; nothing scrolls sideways at 320).
///
/// - `home_text-200_<size>` and `home_text-200-320_phone`: the home screen.
/// - `home_text-200-full_phone`: the same on a very tall phone window, so
///   every game card shows.
/// - `set-picker_text-200_<size>`, `-320_phone` and `-full_phone`: the
///   Recall set picker with "By conversation" on (U18).
/// - `<game>_text-200_<size>` and `<game>_text-200-320_phone`: each game's
///   first question, before answering.
/// - `choose-correction_text-200-checked-wrong_<size>`,
///   `choose-correction_text-200-checked-wrong-320_phone` and
///   `choose-correction_text-200-checked-wrong-full_phone`: a wrong answer
///   after the toast has gone, scrolled to the explanation card.
/// - `spot-error_text-200-fixing_<size>`: "It needs fixing" chosen, the
///   field in the card with focus.
/// - `summary_text-200_<size>` and `summary_text-200-320_phone`: the
///   end-of-session summary for four Choose a correction questions, two
///   wrong.
///
/// `<size>` is phone (390×844), landscape (844×390) or laptop (1280×800);
/// 320 is 320×640 and full is 390×2000.
@Tags(['golden'])
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/data/question_loader.dart';
import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/models/question_parser.dart';
import 'package:spanish_companion_games/screens/choose_correction_screen.dart';
import 'package:spanish_companion_games/screens/fill_gap_screen.dart';
import 'package:spanish_companion_games/screens/home_screen.dart';
import 'package:spanish_companion_games/screens/match_screen.dart';
import 'package:spanish_companion_games/screens/order_screen.dart';
import 'package:spanish_companion_games/screens/repair_screen.dart';
import 'package:spanish_companion_games/screens/session_summary_view.dart';
import 'package:spanish_companion_games/screens/spot_error_screen.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';
import 'package:spanish_companion_games/widgets/widgets.dart';

import 'golden_helpers.dart';

/// A screenshot size: the file-name suffix after the state, and the window.
typedef _Shot = ({String suffix, String size, Size window});

const List<_Shot> _shots = [
  (suffix: '', size: 'phone', window: Size(390, 844)),
  (suffix: '', size: 'landscape', window: Size(844, 390)),
  (suffix: '', size: 'laptop', window: Size(1280, 800)),
  (suffix: '-320', size: 'phone', window: Size(320, 640)),
];

const _Shot _full = (suffix: '-full', size: 'phone', window: Size(390, 2000));

const Map<GameType, String> _names = {
  GameType.chooseCorrection: 'choose-correction',
  GameType.repair: 'repair',
  GameType.fillGap: 'fill-gap',
  GameType.match: 'match',
  GameType.order: 'order',
  GameType.spotError: 'spot-error',
};

Widget _game(GameType game, List<Question> questions) => switch (game) {
  GameType.chooseCorrection => ChooseCorrectionScreen(questions: questions),
  GameType.repair => RepairScreen(questions: questions),
  GameType.fillGap => FillGapScreen(questions: questions),
  // Seeded (U18), so these screenshots stop changing on every run.
  GameType.match => MatchScreen(questions: questions, random: Random(3)),
  GameType.order => OrderScreen(questions: questions, random: Random(3)),
  GameType.spotError => SpotErrorScreen(questions: questions),
};

String _file(String screen, String state, _Shot shot) =>
    '${screen}_$state${shot.suffix}_${shot.size}.png';

void main() {
  late ParsedQuestions sample;

  setUpAll(() async {
    await setUpGoldens();
    await rootBundle.loadString(sampleQuestionsAsset);
    sample = await loadQuestionsFromAsset();
  });

  void setUp200(WidgetTester tester, _Shot shot) {
    tester.view.physicalSize = shot.window;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> shoot(WidgetTester tester, String name) =>
      expectLater(find.byType(_App), matchesGoldenFile(name));

  for (final shot in [..._shots, _full]) {
    testWidgets('home, 200%, ${shot.size}${shot.suffix}', (tester) async {
      setUp200(tester, shot);
      await tester.pumpWidget(
        _App(child: HomeScreen(source: () async => sample)),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      await shoot(tester, _file('home', 'text-200', shot));
    });
  }

  // U18: the set picker at 200%, "Recall" with "By conversation" on.
  for (final shot in [..._shots, _full]) {
    testWidgets('set picker, 200%, ${shot.size}${shot.suffix}', (tester) async {
      setUp200(tester, shot);
      await tester.pumpWidget(
        _App(child: HomeScreen(source: () async => sample)),
      );
      await settle(tester);
      final recall = find.byKey(const ValueKey('phase-card-2'));
      await tester.ensureVisible(recall);
      await settle(tester);
      await tester.tap(recall);
      await settle(tester);
      final toggle = find.byKey(const ValueKey('set-by-conversation'));
      await tester.ensureVisible(toggle);
      await settle(tester);
      await tester.tap(toggle);
      await settle(tester);
      await tester.drag(find.byType(Scrollable).last, const Offset(0, 3000));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await shoot(tester, _file('set-picker', 'text-200', shot));
    });
  }

  for (final game in GameType.values) {
    for (final shot in _shots) {
      testWidgets('${game.label}, 200%, ${shot.size}${shot.suffix}', (
        tester,
      ) async {
        setUp200(tester, shot);
        await tester.pumpWidget(_App(child: _game(game, sample.questions)));
        await settle(tester);
        expect(tester.takeException(), isNull);
        await shoot(tester, _file(_names[game]!, 'text-200', shot));
      });
    }
  }

  for (final shot in [..._shots, _full]) {
    testWidgets('Choose a correction checked wrong, 200%, '
        '${shot.size}${shot.suffix}', (tester) async {
      setUp200(tester, shot);
      await tester.pumpWidget(
        _App(child: ChooseCorrectionScreen(questions: sample.questions)),
      );
      await settle(tester);
      final option = find.widgetWithText(AnswerOption, 'a');
      await tester.ensureVisible(option);
      await settle(tester);
      await tester.tap(option);
      await settle(tester);
      await tester.tap(find.text('Check'));
      await tester.pump();
      // Let the toast come up and go again (phones), then bring the
      // explanation card into view (phones; on laptop it is the side panel).
      await tester.pump(const Duration(seconds: 3));
      await settle(tester);
      final card = find.byType(ExplanationCard);
      if (card.evaluate().isNotEmpty) {
        await tester.ensureVisible(card);
        await settle(tester);
      }
      expect(tester.takeException(), isNull);
      await shoot(
        tester,
        _file('choose-correction', 'text-200-checked-wrong', shot),
      );
    });
  }

  for (final shot in _shots) {
    testWidgets('summary, 200%, ${shot.size}${shot.suffix}', (tester) async {
      setUp200(tester, shot);
      final questions = sample.questions
          .where((q) => q.game == GameType.chooseCorrection)
          .take(4)
          .toList();
      await tester.pumpWidget(
        _App(
          child: SessionSummaryView(
            game: GameType.chooseCorrection,
            questions: questions,
            results: [for (var i = 0; i < questions.length; i++) i.isOdd],
            onPlayAgain: () {},
            onBack: () {},
          ),
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      await shoot(tester, _file('summary', 'text-200', shot));
    });
  }

  for (final shot in _shots.take(3)) {
    testWidgets('Spot the error fixing, 200%, ${shot.size}', (tester) async {
      setUp200(tester, shot);
      await tester.pumpWidget(
        _App(child: SpotErrorScreen(questions: sample.questions)),
      );
      await settle(tester);
      final cross = find.byTooltip('It needs fixing');
      await tester.ensureVisible(cross);
      await settle(tester);
      await tester.tap(cross);
      await settle(tester);
      expect(tester.takeException(), isNull);
      await shoot(tester, _file('spot-error', 'text-200-fixing', shot));
    });
  }
}

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
