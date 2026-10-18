/// Every colour in the app. UI spec section 2.
///
/// This is the only file in `lib/` that may hold colour values. Widgets read
/// colours through `Theme.of(context)` or these constants, never `Color(...)`
/// or hex values of their own.
library;

import 'package:flutter/painting.dart';

abstract final class AppColors {
  // Ground and surfaces.
  static const Color background = Color(0xFF0D1B2A);
  static const Color surface = Color(0xFF1A2E42);

  /// White 8%: card borders, dividers, header rule.
  static const Color hairline = Color(0x14FFFFFF);

  /// White 12%: resting button and chip borders, icon-button borders.
  static const Color stroke = Color(0x1FFFFFFF);

  /// `#4A5568` at 12%: resting answer-option fill.
  static const Color fillNeutral = Color(0x1F4A5568);

  /// White 4%: icon buttons.
  static const Color fillSubtle = Color(0x0AFFFFFF);

  /// White 6%: chips (category chip, neutral rule-pattern chips).
  static const Color fillChip = Color(0x0FFFFFFF);

  /// White 28%: dashed border of a placeholder chip in the rule pattern.
  static const Color placeholderStroke = Color(0x47FFFFFF);

  // Text.
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFE8E8E8);

  /// Captions, counts, instructions, labels, source line, dimmed options.
  static const Color textMuted = Color(0xFF8B95A8);

  /// Divider lines and disabled strokes only. Never text (2.3:1, fails).
  static const Color divider = Color(0xFF4A5568);

  // Action.
  static const Color accent = Color(0xFF00D9FF);

  /// Cyan 12%: primary fills, selected option fill, gap slot fill.
  static const Color accent12 = Color(0x1F00D9FF);

  /// Cyan 40%: resting accent strokes (answer field, placed word chips).
  static const Color accent40 = Color(0x6600D9FF);

  // Feedback. Reserved for feedback; never decoration.
  static const Color correct = Color(0xFF5DE4A0);

  /// Mint 14%: correct fill.
  static const Color correctFill = Color(0x245DE4A0);

  /// Mint 60%: toast border.
  static const Color correct60 = Color(0x995DE4A0);

  /// Mint 40%: feedback panel border.
  static const Color correct40 = Color(0x665DE4A0);

  static const Color wrong = Color(0xFFFF6B4A);

  /// Coral 12%: wrong fill.
  static const Color wrongFill = Color(0x1FFF6B4A);

  /// Coral 60%: toast border.
  static const Color wrong60 = Color(0x99FF6B4A);

  /// Coral 40%: feedback panel border.
  static const Color wrong40 = Color(0x66FF6B4A);

  // Marked words in a phase 1 prompt. Never used for anything else.
  static const Color mark = Color(0xFFFFD166);

  /// Yellow 16%: fill behind the marked words.
  static const Color markFill = Color(0x29FFD166);

  /// Shadows and scrims.
  static const Color black = Color(0xFF000000);

  /// Black 45%: toast shadow (0 -8 24).
  static const Color toastShadow = Color(0x73000000);

  // Game accents: home screen only (icon tile, count, Play link).
  // Not used inside a game.
  static const Color chooseCorrection = Color(0xFFF472B6); // pink
  static const Color repair = Color(0xFFF59E0B); // amber
  static const Color fillGap = Color(0xFF00D9FF); // cyan
  static const Color match = Color(0xFFB39DFF); // lilac
  static const Color order = Color(0xFF5B8DEF); // blue
  static const Color spotError = Color(0xFFD9B98C); // sand

  /// Accent for a game, keyed by its `game` value in `questions.json`.
  static const Map<String, Color> gameAccents = {
    'choose_correction': chooseCorrection,
    'repair': repair,
    'fill_gap': fillGap,
    'match': match,
    'order': order,
    'spot_error': spotError,
  };

  /// Accent for [game] (a `game` value such as `fill_gap`). Unknown games
  /// get the action accent.
  static Color gameAccent(String game) => gameAccents[game] ?? accent;

  /// Icon-tile fill for a game accent (12%).
  static Color gameTileFill(Color gameAccent) =>
      gameAccent.withValues(alpha: 0.12);

  /// Icon-tile stroke for a game accent (40%).
  static Color gameTileStroke(Color gameAccent) =>
      gameAccent.withValues(alpha: 0.40);
}
