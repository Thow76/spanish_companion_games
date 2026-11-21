/// Screenshots of the "Questions per round" choice on the home screen (U22,
/// behaviour from B32). UI spec sections 3, 4, 5, 6 (proposed
/// RoundSizeCard), 10 and 11.
///
/// - `home_round-size-10_<size>`: the sample questions with 10 chosen,
///   scrolled so the filter card is at the top with this card under it.
/// - `home_round-size-10-320_phone`: the same at 320×640.
/// - `home_round-size-text-200_<size>` and
///   `home_round-size-text-200-320_phone`: 5 chosen (the default) at 200%
///   text, where the buttons go under the label.
///
/// `<size>` is phone (390×844), landscape (844×390) or laptop (1280×800).
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/data/question_loader.dart';
import 'package:spanish_companion_games/models/question_parser.dart';
import 'package:spanish_companion_games/screens/home_screen.dart';
import 'package:spanish_companion_games/theme/app_spacing.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';

import 'golden_helpers.dart';

typedef _Shot = ({String suffix, String size, Size window});

const List<_Shot> _shots = [
  (suffix: '', size: 'phone', window: Size(390, 844)),
  (suffix: '', size: 'landscape', window: Size(844, 390)),
  (suffix: '', size: 'laptop', window: Size(1280, 800)),
  (suffix: '-320', size: 'phone', window: Size(320, 640)),
];

const _card = ValueKey('home-round-size');

void main() {
  late ParsedQuestions sample;

  setUpAll(() async {
    await setUpGoldens();
    await rootBundle.loadString(sampleQuestionsAsset);
    sample = await loadQuestionsFromAsset();
  });

  void setWindow(WidgetTester tester, _Shot shot, {double text = 1}) {
    tester.view.physicalSize = shot.window;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    if (text != 1) {
      tester.platformDispatcher.textScaleFactorTestValue = text;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }
  }

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(
      _App(child: HomeScreen(source: () async => sample)),
    );
    await settle(tester);
  }

  /// Scrolls the filter card to the top, so it and this card (just under
  /// it) are on screen. (ensureVisible puts its target at the top.)
  Future<void> showCard(WidgetTester tester) async {
    await tester.ensureVisible(find.byKey(const ValueKey('home-filter')));
    await tester.pumpAndSettle();
  }

  for (final shot in _shots) {
    testWidgets('round size 10 chosen, ${shot.size}${shot.suffix}', (
      tester,
    ) async {
      setWindow(tester, shot);
      await pumpHome(tester);
      await showCard(tester);
      await tester.tap(find.byKey(const ValueKey('round-size-10')));
      await settle(tester);
      expect(tester.takeException(), isNull);

      // One row, as high as the shut filter card (spec proposal: 56).
      expect(
        tester.getSize(find.byKey(_card)).height,
        moreOrLessEquals(AppSizes.optionPhone, epsilon: 0.5),
      );
      // Nothing sideways: the card fits the window.
      expect(
        tester.getRect(find.byKey(_card)).right,
        lessThanOrEqualTo(shot.window.width),
      );

      await expectLater(
        find.byType(_App),
        matchesGoldenFile('home_round-size-10${shot.suffix}_${shot.size}.png'),
      );
    });

    testWidgets('round size at 200%, ${shot.size}${shot.suffix}', (
      tester,
    ) async {
      setWindow(tester, shot, text: 2);
      await pumpHome(tester);
      await showCard(tester);
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byKey(_card)).right,
        lessThanOrEqualTo(shot.window.width),
      );
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(
          'home_round-size-text-200${shot.suffix}_${shot.size}.png',
        ),
      );
    });
  }
}

/// The app's theme around [child], without the debug banner.
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
