/// Screenshots of the end-of-session summary (B7) at the three sizes.
///
/// - `summary_one-wrong_<size>`: a Choose a correction round, 1 of 2 right,
///   with recall questions already played earlier in the session.
/// - `summary_all-right_<size>`: every question right, nothing else played
///   ("Recall: None yet", no list).
/// - `summary_recall-wrong_<size>`: a Fill the gap round with both
///   questions wrong (the gap card form, one typed question).
/// - `summary_long_<size>` (U9): a Choose a correction round of four with
///   three wrong, so the list runs past the screen; on laptop "Play again"
///   is in the side panel and on screen.
/// - `summary_long-320_phone` (U9): the same at 320×640, nothing sideways.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/models/session_tally.dart';
import 'package:spanish_companion_games/screens/session_summary_view.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';

import 'golden_helpers.dart';

const _screen = 'summary';

// Questions from assets/questions.sample.json.
Question _pensando() => Question(
  id: '2026-10-17-001',
  game: GameType.chooseCorrection,
  category: 'Prepositions',
  type: QuestionType.grammar,
  prompt: 'Estoy pensando **de** cambiar de trabajo.',
  answers: const ['en'],
  options: const ['en', 'a', 'por'],
  explanation: 'pensar en + infinitive = to be thinking of doing something',
);

Question _hermana() => Question(
  id: '2026-10-17-002',
  game: GameType.chooseCorrection,
  category: 'Ser/estar',
  type: QuestionType.grammar,
  prompt: 'Mi hermana **es** muy cansada hoy.',
  answers: const ['está'],
  options: const ['está', 'estaba', 'sea'],
  explanation: 'estar cansado = to be tired (a state right now, so estar)',
);

Question _depende() => Question(
  id: '2026-10-17-008',
  game: GameType.fillGap,
  category: 'Prepositions',
  type: QuestionType.grammar,
  prompt: 'Depende ___ tiempo que haga.',
  answers: const ['del'],
  options: const ['del', 'de', 'en', 'al'],
  explanation: 'depender de = to depend on',
);

Question _espero() => Question(
  id: '2026-10-17-009',
  game: GameType.fillGap,
  category: 'Verb forms',
  type: QuestionType.grammar,
  prompt: 'Espero que ___ buen tiempo mañana.',
  answers: const ['haga'],
  explanation:
      'esperar que + subjunctive = to hope that (no options here, so the '
      'learner types)',
);

// Made up for the long round (not in the sample file).
Question _gente() => Question(
  id: 'u9-long-003',
  game: GameType.chooseCorrection,
  category: 'Agreement',
  type: QuestionType.grammar,
  prompt: 'En mi barrio **la gente están** siempre dispuestos a ayudar.',
  answers: const ['la gente está'],
  options: const ['la gente está', 'las gentes están', 'la gente estamos'],
  explanation: 'la gente + singular verb = people (takes a singular verb)',
);

Question _realizar() => Question(
  id: 'u9-long-004',
  type: QuestionType.note,
  game: GameType.chooseCorrection,
  category: 'False friend',
  prompt: 'No **realicé** que la reunión era a las nueve.',
  answers: const ['me di cuenta de'],
  options: const ['me di cuenta de', 'realizaba', 'noté de'],
  explanation: 'darse cuenta de = to realise (realizar = to carry out)',
);

List<Question> _longRound() => [_pensando(), _hermana(), _gente(), _realizar()];

const List<bool?> _longResults = [true, false, false, false];

void main() {
  setUpAll(setUpGoldens);

  Future<void> shoot(
    WidgetTester tester,
    ScreenSize size,
    String state, {
    required GameType game,
    required List<Question> questions,
    required List<bool?> results,
    SessionTally? session,
  }) async {
    setScreenSize(tester, size);
    await tester.pumpWidget(
      _App(
        child: SessionSummaryView(
          game: game,
          questions: questions,
          results: results,
          session: session,
          onPlayAgain: () {},
          onBack: () {},
        ),
      ),
    );
    await settle(tester);
    await expectLater(
      find.byType(_App),
      matchesGoldenFile(goldenName(_screen, state, size)),
    );
  }

  for (final size in ScreenSize.values) {
    testWidgets('summary one wrong, ${size.name}', (tester) async {
      final session = SessionTally()
        ..record(_depende(), true)
        ..record(_espero(), false)
        ..record(_pensando(), true)
        ..record(_hermana(), false);
      await shoot(
        tester,
        size,
        'one-wrong',
        game: GameType.chooseCorrection,
        questions: [_pensando(), _hermana()],
        results: [true, false],
        session: session,
      );
    });

    testWidgets('summary all right, ${size.name}', (tester) async {
      await shoot(
        tester,
        size,
        'all-right',
        game: GameType.chooseCorrection,
        questions: [_pensando(), _hermana()],
        results: [true, true],
      );
    });

    testWidgets('summary recall wrong, ${size.name}', (tester) async {
      await shoot(
        tester,
        size,
        'recall-wrong',
        game: GameType.fillGap,
        questions: [_depende(), _espero()],
        results: [false, false],
      );
    });

    testWidgets('summary long, ${size.name}', (tester) async {
      await shoot(
        tester,
        size,
        'long',
        game: GameType.chooseCorrection,
        questions: _longRound(),
        results: _longResults,
      );
      if (size == ScreenSize.laptop) {
        // "Play again" sits in the side panel, inside the window.
        final button = tester.getRect(
          find.widgetWithText(FilledButton, 'Play again'),
        );
        expect(button.bottom, lessThanOrEqualTo(size.size.height));
      }
    });
  }

  testWidgets('summary long, 320 wide', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _App(
        child: SessionSummaryView(
          game: GameType.chooseCorrection,
          questions: _longRound(),
          results: _longResults,
          onPlayAgain: () {},
          onBack: () {},
        ),
      ),
    );
    await settle(tester);
    await expectLater(
      find.byType(_App),
      matchesGoldenFile('summary_long-320_phone.png'),
    );
  });
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
