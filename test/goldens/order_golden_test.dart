/// Screenshots of the Sentence ordering screen (B4) at the three sizes.
/// UI spec section 11: before answering, part-way, every word placed, and
/// after checking (right and wrong); on phones the checked state with the
/// toast showing and after it has gone.
///
/// - `order_start_<size>`: the shuffled words, nothing placed.
/// - `order_building_<size>`: three words placed.
/// - `order_placed_<size>`: every word placed, before checking.
/// - `order_checked-right[-toast]_<size>`, `order_checked-wrong[-toast]_<size>`
///
/// The words are shuffled with a seeded [Random], so the screenshots are
/// the same every run.
@Tags(['golden'])
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/screens/order_screen.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';
import 'package:spanish_companion_games/widgets/widgets.dart';

import 'golden_helpers.dart';

const _screen = 'order';

// The two order questions in assets/questions.sample.json.
Question _siempre() => Question(
  id: '2026-10-17-012',
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
  id: '2026-10-17-013',
  game: GameType.order,
  category: 'Pronouns',
  type: QuestionType.grammar,
  prompt: 'No se lo he dicho a nadie.',
  answers: const ['No se lo he dicho a nadie.'],
  explanation:
      'no + se + lo + verb = negation, then the indirect pronoun, then the '
      'direct pronoun',
);

const _nadieRight = ['No', 'se', 'lo', 'he', 'dicho', 'a', 'nadie.'];
const _nadieWrong = ['No', 'lo', 'se', 'he', 'dicho', 'a', 'nadie.'];

void main() {
  setUpAll(setUpGoldens);

  Future<void> start(WidgetTester tester, ScreenSize size) async {
    setScreenSize(tester, size);
    await tester.pumpWidget(
      _App(
        child: OrderScreen(
          questions: [_nadie(), _siempre()],
          random: Random(3),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> place(WidgetTester tester, List<String> words) async {
    for (final w in words) {
      await tester.tap(find.widgetWithText(AnswerOption, w));
      await tester.pumpAndSettle();
    }
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
    testWidgets('order start, ${size.name}', (tester) async {
      await start(tester, size);
      await shot(tester, size, 'start');
    });

    testWidgets('order building, ${size.name}', (tester) async {
      await start(tester, size);
      await place(tester, _nadieRight.take(3).toList());
      await shot(tester, size, 'building');
    });

    testWidgets('order placed, ${size.name}', (tester) async {
      await start(tester, size);
      await place(tester, _nadieRight);
      await shot(tester, size, 'placed');
    });

    testWidgets('order checked right, ${size.name}', (tester) async {
      await start(tester, size);
      await place(tester, _nadieRight);
      await check(tester, size, 'checked-right');
    });

    testWidgets('order checked wrong, ${size.name}', (tester) async {
      await start(tester, size);
      await place(tester, _nadieWrong);
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
