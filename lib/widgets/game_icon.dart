/// The six game icons (UI spec section 7): SVGs in `assets/icons/`, drawn
/// with 2px round strokes on a 24 grid, tinted with a colour.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_spacing.dart';

class GameIcon extends StatelessWidget {
  const GameIcon({
    super.key,
    required this.game,
    required this.color,
    this.size = AppSizes.glyph,
  });

  /// The `game` value from `questions.json`, e.g. `fill_gap`.
  final String game;
  final Color color;
  final double size;

  /// The `game` values that have an icon.
  static const List<String> games = [
    'choose_correction',
    'repair',
    'fill_gap',
    'match',
    'order',
    'spot_error',
  ];

  /// Asset path of the icon for [game].
  static String assetPath(String game) => 'assets/icons/$game.svg';

  @override
  Widget build(BuildContext context) {
    if (!games.contains(game)) return SizedBox.square(dimension: size);
    return SvgPicture.asset(
      assetPath(game),
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      // The card or button around it carries the label.
      excludeFromSemantics: true,
    );
  }
}
