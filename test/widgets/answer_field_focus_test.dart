/// AnswerField after a wrong first try (U21, Andrew on PR #50, 2026-11-20):
/// the coral border and cross are the only outline. The field keeps
/// keyboard focus for the second try, but the keyboard focus ring is not
/// drawn round it, so it never shows two boxes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';
import 'package:spanish_companion_games/widgets/widgets.dart';

Widget _field(
  TextEditingController controller,
  FocusNode focusNode,
  AnswerFieldState state,
) => MaterialApp(
  theme: appTheme(FormFactor.laptop),
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: AnswerField(
        controller: controller,
        focusNode: focusNode,
        state: state,
        semanticLabel: 'Your corrected sentence',
      ),
    ),
  ),
);

/// The ring is the only Positioned inside a FocusRing.
bool _ringShown() => find
    .descendant(of: find.byType(FocusRing), matching: find.byType(Positioned))
    .evaluate()
    .isNotEmpty;

void main() {
  setUp(() {
    // As after typing on a laptop: focus counts as keyboard focus.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
  });

  testWidgets('editing with keyboard focus keeps the focus ring', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Esto no hace sentido.');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _field(controller, focusNode, AnswerFieldState.editing),
    );
    focusNode.requestFocus();
    await tester.pump();

    expect(focusNode.hasFocus, isTrue);
    expect(_ringShown(), isTrue);
  });

  testWidgets('try again: coral only, no focus ring, still focused', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Esto no hace sentido.');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      _field(controller, focusNode, AnswerFieldState.editing),
    );
    focusNode.requestFocus();
    await tester.pump();

    await tester.pumpWidget(
      _field(controller, focusNode, AnswerFieldState.tryAgain),
    );
    await tester.pump();

    expect(focusNode.hasFocus, isTrue);
    expect(_ringShown(), isFalse);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    // Still editable for the second try.
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);

    // Back to editing once the text changes: the ring returns.
    await tester.pumpWidget(
      _field(controller, focusNode, AnswerFieldState.editing),
    );
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    expect(_ringShown(), isTrue);
  });
}
