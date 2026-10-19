/// AnswerOption (UI spec section 6): one answer button.
///
/// States: resting (fillNeutral, 1px stroke, textSecondary); selected
/// (accent 12%, 2px accent, textPrimary); correct (mint 14%, 2px mint, mint
/// text, tick); chosen-and-wrong (coral 12%, 2px coral, coral text, cross);
/// dimmed after checking (transparent, 1px hairline, textMuted). After
/// checking every option is disabled: pass `onPressed: null`.
///
/// Minimum heights 56 phone portrait, 48 phone landscape, 64 laptop.
/// Phrase-length labels (longer than 16 characters) use the smaller phrase
/// size, wrap onto more lines and the option grows; never truncated.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import 'focus_ring.dart';

enum AnswerState { resting, selected, correct, wrong, dimmed }

class AnswerOption extends StatelessWidget {
  const AnswerOption({
    super.key,
    required this.label,
    required this.state,
    required this.onPressed,
    this.focusNode,
    this.autofocus = false,
  });

  final String label;
  final AnswerState state;

  /// Null disables the option (always, after checking).
  final VoidCallback? onPressed;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Labels longer than this are phrase-length (section 5 and 3).
  static const int phraseLength = 16;

  /// Whether any of [labels] is phrase-length; the option grid then uses
  /// fewer columns (section 5).
  static bool anyPhrase(Iterable<String> labels) =>
      labels.any((l) => l.length > phraseLength);

  bool get _isPhrase => label.length > phraseLength;

  ({Color fill, Color border, double width, Color text}) get _look =>
      switch (state) {
        AnswerState.resting => (
          fill: AppColors.fillNeutral,
          border: AppColors.stroke,
          width: AppStroke.resting,
          text: AppColors.textSecondary,
        ),
        AnswerState.selected => (
          fill: AppColors.accent12,
          border: AppColors.accent,
          width: AppStroke.strong,
          text: AppColors.textPrimary,
        ),
        AnswerState.correct => (
          fill: AppColors.correctFill,
          border: AppColors.correct,
          width: AppStroke.strong,
          text: AppColors.correct,
        ),
        AnswerState.wrong => (
          fill: AppColors.wrongFill,
          border: AppColors.wrong,
          width: AppStroke.strong,
          text: AppColors.wrong,
        ),
        AnswerState.dimmed => (
          fill: AppColors.transparent,
          border: AppColors.hairline,
          width: AppStroke.resting,
          text: AppColors.textMuted,
        ),
      };

  double _minHeight(FormFactor f) => switch (f) {
    FormFactor.phone => AppSizes.optionPhone,
    FormFactor.phoneLandscape => AppSizes.optionLandscape,
    FormFactor.laptop => AppSizes.optionLaptop,
  };

  String get _semanticLabel => switch (state) {
    AnswerState.correct => '$label, correct',
    AnswerState.wrong => '$label, wrong',
    _ => label,
  };

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    final look = _look;
    final marked = state == AnswerState.correct || state == AnswerState.wrong;
    final base = _isPhrase ? type.optionPhrase : type.option;
    final textStyle = (marked ? base.withWeight(600) : base).copyWith(
      color: look.text,
    );
    final icon = switch (state) {
      AnswerState.correct => Icons.check_rounded,
      AnswerState.wrong => Icons.close_rounded,
      _ => null,
    };
    // Keep the content still when the border thickens from 1 to 2px.
    final inset = AppSpacing.s12 - look.width;

    return FocusRing(
      radius: AppRadius.control,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        selected: state == AnswerState.selected,
        label: _semanticLabel,
        excludeSemantics: true,
        onTap: onPressed,
        child: AnimatedContainer(
          duration: AppMotion.duration(context),
          curve: AppMotion.curve,
          constraints: BoxConstraints(
            minHeight: _minHeight(FormFactor.of(context)),
          ),
          decoration: BoxDecoration(
            color: look.fill,
            borderRadius: AppRadius.controlAll,
            border: Border.all(color: look.border, width: look.width),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onPressed,
              focusNode: focusNode,
              autofocus: autofocus,
              borderRadius: AppRadius.controlAll,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: inset,
                  vertical: inset,
                ),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: AppSizes.iconSmall, color: look.text),
                        const SizedBox(width: AppSpacing.s8),
                      ],
                      Flexible(
                        child: Text(
                          label,
                          style: textStyle,
                          textAlign: TextAlign.center,
                          softWrap: true,
                        ),
                      ),
                    ],
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
