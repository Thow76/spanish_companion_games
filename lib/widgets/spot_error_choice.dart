/// The Spot the error choice (UI spec section 6): two AnswerOptions side by
/// side, "It's correct" and "It needs fixing" (one column below 360px).
///
/// Choosing "It needs fixing" shows [field] (usually an [AnswerField]
/// prefilled with the sentence) under them, growing in over 150 ms, with no
/// motion under reduced motion. Check is enabled once "It's correct" is
/// chosen, or once the field differs from the sentence: see [canCheck].
///
/// After checking pass [sentenceWasCorrect] (and `onPicked: null`): the
/// chosen option is marked correct or wrong; if it was wrong, the right one
/// is shown correct, the same as the other option games.
library;

import 'package:flutter/material.dart';

import '../theme/app_layout.dart';
import '../theme/app_motion.dart';
import 'answer_option.dart';

enum SpotErrorPick { correct, needsFixing }

class SpotErrorChoice extends StatelessWidget {
  const SpotErrorChoice({
    super.key,
    required this.picked,
    required this.onPicked,
    required this.field,
    this.sentenceWasCorrect,
  });

  /// What the learner chose, or null before choosing.
  final SpotErrorPick? picked;

  /// Null disables both options (always, after checking).
  final ValueChanged<SpotErrorPick>? onPicked;

  /// Shown under the options while [picked] is "It needs fixing".
  final Widget field;

  /// Null before checking; after checking, whether the sentence as shown
  /// was already correct.
  final bool? sentenceWasCorrect;

  /// Option labels (section 8).
  static const String correctLabel = "It's correct";
  static const String needsFixingLabel = 'It needs fixing';

  /// Below this window width the two options stack in one column.
  static const double singleColumnBelow = 360;

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

  AnswerState _stateOf(SpotErrorPick option) {
    final wasCorrect = sentenceWasCorrect;
    if (wasCorrect == null) {
      return option == picked ? AnswerState.selected : AnswerState.resting;
    }
    final right = wasCorrect
        ? SpotErrorPick.correct
        : SpotErrorPick.needsFixing;
    if (option == right) return AnswerState.correct;
    if (option == picked) return AnswerState.wrong;
    return AnswerState.dimmed;
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < singleColumnBelow;

    Widget option(SpotErrorPick value, String label) => AnswerOption(
      label: label,
      state: _stateOf(value),
      onPressed: onPicked == null ? null : () => onPicked!(value),
    );

    final correct = option(SpotErrorPick.correct, correctLabel);
    final needsFixing = option(SpotErrorPick.needsFixing, needsFixingLabel);

    final options = narrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              correct,
              const SizedBox(height: AppLayout.optionGap),
              needsFixing,
            ],
          )
        : IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: correct),
                const SizedBox(width: AppLayout.optionGap),
                Expanded(child: needsFixing),
              ],
            ),
          );

    final showField = picked == SpotErrorPick.needsFixing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          container: true,
          label: 'Is this sentence correct?',
          child: options,
        ),
        AnimatedSize(
          duration: AppMotion.duration(context),
          curve: AppMotion.curve,
          alignment: Alignment.topCenter,
          child: showField
              ? Padding(
                  padding: const EdgeInsets.only(top: AppLayout.optionGap),
                  child: field,
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
