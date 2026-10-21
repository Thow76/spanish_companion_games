import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/models/question_parser.dart';
import 'package:spanish_companion_games/screens/home_screen.dart';

Question _q(String id, GameType game) => Question(
      id: id,
      game: game,
      category: 'test',
      type: QuestionType.grammar,
      prompt: game == GameType.fillGap ? 'Hola ___.' : 'Hola.',
      answers: const ['x'],
    );

ParsedQuestions _sample() => ParsedQuestions(
      questions: [
        _q('a', GameType.fillGap),
        _q('b', GameType.fillGap),
        _q('c', GameType.order),
        _q('d', GameType.repair),
      ],
      problems: const [
        QuestionProblem(index: 4, id: 'e', message: '"answers" is missing'),
      ],
    );

Widget _app(QuestionSource source) =>
    MaterialApp(home: HomeScreen(source: source));

void main() {
  testWidgets('shows six game buttons with counts', (tester) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();

    expect(find.text('4 questions loaded from the sample file'), findsOneWidget);
    for (final game in GameType.values) {
      expect(find.text(game.label), findsOneWidget);
    }
    expect(find.text('2 questions'), findsOneWidget); // fill the gap
    expect(find.text('1 question'), findsNWidgets(2)); // order, repair
    // choose_correction, match, spot_error
    expect(find.text('No questions yet'), findsNWidgets(3));
    expect(
      find.text('1 question was skipped because of a format problem'),
      findsOneWidget,
    );
  });

  testWidgets('games are grouped by phase, phase 1 first', (tester) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();

    expect(find.text('New corrections'), findsOneWidget);
    expect(find.text('Recall'), findsOneWidget);

    double top(String text) => tester.getTopLeft(find.text(text)).dy;

    // Heading, its games, next heading, its games: top to bottom.
    final newCorrections = top('New corrections');
    final recall = top('Recall');
    expect(newCorrections, lessThan(recall));
    for (final game in GameType.forPhase(QuestionPhase.noticeAndCorrect)) {
      expect(top(game.label), greaterThan(newCorrections));
      expect(top(game.label), lessThan(recall));
    }
    for (final game in GameType.forPhase(QuestionPhase.recall)) {
      expect(top(game.label), greaterThan(recall));
    }
  });

  testWidgets('a game with no questions is disabled', (tester) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();

    final matchButton = find.ancestor(
      of: find.text(GameType.match.label),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(matchButton).onPressed, isNull);
  });

  testWidgets('tapping a game opens its screen', (tester) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(GameType.fillGap.label));
    await tester.tap(find.text(GameType.fillGap.label));
    await tester.pumpAndSettle();

    expect(find.text('2 questions ready'), findsOneWidget);
    await tester.tap(find.text('Back to games'));
    await tester.pumpAndSettle();
    expect(find.text('Reload questions'), findsOneWidget);
  });

  testWidgets('reload calls the source again', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _app(() async {
        calls++;
        return _sample();
      }),
    );
    await tester.pumpAndSettle();
    expect(calls, 1);

    // The top-bar icon: with six games in two groups the bottom "Reload
    // questions" button sits below the test window, so a tap on it misses.
    await tester.tap(find.byTooltip('Reload questions'));
    await tester.pumpAndSettle();
    expect(calls, 2);

    // The bottom button still works once scrolled into view.
    await tester.ensureVisible(find.text('Reload questions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reload questions'));
    await tester.pumpAndSettle();
    expect(calls, 3);
  });

  testWidgets('a broken file shows an error and a reload button',
      (tester) async {
    await tester.pumpWidget(
      _app(() async => throw const QuestionFileException('File is not valid JSON')),
    );
    await tester.pumpAndSettle();

    expect(find.text('File is not valid JSON'), findsOneWidget);
    expect(find.text('Reload questions'), findsOneWidget);
  });
}
