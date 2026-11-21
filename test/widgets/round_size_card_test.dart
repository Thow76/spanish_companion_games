/// RoundSizeCard (U22): spoken labels, the chosen state, and taps.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/theme/app_spacing.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';
import 'package:spanish_companion_games/widgets/widgets.dart';

void main() {
  Future<List<int>> pump(WidgetTester tester, {int value = 5}) async {
    final picked = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(FormFactor.phone),
        home: Scaffold(
          body: Center(
            child: RoundSizeCard(
              sizes: const [5, 10],
              value: value,
              onChanged: picked.add,
              buttonKey: (n) => ValueKey('size-$n'),
            ),
          ),
        ),
      ),
    );
    return picked;
  }

  testWidgets('each size is a labelled button; the chosen one is selected', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('size-5'))),
      isSemantics(
        label: '5 questions per round',
        isButton: true,
        isSelected: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey('size-10'))),
      isSemantics(label: '10 questions per round', isSelected: false),
    );
    handle.dispose();
  });

  testWidgets('tapping the other size reports it; the chosen one does '
      'nothing', (tester) async {
    final picked = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('size-5')));
    await tester.tap(find.byKey(const ValueKey('size-10')));
    expect(picked, [10]);
  });

  testWidgets('buttons are at least 56 wide and 48 high on a phone', (
    tester,
  ) async {
    await pump(tester);
    final size = tester.getSize(find.byKey(const ValueKey('size-5')));
    expect(size.width, greaterThanOrEqualTo(RoundSizeCard.buttonMinWidth));
    expect(size.height, greaterThanOrEqualTo(AppSizes.phoneTarget));
  });
}
