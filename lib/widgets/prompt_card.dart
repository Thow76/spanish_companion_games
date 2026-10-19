/// PromptCard (UI spec section 6): the Spanish sentence on its own card.
/// `surface`, radius 16, padding 24/20 phone portrait, 16/20 phone
/// landscape, 28/28 laptop. The sentence (16/28) wraps onto as many lines
/// as it needs; it is never truncated or shrunk to fit.
///
/// Three forms:
/// - [PromptCard.gap] (Fill the gap): an inline slot for the missing word.
/// - [PromptCard.marked] (Choose a correction, Repair): "Original version"
///   with the `**…**` words marked; after checking, "Corrected version"
///   with the changed words in `correct`.
/// - [PromptCard.plain] (Sentence ordering, Spot the error): the sentence
///   only; Spot the error shows the corrected version after checking.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import 'sentence_text.dart';

/// State of the gap slot in Fill the gap.
enum GapState {
  /// Nothing picked yet: an empty slot.
  empty,

  /// A word picked, not yet checked: shown in accent.
  chosen,

  /// After checking: the correct word, in `correct`.
  correct,
}

enum _Form { gap, marked, plain }

class PromptCard extends StatelessWidget {
  /// Fill the gap. [sentence] contains `___` where the gap goes. [fill] is
  /// the chosen word ([GapState.chosen]) or the correct word
  /// ([GapState.correct]); ignored when [gapState] is [GapState.empty].
  const PromptCard.gap({
    super.key,
    required this.sentence,
    this.fill,
    this.gapState = GapState.empty,
  }) : _form = _Form.gap,
       missingWord = false,
       replacement = null,
       corrected = null;

  /// Phase 1: Andrew's sentence with the problem words wrapped in `**…**`.
  ///
  /// - [missingWord]: adds "A word is missing near the marked words."
  /// - [replacement]: Choose a correction, once an option is picked: the
  ///   marked span shows it in accent, still underlined.
  /// - [corrected]: after checking, the corrected sentence (for Choose a
  ///   correction use [SentenceText.replaceFirstMark] with the first
  ///   accepted answer; for Repair the first accepted sentence). The label
  ///   changes to "Corrected version" and the changed words are in
  ///   `correct`, weight 600.
  const PromptCard.marked({
    super.key,
    required this.sentence,
    this.missingWord = false,
    this.replacement,
    this.corrected,
  }) : _form = _Form.marked,
       fill = null,
       gapState = GapState.empty;

  /// Sentence ordering and Spot the error: the sentence only, no label,
  /// nothing marked. For Spot the error after checking, pass [corrected]
  /// when the sentence was wrong: the card shows "Corrected version" and
  /// the corrected sentence with the changed words in `correct`.
  const PromptCard.plain({super.key, required this.sentence, this.corrected})
    : _form = _Form.plain,
      fill = null,
      gapState = GapState.empty,
      missingWord = false,
      replacement = null;

  final _Form _form;
  final String sentence;
  final String? fill;
  final GapState gapState;
  final bool missingWord;
  final String? replacement;
  final String? corrected;

  static const String originalLabel = 'Original version';
  static const String correctedLabel = 'Corrected version';
  static const String missingWordText =
      'A word is missing near the marked words.';
  static const String _gapToken = '___';

  EdgeInsets _padding(FormFactor f) => switch (f) {
    FormFactor.phone => AppInsets.promptPhone,
    FormFactor.phoneLandscape => AppInsets.promptLandscape,
    FormFactor.laptop => AppInsets.promptLaptop,
  };

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    final original = SentenceText.stripMarks(sentence);
    final showCorrected =
        corrected != null &&
        (_form == _Form.marked ||
            SentenceText.diff(corrected!, original).any((w) => w.changed));

    final children = <Widget>[];
    if (showCorrected) {
      children
        ..add(Text(correctedLabel, style: type.promptLabel))
        ..add(const SizedBox(height: AppSpacing.s8))
        ..add(_corrected(type, original));
    } else {
      switch (_form) {
        case _Form.gap:
          children.add(_gap(type));
        case _Form.marked:
          children
            ..add(Text(originalLabel, style: type.promptLabel))
            ..add(const SizedBox(height: AppSpacing.s8))
            ..add(_marked(type));
          if (missingWord) {
            children
              ..add(const SizedBox(height: AppSpacing.s8))
              ..add(Text(missingWordText, style: type.caption));
          }
        case _Form.plain:
          children.add(Text(original, style: type.prompt, softWrap: true));
      }
    }

    return Container(
      width: double.infinity,
      padding: _padding(FormFactor.of(context)),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardAll,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }

  /// The corrected sentence, changed words in `correct` 600. If the
  /// comparison is unclear, the whole sentence in `textPrimary`.
  Widget _corrected(AppTypography type, String original) {
    final diff = SentenceText.diff(corrected!, original);
    if (!SentenceText.isClear(diff)) {
      return Text(corrected!, style: type.prompt, softWrap: true);
    }
    final changedStyle = type.promptStrong.copyWith(color: AppColors.correct);
    final changedWords = diff.where((w) => w.changed).map((w) => w.word);
    return Semantics(
      label:
          '$correctedLabel: ${corrected!}. Changed: ${changedWords.join(' ')}',
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            style: type.prompt,
            children: [
              for (var i = 0; i < diff.length; i++)
                TextSpan(
                  text: i == diff.length - 1
                      ? diff[i].word
                      : '${diff[i].word} ',
                  style: diff[i].changed ? changedStyle : null,
                ),
            ],
          ),
          softWrap: true,
        ),
      ),
    );
  }

  Widget _marked(AppTypography type) {
    final runs = SentenceText.parseMarks(sentence);
    // The underline is drawn by [_InlineHighlight] (2px, along the bottom of
    // the highlight), so the style's own text underline is turned off here.
    final markedStyle = type.promptMarked.copyWith(
      decoration: TextDecoration.none,
      color: replacement == null ? AppColors.textPrimary : AppColors.accent,
    );
    var replaced = false;
    final spans = <InlineSpan>[];
    final spoken = <String>[];
    for (final run in runs) {
      if (!run.marked) {
        spans.add(TextSpan(text: run.text));
        spoken.add(run.text.trim());
        continue;
      }
      final text = (replacement != null && !replaced) ? replacement! : run.text;
      if (replacement != null) replaced = true;
      spoken.add('marked: ${text.trim()}');
      // One inline box per word, so a long marked span still wraps between
      // words. The space after a word sits inside its box so the highlight
      // runs on between words on the same line.
      final words = text.split(' ');
      for (var i = 0; i < words.length; i++) {
        final word = i < words.length - 1 ? '${words[i]} ' : words[i];
        if (word.isEmpty) continue;
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _InlineHighlight(
              fill: AppColors.markFill,
              underline: AppColors.mark,
              child: Text(word, style: markedStyle),
            ),
          ),
        );
      }
    }
    return Semantics(
      label: '$originalLabel: ${spoken.where((s) => s.isNotEmpty).join(', ')}',
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(style: type.prompt, children: spans),
          softWrap: true,
        ),
      ),
    );
  }

  Widget _gap(AppTypography type) {
    final index = sentence.indexOf(_gapToken);
    if (index < 0) {
      return Text(sentence, style: type.prompt, softWrap: true);
    }
    final before = sentence.substring(0, index);
    final after = sentence.substring(index + _gapToken.length);
    final word = gapState == GapState.empty ? null : fill;
    final colour = gapState == GapState.correct
        ? AppColors.correct
        : AppColors.accent;
    final spoken = '$before${word ?? 'blank'}$after';
    return Semantics(
      label: spoken,
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            style: type.prompt,
            children: [
              TextSpan(text: before),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: _InlineHighlight(
                  fill: AppColors.accent12,
                  underline: gapState == GapState.correct
                      ? AppColors.correct
                      : AppColors.accent,
                  minWidth: AppSizes.gapSlotMinWidth,
                  child: Text(
                    // A non-breaking space keeps the empty slot one line high.
                    word ?? ' ',
                    style: type.promptStrong.copyWith(color: colour),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              TextSpan(text: after),
            ],
          ),
          softWrap: true,
        ),
      ),
    );
  }
}

/// An inline box behind a word: fill with top radius 4 and a 2px underline
/// along the bottom. Used for the marked words and the gap slot.
class _InlineHighlight extends StatelessWidget {
  const _InlineHighlight({
    required this.fill,
    required this.underline,
    required this.child,
    this.minWidth = 0,
  });

  final Color fill;
  final Color underline;
  final Widget child;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    // The sentence's own text scaling is applied to the whole inline box by
    // the paragraph, so the text inside is not scaled a second time.
    return MediaQuery.withNoTextScaling(
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: AppRadius.markTop,
          ),
          child: CustomPaint(
            foregroundPainter: _UnderlinePainter(underline),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _UnderlinePainter extends CustomPainter {
  _UnderlinePainter(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    const width = AppStroke.strong;
    final y = size.height - width / 2;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = colour
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(_UnderlinePainter old) => old.colour != colour;
}
