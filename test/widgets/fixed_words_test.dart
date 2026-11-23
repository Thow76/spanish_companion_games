// FixedWords and the ordering form of PromptCard.plain (U20).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/theme/app_colors.dart';
import 'package:spanish_companion_games/theme/app_spacing.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';
import 'package:spanish_companion_games/widgets/widgets.dart';

Widget _app(Widget child) => MaterialApp(
  theme: appTheme(FormFactor.phone),
  home: Scaffold(body: Center(child: child)),
);

const _start = 'Cuando llegué a casa anoche,';
const _end = 'las llaves en el trabajo.';

void main() {
  group('FixedWords', () {
    testWidgets('muted text, chip height, not a button', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(const FixedWords(text: _start, place: FixedWordsPlace.start)),
      );

      final text = tester.widget<Text>(find.text(_start));
      expect(text.style?.color, AppColors.textMuted);
      expect(
        tester.getSize(find.byType(FixedWords)).height,
        greaterThanOrEqualTo(AppSizes.wordChip),
      );
      expect(find.byType(InkWell), findsNothing);
      expect(find.bySemanticsLabel('Fixed start: $_start'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the end is labelled as the end', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(const FixedWords(text: _end, place: FixedWordsPlace.end)),
      );
      expect(find.bySemanticsLabel('Fixed end: $_end'), findsOneWidget);
      handle.dispose();
    });
  });

  group('PromptCard.plain with fixed ends', () {
    testWidgets('a gap slot while words are still to place', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const PromptCard.plain(
            sentence: '$_start me di $_end',
            fixedStart: _start,
            fixedEnd: _end,
            window: 'me di',
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('$_start me di blank $_end'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('no slot once every word is placed', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          const PromptCard.plain(
            sentence: '$_start me di cuenta $_end',
            fixedStart: _start,
            fixedEnd: _end,
            window: 'me di cuenta',
            windowComplete: true,
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('$_start me di cuenta $_end'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('without fixed ends it is the plain sentence', (tester) async {
      await tester.pumpWidget(
        _app(const PromptCard.plain(sentence: 'No se lo he dicho a nadie.')),
      );
      expect(find.text('No se lo he dicho a nadie.'), findsOneWidget);
    });
  });
}
