/// Screenshots of the set picker (B24) at the three sizes, on the sample
/// questions. A stand-in look until U18.
///
/// - `set-picker_recall_<size>`: "Recall" tapped on home: sets of 5,
///   oldest first, "By conversation" off.
/// - `set-picker_by-conversation_<size>`: "Recall" with "By conversation"
///   on: one set per conversation, with its date.
/// - `set-picker_new-filter_<size>`: "New corrections" with the filter
///   opened (Type and Category, no Phase row).
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/data/question_loader.dart';
import 'package:spanish_companion_games/models/question_parser.dart';
import 'package:spanish_companion_games/screens/home_screen.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';

import 'golden_helpers.dart';

void main() {
  late ParsedQuestions sample;

  setUpAll(() async {
    await setUpGoldens();
    await rootBundle.loadString(sampleQuestionsAsset);
    sample = await loadQuestionsFromAsset();
  });

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await settle(tester);
  }

  /// Back to the top of the page, so the top bar is in the picture.
  Future<void> scrollToTop(WidgetTester tester) async {
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 3000));
    await settle(tester);
  }

  Future<void> openPhase(
    WidgetTester tester,
    ScreenSize size,
    int phase,
  ) async {
    setScreenSize(tester, size);
    await tester.pumpWidget(
      _App(child: HomeScreen(source: () async => sample)),
    );
    await settle(tester);
    await tapVisible(tester, find.byKey(ValueKey('phase-card-$phase')));
  }

  for (final size in ScreenSize.values) {
    testWidgets('set picker, recall, ${size.name}', (tester) async {
      await openPhase(tester, size, 2);
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName('set-picker', 'recall', size)),
      );
    });

    testWidgets('set picker, by conversation, ${size.name}', (tester) async {
      await openPhase(tester, size, 2);
      await tapVisible(tester, find.byKey(const ValueKey('set-by-conversation')));
      await scrollToTop(tester);
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName('set-picker', 'by-conversation', size)),
      );
    });

    testWidgets('set picker, new corrections filter, ${size.name}', (
      tester,
    ) async {
      await openPhase(tester, size, 1);
      await tapVisible(tester, find.textContaining('Filter: '));
      await scrollToTop(tester);
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName('set-picker', 'new-filter', size)),
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
