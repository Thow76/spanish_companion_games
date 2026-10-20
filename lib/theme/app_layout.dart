/// Layout constants and rules for the responsive frame. UI spec section 5.
///
/// The breakpoints themselves (phone landscape: height < 500 and width
/// ≥ 600, checked first; 600; 1024) are in [FormFactor]. This file holds the
/// widths, paddings and gaps the frames in `lib/widgets/screen_frames.dart`
/// build from them, and the option-grid column rule.
library;

import 'package:flutter/widgets.dart';

import 'app_spacing.dart';
import 'form_factor.dart';

abstract final class AppLayout {
  /// Widest the single column may be (phone landscape home, 600–1023), not
  /// counting the side padding.
  static const double columnMaxWidth = 640;

  /// Widest the laptop content may be, not counting the side padding.
  static const double laptopMaxWidth = 1040;

  /// Laptop game screen side panel: 280–320 wide.
  static const double sidePanelMinWidth = 280;
  static const double sidePanelMaxWidth = 320;

  /// Share of the laptop content width the side panel takes before it is
  /// held between its minimum and maximum.
  static const double sidePanelShare = 0.3;

  /// Gap between the laptop main column and the side panel.
  static const double sidePanelGap = AppSpacing.s32;

  /// Gap between rows on a game screen: 16 on phone and 600–1023, 10 in
  /// phone landscape, 20 on laptop.
  static double gameRowGap(FormFactor f) => switch (f) {
    FormFactor.phone => AppSpacing.s16,
    FormFactor.phoneLandscape => AppSpacing.landscapeRowGap,
    FormFactor.laptop => AppSpacing.s20,
  };

  /// Gap above the explanation card: 24 in phone landscape (so the result
  /// reads as its own block), otherwise the row gap.
  static double resultGap(FormFactor f) =>
      f == FormFactor.phoneLandscape ? AppSpacing.s24 : gameRowGap(f);

  /// Side padding: 16 on phone, 44 in phone landscape, 32 on laptop.
  static double sidePadding(FormFactor f) => switch (f) {
    FormFactor.phone => AppSpacing.phoneMargin,
    FormFactor.phoneLandscape => AppSpacing.landscapePadding,
    FormFactor.laptop => AppSpacing.laptopPadding,
  };

  /// The back chevron's glyph sits this far inside its 44×44 tap area, so
  /// the top bar is pulled left by this much to line the glyph up with the
  /// content edge.
  static const double backChevronInset = 10;

  /// Space above the top bar on a phone (portrait and 600–1023).
  static const double phoneTopPadding = AppSpacing.s24;

  /// Space above the slim top bar in phone landscape.
  static const double landscapeTopPadding = AppSpacing.s8;

  /// Space under the pinned primary button in portrait (clears the home
  /// indicator), and at its sides.
  static const EdgeInsets bottomButtonPadding = EdgeInsets.fromLTRB(
    AppSpacing.s16,
    AppSpacing.s16,
    AppSpacing.s16,
    AppSpacing.s40,
  );

  /// Laptop game screen content padding (under the top bar).
  static const EdgeInsets laptopGamePadding = EdgeInsets.fromLTRB(
    AppSpacing.laptopPadding,
    AppSpacing.s40,
    AppSpacing.laptopPadding,
    64,
  );

  /// Laptop home content padding (under the top bar).
  static const EdgeInsets laptopHomePadding = EdgeInsets.fromLTRB(
    AppSpacing.laptopPadding,
    AppSpacing.s48,
    AppSpacing.laptopPadding,
    AppSpacing.s40,
  );

  /// Gap between the laptop home groups.
  static const double laptopGroupGap = AppSpacing.s32;

  /// Gap between game cards (column on phone, grid on laptop).
  static const double phoneCardGap = AppSpacing.s12;
  static const double laptopCardGap = AppSpacing.s20;

  /// Width of the laptop side panel for a content width of [contentWidth].
  static double sidePanelWidth(double contentWidth) =>
      (contentWidth * sidePanelShare).clamp(
        sidePanelMinWidth,
        sidePanelMaxWidth,
      );

  // Option grids (Choose a correction and Fill the gap).

  /// From this window width the option grid has 4 columns (2 below).
  static const double optionFourColumnsMinWidth = 700;

  /// From this window width phrase-length options go 2 across (1 below).
  static const double optionPhraseTwoColumnsMinWidth = 600;

  /// Gap between options.
  static const double optionGap = AppSpacing.s12;

  /// Columns for an option grid in a window [windowWidth] wide, with
  /// [count] options, [phrases] when any option is longer than 16
  /// characters. 2 columns below 700 and 4 from 700 (wrapping in rows of
  /// 4); with phrases 1 column below 600 and 2 from 600, phone landscape
  /// included. Never more columns than options.
  static int optionColumns(
    double windowWidth, {
    required int count,
    required bool phrases,
  }) {
    final columns = phrases
        ? (windowWidth >= optionPhraseTwoColumnsMinWidth ? 2 : 1)
        : (windowWidth >= optionFourColumnsMinWidth ? 4 : 2);
    if (count <= 0) return columns;
    return count < columns ? count : columns;
  }
}
