import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/data/drive_source.dart';
import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/models/question_parser.dart';
import 'package:spanish_companion_games/screens/fill_gap_screen.dart';
import 'package:spanish_companion_games/screens/home_screen.dart';
import 'package:spanish_companion_games/screens/match_screen.dart';
import 'package:spanish_companion_games/screens/order_screen.dart';
import 'package:spanish_companion_games/screens/repair_screen.dart';
import 'package:spanish_companion_games/screens/set_picker_screen.dart';
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

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  // ensureVisible only moves the scroll position; pump so the tap uses the
  // new layout, not the old (off-screen) one.
  await tester.pumpAndSettle();
  await tester.tap(finder);
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
    expect(find.byType(SetPickerScreen), findsNothing);
  });

  testWidgets('Recall opens its set picker with that phase only',
      (tester) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();
    await _openPhase(tester, 'Recall');

    final screen =
        tester.widget<SetPickerScreen>(find.byType(SetPickerScreen));
    expect(screen.phase, QuestionPhase.recall);
    expect([for (final q in screen.questions) q.id], ['a', 'b', 'c']);
    // The three recall questions have no source or date: one set of 3.
    expect(find.text('1 set'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('set-card-0')),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('set-card-1')), findsNothing);
  });

  testWidgets('back from a phase returns home', (tester) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();
    await _openPhase(tester, 'New corrections');
    expect(find.byType(SetPickerScreen), findsOneWidget);

    await _tapVisible(tester, find.byTooltip(SetPickerScreen.backLabel));
    expect(find.byType(SetPickerScreen), findsNothing);
    expect(find.byKey(const ValueKey('phase-card-1')), findsOneWidget);
  });

  testWidgets('the set size and by conversation are kept', (tester) async {
    await tester.pumpWidget(_app(() async => _sample()));
    await tester.pumpAndSettle();
    await _openPhase(tester, 'Recall');

    await _tapVisible(tester, find.byKey(const ValueKey('set-size-10')));
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('set-by-conversation')),
    );
    await _tapVisible(tester, find.byTooltip(SetPickerScreen.backLabel));

    await _openPhase(tester, 'New corrections');
    final screen =
        tester.widget<SetPickerScreen>(find.byType(SetPickerScreen));
    expect(screen.choices.size, 10);
    expect(screen.choices.byConversation, isTrue);
  });

  // Until B25, a set opens the game of its first question.
  for (final (game, phase, type) in [
    (GameType.order, 'Recall', OrderScreen),
    (GameType.fillGap, 'Recall', FillGapScreen),
    (GameType.repair, 'New corrections', RepairScreen),
  ]) {
    testWidgets('a set starting with ${game.label} opens it', (tester) async {
      await tester.pumpWidget(
        _app(
          () async => ParsedQuestions(
            questions: [_q('x', game), ..._sample().questions],
            problems: const [],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openPhase(tester, phase);
      await _tapVisible(tester, find.byKey(const ValueKey('set-card-0')));
      expect(find.byType(type), findsOneWidget);
    });
  }

  testWidgets('a set starting with Matching opens it', (tester) async {
    final withMatch = ParsedQuestions(
      questions: [
        Question(
          id: 'm',
          game: GameType.match,
          category: 'test',
          type: QuestionType.grammar,
          prompt: 'Match the verb to its preposition',
          pairs: const [MatchPair('pensar', 'en'), MatchPair('depender', 'de')],
        ),
        ..._sample().questions,
      ],
      problems: const [],
    );
    await tester.pumpWidget(_app(() async => withMatch));
    await tester.pumpAndSettle();

    await _openPhase(tester, 'Recall');
    await _tapVisible(tester, find.byKey(const ValueKey('set-card-0')));
    final screen = tester.widget<MatchScreen>(find.byType(MatchScreen));
    // Only the set's questions of that game.
    expect([for (final q in screen.questions) q.id], ['m']);
  });

  testWidgets('a set starting with Spot the error opens it', (tester) async {
    final withSpotError = ParsedQuestions(
      questions: [
        Question(
          id: 's',
          game: GameType.spotError,
          category: 'test',
          type: QuestionType.grammar,
          prompt: 'Depende del tiempo.',
          answers: const ['Depende del tiempo.'],
        ),
        ..._sample().questions,
      ],
      problems: const [],
    );
    await tester.pumpWidget(_app(() async => withSpotError));
    await tester.pumpAndSettle();

    await _openPhase(tester, 'Recall');
    await _tapVisible(tester, find.byKey(const ValueKey('set-card-0')));
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
