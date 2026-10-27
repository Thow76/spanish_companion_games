import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/models/question_parser.dart';
import 'package:spanish_companion_games/screens/fill_gap_screen.dart';
import 'package:spanish_companion_games/screens/home_screen.dart';
import 'package:spanish_companion_games/screens/match_screen.dart';
import 'package:spanish_companion_games/screens/order_screen.dart';
import 'package:spanish_companion_games/screens/repair_screen.dart';
import 'package:spanish_companion_games/screens/spot_error_screen.dart';
import 'package:spanish_companion_games/widgets/game_card.dart';

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

    expect(find.text('4 questions · sample file'), findsOneWidget);
    for (final game in GameType.values) {
      expect(find.text(game.label), findsOneWidget);
    }
    // Phone cards show the number over "question(s)".
    Finder countOn(GameType game, String text) => find.descendant(
          of: find.byKey(ValueKey('game-card-${game.jsonValue}')),
          matching: find.text(text),
        );
    expect(countOn(GameType.fillGap, '2'), findsOneWidget);
    expect(countOn(GameType.order, '1'), findsOneWidget);
    expect(countOn(GameType.repair, '1'), findsOneWidget);
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

    final matchCard = find.byKey(const ValueKey('game-card-match'));
    expect(tester.widget<GameCard>(matchCard).onTap, isNull);
    final ink = find.descendant(of: matchCard, matching: find.byType(InkWell));
    expect(tester.widget<InkWell>(ink).onTap, isNull);
  });

  testWidgets('Sentence ordering opens its game screen', (tester) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(GameType.order.label));
    // ensureVisible only moves the scroll position; pump so the tap
    // uses the new layout, not the old (off-screen) one.
    await tester.pumpAndSettle();
    await tester.tap(find.text(GameType.order.label));
    await tester.pumpAndSettle();
    expect(find.byType(OrderScreen), findsOneWidget);
  });

  testWidgets('Matching opens its game screen', (tester) async {
    final withMatch = ParsedQuestions(
      questions: [
        ..._sample().questions,
        Question(
          id: 'm',
          game: GameType.match,
          category: 'test',
          type: QuestionType.grammar,
          prompt: 'Match the verb to its preposition',
          pairs: const [MatchPair('pensar', 'en'), MatchPair('depender', 'de')],
        ),
      ],
      problems: const [],
    );
    await tester.pumpWidget(_app(() async => withMatch));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(GameType.match.label));
    // ensureVisible only moves the scroll position; pump so the tap
    // uses the new layout, not the old (off-screen) one.
    await tester.pumpAndSettle();
    await tester.tap(find.text(GameType.match.label));
    await tester.pumpAndSettle();
    expect(find.byType(MatchScreen), findsOneWidget);
  });

  testWidgets('Fill the gap opens its game screen', (tester) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(GameType.fillGap.label));
    // ensureVisible only moves the scroll position; pump so the tap
    // uses the new layout, not the old (off-screen) one.
    await tester.pumpAndSettle();
    await tester.tap(find.text(GameType.fillGap.label));
    await tester.pumpAndSettle();
    expect(find.byType(FillGapScreen), findsOneWidget);
  });

  testWidgets('Repair opens its game screen', (tester) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(GameType.repair.label));
    // ensureVisible only moves the scroll position; pump so the tap
    // uses the new layout, not the old (off-screen) one.
    await tester.pumpAndSettle();
    await tester.tap(find.text(GameType.repair.label));
    await tester.pumpAndSettle();
    expect(find.byType(RepairScreen), findsOneWidget);
  });

  testWidgets('Spot the error opens its game screen', (tester) async {
    final withSpotError = ParsedQuestions(
      questions: [
        ..._sample().questions,
        Question(
          id: 's',
          game: GameType.spotError,
          category: 'test',
          type: QuestionType.grammar,
          prompt: 'Depende del tiempo.',
          answers: const ['Depende del tiempo.'],
        ),
      ],
      problems: const [],
    );
    await tester.pumpWidget(_app(() async => withSpotError));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(GameType.spotError.label));
    // ensureVisible only moves the scroll position; pump so the tap
    // uses the new layout, not the old (off-screen) one.
    await tester.pumpAndSettle();
    await tester.tap(find.text(GameType.spotError.label));
    await tester.pumpAndSettle();
    expect(find.byType(SpotErrorScreen), findsOneWidget);
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

    // Reload is the top-bar icon button (UI spec section 6, U4).
    await tester.tap(find.byTooltip('Reload questions'));
    await tester.pumpAndSettle();
    expect(calls, 2);
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
