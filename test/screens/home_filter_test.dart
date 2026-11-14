/// The home screen filter (B12).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/models/question_parser.dart';
import 'package:spanish_companion_games/screens/fill_gap_screen.dart';
import 'package:spanish_companion_games/screens/home_screen.dart';
import 'package:spanish_companion_games/widgets/phase_heading.dart';

Question _q(String id, GameType game, QuestionType type, String category) =>
    Question(
      id: id,
      game: game,
      category: category,
      type: type,
      prompt: game == GameType.fillGap ? 'Hola ___.' : 'Hola.',
      answers: const ['x'],
    );

ParsedQuestions _sample() => ParsedQuestions(
  questions: [
    _q('a', GameType.fillGap, QuestionType.grammar, 'Prepositions'),
    _q('b', GameType.fillGap, QuestionType.note, 'Calque'),
    _q('c', GameType.order, QuestionType.grammar, 'Word order'),
    _q('d', GameType.repair, QuestionType.grammar, 'Prepositions'),
  ],
  problems: const [],
);

Widget _app(QuestionSource source) =>
    MaterialApp(home: HomeScreen(source: source));

/// The number shown on a game's phone card.
Finder _countOn(GameType game, String text) => find.descendant(
  of: find.byKey(ValueKey('game-card-${game.jsonValue}')),
  matching: find.text(text),
);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openFilter(WidgetTester tester) =>
    _tapVisible(tester, find.textContaining('Filter: '));

Finder _chip(String row, String label) =>
    find.byKey(ValueKey('filter-$row-$label'));

void main() {
  testWidgets('starts with every question', (tester) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();

    expect(find.text('Filter: All questions'), findsOneWidget);
    expect(_countOn(GameType.fillGap, '2'), findsOneWidget);
    expect(find.byType(PhaseHeading), findsNWidgets(2));
  });

  testWidgets('choosing a type narrows the counts', (tester) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();

    await _openFilter(tester);
    await _tapVisible(tester, _chip('Type', 'Language notes'));

    expect(find.text('Filter: Language notes'), findsOneWidget);
    expect(find.text('1 of 4 questions'), findsOneWidget);
    expect(_countOn(GameType.fillGap, '1'), findsOneWidget);
    // Repair and Sentence ordering have only grammar questions here.
    final repair = find.byKey(const ValueKey('game-card-repair'));
    expect(
      find.descendant(of: repair, matching: find.text('No questions yet')),
      findsOneWidget,
    );

    // "All" puts it back.
    await _tapVisible(tester, _chip('Type', 'All'));
    expect(find.text('Filter: All questions'), findsOneWidget);
    expect(_countOn(GameType.fillGap, '2'), findsOneWidget);
  });

  testWidgets('choosing a phase shows only that group', (tester) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();

    await _openFilter(tester);
    await _tapVisible(tester, _chip('Phase', 'Recall'));

    expect(find.byType(PhaseHeading), findsOneWidget);
    expect(find.byKey(const ValueKey('game-card-repair')), findsNothing);
    expect(find.byKey(const ValueKey('game-card-fill_gap')), findsOneWidget);
  });

  testWidgets('a game opens with only the questions that pass', (tester) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();

    await _openFilter(tester);
    await _tapVisible(tester, _chip('Category', 'Prepositions'));
    expect(find.text('Filter: Prepositions'), findsOneWidget);

    await _tapVisible(tester, find.text(GameType.fillGap.label));
    final screen = tester.widget<FillGapScreen>(find.byType(FillGapScreen));
    expect([for (final q in screen.questions) q.id], ['a']);
  });

  testWidgets('the filter is kept when the questions are reloaded', (
    tester,
  ) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();

    await _openFilter(tester);
    await _tapVisible(tester, _chip('Type', 'Grammar errors'));
    expect(find.text('Filter: Grammar errors'), findsOneWidget);

    await tester.tap(find.byTooltip('Reload questions'));
    await tester.pumpAndSettle();
    expect(find.text('Filter: Grammar errors'), findsOneWidget);
  });

  testWidgets('nothing matching says so', (tester) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();

    await _openFilter(tester);
    await _tapVisible(tester, _chip('Type', 'Language notes'));
    await _tapVisible(tester, _chip('Category', 'Word order'));

    expect(find.text('0 of 4 questions'), findsOneWidget);
    expect(
      find.textContaining('No questions match this filter.'),
      findsOneWidget,
    );
  });
}
