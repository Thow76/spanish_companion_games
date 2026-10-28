/// WordChip (UI spec section 6, "word chips for ordering"): one word of a
/// Sentence ordering question.
///
/// States:
/// - [WordChipState.toPlace]: not in the sentence yet. `fillNeutral`, 1px
///   `stroke`, `textSecondary`.
/// - [WordChipState.placed]: already in the sentence. Accent 12% fill, 1px
///   accent 40% stroke, `textPrimary`.
/// - [WordChipState.done]: after checking, every chip. Transparent, 1px
///   `hairline`, `textMuted`, disabled (as answer options are dimmed after
///   checking; the result is on the prompt card and the explanation).
///
/// Radius 12, at least 48 high at every size, the label wraps rather than
/// being cut off. The stroke is 1px in every state, so the word never moves
/// when it is placed. A real button with a semantic label ("lo, placed").
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'focus_ring.dart';

enum WordChipState { toPlace, placed, done }

class WordChip extends StatelessWidget {
  const WordChip({
    super.key,
    required this.label,
    required this.state,
    required this.onPressed,
    this.focusNode,
  });

  final String label;
  final WordChipState state;

  /// Null disables the chip (always, after checking).
  final VoidCallback? onPressed;
  final FocusNode? focusNode;

  ({Color fill, Color border, Color text}) get _look => switch (state) {
    WordChipState.toPlace => (
      fill: AppColors.fillNeutral,
      border: AppColors.stroke,
      text: AppColors.textSecondary,
    ),
    WordChipState.placed => (
      fill: AppColors.accent12,
      border: AppColors.accent40,
      text: AppColors.textPrimary,
    ),
    WordChipState.done => (
      fill: AppColors.transparent,
      border: AppColors.hairline,
      text: AppColors.textMuted,
    ),
  };

  String get _semanticLabel =>
      state == WordChipState.placed ? '$label, placed' : label;

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    final look = _look;

    return FocusRing(
      radius: AppRadius.control,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        selected: state == WordChipState.placed,
        label: _semanticLabel,
        excludeSemantics: true,
        onTap: onPressed,
        child: AnimatedContainer(
          duration: AppMotion.duration(context),
          curve: AppMotion.curve,
          constraints: const BoxConstraints(minHeight: AppSizes.wordChip),
          decoration: BoxDecoration(
            color: look.fill,
            borderRadius: AppRadius.controlAll,
            border: Border.all(color: look.border, width: AppStroke.resting),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onPressed,
              focusNode: focusNode,
              borderRadius: AppRadius.controlAll,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.wordChip - 2 * AppStroke.resting,
                ),
                child: Padding(
                  padding: AppInsets.wordChip,
                  child: Center(
                    widthFactor: 1,
                    heightFactor: 1,
                    child: Text(
                      label,
                      style: type.option.copyWith(color: look.text),
                      textAlign: TextAlign.center,
                      softWrap: true,
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
