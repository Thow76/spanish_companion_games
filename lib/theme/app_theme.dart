/// The app's dark `ThemeData`. UI spec sections 2–4 and 10 (focus colour).
///
/// Built per [FormFactor] so `Theme.of(context).textTheme` has the right
/// sizes for the screen; `main.dart` rebuilds it as the window changes size.
///
/// Text theme mapping (the roles are in [AppTypography]):
/// - headlineMedium: screen title
/// - headlineSmall: game title (top bar)
/// - titleLarge: card title
/// - titleMedium: phase heading
/// - titleSmall: feedback heading
/// - labelLarge: button label
/// - labelMedium: chip
/// - labelSmall: explanation card label ("RULE")
/// - bodyLarge: the Spanish sentence (prompt)
/// - bodyMedium: body (also the default for plain `Text`)
/// - bodySmall: caption, counts, instructions
/// - display*, headlineLarge: screen title (not used by the spec)
library;

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';
import 'form_factor.dart';

final Map<FormFactor, ThemeData> _themes = {};

/// The theme for [formFactor], built once and reused.
ThemeData appTheme(FormFactor formFactor) =>
    _themes.putIfAbsent(formFactor, () => buildAppTheme(formFactor));

ThemeData buildAppTheme([FormFactor formFactor = FormFactor.phone]) {
  final type = AppTypography.forFormFactor(formFactor);

  const colorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.accent,
    onPrimary: AppColors.background,
    primaryContainer: AppColors.accent12,
    onPrimaryContainer: AppColors.accent,
    secondary: AppColors.accent,
    onSecondary: AppColors.background,
    secondaryContainer: AppColors.accent12,
    onSecondaryContainer: AppColors.accent,
    tertiary: AppColors.accent,
    onTertiary: AppColors.background,
    error: AppColors.wrong,
    onError: AppColors.background,
    errorContainer: AppColors.wrongFill,
    onErrorContainer: AppColors.wrong,
    surface: AppColors.surface,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textMuted,
    surfaceContainerLowest: AppColors.background,
    surfaceContainerLow: AppColors.surface,
    surfaceContainer: AppColors.surface,
    surfaceContainerHigh: AppColors.surface,
    surfaceContainerHighest: AppColors.surface,
    outline: AppColors.stroke,
    outlineVariant: AppColors.hairline,
    shadow: AppColors.black,
    scrim: AppColors.black,
    inverseSurface: AppColors.textSecondary,
    onInverseSurface: AppColors.background,
    inversePrimary: AppColors.accent,
    surfaceTint: AppColors.background,
  );

  final textTheme = TextTheme(
    displayLarge: type.screenTitle,
    displayMedium: type.screenTitle,
    displaySmall: type.screenTitle,
    headlineLarge: type.screenTitle,
    headlineMedium: type.screenTitle,
    headlineSmall: type.gameTitle,
    titleLarge: type.cardTitle,
    titleMedium: type.phaseHeading,
    titleSmall: type.feedbackHeading,
    labelLarge: type.button,
    labelMedium: type.chip,
    labelSmall: type.explanationLabel,
    bodyLarge: type.prompt,
    bodyMedium: type.body,
    bodySmall: type.caption,
  );

  const controlShape = RoundedRectangleBorder(
    borderRadius: AppRadius.controlAll,
  );

  // Primary action: accent 12% fill, 2px accent stroke, white Sora label.
  // Disabled: fillSubtle, 1px stroke, muted label. No solid accent fills.
  final primaryButtonStyle = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(
      Size(AppSizes.minTarget, AppSizes.primaryButton),
    ),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: AppSpacing.s24),
    ),
    shape: const WidgetStatePropertyAll(controlShape),
    textStyle: WidgetStatePropertyAll(type.button),
    elevation: const WidgetStatePropertyAll(0),
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? AppColors.fillSubtle
          : AppColors.accent12,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? AppColors.textMuted
          : AppColors.textPrimary,
    ),
    iconColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? AppColors.textMuted
          : AppColors.accent,
    ),
    side: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? const BorderSide(color: AppColors.stroke)
          : const BorderSide(color: AppColors.accent, width: AppStroke.strong),
    ),
    overlayColor: const WidgetStatePropertyAll(AppColors.accent12),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    extensions: [type],
    scaffoldBackgroundColor: AppColors.background,
    canvasColor: AppColors.background,
    dividerColor: AppColors.hairline,
    focusColor: AppColors.accent12,
    hoverColor: AppColors.fillSubtle,
    highlightColor: AppColors.accent12,
    splashColor: AppColors.accent12,
    disabledColor: AppColors.textMuted,
    iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 24),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: type.gameTitle,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: AppColors.hairline),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.hairline,
      thickness: AppStroke.resting,
      space: AppStroke.resting,
    ),
    filledButtonTheme: FilledButtonThemeData(style: primaryButtonStyle),
    elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(AppSizes.minTarget, AppSizes.minTarget),
        ),
        shape: const WidgetStatePropertyAll(controlShape),
        textStyle: WidgetStatePropertyAll(type.button),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? AppColors.textMuted
              : AppColors.textSecondary,
        ),
        backgroundColor: const WidgetStatePropertyAll(AppColors.fillSubtle),
        side: const WidgetStatePropertyAll(
          BorderSide(color: AppColors.stroke),
        ),
        overlayColor: const WidgetStatePropertyAll(AppColors.fillSubtle),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(
          Size(AppSizes.minTarget, AppSizes.minTarget),
        ),
        shape: const WidgetStatePropertyAll(controlShape),
        textStyle: WidgetStatePropertyAll(type.button),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? AppColors.textMuted
              : AppColors.accent,
        ),
        overlayColor: const WidgetStatePropertyAll(AppColors.accent12),
      ),
    ),
    iconButtonTheme: const IconButtonThemeData(
      style: ButtonStyle(
        fixedSize: WidgetStatePropertyAll(
          Size(AppSizes.iconButton, AppSizes.iconButton),
        ),
        minimumSize: WidgetStatePropertyAll(
          Size(AppSizes.iconButton, AppSizes.iconButton),
        ),
        iconSize: WidgetStatePropertyAll(20),
        iconColor: WidgetStatePropertyAll(AppColors.textSecondary),
        backgroundColor: WidgetStatePropertyAll(AppColors.fillSubtle),
        side: WidgetStatePropertyAll(BorderSide(color: AppColors.stroke)),
        shape: WidgetStatePropertyAll(controlShape),
        overlayColor: WidgetStatePropertyAll(AppColors.fillSubtle),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.fillChip,
      side: const BorderSide(color: AppColors.stroke),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.chipAll),
      labelStyle: type.chip,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      hintStyle: type.answerField.copyWith(color: AppColors.textMuted),
      helperStyle: type.caption,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s16,
      ),
      border: const OutlineInputBorder(
        borderRadius: AppRadius.controlAll,
        borderSide: BorderSide(color: AppColors.accent40),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: AppRadius.controlAll,
        borderSide: BorderSide(color: AppColors.accent40),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: AppRadius.controlAll,
        borderSide: BorderSide(
          color: AppColors.accent,
          width: AppStroke.strong,
        ),
      ),
      disabledBorder: const OutlineInputBorder(
        borderRadius: AppRadius.controlAll,
        borderSide: BorderSide(color: AppColors.divider),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.controlAll,
        borderSide: BorderSide(color: AppColors.wrong, width: AppStroke.strong),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: AppRadius.controlAll,
        borderSide: BorderSide(color: AppColors.wrong, width: AppStroke.strong),
      ),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.accent,
      selectionColor: AppColors.accent40,
      selectionHandleColor: AppColors.accent,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.chipAll,
        border: Border.fromBorderSide(BorderSide(color: AppColors.stroke)),
      ),
      textStyle: type.caption.copyWith(color: AppColors.textPrimary),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accent,
    ),
  );
}
