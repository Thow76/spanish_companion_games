/// TitleText: a screen or game title that grows with the text size
/// setting up to [AppLayout.maxTitleFontSize] (UI spec sections 3 and 10).
///
/// At 200% the 28px game title would be 56px, and a word like "correction"
/// no longer fits a 320 phone, so Flutter breaks it mid-word. Capping the
/// title at 36px (the spec's largest type size) keeps whole words. Only
/// titles use this; question content (prompt, options, explanation) always
/// takes the full text size.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_layout.dart';

class TitleText extends StatelessWidget {
  const TitleText(this.text, {super.key, required this.style}) : span = null;

  /// A title made of styled parts (the laptop home title).
  const TitleText.rich(this.span, {super.key, required this.style})
    : text = null;

  final String? text;
  final InlineSpan? span;
  final TextStyle style;

  /// The largest text scale a title of [fontSize] may take.
  static double maxScaleFor(double fontSize) =>
      math.max(1, AppLayout.maxTitleFontSize / fontSize);

  @override
  Widget build(BuildContext context) {
    final child = span != null
        ? Text.rich(span!, style: style)
        : Text(text!, style: style);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: maxScaleFor(style.fontSize ?? 14),
      child: child,
    );
  }
}
