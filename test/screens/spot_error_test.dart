/// Behaviour of the Spot the error screen (B15, redesigned in U17): the
/// ✓/✗ buttons in the prompt card, the sentence turning into the field for
/// "It needs fixing", Check enabled per spec section 6, both steps
/// checked, the corrected sentence and explanation, next question, the
/// score.
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

SpotErrorButtonState _choiceState(WidgetTester tester, String label) => tester
    .widget<SpotErrorButton>(
      find.ancestor(
        of: find.byTooltip(label),
        matching: find.byType(SpotErrorButton),
      ),
    )
    .state;

Future<void> _pick(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip(label));
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
  testWidgets('sentence in the card with the ✓/✗ row, no field, Check '
      'disabled', (tester) async {
    await tester.pumpWidget(_app(SpotErrorScreen(questions: [_pensando()])));
    await tester.pumpAndSettle();

    expect(find.text('Spot the error'), findsOneWidget);
    expect(find.text('Question 1 of 1'), findsOneWidget);
    expect(find.text('Grammar error · Prepositions'), findsOneWidget);
    // The question is inside the card, once.
    expect(find.text(SpotErrorChoice.question), findsOneWidget);
    expect(find.text(PromptCard.originalLabel), findsNothing);
    expect(find.byTooltip(SpotErrorChoice.correctLabel), findsOneWidget);
    expect(find.byTooltip(SpotErrorChoice.needsFixingLabel), findsOneWidget);
    expect(find.text('Estoy pensando de mudarme a Glasgow.'), findsOneWidget);
    expect(_field, findsNothing);
    expect(_button(tester).label, 'Check');
    expect(_button(tester).onPressed, isNull);
  });

  testWidgets('"It needs fixing" turns the sentence into the prefilled '
      'field; edit enables Check', (tester) async {
    await tester.pumpWidget(_app(SpotErrorScreen(questions: [_pensando()])));
    await tester.pumpAndSettle();

    await _pick(tester, SpotErrorChoice.needsFixingLabel);
    expect(_field, findsOneWidget);
    expect(
      tester.widget<TextField>(_field).controller!.text,
      'Estoy pensando de mudarme a Glasgow.',
    );
    expect(find.text(PromptCard.fixLabel), findsOneWidget);
    expect(
      _choiceState(tester, SpotErrorChoice.needsFixingLabel),
      SpotErrorButtonState.chosen,
    );
    expect(_button(tester).onPressed, isNull);

    await tester.enterText(_field, 'Estoy pensando en mudarme a Glasgow.');
    await tester.pump();
    expect(_button(tester).onPressed, isNotNull);

    // Switching to "It's correct" shows the sentence again and allows Check.
    await _pick(tester, SpotErrorChoice.correctLabel);
    expect(_field, findsNothing);
    expect(find.text('Estoy pensando de mudarme a Glasgow.'), findsOneWidget);
    expect(_button(tester).onPressed, isNotNull);

    // Back to "It needs fixing": the typed text is kept.
    await _pick(tester, SpotErrorChoice.needsFixingLabel);
    expect(
      tester.widget<TextField>(_field).controller!.text,
      'Estoy pensando en mudarme a Glasgow.',
    );
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

    // "Correct" in the toast and the explanation card's heading.
    expect(find.text(ResultToast.correctText), findsNWidgets(2));
    // The field is replaced by the corrected version.
    expect(_field, findsNothing);
    expect(
      _choiceState(tester, SpotErrorChoice.needsFixingLabel),
      SpotErrorButtonState.chosen,
    );
    expect(
      _choiceState(tester, SpotErrorChoice.correctLabel),
      SpotErrorButtonState.dimmed,
    );
    expect(find.text(PromptCard.correctedLabel), findsOneWidget);
    expect(find.byType(ExplanationCard), findsOneWidget);
    expect(
      tester.widget<ExplanationCard>(find.byType(ExplanationCard)).result,
      isTrue,
    );
    expect(find.text('You wrote'), findsNothing);

    await _letToastGo(tester);
    await tester.tap(find.text('Next question'));
    await tester.pumpAndSettle();

    expect(find.text('Question 2 of 2'), findsOneWidget);
    expect(_field, findsNothing);
    expect(
      _choiceState(tester, SpotErrorChoice.correctLabel),
      SpotErrorButtonState.resting,
    );
    expect(find.byType(ExplanationCard), findsNothing);
  });

  testWidgets('correct sentence, "It\'s correct": Correct, no corrected '
      'version', (tester) async {
    await tester.pumpWidget(_app(SpotErrorScreen(questions: [_depende()])));
    await tester.pumpAndSettle();

    await _pick(tester, SpotErrorChoice.correctLabel);
    await _checkNow(tester);

    expect(find.text(ResultToast.correctText), findsNWidgets(2));
    expect(
      _choiceState(tester, SpotErrorChoice.correctLabel),
      SpotErrorButtonState.chosen,
    );
    expect(find.text(PromptCard.correctedLabel), findsNothing);
    expect(find.text('Depende del tiempo que haga.'), findsOneWidget);
  });

  testWidgets('wrong sentence, "It\'s correct": Not quite, ✓ keeps its '
      'chosen style, You wrote', (tester) async {
    await tester.pumpWidget(_app(SpotErrorScreen(questions: [_pensando()])));
    await tester.pumpAndSettle();

    await _pick(tester, SpotErrorChoice.correctLabel);
    await _checkNow(tester);

    expect(find.text(ResultToast.wrongText), findsNWidgets(2));
    // The buttons label the sentence, not the learner's result.
    expect(
      _choiceState(tester, SpotErrorChoice.correctLabel),
      SpotErrorButtonState.chosen,
    );
    expect(
      _choiceState(tester, SpotErrorChoice.needsFixingLabel),
      SpotErrorButtonState.dimmed,
    );
    expect(find.text(PromptCard.correctedLabel), findsOneWidget);
    expect(find.text('You wrote'), findsOneWidget);
    expect(
      tester.widget<ExplanationCard>(find.byType(ExplanationCard)).result,
      isFalse,
    );
  });

  testWidgets('right choice, wrong fix: Not quite; then See results and '
      'Play again', (tester) async {
    await tester.pumpWidget(_app(SpotErrorScreen(questions: [_pensando()])));
    await tester.pumpAndSettle();

    await _pick(tester, SpotErrorChoice.needsFixingLabel);
    await tester.enterText(_field, 'Estoy pensando a mudarme a Glasgow.');
    await tester.pump();
    await _checkNow(tester);

    expect(find.text(ResultToast.wrongText), findsNWidgets(2));
    expect(_field, findsNothing);
    expect(find.text(PromptCard.correctedLabel), findsOneWidget);
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

    expect(find.text(ResultToast.wrongText), findsNWidgets(2));
    expect(
      _choiceState(tester, SpotErrorChoice.correctLabel),
      SpotErrorButtonState.dimmed,
    );
    expect(
      _choiceState(tester, SpotErrorChoice.needsFixingLabel),
      SpotErrorButtonState.chosen,
    );
    // The card shows the sentence as it was.
    expect(find.text(PromptCard.correctedLabel), findsNothing);
    expect(_field, findsNothing);
    expect(find.text('Depende del tiempo que haga.'), findsOneWidget);
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
