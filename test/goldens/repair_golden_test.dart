/// Screenshots of the Repair the sentence screen (B5) at the three sizes.
/// UI spec section 11: the marked state before answering (field prefilled),
/// a missing-word question, an edited field before checking, and the
/// corrected sentence after checking (right and wrong); on phones the
/// checked state with the toast showing and after it has gone.
///
/// - `repair_marked_<size>`: question 1, field prefilled, nothing changed.
/// - `repair_missing-word_<size>`: a `missing_word` question.
/// - `repair_edited_<size>`: the field changed, before checking.
/// - `repair_checked-right-toast_<phone|landscape>`, `repair_checked-right_<size>`
/// - `repair_checked-wrong-toast_<phone|landscape>`, `repair_checked-wrong_<size>`
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/screens/repair_screen.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';

import 'golden_helpers.dart';

const _screen = 'repair';

// The three repair questions in assets/questions.sample.json.
Question _gente() => Question(
  id: '2026-10-17-005',
  game: GameType.repair,
  category: 'Agreement',
  type: QuestionType.grammar,
  prompt: 'El problema es muy difícil y **la gente están** cansada.',
  answers: const ['El problema es muy difícil y la gente está cansada.'],
  explanation:
      'la gente + singular verb = people (la gente is singular in Spanish)',
);

Question _gusta() => Question(
  id: '2026-10-17-006',
  game: GameType.repair,
  category: 'Agreement',
  type: QuestionType.grammar,
  prompt: '**Me gusta** los libros y **me gusta** las películas.',
  answers: const ['Me gustan los libros y me gustan las películas.'],
  explanation: 'me gustan + plural noun = gustar agrees with the thing liked',
);

Question _sentido() => Question(
  id: '2026-10-17-007',
  game: GameType.repair,
  category: 'Calque',
  type: QuestionType.note,
  prompt: 'Esto no **hace sentido** para mí.',
  answers: const ['Esto no tiene sentido para mí.'],
  explanation: 'tener sentido = to make sense',
);

// Not in the sample file: a missing-word repair question.
Question _llamo() => Question(
  id: 'test-missing-word',
  game: GameType.repair,
  category: 'Reflexive verbs',
  type: QuestionType.grammar,
  prompt: 'Hola, **llamo** Andrew y vivo en Aberdeen.',
  answers: const ['Hola, me llamo Andrew y vivo en Aberdeen.'],
  missingWord: true,
  explanation: 'llamarse = to be called (the me goes before the verb)',
);

void main() {
  setUpAll(setUpGoldens);

  Future<void> start(
    WidgetTester tester,
    ScreenSize size,
    List<Question> questions,
  ) async {
    setScreenSize(tester, size);
    await tester.pumpWidget(_App(child: RepairScreen(questions: questions)));
    await settle(tester);
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await settle(tester);
  }

  Future<void> check(
    WidgetTester tester,
    ScreenSize size,
    String state,
  ) async {
    await tester.tap(find.text('Check'));
    final phone = FormFactor.fromSize(size.size) != FormFactor.laptop;
    if (phone) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName(_screen, '$state-toast', size)),
      );
      await tester.pump(const Duration(seconds: 3));
    }
    await settle(tester);
    await expectLater(
      find.byType(_App),
      matchesGoldenFile(goldenName(_screen, state, size)),
    );
  }

  for (final size in ScreenSize.values) {
    testWidgets('repair marked, ${size.name}', (tester) async {
      await start(tester, size, [_gente(), _gusta(), _sentido()]);
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName(_screen, 'marked', size)),
      );
    });

    testWidgets('repair missing word, ${size.name}', (tester) async {
      await start(tester, size, [_llamo(), _gente()]);
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName(_screen, 'missing-word', size)),
      );
    });

    testWidgets('repair edited, ${size.name}', (tester) async {
      await start(tester, size, [_gente(), _gusta(), _sentido()]);
      await type(tester, 'El problema es muy difícil y la gente está cansada.');
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName(_screen, 'edited', size)),
      );
    });

    testWidgets('repair checked right, ${size.name}', (tester) async {
      await start(tester, size, [_gente(), _gusta(), _sentido()]);
      await type(tester, 'El problema es muy difícil y la gente está cansada.');
      await check(tester, size, 'checked-right');
    });

    testWidgets('repair checked wrong, ${size.name}', (tester) async {
      await start(tester, size, [_gente(), _gusta(), _sentido()]);
      await type(
        tester,
        'El problema es muy difícil y las gentes están cansadas.',
      );
      await check(tester, size, 'checked-wrong');
    });
  }
}

class _App extends StatelessWidget {
  const _App({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme(FormFactor.phone),
      builder: (context, child) => Theme(
        data: appTheme(FormFactor.of(context)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: child,
    );
  }
}
