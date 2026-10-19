/// PrimaryButton (UI spec section 6): accent 12% fill, 2px accent stroke,
/// white Sora label, radius 12, 52 high. Disabled (nothing chosen yet, or
/// the field unchanged): fillSubtle, 1px stroke, muted label. The look comes
/// from the theme's `FilledButton` style (`app_theme.dart`).
///
/// Full width on phone and 600–1023; on laptop it sizes to its label with a
/// minimum width of 200 (the screen right-aligns it). In phone landscape the
/// primary action is the top-bar link instead (see [GameTopBar]).
library;

import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/form_factor.dart';
import 'focus_ring.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailingIcon,
    this.focusNode,
    this.autofocus = false,
  });

  /// "Check". [onPressed] null shows the disabled state.
  const PrimaryButton.check({super.key, required this.onPressed})
    : label = 'Check',
      trailingIcon = null,
      focusNode = null,
      autofocus = false;

  /// "Next question →", or "See results" on the last question. Screens move
  /// keyboard focus here after checking (section 10), through [focusNode].
  const PrimaryButton.next({
    super.key,
    required this.onPressed,
    bool last = false,
    this.focusNode,
    this.autofocus = false,
  }) : label = last ? 'See results' : 'Next question',
       trailingIcon = last ? null : Icons.arrow_forward_rounded;

  final String label;
  final VoidCallback? onPressed;
  final IconData? trailingIcon;
  final FocusNode? focusNode;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final laptop = FormFactor.of(context) == FormFactor.laptop;
    final button = FilledButton(
      onPressed: onPressed,
      focusNode: focusNode,
      autofocus: autofocus,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, textAlign: TextAlign.center),
          if (trailingIcon != null) ...[
            const SizedBox(width: AppSpacing.s8),
            Icon(trailingIcon, size: AppSizes.iconSmall),
          ],
        ],
      ),
    );
    return FocusRing(
      radius: AppRadius.control,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: AppSizes.primaryButton,
          minWidth: laptop ? AppSizes.primaryButtonMinWidthLaptop : 0,
        ),
        child: laptop
            ? button
            : SizedBox(width: double.infinity, child: button),
      ),
    );
  }
}
