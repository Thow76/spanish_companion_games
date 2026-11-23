/// Screenshots of Sentence ordering with a fixed start and end (B31): a
/// long sentence where only the window around the correction is shuffled,
/// the rest shown as plain text before and after the chips.
///
/// - `order-fixed_start_<size>`: nothing placed yet.
/// - `order-fixed_building_<size>`: three words placed.
/// - `order-fixed_checked-wrong_<size>`: a wrong order, after the toast,
///   with the whole sentence as "Corrected version".
/// - `order-fixed_checked-right_<size>`: the right order, after the toast.
/// - `order-fixed_start-320_phone`: nothing placed, at 320×640.
/// - `order-fixed_building-320_phone`: three words placed, at 320×640.
/// - `order-fixed_text-200_<size>`: nothing placed, at 200% text.
/// - `order-fixed_text-200-320_phone`: three words placed, 200% text, 320.
///
/// The words are shuffled with a seeded [Random], so the screenshots are
/// the same every run. Look (U20): the fixed text is [FixedWords] among the
/// chips (muted, no box) and muted on the card, with a gap slot where the
/// words still go.
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

const _screen = 'order-fixed';

// The fixed-ends question in assets/questions.sample.json.
Question _llaves() => Question(
  id: 'SAMPLE-0002-sc1',
  game: GameType.order,
  category: 'Prepositions',
  type: QuestionType.grammar,
  prompt: 'me di cuenta de que había olvidado',
  answers: const ['me di cuenta de que había olvidado'],
  fixedStart: 'Cuando llegué a casa anoche,',
  fixedEnd: 'las llaves en el trabajo.',
  explanation: 'darse cuenta de que = to realise that',
);

const _wrong = ['me', 'di', 'cuenta', 'que', 'de', 'había', 'olvidado'];
const _right = ['me', 'di', 'cuenta', 'de', 'que', 'había', 'olvidado'];

void main() {
  setUpAll(setUpGoldens);

  Future<void> start(WidgetTester tester) async {
    await tester.pumpWidget(
      _App(
        child: OrderScreen(questions: [_llaves()], random: Random(3)),
      ),
    );
    await settle(tester);
  }

  Future<void> place(WidgetTester tester, List<String> words) async {
    for (final w in words) {
      final chip = find.widgetWithText(WordChip, w);
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();
    }
    // Back to the top, so the card shows in the screenshot.
    await tester.ensureVisible(find.byType(PromptCard));
    await tester.pumpAndSettle();
    await settle(tester);
  }

  Future<void> shot(WidgetTester tester, String file) =>
      expectLater(find.byType(_App), matchesGoldenFile(file));

  Future<void> check(WidgetTester tester) async {
    final button = find.text('Check');
    await tester.ensureVisible(button.first);
    await tester.pumpAndSettle();
    await tester.tap(button.first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
  }

  /// Nothing scrolls sideways: every chip and both fixed parts lie inside
  /// the window's width.
  void expectInsideWidth(WidgetTester tester) {
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    for (final finder in [find.byType(WordChip), find.byType(FixedWords)]) {
      for (final element in finder.evaluate()) {
        final box = element.renderObject! as RenderBox;
        final left = box.localToGlobal(Offset.zero).dx;
        expect(left, greaterThanOrEqualTo(0));
        expect(left + box.size.width, lessThanOrEqualTo(width + 0.5));
      }
    }
  }

  Future<void> narrow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('order fixed ends building, 320 wide', (tester) async {
    await narrow(tester);
    await start(tester);
    await place(tester, ['me', 'di', 'cuenta']);
    expectInsideWidth(tester);
    await shot(tester, '${_screen}_building-320_phone.png');
  });

  testWidgets('order fixed ends at 200% text, 320 wide', (tester) async {
    await narrow(tester);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await start(tester);
    await place(tester, ['me', 'di', 'cuenta']);
    expectInsideWidth(tester);
    await shot(tester, '${_screen}_text-200-320_phone.png');
  });

  testWidgets('order fixed ends start, 320 wide', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await start(tester);
    expectInsideWidth(tester);
    await shot(tester, '${_screen}_start-320_phone.png');
  });

  for (final size in ScreenSize.values) {
    testWidgets('order fixed ends start, ${size.name}', (tester) async {
      setScreenSize(tester, size);
      await start(tester);
      await shot(tester, goldenName(_screen, 'start', size));
    });

    testWidgets('order fixed ends building, ${size.name}', (tester) async {
      setScreenSize(tester, size);
      await start(tester);
      await place(tester, ['me', 'di', 'cuenta']);
      await shot(tester, goldenName(_screen, 'building', size));
    });

    testWidgets('order fixed ends checked wrong, ${size.name}', (tester) async {
      setScreenSize(tester, size);
      await start(tester);
      await place(tester, _wrong);
      await check(tester);
      await shot(tester, goldenName(_screen, 'checked-wrong', size));
    });

    testWidgets('order fixed ends checked right, ${size.name}', (tester) async {
      setScreenSize(tester, size);
      await start(tester);
      await place(tester, _right);
      await check(tester);
      await shot(tester, goldenName(_screen, 'checked-right', size));
    });

    testWidgets('order fixed ends at 200% text, ${size.name}', (tester) async {
      setScreenSize(tester, size);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await start(tester);
      await shot(tester, goldenName(_screen, 'text-200', size));
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
