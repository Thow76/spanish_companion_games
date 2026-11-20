/// Questions per round and Finish (B32): a card plays the first 5 or 10 of
/// its open questions, oldest first, its count stays the total; the choice
/// is kept across a reload; Finish on the summary goes home and reloads.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/models/question_parser.dart';
import 'package:spanish_companion_games/screens/fill_gap_screen.dart';
import 'package:spanish_companion_games/screens/home_screen.dart';
import 'package:spanish_companion_games/screens/session_summary_view.dart';
import 'package:spanish_companion_games/widgets/widgets.dart';

/// Fill the gap with options, newest first in the file (day 12 down to 1),
/// so oldest first is the reverse of file order.
List<Question> _gaps(int n) => [
  for (var day = n; day >= 1; day--)
    Question(
      id: 'gap-$day',
      game: GameType.fillGap,
      category: 'Prepositions',
      type: QuestionType.grammar,
      prompt: 'Frase $day: depende ___ tiempo.',
      answers: const ['del'],
      options: const ['del', 'de', 'en'],
      source: 'Chat, 2026-10-${day.toString().padLeft(2, '0')}',
    ),
];

ParsedQuestions _parsed(List<Question> qs) =>
    ParsedQuestions(questions: qs, problems: const []);

Widget _app(QuestionSource source) =>
    MaterialApp(home: HomeScreen(source: source));

Finder _countOn(GameType g, String text) => find.descendant(
  of: find.byKey(ValueKey('game-card-${g.jsonValue}')),
  matching: find.text(text),
);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator)).pop();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a card plays the first 5, oldest first; its count stays the '
      'total', (tester) async {
    await tester.pumpWidget(_app(() async => _parsed(_gaps(12))));
    await tester.pumpAndSettle();

    expect(_countOn(GameType.fillGap, '12'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-round-size')), findsOneWidget);

    await _tapVisible(tester, find.text(GameType.fillGap.label));
    final screen = tester.widget<FillGapScreen>(find.byType(FillGapScreen));
    expect(
      [for (final q in screen.questions) q.id],
      ['gap-1', 'gap-2', 'gap-3', 'gap-4', 'gap-5'],
    );
    expect(find.text(Count.text(1, 5)), findsOneWidget);
  });

  testWidgets('choosing 10 plays 10, and the choice survives a reload', (
    tester,
  ) async {
    await tester.pumpWidget(_app(() async => _parsed(_gaps(12))));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byKey(const ValueKey('round-size-10')));
    await _tapVisible(tester, find.text(GameType.fillGap.label));
    expect(
      tester.widget<FillGapScreen>(find.byType(FillGapScreen)).questions,
      hasLength(10),
    );
    await _back(tester);

    await tester.tap(find.byTooltip('Reload questions'));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text(GameType.fillGap.label));
    expect(
      tester.widget<FillGapScreen>(find.byType(FillGapScreen)).questions,
      hasLength(10),
    );
  });

  testWidgets('a card with fewer than 5 plays them all', (tester) async {
    await tester.pumpWidget(_app(() async => _parsed(_gaps(3))));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text(GameType.fillGap.label));
    expect(
      tester.widget<FillGapScreen>(find.byType(FillGapScreen)).questions,
      hasLength(3),
    );
  });

  testWidgets('Finish on the summary goes home and reloads; back does not', (
    tester,
  ) async {
    var loads = 0;
    await tester.pumpWidget(
      _app(() async {
        loads++;
        return _parsed(_gaps(1));
      }),
    );
    await tester.pumpAndSettle();
    expect(loads, 1);

    // Back from the game: no reload.
    await _tapVisible(tester, find.text(GameType.fillGap.label));
    await _back(tester);
    expect(loads, 1);

    // Play the one question, then Finish.
    await _tapVisible(tester, find.text(GameType.fillGap.label));
    await tester.tap(find.widgetWithText(AnswerOption, 'del'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See results'));
    await tester.pumpAndSettle();

    expect(find.text(FinishButton.label), findsOneWidget);
    await tester.tap(find.text(FinishButton.label));
    await tester.pumpAndSettle();

    expect(find.byType(FillGapScreen), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(loads, 2);
  });
}
