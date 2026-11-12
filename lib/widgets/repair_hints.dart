/// The Repair hint pieces (U18, Flow v2 stage 1), proposed for the spec
/// (section 6):
///
/// - [FocusLine]: above the field, 8 from it (grouped with it): a 16px
///   target icon in `textMuted`, then the focus text in caption size,
///   `textSecondary`, so it reads as a label for the field rather than one
///   more muted line.
/// - [HintCard]: after a wrong first try, under the field: `surface`,
///   1px `stroke`, radius 12, padding 12/16; a 20px lightbulb in
///   `textSecondary`, then "Hint" (prompt card label style) over the hint in
///   body text, `textPrimary`. Announced (live region). No mint, coral or
///   accent: it is neither a result nor an action.
/// - [HintedResultNote]: phones, after a right second try: circled tick and
///   "Right with a hint" in `correct` (Sora 600, the explanation heading
///   size), and under it the caption "It counts as not passed yet, so it
///   will come back." On laptop the same words go in the FeedbackPanel's
///   heading instead.
///
/// The text itself is passed in as a widget, so the screen can render the
/// `*…*` emphasis; [FocusLine.textStyle] and [HintCard.textStyle] give the
/// styles to use.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

class FocusLine extends StatelessWidget {
  const FocusLine({super.key, required this.text});

  /// Usually a Text styled with [textStyle].
  final Widget text;

  static const double iconSize = 16;

  static TextStyle textStyle(BuildContext context) => AppTypography.of(
    context,
  ).caption.copyWith(color: AppColors.textSecondary);

  @override
  Widget build(BuildContext context) {
    final style = textStyle(context);
    // Centre the icon on the first line of text.
    final lineHeight = (style.fontSize ?? 13) * (style.height ?? 1.4);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: lineHeight,
          child: const Center(
            child: ExcludeSemantics(
              child: Icon(
                Icons.track_changes_rounded,
                size: iconSize,
                color: AppColors.textMuted,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(child: text),
      ],
    );
  }
}

class HintCard extends StatelessWidget {
  const HintCard({super.key, required this.text});

  /// Usually a Text styled with [textStyle].
  final Widget text;

  static const String label = 'Hint';

  static TextStyle textStyle(BuildContext context) =>
      AppTypography.of(context).body.copyWith(color: AppColors.textPrimary);

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.controlAll,
          border: Border.all(color: AppColors.stroke),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.s4),
              child: ExcludeSemantics(
                child: Icon(
                  Icons.lightbulb_outline_rounded,
                  size: AppSizes.iconSmall,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(child: Text(label, style: type.promptLabel)),
                  const SizedBox(height: AppSpacing.s4),
                  text,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HintedResultNote extends StatelessWidget {
  const HintedResultNote({
    super.key,
    required this.heading,
    required this.caption,
  });

  final String heading;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                size: AppSizes.explanationHeadingIcon,
                color: AppColors.correct,
              ),
              const SizedBox(width: AppSpacing.s8),
              Flexible(
                child: Text(
                  heading,
                  style: type.explanationHeading.copyWith(
                    color: AppColors.correct,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(caption, style: type.caption),
        ],
      ),
    );
  }
}
