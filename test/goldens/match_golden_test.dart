/// Screenshots of the Matching screen (B6) at the three sizes. UI spec
/// section 11: before answering, a tile picked, pairs matched, a wrong
/// pairing flashing, and once every pair is matched (right, and after a
/// wrong pairing); on phones the done state with the toast showing and
/// after it has gone.
///
/// - `match_start_<size>`: the two columns, nothing picked.
/// - `match_picked_<size>`: "pensar" picked, waiting for its partner.
/// - `match_matched_<size>`: two pairs matched.
/// - `match_wrong_<size>`: "depender" paired with "con", flashing coral.
/// - `match_checked-right[-toast]_<size>`, `match_checked-wrong[-toast]_<size>`
/// - `match_phrases_<size>`: the verb + noun question, phrase-length tiles.
///
/// The right column is shuffled with a seeded [Random], so the screenshots
/// are the same every run.
@Tags(['golden'])
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/screens/match_screen.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';
import 'package:spanish_companion_games/widgets/widgets.dart';

import 'golden_helpers.dart';

const _screen = 'match';

// The two match questions in assets/questions.sample.json.
Question _verbs() => Question(
  id: '2026-10-17-010',
  game: GameType.match,
  category: 'Prepositions',
  type: QuestionType.grammar,
  prompt: 'Match the verb to its preposition',
  pairs: const [
    MatchPair('pensar', 'en'),
    MatchPair('depender', 'de'),
    MatchPair('soñar', 'con'),
    MatchPair('empezar', 'a'),
  ],
  explanation:
      'pensar en, depender de, soñar con, empezar a = verbs that take a '
      'fixed preposition',
);

Question _nouns() => Question(
  id: '2026-10-17-011',
  game: GameType.match,
  category: 'Collocation',
  type: QuestionType.note,
  prompt: 'Match the verb to its noun',
  pairs: const [
    MatchPair('prestar', 'atención'),
    MatchPair('tomar', 'una decisión'),
    MatchPair('hacer', 'cola'),
    MatchPair('dar', 'un paseo'),
  ],
  explanation:
      'prestar atención, tomar una decisión, hacer cola, dar un paseo = '
      'fixed verb + noun pairs',
);

void main() {
  setUpAll(setUpGoldens);

  Future<void> start(
    WidgetTester tester,
    ScreenSize size, [
    List<Question>? questions,
  ]) async {
    setScreenSize(tester, size);
    await tester.pumpWidget(
      _App(
        child: MatchScreen(
          questions: questions ?? [_verbs(), _nouns()],
          random: Random(3),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(AnswerOption, label));
    await tester.pump();
  }

  /// Taps a pair and lets any wrong flash finish.
  Future<void> pair(WidgetTester tester, String left, String right) async {
    await tap(tester, left);
    await tap(tester, right);
    await tester.pump(MatchScreen.wrongFlash);
    await tester.pumpAndSettle();
  }

  Future<void> shot(WidgetTester tester, ScreenSize size, String state) =>
      expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName(_screen, state, size)),
      );

  /// Matches the last pair, which ends the question, and takes the done
  /// screenshots (with the toast on phones, then after it has gone).
  Future<void> finish(
    WidgetTester tester,
    ScreenSize size,
    String state,
    String left,
    String right,
  ) async {
    await tap(tester, left);
    await tap(tester, right);
    final phone = FormFactor.fromSize(size.size) != FormFactor.laptop;
    if (phone) {
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
    testWidgets('match start, ${size.name}', (tester) async {
      await start(tester, size);
      await shot(tester, size, 'start');
    });

    testWidgets('match picked, ${size.name}', (tester) async {
      await start(tester, size);
      await tap(tester, 'pensar');
      await settle(tester);
      await shot(tester, size, 'picked');
    });

    testWidgets('match matched, ${size.name}', (tester) async {
      await start(tester, size);
      await pair(tester, 'pensar', 'en');
      await pair(tester, 'depender', 'de');
      await settle(tester);
      await shot(tester, size, 'matched');
    });

    testWidgets('match wrong, ${size.name}', (tester) async {
      await start(tester, size);
      await pair(tester, 'pensar', 'en');
      await tap(tester, 'depender');
      await tap(tester, 'con');
      // Shorter than the flash, so the tiles are still coral.
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await shot(tester, size, 'wrong');
      await tester.pump(MatchScreen.wrongFlash);
      await tester.pumpAndSettle();
    });

    testWidgets('match checked right, ${size.name}', (tester) async {
      await start(tester, size);
      await pair(tester, 'pensar', 'en');
      await pair(tester, 'depender', 'de');
      await pair(tester, 'soñar', 'con');
      await finish(tester, size, 'checked-right', 'empezar', 'a');
    });

    testWidgets('match checked wrong, ${size.name}', (tester) async {
      await start(tester, size);
      await pair(tester, 'pensar', 'de');
      await pair(tester, 'pensar', 'en');
      await pair(tester, 'depender', 'de');
      await pair(tester, 'soñar', 'con');
      await finish(tester, size, 'checked-wrong', 'empezar', 'a');
    });

    testWidgets('match phrases, ${size.name}', (tester) async {
      await start(tester, size, [_nouns()]);
      await pair(tester, 'tomar', 'una decisión');
      await settle(tester);
      await shot(tester, size, 'phrases');
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
