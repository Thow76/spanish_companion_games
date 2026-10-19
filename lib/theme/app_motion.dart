/// Durations and curves. UI spec section 9.
///
/// Every animation respects reduced motion: use [AppMotion.duration], which
/// is zero when `MediaQuery.disableAnimations` is on.
library;

import 'package:flutter/widgets.dart';

abstract final class AppMotion {
  /// Option state changes, the explanation card and Spot the error field
  /// appearing, the toast sliding, the laptop feedback panel appearing.
  static const Duration fast = Duration(milliseconds: 150);

  /// How long the result toast stays before sliding away.
  static const Duration toastHold = Duration(milliseconds: 2500);

  /// The one curve: ease-out, no bounces.
  static const Curve curve = Curves.easeOut;

  /// [fast], or zero with reduced motion.
  static Duration duration(BuildContext context) =>
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false)
      ? Duration.zero
      : fast;
}
