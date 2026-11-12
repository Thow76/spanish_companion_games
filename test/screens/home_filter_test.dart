/// The question filter (B12). Since U18 it lives on the set picker only;
/// home counts every question.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/models/question_parser.dart';
import 'package:spanish_companion_games/screens/fill_gap_screen.dart';
import 'package:spanish_companion_games/screens/home_screen.dart';
import 'package:spanish_companion_games/screens/set_picker_screen.dart';

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

/// The number shown on a home choice's phone card (B23): 1 = New
/// corrections, 2 = Recall.
Finder _countOn(int phase, String text) => find.descendant(
  of: find.byKey(ValueKey('phase-card-$phase')),
  matching: find.text(text),
);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _openPicker(WidgetTester tester, int phase) =>
    _tapVisible(tester, find.byKey(ValueKey('phase-card-$phase')));

Future<void> _openFilter(WidgetTester tester) =>
    _tapVisible(tester, find.textContaining('Filter: '));

Finder _chip(String row, String label) =>
    find.byKey(ValueKey('filter-$row-$label'));

void main() {
  testWidgets('home counts every question and has no filter', (tester) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Filter: '), findsNothing);
    expect(_countOn(1, '1'), findsOneWidget);
    expect(_countOn(2, '3'), findsOneWidget);
  });

  testWidgets('choosing a type on the picker narrows its sets', (tester) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();

    await _openPicker(tester, 2);
    expect(find.byType(SetPickerScreen), findsOneWidget);
    expect(find.text('Filter: All questions'), findsOneWidget);
    await _openFilter(tester);
    // No Phase row on the picker.
    expect(_chip('Phase', 'Recall'), findsNothing);
    await _tapVisible(tester, _chip('Type', 'Language notes'));

    expect(find.text('Filter: Language notes'), findsOneWidget);
    expect(find.text('1 of 3 questions'), findsOneWidget);
    expect(find.text('1 set'), findsOneWidget);

    // "All" puts it back.
    await _tapVisible(tester, _chip('Type', 'All'));
    expect(find.text('Filter: All questions'), findsOneWidget);
  });

  testWidgets('a set opens with only the questions that pass', (tester) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();

    await _openPicker(tester, 2);
    await _openFilter(tester);
    await _tapVisible(tester, _chip('Category', 'Prepositions'));
    expect(find.text('Filter: Prepositions'), findsOneWidget);
    expect(find.text('1 set'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const ValueKey('set-card-0')));
    final screen = tester.widget<FillGapScreen>(find.byType(FillGapScreen));
    expect([for (final q in screen.questions) q.id], ['a']);
  });

  testWidgets('a filter on the picker leaves home counts alone', (
    tester,
  ) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();

    await _openPicker(tester, 2);
    await _openFilter(tester);
    await _tapVisible(tester, _chip('Type', 'Language notes'));

    await _tapVisible(tester, find.byTooltip(SetPickerScreen.backLabel));
    expect(find.textContaining('Filter: '), findsNothing);
    expect(_countOn(1, '1'), findsOneWidget);
    expect(_countOn(2, '3'), findsOneWidget);

    // The picker still has it when opened again.
    await _openPicker(tester, 2);
    expect(find.text('Filter: Language notes'), findsOneWidget);
  });

  testWidgets('the filter is kept when the questions are reloaded', (
    tester,
  ) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();

    await _openPicker(tester, 2);
    await _openFilter(tester);
    await _tapVisible(tester, _chip('Type', 'Grammar errors'));
    await _tapVisible(tester, find.byTooltip(SetPickerScreen.backLabel));

    await tester.tap(find.byTooltip('Reload questions'));
    await tester.pumpAndSettle();
    await _openPicker(tester, 2);
    expect(find.text('Filter: Grammar errors'), findsOneWidget);
  });
}
