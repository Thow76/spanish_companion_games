/// GameTopBar (UI spec section 6), one widget for the three layouts:
///
/// - Phone portrait (and 600–1023): back chevron (24px glyph, no border,
///   44×44 tap area) and the game title (Sora 600 28/36). Nothing else.
/// - Phone landscape: 44 high. Back chevron and title (20/28) on the left;
///   on the right the primary action as a text link the same size as the
///   title, followed by a right chevron. "Check ›" is muted and does
///   nothing until [onAction] is set; then "Check ›", "Next question ›" or
///   "See results ›" in accent.
/// - Laptop: one wide bar: close button, title, "Question 2 of 3"
///   right-aligned. Hairline underneath.
///
/// No progress bar anywhere.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import 'app_icon_button.dart';
import 'chips.dart';
import 'focus_ring.dart';

class GameTopBar extends StatelessWidget {
  const GameTopBar({
    super.key,
    required this.title,
    required this.onBack,
    this.current,
    this.total,
    this.actionLabel = 'Check',
    this.onAction,
    this.actionFocusNode,
  });

  /// The game's name, e.g. "Choose a correction".
  final String title;

  /// Back (phone) or close (laptop): returns home.
  final VoidCallback? onBack;

  /// Question number and total, shown on laptop only (on phones the count
  /// is on the chip row).
  final int? current;
  final int? total;

  /// Phone landscape only: "Check", "Next question" or "See results".
  final String actionLabel;

  /// Phone landscape only. Null shows the muted, inactive "Check ›".
  final VoidCallback? onAction;

  /// Phone landscape only: lets the screen move focus to the action after
  /// checking (section 10).
  final FocusNode? actionFocusNode;

  @override
  Widget build(BuildContext context) {
    return switch (FormFactor.of(context)) {
      FormFactor.phone => _portrait(context),
      FormFactor.phoneLandscape => _landscape(context),
      FormFactor.laptop => _laptop(context),
    };
  }

  Widget _portrait(BuildContext context) {
    final type = AppTypography.of(context);
    return Row(
      children: [
        AppIconButton.back(onPressed: onBack),
        const SizedBox(width: AppSpacing.s4),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: type.gameTitle),
          ),
        ),
      ],
    );
  }

  Widget _landscape(BuildContext context) {
    final type = AppTypography.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.landscapeTopBar),
      child: Row(
        children: [
          AppIconButton.back(onPressed: onBack),
          const SizedBox(width: AppSpacing.s4),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(title, style: type.gameTitle),
            ),
          ),
          const SizedBox(width: AppSpacing.s16),
          _TopBarAction(
            label: actionLabel,
            onPressed: onAction,
            focusNode: actionFocusNode,
          ),
        ],
      ),
    );
  }

  Widget _laptop(BuildContext context) {
    final type = AppTypography.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
        child: Row(
          children: [
            AppIconButton(
              icon: Icons.close_rounded,
              tooltip: 'Close',
              onPressed: onBack,
              compact: true,
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title, style: type.gameTitle),
              ),
            ),
            if (current != null && total != null) ...[
              const SizedBox(width: AppSpacing.s16),
              Count(current: current!, total: total!),
            ],
          ],
        ),
      ),
    );
  }
}

/// The phone-landscape primary action: a text link with a right chevron,
/// 44 high, no box. A real button labelled with its text.
class _TopBarAction extends StatelessWidget {
  const _TopBarAction({
    required this.label,
    required this.onPressed,
    this.focusNode,
  });

  final String label;
  final VoidCallback? onPressed;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final colour = enabled ? AppColors.accent : AppColors.textMuted;
    final style = AppTypography.of(
      context,
    ).topBarAction.copyWith(color: colour);
    return FocusRing(
      radius: AppRadius.control,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        excludeSemantics: true,
        onTap: onPressed,
        child: InkWell(
          onTap: onPressed,
          focusNode: focusNode,
          borderRadius: AppRadius.controlAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: AppSizes.landscapeTopBar,
              minWidth: AppSizes.minTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: AppSpacing.s8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: style),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: AppSizes.glyph,
                    color: colour,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
