/// Behaviour of the Choose a correction screen (B3): choose, check, the
/// corrected sentence and explanation, next question, the session score.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/screens/choose_correction_screen.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';
import 'package:spanish_companion_games/widgets/widgets.dart';

Question _pensar() => Question(
  id: '1',
  game: GameType.chooseCorrection,
  category: 'Prepositions',
  type: QuestionType.grammar,
  prompt: 'Estoy pensando **de** cambiar de trabajo.',
  answers: const ['en'],
  options: const ['en', 'a', 'por'],
  explanation: 'pensar en + infinitive = to be thinking of doing something',
);

Question _cansada() => Question(
  id: '2',
  game: GameType.chooseCorrection,
  category: 'Ser/estar',
  type: QuestionType.grammar,
  prompt: 'Mi hermana **es** muy cansada hoy.',
  answers: const ['está'],
  options: const ['está', 'estaba', 'sea'],
  explanation: 'estar cansado = to be tired',
);

Widget _app(List<Question> questions) => MaterialApp(
  theme: appTheme(FormFactor.phone),
  builder: (context, child) => Theme(
    data: appTheme(FormFactor.of(context)),
    child: child ?? const SizedBox.shrink(),
  ),
  home: ChooseCorrectionScreen(questions: questions),
);

/// The state of the AnswerOption labelled [label].
AnswerState _optionState(WidgetTester tester, String label) =>
    tester.widget<AnswerOption>(find.widgetWithText(AnswerOption, label)).state;

/// Lets the result toast come and go (150 ms up, about 2.5 s, 150 ms down).
/// Lets the result toast come up and go. The first pump builds the frame
/// that starts the toast's hide timer; without it the 3 s jump happens
/// before the timer exists, the toast stays up over the bottom button and
/// a tap on "Next question" lands on the toast instead.
Future<void> _letToastGo(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the first question marked, Check disabled', (
    tester,
  ) async {
    await tester.pumpWidget(_app([_pensar(), _cansada()]));
    await tester.pumpAndSettle();

    expect(find.text('Choose a correction'), findsOneWidget);
    expect(find.text('Question 1 of 2'), findsOneWidget);
    expect(find.text('Grammar error · Prepositions'), findsOneWidget);
    expect(find.text(ChooseCorrectionScreen.instruction), findsOneWidget);
    expect(find.text(PromptCard.originalLabel), findsOneWidget);
    // The marked word is drawn in its own inline box, without asterisks.
    expect(find.text('de'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);
    for (final option in ['en', 'a', 'por']) {
      expect(_optionState(tester, option), AnswerState.resting);
    }
    final check = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(check.label, 'Check');
    expect(check.onPressed, isNull);
  });

  testWidgets('choosing selects the option and enables Check', (tester) async {
    await tester.pumpWidget(_app([_pensar()]));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AnswerOption, 'a'));
    await tester.pumpAndSettle();

    expect(_optionState(tester, 'a'), AnswerState.selected);
    expect(_optionState(tester, 'en'), AnswerState.resting);
    final check = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
    expect(check.onPressed, isNotNull);

    // Changing your mind moves the selection.
    await tester.tap(find.widgetWithText(AnswerOption, 'en'));
    await tester.pumpAndSettle();
    expect(_optionState(tester, 'en'), AnswerState.selected);
    expect(_optionState(tester, 'a'), AnswerState.resting);
  });

  testWidgets('a right answer: Correct toast, corrected sentence, Next', (
    tester,
  ) async {
    await tester.pumpWidget(_app([_pensar(), _cansada()]));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AnswerOption, 'en'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text(ResultToast.correctText), findsOneWidget);
    expect(_optionState(tester, 'en'), AnswerState.correct);
    expect(_optionState(tester, 'a'), AnswerState.dimmed);
    expect(_optionState(tester, 'por'), AnswerState.dimmed);
    expect(find.text(PromptCard.correctedLabel), findsOneWidget);
    expect(find.byType(ExplanationCard), findsOneWidget);
    expect(find.text('You wrote'), findsNothing);

    // After checking the options are disabled.
    final option = tester.widget<AnswerOption>(
      find.widgetWithText(AnswerOption, 'a'),
    );
    expect(option.onPressed, isNull);

    await _letToastGo(tester);
    expect(find.text(ResultToast.correctText), findsNothing);
    expect(find.text('Next question'), findsOneWidget);

    await tester.tap(find.text('Next question'));
    await tester.pumpAndSettle();
    expect(find.text('Question 2 of 2'), findsOneWidget);
    expect(find.text('Grammar error · Ser/estar'), findsOneWidget);
    expect(find.text(PromptCard.originalLabel), findsOneWidget);
    expect(_optionState(tester, 'está'), AnswerState.resting);
    expect(find.byType(ExplanationCard), findsNothing);
  });

  testWidgets('a wrong answer: Not quite, You wrote, right option shown', (
    tester,
  ) async {
    await tester.pumpWidget(_app([_pensar()]));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AnswerOption, 'a'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text(ResultToast.wrongText), findsOneWidget);
    expect(_optionState(tester, 'a'), AnswerState.wrong);
    expect(_optionState(tester, 'en'), AnswerState.correct);
    expect(_optionState(tester, 'por'), AnswerState.dimmed);
    expect(find.text(PromptCard.correctedLabel), findsOneWidget);
    expect(find.text('You wrote'), findsOneWidget);

    await _letToastGo(tester);
    // The last question: "See results" instead of "Next question".
    expect(find.text('See results'), findsOneWidget);
  });

  testWidgets('See results shows the session score and Play again', (
    tester,
  ) async {
    await tester.pumpWidget(_app([_pensar(), _cansada()]));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AnswerOption, 'en'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check'));
    await _letToastGo(tester);
    await tester.tap(find.text('Next question'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(AnswerOption, 'sea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check'));
    await _letToastGo(tester);
    await tester.tap(find.text('See results'));
    await tester.pumpAndSettle();

    expect(find.text('Session complete'), findsOneWidget);
    expect(find.text('You got 1 of 2 right.'), findsOneWidget);

    await tester.tap(find.text('Play again'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 2'), findsOneWidget);
    expect(_optionState(tester, 'en'), AnswerState.resting);
  });

  testWidgets('the back chevron returns home', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(FormFactor.phone),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) =>
                        ChooseCorrectionScreen(questions: [_pensar()]),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a correction'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Choose a correction'), findsNothing);
  });

  testWidgets('questions from other games are skipped', (tester) async {
    final other = Question(
      id: '3',
      game: GameType.fillGap,
      category: 'x',
      type: QuestionType.grammar,
      prompt: 'Hola ___.',
      answers: const ['x'],
    );
    await tester.pumpWidget(_app([other, _pensar()]));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 1'), findsOneWidget);

    // A different tree first, so the screen starts afresh with the new
    // list instead of keeping the old state.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(_app([other]));
    await tester.pumpAndSettle();
    expect(find.text('No questions for this game yet.'), findsOneWidget);
  });
}
