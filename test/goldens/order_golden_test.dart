/// Screenshots of the Sentence ordering screen (B4) at the three sizes.
/// UI spec section 11: before answering, part-way, every word placed, and
/// after checking (right and wrong); on phones the checked state with the
/// toast showing and after it has gone.
///
/// - `order_start_<size>`: the shuffled words, nothing placed.
/// - `order_building_<size>`: three words placed.
/// - `order_placed_<size>`: every word placed, before checking.
/// - `order_checked-right[-toast]_<size>`, `order_checked-wrong[-toast]_<size>`
/// - `order_long_<size>`: a 13-word sentence, half placed, to show the
///   chips wrapping (U6).
/// - `order_long-320_phone`: the same at 320×640, the narrowest width
///   (spec section 10: nothing scrolls sideways).
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

// Made up for the screenshots: a longer sentence than the sample has.
const _estacionSentence =
    'Cuando llegué a la estación, el tren ya se había ido sin nosotros.';

Question _estacion() => Question(
  id: 'u6-long',
  game: GameType.order,
  category: 'Verb forms',
  type: QuestionType.grammar,
  prompt: _estacionSentence,
  answers: const [_estacionSentence],
  explanation: 'ya se había ido = had already left (pluperfect)',
);

const _estacionHalf = ['Cuando', 'llegué', 'a', 'la', 'estación,', 'el'];

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
      final chip = find.widgetWithText(WordChip, w);
      // The long sentence's chips run below a landscape screen.
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
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

  Future<void> startLong(WidgetTester tester) async {
    await tester.pumpWidget(
      _App(
        child: OrderScreen(questions: [_estacion()], random: Random(3)),
      ),
    );
    await settle(tester);
    await place(tester, _estacionHalf);
  }

  testWidgets('order long sentence, 320 wide', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await startLong(tester);
    await expectLater(
      find.byType(_App),
      matchesGoldenFile('${_screen}_long-320_phone.png'),
    );
  });

  for (final size in ScreenSize.values) {
    testWidgets('order long sentence, ${size.name}', (tester) async {
      setScreenSize(tester, size);
      await startLong(tester);
      await shot(tester, size, 'long');
    });

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
