/// Screenshots of the Choose a correction screen (B3) at the three sizes.
/// UI spec section 11: the marked state before answering, a missing-word
/// question, and the corrected sentence after checking (right and wrong);
/// on phones the checked state with the toast showing and after it has
/// gone.
///
/// The screen is driven as a learner would: tap an option, tap Check.
///
/// - `choose-correction_marked_<size>`: question 1, nothing chosen.
/// - `choose-correction_missing-word_<size>`: a `missing_word` question.
/// - `choose-correction_chosen_<size>`: an option picked, before checking.
/// - `choose-correction_checked-right-toast_<phone|landscape>` and
///   `choose-correction_checked-right_<size>`: right answer.
/// - `choose-correction_checked-wrong-toast_<phone|landscape>` and
///   `choose-correction_checked-wrong_<size>`: wrong answer.
/// - `choose-correction_missing-word-checked-wrong-toast_<phone|landscape>`
///   and `choose-correction_missing-word-checked-wrong_<size>`: the
///   missing-word question answered wrong (two marked words, U5).
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/screens/choose_correction_screen.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';
import 'package:spanish_companion_games/widgets/widgets.dart';

import 'golden_helpers.dart';

const _screen = 'choose-correction';

// The first four sample questions (assets/questions.sample.json).
Question _pensar() => Question(
  id: '2026-10-17-001',
  game: GameType.chooseCorrection,
  category: 'Prepositions',
  type: QuestionType.grammar,
  prompt: 'Estoy pensando **de** cambiar de trabajo.',
  answers: const ['en'],
  options: const ['en', 'a', 'por'],
  explanation: 'pensar en + infinitive = to be thinking of doing something',
);

Question _cansada() => Question(
  id: '2026-10-17-002',
  game: GameType.chooseCorrection,
  category: 'Ser/estar',
  type: QuestionType.grammar,
  prompt: 'Mi hermana **es** muy cansada hoy.',
  answers: const ['está'],
  options: const ['está', 'estaba', 'sea'],
  explanation: 'estar cansado = to be tired (a state right now, so estar)',
);

Question _aplicar() => Question(
  id: '2026-10-17-003',
  game: GameType.chooseCorrection,
  category: 'False friend',
  type: QuestionType.note,
  prompt: 'Voy a **aplicar para** el trabajo.',
  answers: const ['solicitar'],
  options: const ['solicitar', 'aplicar a', 'aplicar por'],
  explanation: 'solicitar un trabajo = to apply for a job',
);

Question _verAMis() => Question(
  id: '2026-10-17-004',
  game: GameType.chooseCorrection,
  category: 'Personal a',
  type: QuestionType.grammar,
  prompt: 'Voy a **ver mis** padres el domingo.',
  answers: const ['ver a mis'],
  options: const ['ver a mis', 'ver a los', 'ver de mis'],
  missingWord: true,
  explanation:
      'ver a + person = the personal a goes before a person who is the object',
);

void main() {
  setUpAll(setUpGoldens);

  Future<void> start(
    WidgetTester tester,
    ScreenSize size,
    List<Question> questions,
  ) async {
    setScreenSize(tester, size);
    await tester.pumpWidget(
      _App(child: ChooseCorrectionScreen(questions: questions)),
    );
    await settle(tester);
  }

  Future<void> choose(WidgetTester tester, String option) async {
    await tester.tap(find.widgetWithText(AnswerOption, option));
    await settle(tester);
  }

  /// Taps Check (the bottom button, or the top-bar link in landscape) and,
  /// on phones, takes a screenshot with the toast up, then lets it go.
  Future<void> check(
    WidgetTester tester,
    ScreenSize size,
    String state,
  ) async {
    await tester.tap(find.text('Check'));
    final phone = FormFactor.fromSize(size.size) != FormFactor.laptop;
    if (phone) {
      // Toast up (the slide takes 150 ms).
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
      // Wait for it to go (about 2.5 s, then the slide down).
      await tester.pump(const Duration(seconds: 3));
    }
    await settle(tester);
    await expectLater(
      find.byType(_App),
      matchesGoldenFile(goldenName(_screen, state, size)),
    );
  }

  for (final size in ScreenSize.values) {
    testWidgets('choose a correction marked, ${size.name}', (tester) async {
      await start(tester, size, [_pensar(), _cansada(), _aplicar()]);
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName(_screen, 'marked', size)),
      );
    });

    testWidgets('choose a correction missing word, ${size.name}', (
      tester,
    ) async {
      await start(tester, size, [_verAMis(), _pensar()]);
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName(_screen, 'missing-word', size)),
      );
    });

    // A marked span of two words, after checking: the joined highlight
    // before, and the corrected sentence with the added word (U5).
    testWidgets(
      'choose a correction missing word checked wrong, ${size.name}',
      (tester) async {
        await start(tester, size, [_verAMis(), _pensar()]);
        await choose(tester, 'ver a los');
        await check(tester, size, 'missing-word-checked-wrong');
      },
    );

    testWidgets('choose a correction chosen, ${size.name}', (tester) async {
      await start(tester, size, [_pensar(), _cansada(), _aplicar()]);
      await choose(tester, 'a');
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName(_screen, 'chosen', size)),
      );
    });

    testWidgets('choose a correction checked right, ${size.name}', (
      tester,
    ) async {
      await start(tester, size, [_pensar(), _cansada(), _aplicar()]);
      await choose(tester, 'en');
      await check(tester, size, 'checked-right');
    });

    testWidgets('choose a correction checked wrong, ${size.name}', (
      tester,
    ) async {
      await start(tester, size, [_pensar(), _cansada(), _aplicar()]);
      await choose(tester, 'a');
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
