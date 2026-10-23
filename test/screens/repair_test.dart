/// Behaviour of the Repair the sentence screen (B5): the prefilled field,
/// Check enabled once the text changes, whole sentence or only the part,
/// the corrected sentence and explanation, next question, the score.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/screens/game_placeholder_screen.dart';
import 'package:spanish_companion_games/screens/repair_screen.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';
import 'package:spanish_companion_games/widgets/widgets.dart';

Question _sentido() => Question(
  id: '1',
  game: GameType.repair,
  category: 'Calque',
  type: QuestionType.note,
  prompt: 'Esto no **hace sentido** para mí.',
  answers: const ['Esto no tiene sentido para mí.'],
  explanation: 'tener sentido = to make sense',
);

Question _gente() => Question(
  id: '2',
  game: GameType.repair,
  category: 'Agreement',
  type: QuestionType.grammar,
  prompt: 'El problema es muy difícil y **la gente están** cansada.',
  answers: const ['El problema es muy difícil y la gente está cansada.'],
  explanation: 'la gente + singular verb = people (la gente is singular)',
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

String _fieldText(WidgetTester tester) =>
    tester.widget<TextField>(_field).controller!.text;

PrimaryButton _button(WidgetTester tester) =>
    tester.widget<PrimaryButton>(find.byType(PrimaryButton));

AnswerFieldState _fieldState(WidgetTester tester) =>
    tester.widget<AnswerField>(find.byType(AnswerField)).state;

Future<void> _letToastGo(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('prefilled with the sentence without marks; Check disabled', (
    tester,
  ) async {
    await tester.pumpWidget(_app(RepairScreen(questions: [_sentido()])));
    await tester.pumpAndSettle();

    expect(find.text('Repair the sentence'), findsOneWidget);
    expect(find.text('Question 1 of 1'), findsOneWidget);
    expect(find.text('Language note · Calque'), findsOneWidget);
    expect(find.text(RepairScreen.instruction), findsOneWidget);
    expect(find.text(PromptCard.originalLabel), findsOneWidget);
    expect(find.text(AnswerField.repairCaption), findsOneWidget);
    expect(_fieldText(tester), 'Esto no hace sentido para mí.');
    expect(find.textContaining('**'), findsNothing);
    expect(_button(tester).label, 'Check');
    expect(_button(tester).onPressed, isNull);
  });

  testWidgets('editing enables Check; undoing the edit disables it', (
    tester,
  ) async {
    await tester.pumpWidget(_app(RepairScreen(questions: [_sentido()])));
    await tester.pumpAndSettle();

    await tester.enterText(_field, 'Esto no tiene sentido para mí.');
    await tester.pump();
    expect(_button(tester).onPressed, isNotNull);

    await tester.enterText(_field, 'Esto no hace sentido para mí.');
    await tester.pump();
    expect(_button(tester).onPressed, isNull);
  });

  testWidgets('the whole sentence, right: Correct, corrected sentence', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(RepairScreen(questions: [_sentido(), _gente()])),
    );
    await tester.pumpAndSettle();

    await tester.enterText(_field, 'esto no tiene sentido para mí');
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text(ResultToast.correctText), findsOneWidget);
    expect(_fieldState(tester), AnswerFieldState.correct);
    expect(find.text(PromptCard.correctedLabel), findsOneWidget);
    expect(find.byType(ExplanationCard), findsOneWidget);
    expect(find.text('You wrote'), findsNothing);

    await _letToastGo(tester);
    await tester.tap(find.text('Next question'));
    await tester.pumpAndSettle();

    expect(find.text('Question 2 of 2'), findsOneWidget);
    expect(_fieldState(tester), AnswerFieldState.editing);
    expect(
      _fieldText(tester),
      'El problema es muy difícil y la gente están cansada.',
    );
    expect(find.byType(ExplanationCard), findsNothing);
  });

  testWidgets('only the part for the marked words is accepted', (
    tester,
  ) async {
    await tester.pumpWidget(_app(RepairScreen(questions: [_sentido()])));
    await tester.pumpAndSettle();

    await tester.enterText(_field, 'tiene sentido');
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text(ResultToast.correctText), findsOneWidget);
    expect(_fieldState(tester), AnswerFieldState.correct);
  });

  testWidgets('a wrong answer: Not quite, You wrote, See results', (
    tester,
  ) async {
    await tester.pumpWidget(_app(RepairScreen(questions: [_sentido()])));
    await tester.pumpAndSettle();

    await tester.enterText(_field, 'Esto no hace un sentido para mí.');
    await tester.pump();
    await tester.tap(find.text('Check'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text(ResultToast.wrongText), findsOneWidget);
    expect(_fieldState(tester), AnswerFieldState.wrong);
    expect(find.text(PromptCard.correctedLabel), findsOneWidget);
    expect(find.text('You wrote'), findsOneWidget);

    await _letToastGo(tester);
    expect(find.text('See results'), findsOneWidget);
    await tester.tap(find.text('See results'));
    await tester.pumpAndSettle();
    expect(find.text('Session complete'), findsOneWidget);
    expect(find.text('You got 0 of 1 right.'), findsOneWidget);

    await tester.tap(find.text('Play again'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 1'), findsOneWidget);
    expect(_fieldText(tester), 'Esto no hace sentido para mí.');
  });

  test('learnerSentence puts a short part in place of the marked words', () {
    final q = _sentido();
    expect(
      RepairScreen.learnerSentence(q, 'tiene un'),
      'Esto no tiene un para mí.',
    );
    expect(
      RepairScreen.learnerSentence(q, 'Esto no hace un sentido para mí.'),
      'Esto no hace un sentido para mí.',
    );
  });

  testWidgets('the home screen route opens Repair for repair questions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        GamePlaceholderScreen(game: GameType.repair, questions: [_sentido()]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(RepairScreen), findsOneWidget);
  });
}
