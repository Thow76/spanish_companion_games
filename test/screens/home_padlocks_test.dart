/// Home with padlocks (B30): locked cards, "n locked", the locked
/// message, unlocking in the same session, and the reload rule.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/ladder_locks.dart';
import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/models/question_parser.dart';
import 'package:spanish_companion_games/screens/fill_gap_screen.dart';
import 'package:spanish_companion_games/screens/home_screen.dart';
import 'package:spanish_companion_games/screens/repair_screen.dart';
import 'package:spanish_companion_games/widgets/game_card.dart';

const _s3 = 'FB-0012-s3';
const _s4 = 'FB-0012-s4';
const _sentence = 'Espero que tengas un buen fin de semana.';

Question _repair() => Question(
  id: _s3,
  item: 'FB-0012',
  game: GameType.repair,
  category: 'Verb forms',
  type: QuestionType.grammar,
  prompt: 'Espero que **tienes** un buen fin de semana.',
  answers: const [_sentence],
);

Question _typedGap({String? unlocksAfter = _s3}) => Question(
  id: _s4,
  item: 'FB-0012',
  game: GameType.fillGap,
  category: 'Verb forms',
  type: QuestionType.grammar,
  prompt: 'Espero que ___ (tener) un buen viaje.',
  answers: const ['tengas'],
  unlocksAfter: unlocksAfter,
);

Question _optionsGap() => Question(
  id: 'FB-0020-s2',
  item: 'FB-0020',
  game: GameType.fillGap,
  category: 'Prepositions',
  type: QuestionType.grammar,
  prompt: 'Depende ___ tiempo.',
  answers: const ['del'],
  options: const ['del', 'de', 'en'],
);

ParsedQuestions _parsed(List<Question> qs) =>
    ParsedQuestions(questions: qs, problems: const []);

Widget _app(QuestionSource source) =>
    MaterialApp(home: HomeScreen(source: source));

Finder _card(GameType g) => find.byKey(ValueKey('game-card-${g.jsonValue}'));
Finder _lockLine(GameType g) =>
    find.byKey(ValueKey('lock-line-${g.jsonValue}'));
Finder _countOn(GameType g, String text) =>
    find.descendant(of: _card(g), matching: find.text(text));

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Plays the Repair question right and comes back to home.
Future<void> _passRepair(WidgetTester tester) async {
  await _tapVisible(tester, find.text(GameType.repair.label));
  expect(find.byType(RepairScreen), findsOneWidget);
  await tester.enterText(find.byType(TextField), _sentence);
  await tester.pump();
  await tester.tap(find.text('Check'));
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
  tester.state<NavigatorState>(find.byType(Navigator)).pop();
  await tester.pumpAndSettle();
  expect(find.byType(HomeScreen), findsOneWidget);
}

void main() {
  testWidgets('a card with only locked questions is locked and says so', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(() async => _parsed([_repair(), _typedGap()])),
    );
    await tester.pumpAndSettle();

    // Repair is open; Fill the gap holds only the locked stage 4.
    expect(_countOn(GameType.repair, '1'), findsOneWidget);
    expect(tester.widget<GameCard>(_card(GameType.fillGap)).onTap, isNull);
    expect(
      find.descendant(
        of: _lockLine(GameType.fillGap),
        matching: find.text('Locked'),
      ),
      findsOneWidget,
    );
    // Spot the error and the consolidation cards come after stage 3.
    expect(_lockLine(GameType.spotError), findsOneWidget);
    expect(_lockLine(GameType.order), findsOneWidget);
    expect(_lockLine(GameType.match), findsOneWidget);
    // Choose a correction comes before: "No questions yet", no padlock.
    expect(_lockLine(GameType.chooseCorrection), findsNothing);
    expect(
      find.descendant(
        of: _card(GameType.chooseCorrection),
        matching: find.text('No questions yet'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tapping a locked card shows the locked message', (tester) async {
    await tester.pumpWidget(
      _app(() async => _parsed([_repair(), _typedGap()])),
    );
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.text(GameType.fillGap.label));
    expect(find.byType(FillGapScreen), findsNothing);
    expect(find.text(lockedCardMessage), findsOneWidget);
    expect(
      lockedCardMessage,
      'Please complete the necessary steps before this card is unlocked.',
    );
  });

  testWidgets('a part-locked card shows its open count and "n locked", and '
      'opens with the open questions only', (tester) async {
    await tester.pumpWidget(
      _app(() async => _parsed([_repair(), _optionsGap(), _typedGap()])),
    );
    await tester.pumpAndSettle();

    expect(_countOn(GameType.fillGap, '1'), findsOneWidget);
    expect(
      find.descendant(
        of: _lockLine(GameType.fillGap),
        matching: find.text('1 locked'),
      ),
      findsOneWidget,
    );

    await _tapVisible(tester, find.text(GameType.fillGap.label));
    final screen = tester.widget<FillGapScreen>(find.byType(FillGapScreen));
    expect([for (final q in screen.questions) q.id], ['FB-0020-s2']);
  });

  testWidgets('passing the earlier stage unlocks the card straight away', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(() async => _parsed([_repair(), _typedGap()])),
    );
    await tester.pumpAndSettle();
    expect(_lockLine(GameType.fillGap), findsOneWidget);

    await _passRepair(tester);

    expect(_lockLine(GameType.fillGap), findsNothing);
    expect(_countOn(GameType.fillGap, '1'), findsOneWidget);
    await _tapVisible(tester, find.text(GameType.fillGap.label));
    final screen = tester.widget<FillGapScreen>(find.byType(FillGapScreen));
    expect([for (final q in screen.questions) q.id], [_s4]);
  });

  testWidgets('reload rule: after a reload without the passed question, the '
      'unlocked stage stays', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _app(() async {
        calls++;
        // The script removes a question once it is answered right.
        return calls == 1
            ? _parsed([_repair(), _typedGap()])
            : _parsed([_typedGap()]);
      }),
    );
    await tester.pumpAndSettle();
    await _passRepair(tester);

    // The phone top bar scrolls with the page.
    await _tapVisible(tester, find.byTooltip('Reload questions'));
    expect(calls, 2);
    expect(_countOn(GameType.fillGap, '1'), findsOneWidget);
    expect(_lockLine(GameType.fillGap), findsNothing);
  });

  testWidgets('reload rule: a follower whose question is gone from the file '
      'is open even if not answered this session', (tester) async {
    // Parsed from JSON, so the parser keeps it too.
    final parsed = parseQuestionList([
      {
        'id': _s4,
        'item': 'FB-0012',
        'stage': 4,
        'unlocks_after': _s3,
        'game': 'fill_gap',
        'category': 'Verb forms',
        'prompt': 'Espero que ___ (tener) un buen viaje.',
        'answers': ['tengas'],
      },
    ]);
    expect(parsed.problems, isEmpty);
    await tester.pumpWidget(_app(() async => parsed));
    await tester.pumpAndSettle();
    expect(_countOn(GameType.fillGap, '1'), findsOneWidget);
    expect(_lockLine(GameType.fillGap), findsNothing);
  });
}
