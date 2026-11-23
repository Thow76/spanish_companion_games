/// FixedWords (U20): the fixed start or end of a long Sentence ordering
/// sentence (B29/B31), shown among the word chips.
///
/// It reads as part of the sentence but clearly cannot be moved: the same
/// text size as the chips (answer-option style), but no box, no border and
/// no fill, in `textMuted`, so it does not look like something to tap. It is
/// padded to the word chip's height and centred, so it sits on the same
/// line as the chips around it, and it wraps rather than being cut off.
///
/// Not a button and not focusable. A screen reader hears "Fixed start:
/// Cuando llegué a casa anoche," (or "Fixed end: …").
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

enum FixedWordsPlace { start, end }

class FixedWords extends StatelessWidget {
  const FixedWords({super.key, required this.text, required this.place});

  final String text;
  final FixedWordsPlace place;

  static const String startLabel = 'Fixed start';
  static const String endLabel = 'Fixed end';

  /// Side padding, so the text keeps a little room from the chips beside
  /// it on top of the Wrap's own spacing.
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: AppSpacing.s4,
    vertical: AppSpacing.s8,
  );

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    final label = place == FixedWordsPlace.start ? startLabel : endLabel;
    return Semantics(
      label: '$label: $text',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.wordChip),
        child: Padding(
          padding: padding,
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              text,
              style: type.option.copyWith(color: AppColors.textMuted),
              softWrap: true,
            ),
          ),
        ),
      ),
    );
  }
}
