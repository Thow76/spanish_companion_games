/// Screenshots of the Fill the gap screen (B14) at the three sizes.
/// UI spec section 11: before answering, an answer picked or typed, and
/// after checking (right and wrong); on phones the checked state with the
/// toast showing and after it has gone. Both modes: options and typed.
///
/// - `fill-gap_empty_<size>`: option question, nothing picked.
/// - `fill-gap_chosen_<size>`: an option picked, before checking.
/// - `fill-gap_checked-right[-toast]_<size>`, `fill-gap_checked-wrong[-toast]_<size>`
/// - `fill-gap_typed-empty_<size>`: typed question, empty field.
/// - `fill-gap_typed_<size>`: a word typed, before checking.
/// - `fill-gap_typed-wrong[-toast]_<size>`: a wrong typed word, checked.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/screens/fill_gap_screen.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';
import 'package:spanish_companion_games/widgets/widgets.dart';

import 'golden_helpers.dart';

const _screen = 'fill-gap';

// The two fill_gap questions in assets/questions.sample.json.
Question _depende() => Question(
  id: '2026-10-17-008',
  game: GameType.fillGap,
  category: 'Prepositions',
  type: QuestionType.grammar,
  prompt: 'Depende ___ tiempo que haga.',
  answers: const ['del'],
  options: const ['del', 'de', 'en', 'al'],
  explanation: 'depender de = to depend on',
);

Question _espero() => Question(
  id: '2026-10-17-009',
  game: GameType.fillGap,
  category: 'Verb forms',
  type: QuestionType.grammar,
  prompt: 'Espero que ___ buen tiempo mañana.',
  answers: const ['haga'],
  explanation:
      'esperar que + subjunctive = to hope that (no options here, so the '
      'learner types)',
);

void main() {
  setUpAll(setUpGoldens);

  Future<void> start(
    WidgetTester tester,
    ScreenSize size,
    List<Question> questions,
  ) async {
    setScreenSize(tester, size);
    await tester.pumpWidget(_App(child: FillGapScreen(questions: questions)));
    await settle(tester);
  }

  Future<void> pick(WidgetTester tester, String option) async {
    await tester.tap(find.widgetWithText(AnswerOption, option));
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

  Future<void> shot(WidgetTester tester, ScreenSize size, String state) =>
      expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName(_screen, state, size)),
      );

  for (final size in ScreenSize.values) {
    testWidgets('fill gap empty, ${size.name}', (tester) async {
      await start(tester, size, [_depende(), _espero()]);
      await shot(tester, size, 'empty');
    });

    testWidgets('fill gap chosen, ${size.name}', (tester) async {
      await start(tester, size, [_depende(), _espero()]);
      await pick(tester, 'de');
      await shot(tester, size, 'chosen');
    });

    testWidgets('fill gap checked right, ${size.name}', (tester) async {
      await start(tester, size, [_depende(), _espero()]);
      await pick(tester, 'del');
      await check(tester, size, 'checked-right');
    });

    testWidgets('fill gap checked wrong, ${size.name}', (tester) async {
      await start(tester, size, [_depende(), _espero()]);
      await pick(tester, 'de');
      await check(tester, size, 'checked-wrong');
    });

    testWidgets('fill gap typed empty, ${size.name}', (tester) async {
      await start(tester, size, [_espero(), _depende()]);
      await shot(tester, size, 'typed-empty');
    });

    testWidgets('fill gap typed, ${size.name}', (tester) async {
      await start(tester, size, [_espero(), _depende()]);
      await type(tester, 'haga');
      await shot(tester, size, 'typed');
    });

    testWidgets('fill gap typed wrong, ${size.name}', (tester) async {
      await start(tester, size, [_espero(), _depende()]);
      await type(tester, 'hace');
      await check(tester, size, 'typed-wrong');
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
