/// SetCard (U18, Flow v2): one set of questions on the set picker.
///
/// Proposed for the spec (section 6, alongside GameCard): `surface`, 1px
/// `hairline`, radius 16, padding 16 (20 on laptop), min height 72. One row
/// at every size: the set's title (card title style) over its detail line
/// ("14 Oct · 1 of 2", card description style); on the right the count in
/// the phase accent over "questions", then a right chevron in `textMuted`.
/// No icon tile: every set in a list is the same kind of thing, so a tile
/// would repeat the same icon down the page. On laptop the cards sit in
/// the home 2-column grid. The whole card is one button.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import 'focus_ring.dart';

class SetCard extends StatelessWidget {
  const SetCard({
    super.key,
    required this.title,
    required this.detail,
    required this.count,
    required this.accent,
    required this.onTap,
  });

  final String title;

  /// The date or date range, and "1 of 2" when a conversation is split.
  final String detail;

  /// Questions in the set (at least 1).
  final int count;

  /// The phase's accent (the colour of its card on home).
  final Color accent;

  final VoidCallback? onTap;

  /// Minimum height of the card.
  static const double minHeight = 72;

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    final laptop = FormFactor.of(context) == FormFactor.laptop;
    final large = AppLayout.isLargeText(context);
    final noun = count == 1 ? 'question' : 'questions';

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: type.cardTitle),
        if (detail.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s4),
          Text(detail, style: type.cardDescription),
        ],
      ],
    );

    final countBlock = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('$count', style: type.homeCount.copyWith(color: accent)),
        Text(noun, style: type.caption),
      ],
    );

    const chevron = Icon(
      Icons.chevron_right_rounded,
      size: AppSizes.glyph,
      color: AppColors.textMuted,
    );

    // With large text (spec section 10) the count goes under the title,
    // so the title keeps the card's width and wraps between words.
    final Widget content = large
        ? Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    text,
                    const SizedBox(height: AppSpacing.s8),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$count ',
                            style: type.caption
                                .withWeight(600)
                                .copyWith(color: accent),
                          ),
                          TextSpan(text: noun),
                        ],
                      ),
                      style: type.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              chevron,
            ],
          )
        : Row(
            children: [
              Expanded(child: text),
              const SizedBox(width: AppSpacing.s12),
              countBlock,
              const SizedBox(width: AppSpacing.s8),
              chevron,
            ],
          );

    return FocusRing(
      radius: AppRadius.card,
      child: Semantics(
        button: true,
        enabled: onTap != null,
        label: '$title. $detail. $count $noun.',
        excludeSemantics: true,
        onTap: onTap,
        child: Material(
          color: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.cardAll,
            side: BorderSide(color: AppColors.hairline),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: minHeight),
              child: Padding(
                padding: EdgeInsets.all(
                  laptop ? AppSpacing.s20 : AppSpacing.s16,
                ),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
