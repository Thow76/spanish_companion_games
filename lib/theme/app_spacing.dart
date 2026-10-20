/// Spacing, radius, stroke and size constants. UI spec section 4.
library;

import 'package:flutter/painting.dart';

import 'app_colors.dart';

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
  static const BorderRadius controlAll = BorderRadius.all(
    Radius.circular(control),
  );
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

  // Icons (section 6 and 7).

  /// Generic glyphs: back chevron, landscape action chevron, game icons.
  static const double glyph = 24;

  /// Icons inside icon buttons, answer options and buttons.
  static const double iconSmall = 20;

  /// Circled tick or cross on the portrait toast.
  static const double toastIcon = 22;

  /// Portrait toast height, including the bottom safe area ("about 100").
  static const double toastPortraitMinHeight = 100;

  /// Circled tick or cross on the landscape toast.
  static const double toastIconLandscape = 20;

  // Game cards (section 6, GameCard).

  /// Icon tile on a phone game card, and on a laptop card.
  static const double gameTilePhone = 48;
  static const double gameTileLaptop = 56;

  /// Minimum heights of a game card.
  static const double gameCardPhone = 88;
  static const double gameCardLaptop = 196;

  /// Widest the "No questions yet" text may be on a phone card (wraps).
  static const double gameCardCountMaxWidth = 88;

  // Explanation card (section 6, ExplanationCard).

  /// Width of the label column ("Meaning", "You wrote") in the portrait card.
  static const double explanationLabelColumn = 80;

  /// Smallest width left for the labelled lines beside the chips in the
  /// landscape card; below it the card falls back to the portrait layout.
  static const double explanationLandscapeMinRight = 240;

  /// Session panel dots (current and to come).
  static const double sessionDot = 10;
}

/// Paddings with values from the spec that are not on the 4px scale.
abstract final class AppInsets {
  /// Landscape explanation card: 10 top and bottom, 16 sides.
  static const EdgeInsets explanationLandscape = EdgeInsets.symmetric(
    vertical: 10,
    horizontal: 16,
  );

  /// Portrait toast: 22 top, 24 sides, 40 bottom (clears the home indicator).
  static const EdgeInsets toastPortrait = EdgeInsets.fromLTRB(24, 22, 24, 40);

  /// Landscape toast, about 69 high with a 20px line.
  static const EdgeInsets toastLandscape = EdgeInsets.symmetric(
    vertical: 24,
    horizontal: 24,
  );

  /// Prompt card padding: 24/20 phone portrait, 16/20 phone landscape,
  /// 28/28 laptop (vertical/horizontal).
  static const EdgeInsets promptPhone = EdgeInsets.symmetric(
    vertical: 24,
    horizontal: 20,
  );
  static const EdgeInsets promptLandscape = EdgeInsets.symmetric(
    vertical: 16,
    horizontal: 20,
  );
  static const EdgeInsets promptLaptop = EdgeInsets.all(28);

  /// Chip padding: 4 top and bottom, 8 sides.
  static const EdgeInsets chip = EdgeInsets.symmetric(
    vertical: 4,
    horizontal: 8,
  );
}

/// Toast shadow: 0 −8 24, black 45%.
const List<BoxShadow> appToastShadow = [
  BoxShadow(
    color: AppColors.toastShadow,
    offset: Offset(0, -8),
    blurRadius: 24,
  ),
];
