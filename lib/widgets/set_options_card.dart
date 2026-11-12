/// SetOptionsCard (U18, Flow v2): the set picker's two settings in one card.
///
/// Proposed for the spec (section 6): `surface`, 1px `hairline`, radius 16,
/// padding 16 (20 on laptop).
/// - Row 1: "Set size" (body, `textPrimary`) on the left; on the right two
///   size buttons, 8 apart, each 48 high (44 in phone landscape), at least
///   56 wide, radius 12, Sora button label. Resting: `fillNeutral`, 1px
///   `stroke`, `textSecondary`. Chosen: accent 12% fill, 2px accent,
///   `textPrimary` (the AnswerOption selected style). Read as "5 questions
///   per set, selected".
/// - A hairline, 12 above and below.
/// - Row 2: "By conversation" (body, `textPrimary`) over its caption, and the
///   switch on the right (the theme's switch: accent when on); the whole row
///   toggles it.
/// With large text the size buttons go under their label and the switch
/// under its text.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import 'focus_ring.dart';

class SetOptionsCard extends StatelessWidget {
  const SetOptionsCard({
    super.key,
    required this.sizes,
    required this.size,
    required this.onSizeChanged,
    required this.byConversation,
    required this.onByConversationChanged,
    this.sizeLabel = 'Set size',
    this.byConversationLabel = 'By conversation',
    this.byConversationHint = 'Each set comes from one conversation.',
    this.switchKey,
  });

  final List<int> sizes;
  final int size;
  final ValueChanged<int> onSizeChanged;
  final bool byConversation;
  final ValueChanged<bool> onByConversationChanged;
  final String sizeLabel;
  final String byConversationLabel;
  final String byConversationHint;

  /// Key for the "By conversation" row (tests tap it).
  final Key? switchKey;

  /// Spoken label of a size button: "5 questions per set".
  static String sizeSemantics(int n) => '$n questions per set';

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    final f = FormFactor.of(context);
    final large = AppLayout.isLargeText(context);
    final label = type.body.copyWith(color: AppColors.textPrimary);

    final buttons = Wrap(
      spacing: AppSpacing.s8,
      runSpacing: AppSpacing.s8,
      children: [
        for (final n in sizes)
          _SizeButton(
            key: ValueKey('set-size-$n'),
            size: n,
            chosen: n == size,
            landscape: f == FormFactor.phoneLandscape,
            onPressed: n == size ? null : () => onSizeChanged(n),
          ),
      ],
    );

    final sizeRow = large
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(sizeLabel, style: label)),
              const SizedBox(height: AppSpacing.s8),
              buttons,
            ],
          )
        : Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(sizeLabel, style: label),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              buttons,
            ],
          );

    return Container(
      padding: EdgeInsets.all(
        f == FormFactor.laptop ? AppSpacing.s20 : AppSpacing.s16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          sizeRow,
          const SizedBox(height: AppSpacing.s12),
          const Divider(height: 1, thickness: 1, color: AppColors.hairline),
          const SizedBox(height: AppSpacing.s4),
          _SwitchRow(
            key: switchKey,
            label: byConversationLabel,
            hint: byConversationHint,
            value: byConversation,
            onChanged: onByConversationChanged,
            stacked: large,
            labelStyle: label,
          ),
        ],
      ),
    );
  }
}

/// "By conversation" and its caption with the theme's switch: the switch on
/// the right, or under the text with large text (so the label never breaks
/// inside a word). The whole row toggles it and reads as one switch.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.onChanged,
    required this.stacked,
    required this.labelStyle,
  });

  final String label;
  final String hint;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool stacked;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: labelStyle),
        const SizedBox(height: AppSpacing.s4),
        Text(hint, style: type.caption),
      ],
    );
    final toggle = Switch(value: value, onChanged: onChanged);
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: AppRadius.controlAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    text,
                    const SizedBox(height: AppSpacing.s8),
                    toggle,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: text),
                    const SizedBox(width: AppSpacing.s12),
                    toggle,
                  ],
                ),
        ),
      ),
    );
  }
}

class _SizeButton extends StatelessWidget {
  const _SizeButton({
    super.key,
    required this.size,
    required this.chosen,
    required this.landscape,
    required this.onPressed,
  });

  final int size;
  final bool chosen;
  final bool landscape;
  final VoidCallback? onPressed;

  static const double minWidth = 56;

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    final height = landscape ? AppSizes.minTarget : AppSizes.phoneTarget;
    return FocusRing(
      radius: AppRadius.control,
      child: Semantics(
        button: true,
        selected: chosen,
        label: SetOptionsCard.sizeSemantics(size),
        excludeSemantics: true,
        onTap: onPressed,
        child: Material(
          color: chosen ? AppColors.accent12 : AppColors.fillNeutral,
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
                minWidth: minWidth,
                minHeight: height,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                child: Center(
                  widthFactor: 1,
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
