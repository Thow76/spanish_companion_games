/// The laptop side panel (UI spec section 6): FeedbackPanel and
/// SessionPanel.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'dashed_border.dart';
import 'explanation_card.dart';
import 'explanation_content.dart';
import 'result_toast.dart';

/// FeedbackPanel (laptop only): `surface`, radius 16, padding 20, 1px border
/// in the feedback colour at 40%. Heading row: circled tick + "Correct" in
/// mint, or circled cross + "Not quite" in coral; under it the same contents
/// as the ExplanationCard in its portrait layout. Announced to screen
/// readers.
class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({
    super.key,
    required this.correct,
    required this.content,
  });

  final bool correct;
  final ExplanationContent content;

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    final colour = correct ? AppColors.correct : AppColors.wrong;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(
          color: correct ? AppColors.correct40 : AppColors.wrong40,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Icon(
                  correct ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: colour,
                  size: AppSizes.glyph,
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    correct ? ResultToast.correctText : ResultToast.wrongText,
                    style: type.feedbackHeading.copyWith(color: colour),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          ExplanationBody(content: content),
        ],
      ),
    );
  }
}

/// How one question in the session went, for [SessionPanel].
enum QuestionMark {
  /// Answered correctly: tick.
  correct,

  /// Answered wrongly: cross.
  wrong,

  /// On screen now: filled accent dot, bold.
  current,

  /// Still to come: hollow muted dot.
  upcoming,
}

/// SessionPanel (laptop only): "This session" and the score, then one row
/// per question. Before checking, a dashed placeholder under it reads "The
/// explanation appears here after you check." ([showPlaceholder]).
class SessionPanel extends StatelessWidget {
  const SessionPanel({
    super.key,
    required this.marks,
    this.showPlaceholder = false,
  });

  /// One entry per question in the session, in order.
  final List<QuestionMark> marks;
  final bool showPlaceholder;

  static const String placeholderText =
      'The explanation appears here after you check.';

  int get _score => marks.where((m) => m == QuestionMark.correct).length;
  int get _answered => marks
      .where((m) => m == QuestionMark.correct || m == QuestionMark.wrong)
      .length;

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.s20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.cardAll,
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text('This session', style: type.phaseHeading),
                    ),
                  ),
                  Text('$_score of $_answered correct', style: type.caption),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              for (var i = 0; i < marks.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.s8),
                _row(type, i, marks[i]),
              ],
            ],
          ),
        ),
        if (showPlaceholder) ...[
          const SizedBox(height: AppSpacing.s16),
          DashedBorder(
            color: AppColors.divider,
            radius: AppRadius.card,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s20),
              child: Text(placeholderText, style: type.caption),
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(AppTypography type, int index, QuestionMark mark) {
    final label = 'Question ${index + 1}';
    final current = mark == QuestionMark.current;
    final style = current
        ? type.body.withWeight(600).copyWith(color: AppColors.textPrimary)
        : type.body.copyWith(
            color: mark == QuestionMark.upcoming
                ? AppColors.textMuted
                : AppColors.textSecondary,
          );
    final spoken = switch (mark) {
      QuestionMark.correct => '$label, correct',
      QuestionMark.wrong => '$label, wrong',
      QuestionMark.current => '$label, now',
      QuestionMark.upcoming => '$label, to come',
    };
    return Semantics(
      label: spoken,
      child: ExcludeSemantics(
        child: Row(
          children: [
            SizedBox(
              width: AppSizes.iconSmall,
              height: AppSizes.iconSmall,
              child: Center(child: _icon(mark)),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(child: Text(label, style: style)),
          ],
        ),
      ),
    );
  }

  Widget _icon(QuestionMark mark) => switch (mark) {
    QuestionMark.correct => const Icon(
      Icons.check_rounded,
      color: AppColors.correct,
      size: AppSizes.iconSmall,
    ),
    QuestionMark.wrong => const Icon(
      Icons.close_rounded,
      color: AppColors.wrong,
      size: AppSizes.iconSmall,
    ),
    QuestionMark.current => Container(
      width: AppSizes.sessionDot,
      height: AppSizes.sessionDot,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
    ),
    QuestionMark.upcoming => Container(
      width: AppSizes.sessionDot,
      height: AppSizes.sessionDot,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.textMuted,
          width: AppStroke.resting,
        ),
      ),
    ),
  };
}
