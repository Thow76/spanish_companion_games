/// Screenshots of the home screen filter (B12) at the three sizes, on the
/// sample questions.
///
/// - `home-filter_open_<size>`: the filter card opened, "Grammar errors"
///   chosen, so the card reads "Filter: Grammar errors" over "12 of 15
///   questions" (or whatever the sample gives) and the three rows of
///   choices show.
/// - `home-filter_recall_<size>`: "Recall" chosen and the card shut again:
///   only the Recall group shows, its counts narrowed.
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
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await settle(tester);
  }

  Future<void> start(WidgetTester tester, ScreenSize size) async {
    setScreenSize(tester, size);
    await tester.pumpWidget(
      _App(child: HomeScreen(source: () async => sample)),
    );
    await settle(tester);
  }

  for (final size in ScreenSize.values) {
    testWidgets('home filter, open, ${size.name}', (tester) async {
      await start(tester, size);
      await tapVisible(tester, find.textContaining('Filter: '));
      await tapVisible(
        tester,
        find.byKey(const ValueKey('filter-Type-Grammar errors')),
      );
      await scrollToTop(tester);
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName('home-filter', 'open', size)),
      );
    });

    testWidgets('home filter, recall only, ${size.name}', (tester) async {
      await start(tester, size);
      await tapVisible(tester, find.textContaining('Filter: '));
      await tapVisible(
        tester,
        find.byKey(const ValueKey('filter-Phase-Recall')),
      );
      // Shut the card again.
      await tapVisible(tester, find.textContaining('Filter: '));
      await scrollToTop(tester);
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName('home-filter', 'recall', size)),
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
