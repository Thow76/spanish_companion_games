/// Screenshots of the end-of-set summary (B25) at the three sizes.
///
/// - `set-summary_next-set_<size>`: a New corrections set of three (two
///   Choose a correction, one Repair right only with the hint), with a next
///   set: "Next set" is the main action and "Play again" a secondary
///   button; the top bar reads "New corrections".
/// - `set-summary_last-set_<size>`: a Recall set mixing Fill the gap and
///   Sentence ordering, the last set: "Play again" as before, no "Next
///   set".
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/screens/session_summary_view.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';

import 'golden_helpers.dart';

const _screen = 'set-summary';

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

Question _sentido() => Question(
  id: 'b25-003',
  game: GameType.repair,
  category: 'Calque',
  type: QuestionType.note,
  prompt: 'Esto no **hace sentido** para mí.',
  answers: const ['Esto no tiene sentido para mí.'],
  explanation: 'tener sentido = to make sense',
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

Question _nolose() => Question(
  id: 'b25-005',
  game: GameType.order,
  category: 'Word order',
  type: QuestionType.grammar,
  prompt: 'No lo he visto todavía.',
  answers: const ['No lo he visto todavía.'],
  explanation: 'no + pronoun + haber + participle = not yet done',
);

void main() {
  setUpAll(setUpGoldens);

  for (final size in ScreenSize.values) {
    testWidgets('set summary with a next set, ${size.name}', (tester) async {
      setScreenSize(tester, size);
      await tester.pumpWidget(
        _App(
          child: SessionSummaryView(
            game: GameType.chooseCorrection,
            topBarTitle: QuestionPhase.noticeAndCorrect.label,
            questions: [_pensando(), _hermana(), _sentido()],
            results: const [true, false, false],
            hinted: const [false, false, true],
            onPlayAgain: () {},
            onBack: () {},
            onNextSet: () {},
          ),
        ),
      );
      await settle(tester);
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName(_screen, 'next-set', size)),
      );
    });

    testWidgets('set summary, last set, ${size.name}', (tester) async {
      setScreenSize(tester, size);
      await tester.pumpWidget(
        _App(
          child: SessionSummaryView(
            game: GameType.fillGap,
            topBarTitle: QuestionPhase.recall.label,
            questions: [_depende(), _nolose()],
            results: const [true, false],
            onPlayAgain: () {},
            onBack: () {},
          ),
        ),
      );
      await settle(tester);
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName(_screen, 'last-set', size)),
      );
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
