/// Screenshots of Repair the sentence with the focus line and the hint
/// (B22) at the three sizes.
///
/// - `repair-hint_focus_<size>`: before answering, the focus line above the
///   field.
/// - `repair-hint_hint_<size>`: after a wrong first try, the hint under the
///   field and the field still editable (phones: with the toast showing,
///   `-toast`, and after it has gone).
/// - `repair-hint_right-with-hint_<size>`: right on the second try.
/// - `repair-hint_wrong-after-hint_<size>`: wrong again on the second try.
/// - `repair-hint_fallback_<size>`: a question without `focus` or `hint`
///   after a wrong first try (category in both places).
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/screens/repair_screen.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';

import 'golden_helpers.dart';

const _screen = 'repair-hint';

// As in assets/questions.sample.json (2026-10-17-005 and -007).
Question _gente() => Question(
  id: '2026-10-17-005',
  game: GameType.repair,
  category: 'Agreement',
  type: QuestionType.grammar,
  prompt: 'El problema es muy difícil y **la gente están** cansada.',
  answers: const ['El problema es muy difícil y la gente está cansada.'],
  explanation:
      'la gente + singular verb = people (la gente is singular in Spanish)',
  focus: 'Verb agreement with la gente',
  hint: 'Is la gente one thing or many in Spanish?',
);

Question _sentido() => Question(
  id: '2026-10-17-007',
  game: GameType.repair,
  category: 'Calque',
  type: QuestionType.note,
  prompt: 'Esto no **hace sentido** para mí.',
  answers: const ['Esto no tiene sentido para mí.'],
  explanation: 'tener sentido = to make sense',
);

const _right = 'El problema es muy difícil y la gente está cansada.';
const _wrong1 = 'El problema es muy difícil y las gentes están cansada.';
const _wrong2 = 'El problema es muy difícil y la gente están cansadas.';

void main() {
  setUpAll(setUpGoldens);

  Future<void> start(
    WidgetTester tester,
    ScreenSize size,
    List<Question> questions,
  ) async {
    setScreenSize(tester, size);
    await tester.pumpWidget(_App(child: RepairScreen(questions: questions)));
    await settle(tester);
  }

  bool isPhone(ScreenSize size) =>
      FormFactor.fromSize(size.size) != FormFactor.laptop;

  /// Types [text] and checks. With [shot], takes the screenshot(s): on
  /// phones with the toast showing and after it has gone.
  Future<void> tryText(
    WidgetTester tester,
    ScreenSize size,
    String text, {
    String? shot,
  }) async {
    await tester.enterText(find.byType(TextField), text);
    await settle(tester);
    await tester.tap(find.text('Check'));
    if (isPhone(size)) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      if (shot != null) {
        await expectLater(
          find.byType(_App),
          matchesGoldenFile(goldenName(_screen, '$shot-toast', size)),
        );
      }
      await tester.pump(const Duration(seconds: 3));
    }
    await settle(tester);
    if (shot != null) {
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName(_screen, shot, size)),
      );
    }
  }

  for (final size in ScreenSize.values) {
    testWidgets('repair hint focus, ${size.name}', (tester) async {
      await start(tester, size, [_gente(), _sentido()]);
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName(_screen, 'focus', size)),
      );
    });

    testWidgets('repair hint after a wrong first try, ${size.name}', (
      tester,
    ) async {
      await start(tester, size, [_gente(), _sentido()]);
      await tryText(tester, size, _wrong1, shot: 'hint');
    });

    testWidgets('repair right with a hint, ${size.name}', (tester) async {
      await start(tester, size, [_gente(), _sentido()]);
      await tryText(tester, size, _wrong1);
      await tryText(tester, size, _right, shot: 'right-with-hint');
    });

    testWidgets('repair wrong after the hint, ${size.name}', (tester) async {
      await start(tester, size, [_gente(), _sentido()]);
      await tryText(tester, size, _wrong1);
      await tryText(tester, size, _wrong2, shot: 'wrong-after-hint');
    });

    testWidgets('repair hint fallback, ${size.name}', (tester) async {
      await start(tester, size, [_sentido()]);
      await tryText(tester, size, 'Esto no hace sentido a mí.');
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName(_screen, 'fallback', size)),
      );
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
