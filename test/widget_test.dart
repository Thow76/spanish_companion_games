import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/data/drive_source.dart';
import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/models/question_parser.dart';
import 'package:spanish_companion_games/screens/fill_gap_screen.dart';
import 'package:spanish_companion_games/screens/home_screen.dart';
import 'package:spanish_companion_games/screens/match_screen.dart';
import 'package:spanish_companion_games/screens/order_screen.dart';
import 'package:spanish_companion_games/screens/phase_games_screen.dart';
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

/// Taps the home screen's "New corrections" or "Recall" choice (B23).
Future<void> _openPhase(WidgetTester tester, String title) async {
  await tester.ensureVisible(find.text(title));
  await tester.pumpAndSettle();
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('home shows two choices with their counts', (tester) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();

    expect(find.text('4 questions · sample file'), findsOneWidget);
    // The six game cards are gone from home (B23).
    for (final game in GameType.values) {
      expect(find.text(game.label), findsNothing);
    }
    Finder countOn(int phase, String text) => find.descendant(
          of: find.byKey(ValueKey('phase-card-$phase')),
          matching: find.text(text),
        );
    // Phase 1: one repair; phase 2: two fill the gap and one ordering.
    expect(countOn(1, '1'), findsOneWidget);
    expect(countOn(2, '3'), findsOneWidget);
    expect(find.text('New corrections'), findsOneWidget);
    expect(find.text('Recall'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('New corrections')).dy,
      lessThan(tester.getTopLeft(find.text('Recall')).dy),
    );
    expect(
      find.text('1 question was skipped because of a format problem'),
      findsOneWidget,
    );
  });

  testWidgets('a choice with no questions is disabled', (tester) async {
    await tester.pumpWidget(
      _app(
        () async => ParsedQuestions(
          questions: [_q('a', GameType.fillGap)],
          problems: const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final newCard = find.byKey(const ValueKey('phase-card-1'));
    expect(tester.widget<GameCard>(newCard).onTap, isNull);
    expect(
      find.descendant(of: newCard, matching: find.text('No questions yet')),
      findsOneWidget,
    );
    await tester.tap(newCard);
    await tester.pumpAndSettle();
    expect(find.byType(PhaseGamesScreen), findsNothing);
  });

  testWidgets('Recall lists its four games, with counts', (tester) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();
    await _openPhase(tester, 'Recall');

    final screen =
        tester.widget<PhaseGamesScreen>(find.byType(PhaseGamesScreen));
    expect(screen.phase, QuestionPhase.recall);
    expect([for (final q in screen.questions) q.id], ['a', 'b', 'c']);
    for (final game in GameType.forPhase(QuestionPhase.recall)) {
      expect(find.text(game.label), findsOneWidget);
    }
    expect(find.text(GameType.repair.label), findsNothing);
    Finder countOn(GameType game, String text) => find.descendant(
          of: find.byKey(ValueKey('game-card-${game.jsonValue}')),
          matching: find.text(text),
        );
    expect(countOn(GameType.fillGap, '2'), findsOneWidget);
    expect(countOn(GameType.order, '1'), findsOneWidget);
    // Matching and Spot the error have none.
    expect(find.text('No questions yet'), findsNWidgets(2));
    final matchCard = find.byKey(const ValueKey('game-card-match'));
    expect(tester.widget<GameCard>(matchCard).onTap, isNull);
  });

  testWidgets('back from a phase returns home', (tester) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();
    await _openPhase(tester, 'New corrections');
    expect(find.text(GameType.chooseCorrection.label), findsOneWidget);

    await tester.tap(find.byTooltip(PhaseGamesScreen.backLabel));
    await tester.pumpAndSettle();
    expect(find.byType(PhaseGamesScreen), findsNothing);
    expect(find.byKey(const ValueKey('phase-card-1')), findsOneWidget);
  });

  testWidgets('Sentence ordering opens its game screen', (tester) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();

    await _openPhase(tester, 'Recall');
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

    await _openPhase(tester, 'Recall');
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

    await _openPhase(tester, 'Recall');
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

    await _openPhase(tester, 'New corrections');
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

    await _openPhase(tester, 'Recall');
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

  testWidgets('a Drive failure shows its plain message, and reload retries',
      (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _app(() async {
        calls++;
        if (calls == 1) {
          throw const DriveLoadException(
            DriveProblem.notShared,
            statusCode: 403,
            detail: 'The user does not have sufficient permissions for file.',
          );
        }
        return _sample();
      }),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        const DriveLoadException(DriveProblem.notShared).message(),
      ),
      findsOneWidget,
    );
    expect(
      find.text('The user does not have sufficient permissions for file.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Reload questions'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('4 questions · sample file'), findsOneWidget);
  });

  testWidgets('an unknown error never shows its text (it may hold the key)',
      (tester) async {
    await tester.pumpWidget(
      _app(() async => throw Exception('uri=https://x/?key=secret')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Could not load the questions. Reload to try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('secret'), findsNothing);
  });

  test('describeLoadError', () {
    expect(
      describeLoadError(const QuestionFileException('Bad file')),
      ('Bad file', null),
    );
    final (message, detail) = describeLoadError(
      const DriveLoadException(DriveProblem.noConnection),
    );
    expect(message, startsWith("Couldn't reach Google Drive"));
    expect(detail, isNull);
  });
}
