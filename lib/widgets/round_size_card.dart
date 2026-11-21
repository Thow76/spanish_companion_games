/// RoundSizeCard (U22): the home screen's "Questions per round" choice, 5 or
/// 10 (behaviour from B32).
///
/// Proposed for the spec (section 6; the spec has no control for this), from
/// existing patterns:
/// - A quiet card that pairs with the filter card above it: `surface`, 1px
///   `hairline`, radius 16, padding 16 at the sides and 3 above and below,
///   so with 48-high buttons it is 56 high, the height of the shut filter
///   card (44-high buttons and 5 in phone landscape).
/// - Left: a muted 20px icon in a 24 box (the filter card has `filter_list_rounded`; this
///   is `Icons.format_list_numbered_rounded`), 16 gap, then "Questions per
///   round" in the filter card's title style (caption, `textSecondary`).
/// - Right: one size button per choice, 8 apart. Each at least 56 wide and
///   48 high (44 in phone landscape), radius 12, the number in the button
///   label style. Resting: `fillNeutral`, 1px `stroke`, `textSecondary`.
///   Chosen: accent 12% fill, 2px accent, `textPrimary` (the AnswerOption
///   selected style, as U18 proposed). Spoken as "5 questions per round,
///   selected".
/// - With large text (200%) the buttons go under the label, so the label
///   never breaks inside a word and nothing scrolls sideways at 320.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import 'focus_ring.dart';

class RoundSizeCard extends StatelessWidget {
  const RoundSizeCard({
    super.key,
    required this.sizes,
    required this.value,
    required this.onChanged,
    this.label = defaultLabel,
    this.buttonKey,
  });

  /// The choices, in order (5, 10).
  final List<int> sizes;

  /// The chosen size.
  final int value;
  final ValueChanged<int> onChanged;
  final String label;

  /// Key for each size button (tests tap them by key).
  final Key Function(int size)? buttonKey;

  static const String defaultLabel = 'Questions per round';

  /// Spoken label of a size button: "5 questions per round".
  static String sizeSemantics(int n) => '$n questions per round';

  /// Smallest width of a size button, so "5" is not a narrow sliver.
  static const double buttonMinWidth = 56;

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    final landscape = FormFactor.of(context) == FormFactor.phoneLandscape;
    final large = AppLayout.isLargeText(context);
    final buttonHeight = landscape ? AppSizes.minTarget : AppSizes.phoneTarget;
    // Card height = its 1px borders + button height + this above and
    // below = 56, the height of the shut filter card.
    final vertical =
        (AppSizes.optionPhone - 2 * AppStroke.resting - buttonHeight) / 2;

    final title = Row(
      children: [
        // In a 24-wide box, as the filter card's icon is, so the two
        // labels line up.
        const SizedBox(
          width: AppSizes.glyph,
          child: Icon(
            Icons.format_list_numbered_rounded,
            size: AppSizes.iconSmall,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(width: AppSpacing.s16),
        Flexible(
          child: Semantics(
            header: true,
            child: Text(
              label,
              style: type.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ),
      ],
    );

    final buttons = Wrap(
      spacing: AppSpacing.s8,
      runSpacing: AppSpacing.s8,
      children: [
        for (final n in sizes)
          _SizeButton(
            key: buttonKey?.call(n),
            size: n,
            chosen: n == value,
            height: buttonHeight,
            onPressed: n == value ? null : () => onChanged(n),
          ),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: large ? AppSpacing.s12 : vertical,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.hairline),
      ),
      child: large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                title,
                const SizedBox(height: AppSpacing.s12),
                buttons,
              ],
            )
          : Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: AppSpacing.s12),
                buttons,
              ],
            ),
    );
  }
}

/// One size button: the number, resting or chosen (AnswerOption's resting
/// and selected looks). The chosen one does nothing when tapped.
class _SizeButton extends StatelessWidget {
  const _SizeButton({
    super.key,
    required this.size,
    required this.chosen,
    required this.height,
    required this.onPressed,
  });

  final int size;
  final bool chosen;
  final double height;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    return FocusRing(
      radius: AppRadius.control,
      child: Semantics(
        button: true,
        selected: chosen,
        label: RoundSizeCard.sizeSemantics(size),
        excludeSemantics: true,
        onTap: onPressed,
        // The border is drawn by the shape, not as padding, so the button
        // keeps its size when its border goes from 1px to 2px.
        child: Material(
          color: chosen ? AppColors.accent12 : AppColors.fillNeutral,
          animationDuration: AppMotion.duration(context),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.controlAll,
            side: BorderSide(
              color: chosen ? AppColors.accent : AppColors.stroke,
              width: chosen ? AppStroke.strong : AppStroke.resting,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: RoundSizeCard.buttonMinWidth,
                minHeight: height,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Text(
                    '$size',
                    style: type.button.copyWith(
                      color: chosen
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
