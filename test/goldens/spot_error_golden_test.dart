/// Screenshots of the Spot the error screen (B15) at the three sizes. UI
/// spec section 11: a correct sentence and one that needs fixing; on phones
/// the checked state with the toast showing and after it has gone.
///
/// - `spot-error_start_<size>`: question 1, nothing chosen.
/// - `spot-error_fixing_<size>`: "It needs fixing" chosen, field prefilled.
/// - `spot-error_fixed_<size>`: the field edited, before checking.
/// - `spot-error_checked-right[-toast]_<size>`: a wrong sentence fixed right
///   ("Corrected version" on the card).
/// - `spot-error_checked-wrong[-toast]_<size>`: "It's correct" chosen for a
///   wrong sentence.
/// - `spot-error_fix-wrong[-toast]_<size>`: "It needs fixing" chosen, fixed
///   wrongly ("You wrote" with the typed sentence).
/// - `spot-error_correct-sentence[-toast]_<size>`: "It's correct" chosen
///   for a sentence that is already correct.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/screens/spot_error_screen.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';
import 'package:spanish_companion_games/widgets/widgets.dart';

import 'golden_helpers.dart';

const _screen = 'spot-error';

// The two spot_error questions in assets/questions.sample.json.
Question _pensando() => Question(
  id: '2026-10-17-014',
  game: GameType.spotError,
  category: 'Prepositions',
  type: QuestionType.grammar,
  prompt: 'Estoy pensando de mudarme a Glasgow.',
  answers: const ['Estoy pensando en mudarme a Glasgow.'],
  explanation: 'pensar en + infinitive = to be thinking of doing something',
);

Question _depende() => Question(
  id: '2026-10-17-015',
  game: GameType.spotError,
  category: 'Prepositions',
  type: QuestionType.grammar,
  prompt: 'Depende del tiempo que haga.',
  answers: const ['Depende del tiempo que haga.'],
  explanation: 'depender de + el = del (this sentence is already correct)',
);

void main() {
  setUpAll(setUpGoldens);

  Future<void> start(
    WidgetTester tester,
    ScreenSize size,
    List<Question> questions,
  ) async {
    setScreenSize(tester, size);
    await tester.pumpWidget(_App(child: SpotErrorScreen(questions: questions)));
    await settle(tester);
  }

  Future<void> pick(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await settle(tester);
  }

  Future<void> type(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await settle(tester);
  }

  Future<void> shot(WidgetTester tester, ScreenSize size, String state) =>
      expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName(_screen, state, size)),
      );

  Future<void> check(
    WidgetTester tester,
    ScreenSize size,
    String state,
  ) async {
    await tester.tap(find.text('Check'));
    final phone = FormFactor.fromSize(size.size) != FormFactor.laptop;
    if (phone) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await shot(tester, size, '$state-toast');
      await tester.pump(const Duration(seconds: 3));
    }
    await settle(tester);
    await shot(tester, size, state);
  }

  for (final size in ScreenSize.values) {
    testWidgets('spot error start, ${size.name}', (tester) async {
      await start(tester, size, [_pensando(), _depende()]);
      await shot(tester, size, 'start');
    });

    testWidgets('spot error fixing, ${size.name}', (tester) async {
      await start(tester, size, [_pensando(), _depende()]);
      await pick(tester, SpotErrorChoice.needsFixingLabel);
      await shot(tester, size, 'fixing');
    });

    testWidgets('spot error fixed, ${size.name}', (tester) async {
      await start(tester, size, [_pensando(), _depende()]);
      await pick(tester, SpotErrorChoice.needsFixingLabel);
      await type(tester, 'Estoy pensando en mudarme a Glasgow.');
      await shot(tester, size, 'fixed');
    });

    testWidgets('spot error checked right, ${size.name}', (tester) async {
      await start(tester, size, [_pensando(), _depende()]);
      await pick(tester, SpotErrorChoice.needsFixingLabel);
      await type(tester, 'Estoy pensando en mudarme a Glasgow.');
      await check(tester, size, 'checked-right');
    });

    testWidgets('spot error checked wrong, ${size.name}', (tester) async {
      await start(tester, size, [_pensando(), _depende()]);
      await pick(tester, SpotErrorChoice.correctLabel);
      await check(tester, size, 'checked-wrong');
    });

    testWidgets('spot error fix wrong, ${size.name}', (tester) async {
      await start(tester, size, [_pensando(), _depende()]);
      await pick(tester, SpotErrorChoice.needsFixingLabel);
      await type(tester, 'Estoy pensando a mudarme a Glasgow.');
      await check(tester, size, 'fix-wrong');
    });

    testWidgets('spot error correct sentence, ${size.name}', (tester) async {
      await start(tester, size, [_depende(), _pensando()]);
      await pick(tester, SpotErrorChoice.correctLabel);
      await check(tester, size, 'correct-sentence');
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
