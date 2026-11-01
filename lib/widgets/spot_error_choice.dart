/// The Spot the error choice (UI spec section 6, redesigned 2026-10-30;
/// canvas row "Spot the error · proposed").
///
/// Sits inside the prompt card ([PromptCard.spotError]), under the sentence
/// or the field: a hairline with 16 above and below (8 in phone landscape),
/// then one row: "Is this sentence correct?" on the left and two icon
/// buttons on the right, 8 apart: ✓ ("It's correct") and ✗ ("It needs
/// fixing"), 48×48 (44 in phone landscape), radius 12.
///
/// The ✓ is always `correct` (mint) and the ✗ always `wrong` (coral): they
/// label the sentence, not whether the learner was right. Resting:
/// `fillNeutral`, 1px `stroke`, icon in its colour. Chosen: its colour at
/// 14% (✓) or 12% (✗) and a 2px border in its colour.
///
/// After checking (pass [checked]): both buttons disabled, the chosen one
/// keeps its chosen style, the other is dimmed (transparent, 1px
/// `hairline`, icon `textMuted`), and the question text turns `textMuted`.
/// Whether the learner was right is shown by the toast, the explanation
/// card's heading and the laptop FeedbackPanel, never by these buttons.
///
/// Check is enabled once ✓ is chosen, or once the field differs from the
/// sentence: see [SpotErrorChoice.canCheck].
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import 'focus_ring.dart';

enum SpotErrorPick { correct, needsFixing }

/// How one ✓/✗ button looks.
enum SpotErrorButtonState {
  /// Not chosen (before checking).
  resting,

  /// Chosen, before and after checking.
  chosen,

  /// After checking, the one not chosen.
  dimmed,
}

class SpotErrorChoice extends StatelessWidget {
  const SpotErrorChoice({
    super.key,
    required this.picked,
    required this.onPicked,
    this.checked = false,
  });

  /// What the learner chose, or null before choosing.
  final SpotErrorPick? picked;

  /// Null disables both buttons (always, after checking).
  final ValueChanged<SpotErrorPick>? onPicked;

  /// Whether the question has been checked.
  final bool checked;

  /// The question beside the buttons (section 8).
  static const String question = 'Is this sentence correct?';

  /// The buttons' semantic labels and tooltips (section 8; no visible
  /// text).
  static const String correctLabel = "It's correct";
  static const String needsFixingLabel = 'It needs fixing';

  /// Whether Check can be pressed: "It's correct" chosen, or "It needs
  /// fixing" chosen and [fieldText] differs from [sentence].
  static bool canCheck(
    SpotErrorPick? picked, {
    required String fieldText,
    required String sentence,
  }) => switch (picked) {
    SpotErrorPick.correct => true,
    SpotErrorPick.needsFixing => fieldText.trim() != sentence.trim(),
    null => false,
  };

  SpotErrorButtonState _stateOf(SpotErrorPick value) {
    if (value == picked) return SpotErrorButtonState.chosen;
    return checked ? SpotErrorButtonState.dimmed : SpotErrorButtonState.resting;
  }

  @override
  Widget build(BuildContext context) {
    final landscape = FormFactor.of(context) == FormFactor.phoneLandscape;
    final type = AppTypography.of(context);
    final gap = landscape ? AppSpacing.s8 : AppSpacing.s16;
    final enabled = onPicked != null && !checked;

    Widget button(SpotErrorPick value) => SpotErrorButton(
      pick: value,
      state: _stateOf(value),
      onPressed: enabled ? () => onPicked!(value) : null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: gap),
        const Divider(
          height: AppStroke.resting,
          thickness: AppStroke.resting,
          color: AppColors.hairline,
        ),
        SizedBox(height: gap),
        Semantics(
          container: true,
          explicitChildNodes: true,
          label: question,
          child: Row(
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    question,
                    style: type.spotErrorQuestion.copyWith(
                      color: checked
                          ? AppColors.textMuted
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              button(SpotErrorPick.correct),
              const SizedBox(width: AppSpacing.s8),
              button(SpotErrorPick.needsFixing),
            ],
          ),
        ),
      ],
    );
  }
}

/// One of the two icon buttons: ✓ ("It's correct", always mint) or ✗ ("It
/// needs fixing", always coral). A real button with its label as semantic
/// label and tooltip; its chosen state is announced as selected.
class SpotErrorButton extends StatelessWidget {
  const SpotErrorButton({
    super.key,
    required this.pick,
    required this.state,
    required this.onPressed,
  });

  final SpotErrorPick pick;
  final SpotErrorButtonState state;

  /// Null disables the button.
  final VoidCallback? onPressed;

  String get label => pick == SpotErrorPick.correct
      ? SpotErrorChoice.correctLabel
      : SpotErrorChoice.needsFixingLabel;

  @override
  Widget build(BuildContext context) {
    final landscape = FormFactor.of(context) == FormFactor.phoneLandscape;
    final side = landscape
        ? AppSizes.spotErrorButtonLandscape
        : AppSizes.spotErrorButton;
    final iconSize = landscape
        ? AppSizes.spotErrorIconLandscape
        : AppSizes.spotErrorIcon;
    final isCorrect = pick == SpotErrorPick.correct;
    final colour = isCorrect ? AppColors.correct : AppColors.wrong;

    final (
      Color fill,
      Color border,
      double width,
      Color icon,
    ) = switch (state) {
      SpotErrorButtonState.resting => (
        AppColors.fillNeutral,
        AppColors.stroke,
        AppStroke.resting,
        colour,
      ),
      SpotErrorButtonState.chosen => (
        isCorrect ? AppColors.correctFill : AppColors.wrongFill,
        colour,
        AppStroke.strong,
        colour,
      ),
      SpotErrorButtonState.dimmed => (
        AppColors.transparent,
        AppColors.hairline,
        AppStroke.resting,
        AppColors.textMuted,
      ),
    };

    return FocusRing(
      radius: AppRadius.control,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        selected: state == SpotErrorButtonState.chosen,
        label: label,
        onTap: onPressed,
        excludeSemantics: true,
        child: Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onPressed,
              borderRadius: AppRadius.controlAll,
              // The border and fill show the state; no ripple box on top
              // (as the landscape top-bar link, U5).
              splashFactory: NoSplash.splashFactory,
              highlightColor: AppColors.transparent,
              hoverColor: AppColors.transparent,
              focusColor: AppColors.transparent,
              child: AnimatedContainer(
                duration: AppMotion.duration(context),
                curve: AppMotion.curve,
                width: side,
                height: side,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: AppRadius.controlAll,
                  border: Border.all(color: border, width: width),
                ),
                child: Icon(
                  isCorrect ? Icons.check_rounded : Icons.close_rounded,
                  size: iconSize,
                  color: icon,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
