/// Behaviour of the Spot the error screen (B15): the two choices, the field
/// appearing for "It needs fixing", Check enabled per spec section 6, both
/// steps checked, the corrected sentence and explanation, next question,
/// the score.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/screens/spot_error_screen.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';
import 'package:spanish_companion_games/widgets/widgets.dart';

// The two spot_error questions in assets/questions.sample.json.
Question _pensando() => Question(
  id: '2026-10-17-014',
  game: GameType.spotError,
  category: 'Prepositions',
  type: QuestionType.grammar,
  prompt: 'Estoy pensando de mudarme a Glasgow.',
  answers: const ['Estoy pensando en mudarme a Glasgow.'],
  explanation: 'pensar en + infinitive = to be thinking of doing something',
);

Question _depende() => Question(
  id: '2026-10-17-015',
  game: GameType.spotError,
  category: 'Prepositions',
  type: QuestionType.grammar,
  prompt: 'Depende del tiempo que haga.',
  answers: const ['Depende del tiempo que haga.'],
  explanation: 'depender de + el = del (this sentence is already correct)',
);

Widget _app(Widget home) => MaterialApp(
  theme: appTheme(FormFactor.phone),
  builder: (context, child) => Theme(
    data: appTheme(FormFactor.of(context)),
    child: child ?? const SizedBox.shrink(),
  ),
  home: home,
);

Finder get _field => find.byType(TextField);

PrimaryButton _button(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byType(PrimaryButton));

AnswerFieldState _fieldState(WidgetTester tester) =>
    tester.widget<AnswerField>(find.byType(AnswerField)).state;

AnswerState _optionState(WidgetTester tester, String label) => tester
    .widget<AnswerOption>(
      find.ancestor(
        of: find.text(label),
        matching: find.byType(AnswerOption),
      ),
    )
    .state;

Future<void> _pick(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

Future<void> _checkNow(WidgetTester tester) async {
  await tester.tap(find.text('Check'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

/// Lets the result toast come up and go (see repair_test.dart).
Future<void> _letToastGo(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sentence plain, two choices, no field, Check disabled', (
    tester,
  ) async {
    await tester.pumpWidget(_app(SpotErrorScreen(questions: [_pensando()])));
    await tester.pumpAndSettle();

    expect(find.text('Spot the error'), findsOneWidget);
    expect(find.text('Question 1 of 1'), findsOneWidget);
    expect(find.text('Grammar error · Prepositions'), findsOneWidget);
    expect(find.text(SpotErrorScreen.instruction), findsOneWidget);
    expect(find.text(PromptCard.originalLabel), findsNothing);
    expect(find.text(SpotErrorChoice.correctLabel), findsOneWidget);
    expect(find.text(SpotErrorChoice.needsFixingLabel), findsOneWidget);
    expect(_field, findsNothing);
    expect(_button(tester).label, 'Check');
    expect(_button(tester).onPressed, isNull);
  });

  testWidgets('"It needs fixing" shows the prefilled field; edit enables '
      'Check', (tester) async {
    await tester.pumpWidget(_app(SpotErrorScreen(questions: [_pensando()])));
    await tester.pumpAndSettle();

    await _pick(tester, SpotErrorChoice.needsFixingLabel);
    expect(_field, findsOneWidget);
    expect(
      tester.widget<TextField>(_field).controller!.text,
      'Estoy pensando de mudarme a Glasgow.',
    );
    expect(find.text(AnswerField.spotErrorCaption), findsOneWidget);
    expect(_button(tester).onPressed, isNull);

    await tester.enterText(_field, 'Estoy pensando en mudarme a Glasgow.');
    await tester.pump();
    expect(_button(tester).onPressed, isNotNull);

    // Switching to "It's correct" also allows Check.
    await _pick(tester, SpotErrorChoice.correctLabel);
    expect(_field, findsNothing);
    expect(_button(tester).onPressed, isNotNull);
  });

  testWidgets('wrong sentence fixed right: Correct, corrected version', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(SpotErrorScreen(questions: [_pensando(), _depende()])),
    );
    await tester.pumpAndSettle();

    await _pick(tester, SpotErrorChoice.needsFixingLabel);
    await tester.enterText(_field, 'estoy pensando en mudarme a Glasgow');
    await tester.pump();
    await _checkNow(tester);

    expect(find.text(ResultToast.correctText), findsOneWidget);
    expect(_fieldState(tester), AnswerFieldState.correct);
    expect(
      _optionState(tester, SpotErrorChoice.needsFixingLabel),
      AnswerState.correct,
    );
    expect(find.text(PromptCard.correctedLabel), findsOneWidget);
    expect(find.byType(ExplanationCard), findsOneWidget);
    expect(find.text('You wrote'), findsNothing);

    await _letToastGo(tester);
    await tester.tap(find.text('Next question'));
    await tester.pumpAndSettle();

    expect(find.text('Question 2 of 2'), findsOneWidget);
    expect(_field, findsNothing);
    expect(
      _optionState(tester, SpotErrorChoice.correctLabel),
      AnswerState.resting,
    );
    expect(find.byType(ExplanationCard), findsNothing);
  });

  testWidgets('correct sentence, "It\'s correct": Correct, no corrected '
      'version', (tester) async {
    await tester.pumpWidget(_app(SpotErrorScreen(questions: [_depende()])));
    await tester.pumpAndSettle();

    await _pick(tester, SpotErrorChoice.correctLabel);
    await _checkNow(tester);

    expect(find.text(ResultToast.correctText), findsOneWidget);
    expect(
      _optionState(tester, SpotErrorChoice.correctLabel),
      AnswerState.correct,
    );
    expect(find.text(PromptCard.correctedLabel), findsNothing);
  });

  testWidgets('wrong sentence, "It\'s correct": Not quite, both choices '
      'marked, You wrote', (tester) async {
    await tester.pumpWidget(_app(SpotErrorScreen(questions: [_pensando()])));
    await tester.pumpAndSettle();

    await _pick(tester, SpotErrorChoice.correctLabel);
    await _checkNow(tester);

    expect(find.text(ResultToast.wrongText), findsOneWidget);
    expect(
      _optionState(tester, SpotErrorChoice.correctLabel),
      AnswerState.wrong,
    );
    expect(
      _optionState(tester, SpotErrorChoice.needsFixingLabel),
      AnswerState.correct,
    );
    expect(find.text(PromptCard.correctedLabel), findsOneWidget);
    expect(find.text('You wrote'), findsOneWidget);
  });

  testWidgets('right choice, wrong fix: Not quite; then See results and '
      'Play again', (tester) async {
    await tester.pumpWidget(_app(SpotErrorScreen(questions: [_pensando()])));
    await tester.pumpAndSettle();

    await _pick(tester, SpotErrorChoice.needsFixingLabel);
    await tester.enterText(_field, 'Estoy pensando a mudarme a Glasgow.');
    await tester.pump();
    await _checkNow(tester);

    expect(find.text(ResultToast.wrongText), findsOneWidget);
    expect(_fieldState(tester), AnswerFieldState.wrong);
    expect(find.text('You wrote'), findsOneWidget);

    await _letToastGo(tester);
    await tester.tap(find.text('See results'));
    await tester.pumpAndSettle();
    expect(find.text('Session complete'), findsOneWidget);
    expect(find.text('You got 0 of 1 right.'), findsOneWidget);

    await tester.tap(find.text('Play again'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 1'), findsOneWidget);
    expect(_field, findsNothing);
  });

  testWidgets('correct sentence "fixed": Not quite', (tester) async {
    await tester.pumpWidget(_app(SpotErrorScreen(questions: [_depende()])));
    await tester.pumpAndSettle();

    await _pick(tester, SpotErrorChoice.needsFixingLabel);
    await tester.enterText(_field, 'Depende de el tiempo que haga.');
    await tester.pump();
    await _checkNow(tester);

    expect(find.text(ResultToast.wrongText), findsOneWidget);
    expect(
      _optionState(tester, SpotErrorChoice.correctLabel),
      AnswerState.correct,
    );
    expect(
      _optionState(tester, SpotErrorChoice.needsFixingLabel),
      AnswerState.wrong,
    );
    expect(find.text(PromptCard.correctedLabel), findsNothing);
  });

  testWidgets('questions from other games are skipped', (tester) async {
    final other = Question(
      id: 'x',
      game: GameType.order,
      category: 'test',
      type: QuestionType.grammar,
      prompt: 'Hola.',
      answers: const ['Hola.'],
    );
    await tester.pumpWidget(
      _app(SpotErrorScreen(questions: [other, _depende()])),
    );
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 1'), findsOneWidget);
  });
}
