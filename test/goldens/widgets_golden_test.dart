/// Gallery screenshots of the shared widgets (U2), every state, at the three
/// sizes. UI spec sections 6, 7 and 11.
///
/// Each gallery is rendered at the screen's width with the screen's layout
/// rules (the form factor of 390×844, 844×390 or 1280×800), but as tall as
/// its contents, so every state fits in one picture:
///
/// - `widgets_home_<size>.png`: phase headings, game cards (all six icons,
///   1 question and 0 questions), icon buttons.
/// - `widgets_bars_<size>.png`: game top bar (the form for that size, and in
///   landscape the four action states), chip row with the category chip and
///   the count, primary buttons.
/// - `widgets_prompt_<size>.png`: prompt card in every form: gap (empty,
///   chosen, correct), marked (before, option picked, missing word,
///   corrected right, Repair with two marks corrected), plain, plain
///   corrected.
/// - `widgets_options_<size>.png`: answer options before checking, after a
///   right and a wrong answer, phrase-length options, Spot the error choice.
/// - `widgets_feedback_<size>.png`: explanation card (right, wrong choice,
///   wrong typed answer, plain-text fallback), toasts (phone sizes),
///   feedback and session panels (laptop).
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/theme/app_colors.dart';
import 'package:spanish_companion_games/theme/app_spacing.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/app_typography.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';
import 'package:spanish_companion_games/widgets/widgets.dart';

import 'golden_helpers.dart';

const _galleryKey = ValueKey('gallery');

/// Tall enough for the longest gallery.
const double _galleryHeight = 3200;

void main() {
  setUpAll(setUpGoldens);

  final galleries = <String, Widget Function()>{
    'home': () => const _HomeGallery(),
    'bars': () => const _BarsGallery(),
    'prompt': () => const _PromptGallery(),
    'options': () => const _OptionsGallery(),
    'feedback': () => const _FeedbackGallery(),
  };

  for (final size in ScreenSize.values) {
    for (final entry in galleries.entries) {
      testWidgets('widgets ${entry.key}, ${size.name}', (tester) async {
        tester.view.physicalSize = Size(size.size.width, _galleryHeight);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_GalleryApp(size: size, child: entry.value()));
        await settle(tester);

        await expectLater(
          find.byKey(_galleryKey),
          matchesGoldenFile(goldenName('widgets', entry.key, size)),
        );
      });
    }
  }
}

/// The app theme for [size], with the media query reporting [size] so the
/// widgets pick that size's layout, and the gallery top-aligned at the
/// screen's width.
class _GalleryApp extends StatelessWidget {
  const _GalleryApp({required this.size, required this.child});

  final ScreenSize size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final formFactor = FormFactor.fromSize(size.size);
    final side = switch (formFactor) {
      FormFactor.phone => AppSpacing.phoneMargin,
      FormFactor.phoneLandscape => AppSpacing.landscapePadding,
      FormFactor.laptop => AppSpacing.laptopPadding,
    };
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme(formFactor),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(size: size.size),
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: _galleryKey,
            child: ColoredBox(
              color: AppColors.background,
              child: SizedBox(
                width: size.size.width,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: side,
                    vertical: AppSpacing.s24,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small muted heading naming what follows in the gallery.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.s24,
        bottom: AppSpacing.s8,
      ),
      child: Text(
        text,
        style: AppTypography.of(context).chip.copyWith(color: AppColors.accent),
      ),
    );
  }
}

/// Lays [children] out in [columns] equal columns with [gap] between.
class _Grid extends StatelessWidget {
  const _Grid({
    required this.columns,
    required this.children,
    this.gap = AppSpacing.s12,
  });

  final int columns;
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

bool _laptop(BuildContext context) =>
    FormFactor.of(context) == FormFactor.laptop;

bool _landscape(BuildContext context) =>
    FormFactor.of(context) == FormFactor.phoneLandscape;

void _noop() {}

class _Column extends StatelessWidget {
  const _Column(this.children);

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

// Home: phase headings and game cards.

class _HomeGallery extends StatelessWidget {
  const _HomeGallery();

  @override
  Widget build(BuildContext context) {
    final laptop = _laptop(context);
    final columns = laptop ? 2 : 1;
    final gap = laptop ? AppSpacing.s20 : AppSpacing.s12;
    return _Column([
      const PhaseHeading.newCorrections(),
      _Grid(
        columns: columns,
        gap: gap,
        children: [
          GameCard.forGame(game: 'choose_correction', count: 3, onTap: _noop),
          GameCard.forGame(game: 'repair', count: 1, onTap: _noop),
        ],
      ),
      const PhaseHeading.recall(),
      _Grid(
        columns: columns,
        gap: gap,
        children: [
          GameCard.forGame(game: 'fill_gap', count: 4, onTap: _noop),
          GameCard.forGame(game: 'match', count: 2, onTap: _noop),
          GameCard.forGame(game: 'order', count: 0, onTap: _noop),
          GameCard.forGame(game: 'spot_error', count: 12, onTap: _noop),
        ],
      ),
      const _Label('Icon buttons: reload, close (laptop size), back'),
      const Row(
        children: [
          AppIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Reload questions',
            onPressed: _noop,
          ),
          SizedBox(width: AppSpacing.s16),
          AppIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            onPressed: _noop,
            compact: true,
          ),
          SizedBox(width: AppSpacing.s16),
          AppIconButton.back(onPressed: _noop),
        ],
      ),
    ]);
  }
}

// Top bars, chips and buttons.

class _BarsGallery extends StatelessWidget {
  const _BarsGallery();

  @override
  Widget build(BuildContext context) {
    final landscape = _landscape(context);
    return _Column([
      if (landscape) ...[
        const _Label('Top bar: before choosing (Check inactive)'),
        const GameTopBar(title: 'Choose a correction', onBack: _noop),
        const _Label('Top bar: option chosen'),
        const GameTopBar(
          title: 'Choose a correction',
          onBack: _noop,
          onAction: _noop,
        ),
        const _Label('Top bar: after checking'),
        const GameTopBar(
          title: 'Choose a correction',
          onBack: _noop,
          actionLabel: 'Next question',
          onAction: _noop,
        ),
        const _Label('Top bar: last question'),
        const GameTopBar(
          title: 'Fill the gap',
          onBack: _noop,
          actionLabel: 'See results',
          onAction: _noop,
        ),
      ] else ...[
        const _Label('Top bar'),
        const GameTopBar(
          title: 'Choose a correction',
          onBack: _noop,
          current: 2,
          total: 3,
        ),
        const _Label('Top bar, long title'),
        const GameTopBar(
          title: 'Repair the sentence',
          onBack: _noop,
          current: 12,
          total: 12,
        ),
      ],
      const _Label('Chip row with count'),
      const ChipRow(
        type: 'grammar',
        category: 'Prepositions',
        current: 2,
        total: 3,
      ),
      const SizedBox(height: AppSpacing.s12),
      const ChipRow(type: 'note', category: 'Calque', current: 10, total: 12),
      const SizedBox(height: AppSpacing.s12),
      const ChipRow(
        type: 'grammar',
        category: 'Sentence structure and word order',
        current: 1,
        total: 3,
      ),
      const _Label(
        'Primary button: disabled, Check, Next question, See results',
      ),
      const _Buttons(),
    ]);
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons();

  @override
  Widget build(BuildContext context) {
    final buttons = const [
      PrimaryButton.check(onPressed: null),
      PrimaryButton.check(onPressed: _noop),
      PrimaryButton.next(onPressed: _noop),
      PrimaryButton.next(onPressed: _noop, last: true),
    ];
    if (_laptop(context)) {
      // Right-aligned under the options, at least 200 wide.
      return _Column([
        for (final b in buttons)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s12),
            child: Align(alignment: Alignment.centerRight, child: b),
          ),
      ]);
    }
    return _Column([
      for (final b in buttons)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s12),
          child: b,
        ),
    ]);
  }
}

// Prompt card.

class _PromptGallery extends StatelessWidget {
  const _PromptGallery();

  static const _choose = 'Estoy pensando **de** cambiar de trabajo.';
  static const _missing = 'Ayer **fui cine** con mis amigos.';
  static const _repair = '**Me** gusta **los** libros de historia.';

  @override
  Widget build(BuildContext context) {
    return _Column([
      const _Label('Gap: empty'),
      const PromptCard.gap(sentence: 'Estoy pensando ___ cambiar de trabajo.'),
      const _Label('Gap: option chosen'),
      const PromptCard.gap(
        sentence: 'Estoy pensando ___ cambiar de trabajo.',
        fill: 'en',
        gapState: GapState.chosen,
      ),
      const _Label('Gap: after checking'),
      const PromptCard.gap(
        sentence: 'Estoy pensando ___ cambiar de trabajo.',
        fill: 'en',
        gapState: GapState.correct,
      ),
      const _Label('Marked: before answering'),
      const PromptCard.marked(sentence: _choose),
      const _Label('Marked: option picked'),
      const PromptCard.marked(sentence: _choose, replacement: 'en'),
      const _Label('Marked: missing word'),
      const PromptCard.marked(sentence: _missing, missingWord: true),
      const _Label('Marked: corrected version after checking'),
      PromptCard.marked(
        sentence: _choose,
        corrected: SentenceText.replaceFirstMark(_choose, 'en'),
      ),
      const _Label('Repair: two marks, before and after checking'),
      const PromptCard.marked(sentence: _repair),
      const SizedBox(height: AppSpacing.s12),
      const PromptCard.marked(
        sentence: _repair,
        corrected: 'Me gustan los libros de historia.',
      ),
      const _Label('Plain'),
      const PromptCard.plain(sentence: 'Siempre me levanto a las siete.'),
      const _Label('Plain: Spot the error, corrected after checking'),
      const PromptCard.plain(
        sentence: 'La gente están contentos.',
        corrected: 'La gente está contenta.',
      ),
      const _Label('Long sentence wraps, never truncated'),
      const PromptCard.marked(
        sentence:
            'Cuando era pequeño, mi abuela me contaba historias **sobre** '
            'su pueblo en Galicia, y yo nunca me cansaba de escucharlas.',
      ),
    ]);
  }
}

// Answer options.

class _OptionsGallery extends StatelessWidget {
  const _OptionsGallery();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 700 ? 4 : 2;
    final phraseColumns = width >= 600 ? 2 : 1;
    final choiceColumns = width < 360 ? 1 : 2;

    Widget grid(List<(String, AnswerState)> options, {bool active = true}) =>
        _Grid(
          columns: columns,
          children: [
            for (final (label, state) in options)
              AnswerOption(
                label: label,
                state: state,
                onPressed: active ? _noop : null,
              ),
          ],
        );

    return _Column([
      const _Label('Before checking: resting, one selected'),
      grid(const [
        ('en', AnswerState.selected),
        ('a', AnswerState.resting),
        ('por', AnswerState.resting),
        ('de', AnswerState.resting),
      ]),
      const _Label('After a right answer: correct, the rest dimmed'),
      grid(const [
        ('en', AnswerState.correct),
        ('a', AnswerState.dimmed),
        ('por', AnswerState.dimmed),
        ('de', AnswerState.dimmed),
      ], active: false),
      const _Label('After a wrong answer: chosen wrong, correct shown'),
      grid(const [
        ('en', AnswerState.correct),
        ('a', AnswerState.dimmed),
        ('por', AnswerState.dimmed),
        ('de', AnswerState.wrong),
      ], active: false),
      const _Label('Phrase-length options'),
      _Grid(
        columns: phraseColumns,
        children: const [
          AnswerOption(
            label: 'me acuerdo de mi infancia',
            state: AnswerState.resting,
            onPressed: _noop,
          ),
          AnswerOption(
            label: 'recuerdo de mi infancia',
            state: AnswerState.selected,
            onPressed: _noop,
          ),
          AnswerOption(
            label: 'me recuerdo mi infancia en el pueblo de mis abuelos',
            state: AnswerState.wrong,
            onPressed: null,
          ),
          AnswerOption(
            label: 'acuerdo mi infancia',
            state: AnswerState.dimmed,
            onPressed: null,
          ),
        ],
      ),
      const _Label('Spot the error choice'),
      _Grid(
        columns: choiceColumns,
        children: const [
          AnswerOption(
            label: "It's correct",
            state: AnswerState.resting,
            onPressed: _noop,
          ),
          AnswerOption(
            label: 'It needs fixing',
            state: AnswerState.selected,
            onPressed: _noop,
          ),
        ],
      ),
    ]);
  }
}

// Feedback: explanation card, toasts, laptop panels.

class _FeedbackGallery extends StatelessWidget {
  const _FeedbackGallery();

  static const _explanation =
      'pensar en + infinitive = to be thinking of doing something.';

  @override
  Widget build(BuildContext context) {
    final right = ExplanationContent.build(
      explanation: _explanation,
      answers: const ['en'],
    );
    final wrongChoice = ExplanationContent.build(
      explanation: _explanation,
      answers: const ['en'],
      chosen: 'de',
    );
    final wrongTyped = ExplanationContent.build(
      explanation: 'gustar + plural noun = the verb agrees with what is liked',
      answers: const ['Me gustan los libros de historia.'],
      typed: 'Me gusta los libros de historia.',
      typedAgainst: 'Me gustan los libros de historia.',
    );
    final fallback = ExplanationContent.build(
      explanation:
          'Professions take ser: ella es profesora. No options here, so the '
          'learner types the answer.',
      answers: const ['es'],
    );

    if (_laptop(context)) {
      return _Column([
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Column([
                const _Label('Feedback panel: correct'),
                FeedbackPanel(correct: true, content: right),
                const _Label('Feedback panel: not quite (choice)'),
                FeedbackPanel(correct: false, content: wrongChoice),
                const _Label('Feedback panel: not quite (typed)'),
                FeedbackPanel(correct: false, content: wrongTyped),
                const _Label('Feedback panel: plain-text fallback'),
                FeedbackPanel(correct: true, content: fallback),
              ]),
            ),
            const SizedBox(width: AppSpacing.s32),
            const SizedBox(
              width: 300,
              child: _Column([
                _Label('Session panel, before checking'),
                SessionPanel(
                  marks: [
                    QuestionMark.correct,
                    QuestionMark.wrong,
                    QuestionMark.current,
                    QuestionMark.upcoming,
                    QuestionMark.upcoming,
                  ],
                  showPlaceholder: true,
                ),
              ]),
            ),
          ],
        ),
      ]);
    }

    return _Column([
      const _Label('Explanation card: right answer'),
      ExplanationCard(content: right),
      const _Label('Explanation card: wrong choice'),
      ExplanationCard(content: wrongChoice),
      const _Label('Explanation card: wrong typed answer'),
      ExplanationCard(content: wrongTyped),
      const _Label('Explanation card: plain-text fallback'),
      ExplanationCard(content: fallback),
      const _Label('Toast: correct'),
      const _ToastEdge(child: ResultToast(correct: true)),
      const _Label('Toast: not quite'),
      const _ToastEdge(child: ResultToast(correct: false)),
    ]);
  }
}

/// Shows a toast as it sits on the bottom edge: full screen width in
/// portrait (the gallery's side margin is undone), 44 in from each side in
/// landscape.
class _ToastEdge extends StatelessWidget {
  const _ToastEdge({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (_landscape(context)) return child;
    return Transform.translate(
      offset: const Offset(-AppSpacing.phoneMargin, 0),
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        fit: OverflowBoxFit.deferToChild,
        minWidth: MediaQuery.sizeOf(context).width,
        maxWidth: MediaQuery.sizeOf(context).width,
        child: child,
      ),
    );
  }
}
