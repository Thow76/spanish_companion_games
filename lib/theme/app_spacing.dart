/// Spacing, radius, stroke and size constants. UI spec section 4.
library;

import 'package:flutter/painting.dart';

/// The 4px spacing scale and the fixed paddings built from it.
abstract final class AppSpacing {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;

  /// Phone portrait side margin.
  static const double phoneMargin = 16;

  /// Phone landscape side padding (clears the notch).
  static const double landscapePadding = 44;

  /// Laptop side padding.
  static const double laptopPadding = 32;

  /// Gap between rows on a phone-landscape game screen.
  static const double landscapeRowGap = 10;
}

/// Corner radii.
abstract final class AppRadius {
  /// Chips and rule-pattern chips.
  static const double chip = 8;

  /// Answer options, buttons, inputs, icon buttons, landscape toast.
  static const double control = 12;

  /// Cards and panels; portrait toast (top corners only).
  static const double card = 16;

  /// Marked-word highlight and gap slot (top corners only).
  static const double mark = 4;

  /// Pills.
  static const double pill = 999;

  static const BorderRadius chipAll = BorderRadius.all(Radius.circular(chip));
  static const BorderRadius controlAll =
      BorderRadius.all(Radius.circular(control));
  static const BorderRadius cardAll = BorderRadius.all(Radius.circular(card));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius markTop = BorderRadius.vertical(
    top: Radius.circular(mark),
  );
  static const BorderRadius toastTop = BorderRadius.vertical(
    top: Radius.circular(card),
  );
}

/// Stroke widths.
abstract final class AppStroke {
  /// Resting borders.
  static const double resting = 1;

  /// Selected, marked correct/wrong, rule answer chip, marked-word underline,
  /// primary button, focused field.
  static const double strong = 2;

  /// Focus ring width and its offset from the element (section 10).
  static const double focusRing = 2;
  static const double focusOffset = 2;
}

/// Minimum sizes of touch targets and controls.
abstract final class AppSizes {
  /// Smallest touch target anywhere.
  static const double minTarget = 44;

  /// Preferred touch target on phone.
  static const double phoneTarget = 48;

  /// Answer option minimum heights.
  static const double optionPhone = 56;
  static const double optionLandscape = 48;
  static const double optionLaptop = 64;

  /// Primary button height.
  static const double primaryButton = 52;

  /// Laptop primary button minimum width.
  static const double primaryButtonMinWidthLaptop = 200;

  /// Landscape top bar and its action.
  static const double landscapeTopBar = 44;

  /// Icon buttons: 44 (40 on the laptop top bar).
  static const double iconButton = 44;
  static const double iconButtonLaptop = 40;

  /// Text field minimum heights.
  static const double fieldPhone = 56;
  static const double fieldLandscape = 48;

  /// Gap slot minimum width in a Fill the gap prompt.
  static const double gapSlotMinWidth = 56;
}
