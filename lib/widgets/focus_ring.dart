/// The visible keyboard focus ring. UI spec section 10: 2px accent ring,
/// 2px away from the element, on every focusable element.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Draws the focus ring around [child] while something inside it has
/// keyboard focus. The ring only shows when focus came from the keyboard
/// (not after a tap or click).
class FocusRing extends StatefulWidget {
  const FocusRing({super.key, required this.child, this.radius = 12});

  final Widget child;

  /// Corner radius of [child]; the ring follows it, 4px further out.
  final double radius;

  @override
  State<FocusRing> createState() => _FocusRingState();
}

class _FocusRingState extends State<FocusRing> {
  bool _focused = false;
  bool _keyboard =
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    super.dispose();
  }

  void _onHighlightMode(FocusHighlightMode mode) {
    final keyboard = mode == FocusHighlightMode.traditional;
    if (keyboard != _keyboard && mounted) setState(() => _keyboard = keyboard);
  }

  @override
  Widget build(BuildContext context) {
    const outset = AppStroke.focusRing + AppStroke.focusOffset;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: Stack(
        clipBehavior: Clip.none,
        // Pass the parent's constraints straight to the child, so a
        // full-width button stays full width inside the ring.
        fit: StackFit.passthrough,
        children: [
          widget.child,
          if (_focused && _keyboard)
            Positioned(
              left: -outset,
              top: -outset,
              right: -outset,
              bottom: -outset,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(widget.radius + outset),
                    border: Border.all(
                      color: AppColors.accent,
                      width: AppStroke.focusRing,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
