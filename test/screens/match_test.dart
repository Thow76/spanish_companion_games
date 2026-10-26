/// Behaviour of the Matching screen (B6): two columns of tiles, tap one on
/// each side to pair them, a right pair stays mint, a wrong pairing flashes
/// coral and goes back, the question is done once every pair is matched
/// (right only with no wrong pairing), next question, the score.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/screens/match_screen.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';
import 'package:spanish_companion_games/widgets/widgets.dart';

Question _verbs() => Question(
  id: 'verbs',
  game: GameType.match,
  category: 'Prepositions',
  type: QuestionType.grammar,
  prompt: 'Match the verb to its preposition',
  pairs: const [
    MatchPair('pensar', 'en'),
    MatchPair('depender', 'de'),
    MatchPair('soñar', 'con'),
  ],
  explanation:
      'pensar en, depender de, soñar con = verbs that take a fixed preposition',
);

Question _nouns() => Question(
  id: 'nouns',
  game: GameType.match,
  category: 'Collocation',
  type: QuestionType.note,
  prompt: 'Match the verb to its noun',
  pairs: const [
    MatchPair('prestar', 'atención'),
    MatchPair('hacer', 'cola'),
  ],
  explanation: 'prestar atención, hacer cola = fixed verb + noun pairs',
);

Widget _app(Widget home) => MaterialApp(
  theme: appTheme(FormFactor.phone),
  builder: (context, child) => Theme(
    data: appTheme(FormFactor.of(context)),
    child: child ?? const SizedBox.shrink(),
  ),
  home: home,
);

MatchScreen _screen(List<Question> questions) =>
    MatchScreen(questions: questions, random: Random(1));

PrimaryButton _button(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byType(PrimaryButton));

AnswerState _state(WidgetTester tester, String label) => tester
    .widget<AnswerOption>(find.widgetWithText(AnswerOption, label))
    .state;

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(AnswerOption, label));
  await tester.pump();
}

/// Taps [left] then [right] and lets any wrong flash finish.
Future<void> _pair(WidgetTester tester, String left, String right) async {
  await _tap(tester, left);
  await _tap(tester, right);
  await tester.pump(MatchScreen.wrongFlash);
  await tester.pump(const Duration(milliseconds: 200));
}

/// Lets the result toast come up and go (see fill_gap_test.dart).
Future<void> _letToastGo(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  group('shuffle', () {
    test('keeps every word and avoids starting level with its partner', () {
      const rights = ['en', 'de', 'con', 'a'];
      for (var seed = 0; seed < 50; seed++) {
        final out = MatchScreen.shuffle(rights, Random(seed));
        expect(out.toList()..sort(), rights.toList()..sort());
        for (var i = 0; i < rights.length; i++) {
          expect(out[i], isNot(rights[i]));
        }
      }
    });

    test('all the same is left as it is', () {
      expect(MatchScreen.shuffle(['de', 'de'], Random(1)), ['de', 'de']);
    });
  });

  testWidgets('shows the prompt and a tile for each word; Next is off', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_screen([_verbs()])));
    await tester.pumpAndSettle();

    expect(find.text('Match the verb to its preposition'), findsOneWidget);
    expect(find.byType(AnswerOption), findsNWidgets(6));
    expect(_button(tester).label, 'See results');
    expect(_button(tester).onPressed, isNull);
  });

  testWidgets('a picked tile is selected; tapping it again lets it go', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_screen([_verbs()])));
    await tester.pumpAndSettle();

    await _tap(tester, 'pensar');
    expect(_state(tester, 'pensar'), AnswerState.selected);
    await _tap(tester, 'depender');
    expect(_state(tester, 'pensar'), AnswerState.resting);
    expect(_state(tester, 'depender'), AnswerState.selected);
    await _tap(tester, 'depender');
    expect(_state(tester, 'depender'), AnswerState.resting);
  });

  testWidgets('a right pair turns mint and stays, either side first', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_screen([_verbs()])));
    await tester.pumpAndSettle();

    await _pair(tester, 'pensar', 'en');
    expect(_state(tester, 'pensar'), AnswerState.correct);
    expect(_state(tester, 'en'), AnswerState.correct);

    await _pair(tester, 'de', 'depender');
    expect(_state(tester, 'depender'), AnswerState.correct);
    expect(_state(tester, 'de'), AnswerState.correct);
    expect(_button(tester).onPressed, isNull);
  });

  testWidgets('a wrong pairing flashes coral, then both go back', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_screen([_verbs()])));
    await tester.pumpAndSettle();

    await _tap(tester, 'pensar');
    await _tap(tester, 'de');
    expect(_state(tester, 'pensar'), AnswerState.wrong);
    expect(_state(tester, 'de'), AnswerState.wrong);

    await tester.pump(MatchScreen.wrongFlash);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_state(tester, 'pensar'), AnswerState.resting);
    expect(_state(tester, 'de'), AnswerState.resting);
  });

  testWidgets('all matched with no mistakes: Correct, explanation, Next', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_screen([_verbs(), _nouns()])));
    await tester.pumpAndSettle();

    await _pair(tester, 'pensar', 'en');
    await _pair(tester, 'depender', 'de');
    await _tap(tester, 'soñar');
    await _tap(tester, 'con');
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text(ResultToast.correctText), findsOneWidget);
    expect(find.byType(ExplanationCard), findsOneWidget);
    expect(find.text('You wrote'), findsNothing);
    expect(_button(tester).label, 'Next question');
    expect(_button(tester).onPressed, isNotNull);
    await _letToastGo(tester);
  });

  testWidgets('a wrong pairing on the way: Not quite and You wrote', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_screen([_verbs()])));
    await tester.pumpAndSettle();

    await _pair(tester, 'pensar', 'de');
    await _pair(tester, 'pensar', 'en');
    await _pair(tester, 'depender', 'de');
    await _tap(tester, 'soñar');
    await _tap(tester, 'con');
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text(ResultToast.wrongText), findsOneWidget);
    expect(find.text('You wrote'), findsOneWidget);
    await _letToastGo(tester);
  });

  testWidgets('next question, then the stand-in end view with the score', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_screen([_verbs(), _nouns()])));
    await tester.pumpAndSettle();

    await _pair(tester, 'pensar', 'en');
    await _pair(tester, 'depender', 'de');
    await _pair(tester, 'soñar', 'con');
    await _letToastGo(tester);
    await tester.tap(find.text('Next question'));
    await tester.pumpAndSettle();

    expect(find.text('Question 2 of 2'), findsOneWidget);
    expect(find.byType(AnswerOption), findsNWidgets(4));

    await _pair(tester, 'prestar', 'cola');
    await _pair(tester, 'prestar', 'atención');
    await _pair(tester, 'hacer', 'cola');
    await _letToastGo(tester);
    await tester.tap(find.text('See results'));
    await tester.pumpAndSettle();

    expect(find.text('You got 1 of 2 right.'), findsOneWidget);
  });

  testWidgets('questions from other games are skipped', (tester) async {
    final other = Question(
      id: 'gap',
      game: GameType.fillGap,
      category: 'Prepositions',
      type: QuestionType.grammar,
      prompt: 'Depende ___ tiempo.',
      answers: const ['del'],
    );
    await tester.pumpWidget(_app(_screen([other, _nouns()])));
    await tester.pumpAndSettle();

    expect(find.text('Question 1 of 1'), findsOneWidget);
  });
}
