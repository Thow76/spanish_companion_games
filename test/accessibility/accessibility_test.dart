/// Accessibility checks (U10, UI spec section 10): Flutter's tap-target,
/// labelled-target and text-contrast guidelines on every screen at the
/// three sizes, nothing overflowing at 200% text or at 320 wide, and
/// keyboard play (Tab, Enter) on a game.
///
/// An overflow (text or a row that does not fit) makes a widget test fail
/// on its own, so pumping each screen at 200% and at 320 wide is itself a
/// check that nothing is clipped.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/data/question_loader.dart';
import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/models/question_parser.dart';
import 'package:spanish_companion_games/screens/choose_correction_screen.dart';
import 'package:spanish_companion_games/screens/fill_gap_screen.dart';
import 'package:spanish_companion_games/screens/home_screen.dart';
import 'package:spanish_companion_games/screens/match_screen.dart';
import 'package:spanish_companion_games/screens/order_screen.dart';
import 'package:spanish_companion_games/screens/repair_screen.dart';
import 'package:spanish_companion_games/screens/spot_error_screen.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';
import 'package:spanish_companion_games/widgets/widgets.dart';

Widget _app(Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: appTheme(FormFactor.phone),
  builder: (context, child) => Theme(
    data: appTheme(FormFactor.of(context)),
    child: child ?? const SizedBox.shrink(),
  ),
  home: home,
);

Widget _game(GameType game, List<Question> questions) => switch (game) {
  GameType.chooseCorrection => ChooseCorrectionScreen(questions: questions),
  GameType.repair => RepairScreen(questions: questions),
  GameType.fillGap => FillGapScreen(questions: questions),
  GameType.match => MatchScreen(questions: questions),
  GameType.order => OrderScreen(questions: questions),
  GameType.spotError => SpotErrorScreen(questions: questions),
};

/// Spec section 4: touch targets at least 44×44 (48 preferred on phone,
/// 44 allowed in phone landscape and for the back chevron).
const _tapTarget44 = MinimumTapTargetGuideline(
  size: Size(44, 44),
  link: 'UI spec section 4',
);

const _sizes = <String, Size>{
  'phone': Size(390, 844),
  'landscape': Size(844, 390),
  'laptop': Size(1280, 800),
  '320': Size(320, 640),
};

void _setSize(WidgetTester tester, Size size, {double textScale = 1}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
}

void main() {
  late ParsedQuestions sample;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await rootBundle.loadString(sampleQuestionsAsset);
    sample = await loadQuestionsFromAsset();
  });

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(_app(HomeScreen(source: () async => sample)));
    await tester.pumpAndSettle();
  }

  group('guidelines', () {
    for (final size in _sizes.entries) {
      testWidgets('home, ${size.key}', (tester) async {
        final handle = tester.ensureSemantics();
        _setSize(tester, size.value);
        await pumpHome(tester);
        await expectLater(tester, meetsGuideline(_tapTarget44));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });

      for (final game in GameType.values) {
        testWidgets('${game.label}, ${size.key}', (tester) async {
          final handle = tester.ensureSemantics();
          _setSize(tester, size.value);
          await tester.pumpWidget(_app(_game(game, sample.questions)));
          await tester.pumpAndSettle();
          await expectLater(tester, meetsGuideline(_tapTarget44));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
          handle.dispose();
        });
      }
    }
  });

  group('200% text, nothing overflows', () {
    for (final size in _sizes.entries) {
      testWidgets('home, ${size.key}', (tester) async {
        _setSize(tester, size.value, textScale: 2);
        await pumpHome(tester);
        expect(tester.takeException(), isNull);
      });

      for (final game in GameType.values) {
        testWidgets('${game.label}, ${size.key}', (tester) async {
          _setSize(tester, size.value, textScale: 2);
          await tester.pumpWidget(_app(_game(game, sample.questions)));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('keyboard play', () {
    testWidgets('Choose a correction: Tab to an option, Enter to choose, '
        'Tab to Check, Enter to check, focus on Next question', (tester) async {
      _setSize(tester, const Size(1280, 800));
      await tester.pumpWidget(
        _app(ChooseCorrectionScreen(questions: sample.questions)),
      );
      await tester.pumpAndSettle();

      // Tab until an answer option has focus.
      String? focusedOption() {
        final focus = FocusManager.instance.primaryFocus;
        if (focus?.context == null) return null;
        final option = focus!.context!
            .findAncestorWidgetOfExactType<AnswerOption>();
        return option?.label;
      }

      for (var i = 0; i < 10 && focusedOption() == null; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      }
      final label = focusedOption();
      expect(label, isNotNull, reason: 'Tab reaches the answer options');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AnswerOption>(find.widgetWithText(AnswerOption, label!))
            .state,
        AnswerState.selected,
      );

      // Tab on to Check and press Enter.
      bool checkFocused() {
        final focus = FocusManager.instance.primaryFocus;
        return focus?.context
                ?.findAncestorWidgetOfExactType<PrimaryButton>()
                ?.label ==
            'Check';
      }

      for (var i = 0; i < 10 && !checkFocused(); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      }
      expect(checkFocused(), isTrue, reason: 'Tab reaches Check');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      final focused = FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<PrimaryButton>();
      expect(focused?.label, 'Next question');
    });

    testWidgets('Spot the error: choosing ✗ puts focus in the field', (
      tester,
    ) async {
      _setSize(tester, const Size(1280, 800));
      await tester.pumpWidget(
        _app(SpotErrorScreen(questions: sample.questions)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('It needs fixing'));
      await tester.pumpAndSettle();
      final field = tester.widget<EditableText>(find.byType(EditableText));
      expect(field.focusNode.hasFocus, isTrue);

      // Back to ✓: the field goes and focus leaves it.
      await tester.tap(find.byTooltip("It's correct"));
      await tester.pumpAndSettle();
      expect(find.byType(EditableText), findsNothing);
    });
  });
}
