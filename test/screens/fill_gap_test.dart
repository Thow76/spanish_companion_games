/// Behaviour of the Fill the gap screen (B14): option mode and typed mode,
/// Check enabled once something is picked or typed, the right word in the
/// gap after checking, the explanation, next question, the score.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/screens/fill_gap_screen.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';
import 'package:spanish_companion_games/widgets/widgets.dart';

Question _depende() => Question(
  id: 'opt',
  game: GameType.fillGap,
  category: 'Prepositions',
  type: QuestionType.grammar,
  prompt: 'Depende ___ tiempo que haga.',
  answers: const ['del'],
  options: const ['del', 'de', 'en', 'al'],
  explanation: 'depender de = to depend on',
);

Question _espero() => Question(
  id: 'typed',
  game: GameType.fillGap,
  category: 'Verb forms',
  type: QuestionType.grammar,
  prompt: 'Espero que ___ buen tiempo mañana.',
  answers: const ['haga'],
  explanation: 'esperar que + subjunctive = to hope that',
);

Widget _app(Widget home) => MaterialApp(
  theme: appTheme(FormFactor.phone),
  builder: (context, child) => Theme(
    data: appTheme(FormFactor.of(context)),
    child: child ?? const SizedBox.shrink(),
  ),
  home: home,
);

PrimaryButton _button(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byType(PrimaryButton));

AnswerState _optionState(WidgetTester tester, String label) => tester
    .widget<AnswerOption>(find.widgetWithText(AnswerOption, label))
    .state;

PromptCard _card(WidgetTester tester) =>
    tester.widget<PromptCard>(find.byType(PromptCard));

Future<void> _letToastGo(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  group('option mode', () {
    testWidgets('shows options, no field, and the choose instruction', (
      tester,
    ) async {
      await tester.pumpWidget(_app(FillGapScreen(questions: [_depende()])));
      await tester.pumpAndSettle();

      expect(find.text(FillGapScreen.chooseInstruction), findsOneWidget);
      expect(find.byType(AnswerOption), findsNWidgets(4));
      expect(find.byType(AnswerField), findsNothing);
      expect(_card(tester).gapState, GapState.empty);
      expect(_button(tester).onPressed, isNull);
    });

    testWidgets('picking an option fills the gap and enables Check', (
      tester,
    ) async {
      await tester.pumpWidget(_app(FillGapScreen(questions: [_depende()])));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(AnswerOption, 'de'));
      await tester.pumpAndSettle();

      expect(_optionState(tester, 'de'), AnswerState.selected);
      expect(_card(tester).fill, 'de');
      expect(_card(tester).gapState, GapState.chosen);
      expect(_button(tester).onPressed, isNotNull);
    });

    testWidgets('a wrong pick marks it wrong and shows the right word', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(FillGapScreen(questions: [_depende(), _espero()])),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(AnswerOption, 'de'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check'));
      await tester.pump();

      expect(_optionState(tester, 'de'), AnswerState.wrong);
      expect(_optionState(tester, 'del'), AnswerState.correct);
      expect(_optionState(tester, 'en'), AnswerState.dimmed);
      expect(_card(tester).fill, 'del');
      expect(_card(tester).gapState, GapState.correct);
      expect(find.byType(ExplanationCard), findsOneWidget);
      await _letToastGo(tester);
    });
  });

  group('typed mode', () {
    testWidgets('shows an empty field and the type instruction', (
      tester,
    ) async {
      await tester.pumpWidget(_app(FillGapScreen(questions: [_espero()])));
      await tester.pumpAndSettle();

      expect(find.text(FillGapScreen.typeInstruction), findsOneWidget);
      expect(find.byType(AnswerOption), findsNothing);
      expect(find.byType(AnswerField), findsOneWidget);
      expect(_button(tester).onPressed, isNull);
    });

    testWidgets('typing fills the gap; spaces alone do not enable Check', (
      tester,
    ) async {
      await tester.pumpWidget(_app(FillGapScreen(questions: [_espero()])));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();
      expect(_button(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), ' haga ');
      await tester.pumpAndSettle();
      expect(_card(tester).fill, 'haga');
      expect(_card(tester).gapState, GapState.chosen);
      expect(_button(tester).onPressed, isNotNull);
    });

    testWidgets('a right answer ignores case and final punctuation', (
      tester,
    ) async {
      await tester.pumpWidget(_app(FillGapScreen(questions: [_espero()])));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Haga.');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check'));
      await tester.pump();

      expect(
        tester.widget<AnswerField>(find.byType(AnswerField)).state,
        AnswerFieldState.correct,
      );
      expect(_card(tester).gapState, GapState.correct);
      await _letToastGo(tester);
    });

    testWidgets('accents must match', (tester) async {
      final q = Question(
        id: 'accent',
        game: GameType.fillGap,
        category: 'Verb forms',
        type: QuestionType.grammar,
        prompt: 'Mañana ___ a Madrid.',
        answers: const ['iré'],
        explanation: 'ir, future = will go',
      );
      await tester.pumpWidget(_app(FillGapScreen(questions: [q])));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'ire');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check'));
      await tester.pump();

      expect(
        tester.widget<AnswerField>(find.byType(AnswerField)).state,
        AnswerFieldState.wrong,
      );
      expect(_card(tester).fill, 'iré');
      await _letToastGo(tester);
    });
  });

  testWidgets('a mixed session moves on, keeps score and ends', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(FillGapScreen(questions: [_depende(), _espero()])),
    );
    await tester.pumpAndSettle();

    // Question 1 (options): right.
    await tester.tap(find.widgetWithText(AnswerOption, 'del'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check'));
    await _letToastGo(tester);
    await tester.tap(find.text('Next question'));
    await tester.pumpAndSettle();

    // Question 2 (typed): starts empty, wrong answer.
    expect(find.byType(AnswerField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    await tester.enterText(find.byType(TextField), 'hace');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check'));
    await _letToastGo(tester);
    await tester.tap(find.text('See results'));
    await tester.pumpAndSettle();

    expect(find.text('You got 1 of 2 right.'), findsOneWidget);

    await tester.tap(find.text('Play again'));
    await tester.pumpAndSettle();
    expect(find.byType(AnswerOption), findsNWidgets(4));
  });

  testWidgets('questions from other games are skipped', (tester) async {
    final other = Question(
      id: 'x',
      game: GameType.order,
      category: 'Word order',
      type: QuestionType.grammar,
      prompt: 'No lo sé.',
      answers: const ['No lo sé.'],
    );
    await tester.pumpWidget(
      _app(FillGapScreen(questions: [other, _espero()])),
    );
    await tester.pumpAndSettle();

    expect(find.text('Question 1 of 1'), findsOneWidget);
  });
}
