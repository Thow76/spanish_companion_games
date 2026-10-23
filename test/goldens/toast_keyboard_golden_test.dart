/// The result toast once it has gone, with the on-screen keyboard up
/// (U16). UI spec sections 6 and 11.
///
/// Before this fix a hidden toast stayed drawn, parked just below the
/// bottom edge. When the keyboard opened, that edge moved up and the old
/// "Correct" showed through a floating keyboard (phone landscape, Repair).
///
/// - `toast_keyboard-after-hide_<phone|landscape>`: a game frame after a
///   question was checked, the toast has gone and the keyboard is open.
///   Nothing should show at the bottom except the frame's own content.
/// - `toast_checked-cutout_landscape`: the toast showing in phone landscape
///   on a phone with a camera cutout on the left. Its left and right edges
///   should line up with the content above it, not run into the cutout.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';
import 'package:spanish_companion_games/widgets/widgets.dart';

import 'golden_helpers.dart';

/// Height of the stand-in keyboard. The real one covers this area; the
/// test leaves it empty, as a floating keyboard does.
const double _keyboard = 160;

void main() {
  setUpAll(setUpGoldens);

  for (final size in [ScreenSize.phone, ScreenSize.landscape]) {
    testWidgets('toast gone, keyboard up, ${size.name}', (tester) async {
      setScreenSize(tester, size);
      final result = ValueNotifier<bool?>(null);
      addTearDown(result.dispose);

      await tester.pumpWidget(_App(child: _Screen(result: result)));
      await settle(tester);

      // Checked: the toast slides up.
      result.value = true;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byType(ResultToast), findsOneWidget);

      // It goes by itself after about 2.5 s; then "Next question" clears
      // the result, as the game screens do.
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      result.value = null;
      await tester.pumpAndSettle();
      expect(find.byType(ResultToast), findsNothing);

      // The learner taps the text field: the keyboard comes up.
      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard);
      await tester.pumpAndSettle();
      expect(find.byType(ResultToast), findsNothing);

      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName('toast', 'keyboard-after-hide', size)),
      );

      // The next check still brings it back.
      result.value = false;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(ResultToast.wrongText), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });
  }

  testWidgets('toast showing, camera cutout, landscape', (tester) async {
    setScreenSize(tester, ScreenSize.landscape);
    // A camera cutout on the left and the gesture bar at the bottom, as on
    // Andrew's phone held with the camera on the left.
    tester.view.padding = const FakeViewPadding(left: 48, bottom: 20);
    final result = ValueNotifier<bool?>(null);
    addTearDown(result.dispose);

    await tester.pumpWidget(_App(child: _Screen(result: result)));
    await settle(tester);

    result.value = true;
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Left edges of the toast and the content line up.
    final toastLeft = tester.getTopLeft(find.byType(ResultToast)).dx;
    final textLeft = tester.getTopLeft(find.text('Question 3 of 3')).dx;
    expect(toastLeft, textLeft);

    await expectLater(
      find.byType(_App),
      matchesGoldenFile(
        goldenName('toast', 'checked-cutout', ScreenSize.landscape),
      ),
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}

/// A game frame with a title and one line of content; [result] drives the
/// toast.
class _Screen extends StatelessWidget {
  const _Screen({required this.result});

  final ValueNotifier<bool?> result;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool?>(
      valueListenable: result,
      builder: (context, value, _) {
        return GameFrame(
          topBar: GameTopBar(title: 'Repair the sentence', onBack: () {}),
          toastResult: value,
          toastId: value == null ? 0 : 1,
          children: const [
            Text('Question 3 of 3'),
            Text('Esto no hace sentido para mí.'),
          ],
        );
      },
    );
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
