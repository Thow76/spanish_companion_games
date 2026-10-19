/// IconButton (UI spec section 6): 44×44 (40 on the laptop top bar),
/// radius 12, 1px stroke, 20px icon in textSecondary, always with a tooltip
/// and a semantic label. The phone back chevron is the borderless form.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'focus_ring.dart';

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.compact = false,
  }) : _borderless = false;

  /// The phone back chevron: no border or fill, a 24px glyph, 44×44 tap
  /// area, labelled "Back".
  const AppIconButton.back({
    super.key,
    required this.onPressed,
    this.tooltip = 'Back',
  }) : icon = Icons.chevron_left_rounded,
       compact = false,
       _borderless = true;

  final IconData icon;

  /// Shown on hover and long press, and read by screen readers.
  final String tooltip;
  final VoidCallback? onPressed;

  /// 40×40, for the laptop top bar.
  final bool compact;

  final bool _borderless;

  @override
  Widget build(BuildContext context) {
    final side = compact ? AppSizes.iconButtonLaptop : AppSizes.iconButton;
    final style = _borderless
        ? IconButton.styleFrom(
            fixedSize: const Size(AppSizes.minTarget, AppSizes.minTarget),
            minimumSize: const Size(AppSizes.minTarget, AppSizes.minTarget),
            iconSize: AppSizes.glyph,
            backgroundColor: AppColors.transparent,
            side: BorderSide.none,
            padding: EdgeInsets.zero,
          )
        : IconButton.styleFrom(
            fixedSize: Size(side, side),
            minimumSize: Size(side, side),
            padding: EdgeInsets.zero,
          );
    return FocusRing(
      radius: AppRadius.control,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        onTap: onPressed,
        child: IconButton(
          icon: Icon(icon),
          tooltip: tooltip,
          onPressed: onPressed,
          style: style,
        ),
      ),
    );
  }
}
