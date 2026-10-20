/// HomeTopBar (UI spec section 6).
///
/// - Phone (portrait, landscape and 600–1023): small "Spanish Companion"
///   label (Sora 600 13, accent), the "Games" title, the source line
///   ("9 questions · sample file", muted), and a 44×44 reload icon button.
/// - Laptop: one bar with "Spanish Companion Games" ("Games" in accent),
///   the source line and a "Reload" button with its icon. The hairline
///   under it is drawn full width by [HomeFrame].
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import 'app_icon_button.dart';
import 'focus_ring.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key, required this.source, required this.onReload});

  /// The source line, e.g. "9 questions · sample file". The home screen
  /// builds it from the loader.
  final String source;

  /// Reloads the questions. Null disables the button (while loading).
  final VoidCallback? onReload;

  static const String brand = 'Spanish Companion';
  static const String phoneTitle = 'Games';
  static const String reloadLabel = 'Reload questions';

  @override
  Widget build(BuildContext context) {
    return FormFactor.of(context) == FormFactor.laptop
        ? _laptop(context)
        : _phone(context);
  }

  Widget _phone(BuildContext context) {
    final type = AppTypography.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(brand, style: type.homeBrand),
              const SizedBox(height: AppSpacing.s4),
              Semantics(
                header: true,
                child: Text(phoneTitle, style: type.screenTitle),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(source, style: type.caption),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        AppIconButton(
          icon: Icons.refresh_rounded,
          tooltip: reloadLabel,
          onPressed: onReload,
        ),
      ],
    );
  }

  Widget _laptop(BuildContext context) {
    final type = AppTypography.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              label: '$brand Games',
              excludeSemantics: true,
              child: Text.rich(
                TextSpan(
                  text: '$brand ',
                  children: const [
                    TextSpan(
                      text: phoneTitle,
                      style: TextStyle(color: AppColors.accent),
                    ),
                  ],
                ),
                style: type.gameTitle,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Text(source, style: type.caption),
          const SizedBox(width: AppSpacing.s12),
          _ReloadButton(onPressed: onReload),
        ],
      ),
    );
  }
}

/// The laptop "Reload" button: 40 high, icon and label, the theme's
/// outlined (icon-button) look.
class _ReloadButton extends StatelessWidget {
  const _ReloadButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    return FocusRing(
      radius: AppRadius.control,
      child: Tooltip(
        message: HomeTopBar.reloadLabel,
        child: Semantics(
          button: true,
          label: HomeTopBar.reloadLabel,
          excludeSemantics: true,
          onTap: onPressed,
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.refresh_rounded, size: AppSizes.iconSmall),
            label: const Text('Reload'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(
                AppSizes.minTarget,
                AppSizes.iconButtonLaptop,
              ),
              fixedSize: const Size.fromHeight(AppSizes.iconButtonLaptop),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
              textStyle: type.caption.withWeight(500),
              foregroundColor: AppColors.textSecondary,
              iconColor: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
