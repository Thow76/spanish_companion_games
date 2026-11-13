/// Behaviour of the set player (B25): the rounds a set is played in, one
/// game screen per round handing back after its last question, one
/// end-of-set summary, "Play again" and "Next set".
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/models/question_sets.dart';
import 'package:spanish_companion_games/models/round_result.dart';
import 'package:spanish_companion_games/models/session_tally.dart';
import 'package:spanish_companion_games/screens/choose_correction_screen.dart';
import 'package:spanish_companion_games/screens/fill_gap_screen.dart';
import 'package:spanish_companion_games/screens/repair_screen.dart';
import 'package:spanish_companion_games/screens/session_summary_view.dart';
import 'package:spanish_companion_games/screens/set_player_screen.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';

Question _choose(String id) => Question(
  id: id,
  game: GameType.chooseCorrection,
  category: 'Prepositions',
  type: QuestionType.grammar,
  prompt: 'Estoy pensando **de** cambiar de trabajo.',
  answers: const ['en'],
  options: const ['en', 'a', 'por'],
  explanation: 'pensar en + infinitive = to be thinking of doing something',
);

Question _repair(String id) => Question(
  id: id,
  game: GameType.repair,
  category: 'Calque',
  type: QuestionType.note,
  prompt: 'Esto no **hace sentido** para mí.',
  answers: const ['Esto no tiene sentido para mí.'],
  explanation: 'tener sentido = to make sense',
);

Question _gap(String id) => Question(
  id: id,
  game: GameType.fillGap,
  category: 'Prepositions',
  type: QuestionType.grammar,
  prompt: 'Depende ___ tiempo.',
  answers: const ['del'],
  options: const ['del', 'de', 'en'],
  explanation: 'depender de + el = del',
);

Question _order(String id) => Question(
  id: id,
  game: GameType.order,
  category: 'Word order',
  type: QuestionType.grammar,
  prompt: 'No lo sé.',
  answers: const ['No lo sé.'],
);

QuestionSet _set(List<Question> questions) =>
    QuestionSet(questions: questions, conversations: const ['Work']);

Widget _app(Widget home) => MaterialApp(
  theme: appTheme(FormFactor.phone),
  builder: (context, child) => Theme(
    data: appTheme(FormFactor.of(context)),
    child: child ?? const SizedBox.shrink(),
  ),
  home: home,
);

Future<void> _letToastGo(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Picks [option] in Choose a correction or Fill the gap and checks.
Future<void> _pickAndCheck(WidgetTester tester, String option) async {
  await _tap(tester, find.text(option).last);
  await _tap(tester, find.text('Check'));
  await _letToastGo(tester);
}

Future<void> _repairAndCheck(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await _tap(tester, find.text('Check'));
  await _letToastGo(tester);
}

void main() {
  group('roundsFor', () {
    List<List<String>> ids(List<List<Question>> rounds) => [
      for (final r in rounds) [for (final q in r) q.id],
    ];

    test('New corrections: Choose a correction first, then Repair', () {
      final rounds = SetPlayerScreen.roundsFor(QuestionPhase.noticeAndCorrect, [
        _repair('r1'),
        _choose('c1'),
        _repair('r2'),
        _choose('c2'),
      ]);
      expect(ids(rounds), [
        ['c1', 'c2'],
        ['r1', 'r2'],
      ]);
    });

    test('Recall: set order, runs of one game share a round', () {
      final rounds = SetPlayerScreen.roundsFor(QuestionPhase.recall, [
        _gap('g1'),
        _gap('g2'),
        _order('o1'),
        _gap('g3'),
      ]);
      expect(ids(rounds), [
        ['g1', 'g2'],
        ['o1'],
        ['g3'],
      ]);
    });

    test('an empty set has no rounds', () {
      expect(
        SetPlayerScreen.roundsFor(QuestionPhase.recall, const []),
        isEmpty,
      );
    });
  });

  testWidgets('plays each game in turn and ends with one summary', (
    tester,
  ) async {
    final tally = SessionTally();
    await tester.pumpWidget(
      _app(
        SetPlayerScreen(
          phase: QuestionPhase.noticeAndCorrect,
          sets: [
            _set([_repair('r1'), _choose('c1')]),
          ],
          session: tally,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Choose a correction comes first, even though Repair is first in the
    // set; its only question ends with "Next question", not "See results".
    expect(find.byType(ChooseCorrectionScreen), findsOneWidget);
    await _pickAndCheck(tester, 'a');
    expect(find.text('See results'), findsNothing);
    await _tap(tester, find.text('Next question'));

    // Then Repair, the set's last round: "See results".
    expect(find.byType(RepairScreen), findsOneWidget);
    expect(find.byType(ChooseCorrectionScreen), findsNothing);
    await _repairAndCheck(tester, 'Esto no tiene sentido para mí.');
    await _tap(tester, find.text('See results'));

    final summary = tester.widget<SessionSummaryView>(
      find.byType(SessionSummaryView),
    );
    expect([for (final q in summary.questions) q.id], ['c1', 'r1']);
    expect(summary.results, [false, true]);
    expect(summary.topBarTitle, 'New corrections');
    expect(find.text('New corrections'), findsWidgets);
    expect(find.text(SessionSummaryView.scoreText(1, 2)), findsOneWidget);
    // One set only: no "Next set"; "Play again" is the main button.
    expect(find.text(SessionSummaryView.nextSetLabel), findsNothing);
    expect(find.text(SessionSummaryView.playAgainLabel), findsWidgets);
    // Both checks reached the app session's tally as they happened.
    expect(tally.answered, 2);
  });

  testWidgets('Next set plays the next set; Play again the same one', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        SetPlayerScreen(
          phase: QuestionPhase.recall,
          sets: [
            _set([_gap('g1')]),
            _set([_gap('g2'), _gap('g3')]),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _pickAndCheck(tester, 'del');
    await _tap(tester, find.text('See results'));
    expect(find.text(SessionSummaryView.nextSetLabel), findsWidgets);
    expect(find.byKey(const ValueKey('summary-play-again')), findsOneWidget);

    // Play again: the same set from its first question.
    await _tap(tester, find.byKey(const ValueKey('summary-play-again')));
    var screen = tester.widget<FillGapScreen>(find.byType(FillGapScreen));
    expect([for (final q in screen.questions) q.id], ['g1']);
    await _pickAndCheck(tester, 'del');
    await _tap(tester, find.text('See results'));

    // Next set: the second set's two questions.
    await _tap(tester, find.text(SessionSummaryView.nextSetLabel).last);
    screen = tester.widget<FillGapScreen>(find.byType(FillGapScreen));
    expect([for (final q in screen.questions) q.id], ['g2', 'g3']);
    expect(find.text('Question 1 of 2'), findsOneWidget);
    await _pickAndCheck(tester, 'del');
    await _tap(tester, find.text('Next question'));
    await _pickAndCheck(tester, 'de');
    await _tap(tester, find.text('See results'));

    final summary = tester.widget<SessionSummaryView>(
      find.byType(SessionSummaryView),
    );
    expect([for (final q in summary.questions) q.id], ['g2', 'g3']);
    expect(summary.results, [true, false]);
    // The last set: no "Next set".
    expect(find.text(SessionSummaryView.nextSetLabel), findsNothing);
    expect(find.byKey(const ValueKey('summary-play-again')), findsNothing);
  });

  testWidgets('a game screen hands its round back after its last question', (
    tester,
  ) async {
    RoundResult? handed;
    await tester.pumpWidget(
      _app(
        RepairScreen(
          questions: [_repair('r1')],
          onFinished: (r) => handed = r,
          lastInSet: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _repairAndCheck(tester, 'Esto no hace un sentido para mí.');
    // A wrong first try gives the hint and a second try (B22).
    await _repairAndCheck(tester, 'Esto no tiene sentido para mí.');
    await _tap(tester, find.text('Next question'));

    expect(handed, isNotNull);
    expect([for (final q in handed!.questions) q.id], ['r1']);
    // Right only with the hint: not passed, hinted.
    expect(handed!.results, [false]);
    expect(handed!.hinted, [true]);
    expect(find.byType(SessionSummaryView), findsNothing);
  });
}
