/// Behaviour of the Sentence ordering screen (B4): the words shuffled into
/// chips, tap to place and tap again to take back, Check once every word
/// is placed, the corrected sentence and explanation after checking, next
/// question, the score.
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/screens/order_screen.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';
import 'package:spanish_companion_games/widgets/widgets.dart';

Question _siempre() => Question(
  id: 'siempre',
  game: GameType.order,
  category: 'Word order',
  type: QuestionType.grammar,
  prompt: 'Siempre me levanto a las siete.',
  answers: const [
    'Siempre me levanto a las siete.',
    'Me levanto siempre a las siete.',
  ],
  explanation:
      'me levanto = the reflexive pronoun goes before the conjugated verb',
);

Question _nadie() => Question(
  id: 'nadie',
  game: GameType.order,
  category: 'Pronouns',
  type: QuestionType.grammar,
  prompt: 'No se lo he dicho a nadie.',
  answers: const ['No se lo he dicho a nadie.'],
  explanation:
      'no + se + lo + verb = negation, then the indirect pronoun, then the '
      'direct pronoun',
);

Widget _app(Widget home) => MaterialApp(
  theme: appTheme(FormFactor.phone),
  builder: (context, child) => Theme(
    data: appTheme(FormFactor.of(context)),
    child: child ?? const SizedBox.shrink(),
  ),
  home: home,
);

OrderScreen _screen(List<Question> questions) =>
    OrderScreen(questions: questions, random: Random(1));

PrimaryButton _button(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byType(PrimaryButton));

AnswerState _wordState(WidgetTester tester, String word) => tester
    .widget<AnswerOption>(find.widgetWithText(AnswerOption, word))
    .state;

PromptCard _card(WidgetTester tester) =>
    tester.widget<PromptCard>(find.byType(PromptCard));

Future<void> _tapWords(WidgetTester tester, List<String> words) async {
  for (final w in words) {
    await tester.tap(find.widgetWithText(AnswerOption, w));
    await tester.pumpAndSettle();
  }
}

/// Lets the result toast come up and go (see fill_gap_test.dart).
Future<void> _letToastGo(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  group('shuffle', () {
    test('never starts in the right order when it can be avoided', () {
      final q = _siempre();
      final words = OrderScreen.wordsOf(q);
      for (var seed = 0; seed < 50; seed++) {
        final out = OrderScreen.shuffle(
          words,
          OrderScreen.acceptedOf(q),
          Random(seed),
        );
        expect(out.toList()..sort(), words.toList()..sort());
        expect(out.join(' '), isNot(words.join(' ')));
      }
    });

    test('a one-word sentence is left as it is', () {
      expect(OrderScreen.shuffle(['Hola.'], ['Hola.'], Random(1)), ['Hola.']);
    });

    test('punctuation stays on its word', () {
      expect(OrderScreen.wordsOf(_nadie()), [
        'No',
        'se',
        'lo',
        'he',
        'dicho',
        'a',
        'nadie.',
      ]);
    });
  });

  testWidgets('shows every word as a chip, the instruction, Check off', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_screen([_siempre()])));
    await tester.pumpAndSettle();

    expect(find.text(OrderScreen.instruction), findsOneWidget);
    expect(find.byType(AnswerOption), findsNWidgets(6));
    expect(_card(tester).sentence, '');
    expect(_button(tester).onPressed, isNull);
  });

  testWidgets('tapping words builds the sentence; tapping again takes back', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_screen([_siempre()])));
    await tester.pumpAndSettle();

    await _tapWords(tester, ['Siempre', 'me']);
    expect(_card(tester).sentence, 'Siempre me');
    expect(_wordState(tester, 'Siempre'), AnswerState.selected);
    expect(_wordState(tester, 'levanto'), AnswerState.resting);

    await _tapWords(tester, ['Siempre']);
    expect(_card(tester).sentence, 'me');
    expect(_wordState(tester, 'Siempre'), AnswerState.resting);
    expect(_button(tester).onPressed, isNull);
  });

  testWidgets('Check turns on once every word is placed', (tester) async {
    await tester.pumpWidget(_app(_screen([_siempre()])));
    await tester.pumpAndSettle();

    await _tapWords(tester, ['Siempre', 'me', 'levanto', 'a', 'las']);
    expect(_button(tester).onPressed, isNull);
    await _tapWords(tester, ['siete.']);
    expect(_button(tester).onPressed, isNotNull);
  });

  testWidgets('right order: correct, no corrected version, no You wrote', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_screen([_siempre(), _nadie()])));
    await tester.pumpAndSettle();

    await _tapWords(tester, ['Siempre', 'me', 'levanto', 'a', 'las', 'siete.']);
    await tester.tap(find.text('Check'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text(ResultToast.correctText), findsOneWidget);
    expect(_card(tester).corrected, isNull);
    expect(find.byType(ExplanationCard), findsOneWidget);
    expect(find.text('You wrote'), findsNothing);
    expect(_wordState(tester, 'Siempre'), AnswerState.dimmed);
    await _letToastGo(tester);
  });

  testWidgets('an alternative listed in answers is accepted', (tester) async {
    await tester.pumpWidget(_app(_screen([_siempre()])));
    await tester.pumpAndSettle();

    await _tapWords(tester, ['me', 'levanto', 'Siempre', 'a', 'las', 'siete.']);
    await tester.tap(find.text('Check'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text(ResultToast.correctText), findsOneWidget);
    await _letToastGo(tester);
  });

  testWidgets('wrong order: Not quite, the corrected version, You wrote', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_screen([_nadie()])));
    await tester.pumpAndSettle();

    await _tapWords(tester, ['No', 'lo', 'se', 'he', 'dicho', 'a', 'nadie.']);
    await tester.tap(find.text('Check'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text(ResultToast.wrongText), findsOneWidget);
    expect(_card(tester).corrected, 'No se lo he dicho a nadie.');
    expect(find.text('You wrote'), findsOneWidget);
    await _letToastGo(tester);
  });

  testWidgets('next question, then the stand-in end view with the score', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_screen([_siempre(), _nadie()])));
    await tester.pumpAndSettle();

    await _tapWords(tester, ['Siempre', 'me', 'levanto', 'a', 'las', 'siete.']);
    await tester.tap(find.text('Check'));
    await _letToastGo(tester);
    await tester.tap(find.text('Next question'));
    await tester.pumpAndSettle();

    expect(find.text('Question 2 of 2'), findsOneWidget);
    expect(_card(tester).sentence, '');
    expect(find.byType(AnswerOption), findsNWidgets(7));

    await _tapWords(tester, ['No', 'lo', 'se', 'he', 'dicho', 'a', 'nadie.']);
    await tester.tap(find.text('Check'));
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
    await tester.pumpWidget(_app(_screen([other, _nadie()])));
    await tester.pumpAndSettle();

    expect(find.text('Question 1 of 1'), findsOneWidget);
  });
}
