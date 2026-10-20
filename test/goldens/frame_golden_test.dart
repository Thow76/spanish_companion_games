/// Screenshots of the responsive frame (U3) at the three sizes. UI spec
/// sections 5 and 11.
///
/// The frames are filled with the U2 widgets and a question like the
/// sample ones, so the pictures show where everything goes on each screen
/// size. The real home and game screens move onto these frames in U4 and
/// U5 onwards.
///
/// - `frame-home_loaded_<size>`: home frame with the top bar, both phase
///   groups and the footer line.
/// - `frame-game_chosen_<size>`: Choose a correction, an option picked,
///   before checking.
/// - `frame-game_checked-toast_<phone|landscape>`: after a wrong answer,
///   with the result toast showing.
/// - `frame-game_checked_<size>`: after a wrong answer, toast gone (laptop:
///   feedback panel in the side panel).
/// - `frame-game_phrases_<size>`: phrase-length options (fewer columns).
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/theme/app_layout.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/app_typography.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';
import 'package:spanish_companion_games/widgets/widgets.dart';

import 'golden_helpers.dart';

const _sentence = 'Estoy pensando **de** cambiar de trabajo.';
const _options = ['en', 'a', 'por'];
const _answer = 'en';
const _wrongChoice = 'a';
const _explanation =
    'pensar en + infinitive = to be thinking of doing something';

const _phraseSentence =
    'Cuando era pequeño **me recordaba de** las historias de mi abuela.';
const _phraseOptions = [
  'me acordaba de',
  'recordaba de',
  'me recordaba a las',
  'acordaba',
];

void main() {
  setUpAll(setUpGoldens);

  for (final size in ScreenSize.values) {
    testWidgets('frame home, ${size.name}', (tester) async {
      setScreenSize(tester, size);
      await tester.pumpWidget(const _App(child: _HomeSample()));
      await settle(tester);
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName('frame-home', 'loaded', size)),
      );
    });

    testWidgets('frame game chosen, ${size.name}', (tester) async {
      setScreenSize(tester, size);
      await tester.pumpWidget(
        const _App(child: _GameSample(stage: _Stage.chosen)),
      );
      await settle(tester);
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName('frame-game', 'chosen', size)),
      );
    });

    testWidgets('frame game checked, ${size.name}', (tester) async {
      setScreenSize(tester, size);
      await tester.pumpWidget(
        const _App(child: _GameSample(stage: _Stage.checked)),
      );
      final phone = FormFactor.fromSize(size.size) != FormFactor.laptop;
      if (phone) {
        // Toast up (the slide takes 150 ms).
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        await expectLater(
          find.byType(_App),
          matchesGoldenFile(goldenName('frame-game', 'checked-toast', size)),
        );
        // Wait for it to go (about 2.5 s, then the slide down).
        await tester.pump(const Duration(seconds: 3));
      }
      await settle(tester);
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName('frame-game', 'checked', size)),
      );
    });

    testWidgets('frame game phrases, ${size.name}', (tester) async {
      setScreenSize(tester, size);
      await tester.pumpWidget(
        const _App(child: _GameSample(stage: _Stage.phrases)),
      );
      await settle(tester);
      await expectLater(
        find.byType(_App),
        matchesGoldenFile(goldenName('frame-game', 'phrases', size)),
      );
    });
  }

  group('option columns (section 5)', () {
    test('short options: 2 below 700, 4 from 700', () {
      expect(AppLayout.optionColumns(390, count: 4, phrases: false), 2);
      expect(AppLayout.optionColumns(699, count: 4, phrases: false), 2);
      expect(AppLayout.optionColumns(700, count: 4, phrases: false), 4);
      expect(AppLayout.optionColumns(844, count: 6, phrases: false), 4);
    });
    test('phrases: 1 below 600, 2 from 600', () {
      expect(AppLayout.optionColumns(390, count: 4, phrases: true), 1);
      expect(AppLayout.optionColumns(844, count: 4, phrases: true), 2);
      expect(AppLayout.optionColumns(1280, count: 4, phrases: true), 2);
    });
    test('never more columns than options', () {
      expect(AppLayout.optionColumns(1280, count: 3, phrases: false), 3);
    });
    test('side panel 280 to 320', () {
      expect(AppLayout.sidePanelWidth(900), 280);
      expect(AppLayout.sidePanelWidth(1040), 312);
      expect(AppLayout.sidePanelWidth(2000), 320);
    });
  });

  group('form factor (section 5)', () {
    test('phone landscape is checked first', () {
      expect(
        FormFactor.fromSize(const Size(844, 390)),
        FormFactor.phoneLandscape,
      );
      expect(
        FormFactor.fromSize(const Size(1280, 480)),
        FormFactor.phoneLandscape,
      );
      expect(FormFactor.fromSize(const Size(560, 390)), FormFactor.phone);
      expect(FormFactor.fromSize(const Size(800, 1000)), FormFactor.phone);
      expect(FormFactor.fromSize(const Size(1280, 800)), FormFactor.laptop);
    });
  });
}

/// The app's theme for the window size, as `main.dart` sets it.
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

void _noop() {}

class _HomeSample extends StatelessWidget {
  const _HomeSample();

  static const _phase1 = {'choose_correction': 2, 'repair': 1};
  static const _phase2 = {
    'fill_gap': 3,
    'match': 1,
    'order': 2,
    'spot_error': 0,
  };

  @override
  Widget build(BuildContext context) {
    final laptop = FormFactor.of(context) == FormFactor.laptop;
    Widget group(Map<String, int> games) {
      final cards = [
        for (final e in games.entries)
          GameCard.forGame(
            game: e.key,
            count: e.value,
            onTap: e.value == 0 ? null : _noop,
          ),
      ];
      if (!laptop) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(height: AppLayout.phoneCardGap),
              cards[i],
            ],
          ],
        );
      }
      // A stand-in for U4's 2-column grid.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i += 2) ...[
            if (i > 0) const SizedBox(height: AppLayout.laptopCardGap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cards[i]),
                  const SizedBox(width: AppLayout.laptopCardGap),
                  Expanded(
                    child: i + 1 < cards.length
                        ? cards[i + 1]
                        : const SizedBox(),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    }

    return HomeFrame(
      topBar: const HomeTopBar(
        source: '9 questions · sample file',
        onReload: _noop,
      ),
      footer: HomeFrame.footerLine(context),
      children: [
        const PhaseHeading.newCorrections(),
        group(_phase1),
        const PhaseHeading.recall(),
        group(_phase2),
      ],
    );
  }
}

enum _Stage { chosen, checked, phrases }

class _GameSample extends StatelessWidget {
  const _GameSample({required this.stage});

  final _Stage stage;

  @override
  Widget build(BuildContext context) {
    final f = FormFactor.of(context);
    final laptop = f == FormFactor.laptop;
    final type = AppTypography.of(context);
    final checked = stage == _Stage.checked;
    final phrases = stage == _Stage.phrases;
    final sentence = phrases ? _phraseSentence : _sentence;
    final options = phrases ? _phraseOptions : _options;
    final chosen = phrases ? _phraseOptions[0] : _wrongChoice;

    AnswerState stateOf(String o) {
      if (!checked) {
        return o == chosen ? AnswerState.selected : AnswerState.resting;
      }
      if (o == _answer) return AnswerState.correct;
      if (o == chosen) return AnswerState.wrong;
      return AnswerState.dimmed;
    }

    final content = ExplanationContent.build(
      explanation: _explanation,
      answers: const [_answer],
      chosen: checked ? _wrongChoice : null,
    );

    final rows = <Widget>[
      if (laptop)
        const Align(
          alignment: Alignment.centerLeft,
          child: CategoryChip(type: 'grammar', category: 'Prepositions'),
        )
      else
        const ChipRow(
          type: 'grammar',
          category: 'Prepositions',
          current: 2,
          total: 3,
        ),
      Text('Choose the correction for the marked words', style: type.caption),
      PromptCard.marked(
        sentence: sentence,
        replacement: checked ? null : chosen,
        corrected: checked
            ? SentenceText.replaceFirstMark(sentence, _answer)
            : null,
      ),
      OptionGrid.forLabels(
        labels: options,
        builder: (o) => AnswerOption(
          label: o,
          state: stateOf(o),
          onPressed: checked ? null : _noop,
        ),
      ),
    ];

    return GameFrame(
      topBar: GameTopBar(
        title: 'Choose a correction',
        onBack: _noop,
        current: 2,
        total: 3,
        actionLabel: checked ? 'Next question' : 'Check',
        onAction: _noop,
      ),
      explanation: checked ? ExplanationCard(content: content) : null,
      primaryButton: checked
          ? const PrimaryButton.next(onPressed: _noop)
          : const PrimaryButton.check(onPressed: _noop),
      sidePanel: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SessionPanel(
            marks: [
              QuestionMark.correct,
              checked ? QuestionMark.wrong : QuestionMark.current,
              QuestionMark.upcoming,
            ],
            showPlaceholder: !checked,
          ),
          if (checked) ...[
            const SizedBox(height: AppLayout.laptopCardGap),
            FeedbackPanel(correct: false, content: content),
          ],
        ],
      ),
      toastResult: checked ? false : null,
      toastId: checked ? 1 : 0,
      children: rows,
    );
  }
}
