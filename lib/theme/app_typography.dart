/// Every text style in the app, by role. UI spec section 3.
///
/// Fonts are bundled (`assets/fonts/`): Sora and DM Sans, both as
/// variable-weight files. Flutter does not pick the weight of a variable font
/// from `fontWeight` alone, so every style here sets both `fontWeight` and
/// `fontVariations: [FontVariation('wght', <weight>)]`. To change the weight
/// of one of these styles, use [AppTextStyleWeight.withWeight], not
/// `copyWith(fontWeight: ...)`.
///
/// Sizes differ by [FormFactor]. Read the styles with
/// `AppTypography.of(context)`; the app's `ThemeData` is built for the
/// current form factor, so `Theme.of(context).textTheme` matches too
/// (mapping in `app_theme.dart`).
library;

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'form_factor.dart';

abstract final class AppFonts {
  static const String sora = 'Sora';
  static const String dmSans = 'DM Sans';
}

/// Builds one style with the weight set on both the weight and the `wght`
/// axis, line height from [lineHeight] in px, and letter spacing in px.
TextStyle appTextStyle({
  required String family,
  required double size,
  required double lineHeight,
  required int weight,
  Color color = AppColors.textPrimary,
  double letterSpacing = 0,
}) {
  return TextStyle(
    fontFamily: family,
    fontSize: size,
    height: lineHeight / size,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: _fontWeight(weight),
    fontVariations: [FontVariation('wght', weight.toDouble())],
    letterSpacing: letterSpacing,
    color: color,
  );
}

FontWeight _fontWeight(int weight) {
  final index = ((weight / 100).round() - 1).clamp(0, 8);
  return FontWeight.values[index];
}

extension AppTextStyleWeight on TextStyle {
  /// This style at [weight] (400, 500, 600, 700), on both the weight and the
  /// variable font's `wght` axis.
  TextStyle withWeight(int weight) => copyWith(
    fontWeight: _fontWeight(weight),
    fontVariations: [FontVariation('wght', weight.toDouble())],
  );
}

/// The text roles of section 3, at the sizes for one [FormFactor].
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography._({
    required this.formFactor,
    required this.screenTitle,
    required this.phaseHeading,
    required this.cardTitle,
    required this.gameTitle,
    required this.topBarAction,
    required this.feedbackHeading,
    required this.button,
    required this.prompt,
    required this.promptStrong,
    required this.promptMarked,
    required this.promptLabel,
    required this.option,
    required this.optionPhrase,
    required this.answerField,
    required this.explanationLabel,
    required this.ruleChip,
    required this.rulePlaceholder,
    required this.explanationRowLabel,
    required this.explanationRowValue,
    required this.body,
    required this.cardDescription,
    required this.caption,
    required this.chip,
    required this.homeBrand,
    required this.homeCount,
  });

  final FormFactor formFactor;

  /// Screen title ("Games"). Sora 600 28/36 −0.3; laptop 700 36/44 −0.5.
  final TextStyle screenTitle;

  /// Phase heading on home ("New corrections"). Sora 600, `textSecondary`.
  final TextStyle phaseHeading;

  /// Game card title. Sora 600.
  final TextStyle cardTitle;

  /// Game title in the top bar. Sora 600; 20/28 in phone landscape,
  /// 18/26 on laptop.
  final TextStyle gameTitle;

  /// Phone-landscape top-bar action ("Next question ›"). Same size as the
  /// landscape game title, in `accent`.
  final TextStyle topBarAction;

  /// "Correct" / "Not quite": toast on phone, panel heading on laptop.
  final TextStyle feedbackHeading;

  /// Button label. Sora 600 16/20 +0.3.
  final TextStyle button;

  /// The Spanish sentence on the prompt card. DM Sans 400 16/28. Wraps,
  /// never truncated.
  final TextStyle prompt;

  /// The prompt at 600: the gap answer and the changed words after checking
  /// (colour set by the widget).
  final TextStyle promptStrong;

  /// Marked words in a phase 1 prompt: 600, `textPrimary`, 2px `mark`
  /// underline. The 16% `mark` fill with top radius 4 behind the words is
  /// drawn by the prompt card (U2), not by this style.
  final TextStyle promptMarked;

  /// "Original version" / "Corrected version". DM Sans 500, `textMuted`.
  final TextStyle promptLabel;

  /// Answer option label. DM Sans 500 (use `withWeight(600)` once marked
  /// correct or wrong).
  final TextStyle option;

  /// Phrase-length answer option label (longer than 16 characters).
  final TextStyle optionPhrase;

  /// Spanish text in the answer field: 18, 16 in phone landscape.
  final TextStyle answerField;

  /// "RULE" label on the explanation card. DM Sans 600 uppercase +0.6,
  /// `textMuted`. Uppercase the text itself; this style does not.
  final TextStyle explanationLabel;

  /// A Spanish word chip in the rule pattern. DM Sans 600.
  final TextStyle ruleChip;

  /// A placeholder chip ("infinitive") in the rule pattern. DM Sans 400.
  final TextStyle rulePlaceholder;

  /// Explanation row label ("Meaning", "You wrote"). `textMuted`.
  final TextStyle explanationRowLabel;

  /// Explanation row value. `textSecondary`.
  final TextStyle explanationRowValue;

  /// Body text. DM Sans 400, `textSecondary`.
  final TextStyle body;

  /// Game card description. DM Sans 400, `textMuted`.
  final TextStyle cardDescription;

  /// Captions, counts ("Question 2 of 3"), instructions, source line.
  /// DM Sans 400, `textMuted`.
  final TextStyle caption;

  /// Chip text ("Grammar error · Prepositions"). DM Sans 500 12/16.
  final TextStyle chip;

  /// "Spanish Companion" label in the phone home top bar. Sora 600 13,
  /// `accent`.
  final TextStyle homeBrand;

  /// The question count on a phone game card. Sora 600 20; colour (the game
  /// accent) set by the card.
  final TextStyle homeCount;

  /// Styles for the current screen size. Falls back to building them from
  /// the media query if the theme has no [AppTypography].
  static AppTypography of(BuildContext context) =>
      Theme.of(context).extension<AppTypography>() ??
      AppTypography.forFormFactor(FormFactor.of(context));

  static AppTypography forFormFactor(FormFactor formFactor) =>
      switch (formFactor) {
        FormFactor.phone => phone,
        FormFactor.phoneLandscape => phoneLandscape,
        FormFactor.laptop => laptop,
      };

  static final AppTypography phone = _build(FormFactor.phone);
  static final AppTypography phoneLandscape = _build(FormFactor.phoneLandscape);
  static final AppTypography laptop = _build(FormFactor.laptop);

  static AppTypography _build(FormFactor f) {
    final isLaptop = f == FormFactor.laptop;
    final isLandscape = f == FormFactor.phoneLandscape;

    TextStyle sora(
      double size,
      double line,
      int weight, {
      Color color = AppColors.textPrimary,
      double letterSpacing = 0,
    }) => appTextStyle(
      family: AppFonts.sora,
      size: size,
      lineHeight: line,
      weight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );

    TextStyle dm(
      double size,
      double line,
      int weight, {
      Color color = AppColors.textSecondary,
      double letterSpacing = 0,
    }) => appTextStyle(
      family: AppFonts.dmSans,
      size: size,
      lineHeight: line,
      weight: weight,
      color: color,
      letterSpacing: letterSpacing,
    );

    final prompt = dm(16, 28, 400, color: AppColors.textPrimary);
    final landscapeTitle = sora(20, 28, 600);

    return AppTypography._(
      formFactor: f,
      screenTitle: isLaptop
          ? sora(36, 44, 700, letterSpacing: -0.5)
          : sora(28, 36, 600, letterSpacing: -0.3),
      phaseHeading: isLaptop
          ? sora(18, 26, 600, color: AppColors.textSecondary)
          : sora(16, 22, 600, color: AppColors.textSecondary),
      cardTitle: isLaptop ? sora(22, 30, 600) : sora(18, 26, 600),
      gameTitle: switch (f) {
        FormFactor.phone => sora(28, 36, 600, letterSpacing: -0.3),
        FormFactor.phoneLandscape => landscapeTitle,
        FormFactor.laptop => sora(18, 26, 600),
      },
      // Only used in phone landscape; the same values elsewhere so the
      // style is always defined.
      topBarAction: landscapeTitle.copyWith(color: AppColors.accent),
      feedbackHeading: switch (f) {
        FormFactor.phone => sora(16, 22, 600),
        FormFactor.phoneLandscape => sora(15, 20, 600),
        FormFactor.laptop => sora(18, 26, 600),
      },
      button: sora(16, 20, 600, letterSpacing: 0.3),
      prompt: prompt,
      promptStrong: prompt.withWeight(600),
      promptMarked: prompt
          .withWeight(600)
          .copyWith(
            color: AppColors.textPrimary,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.mark,
            decorationStyle: TextDecorationStyle.solid,
            // A multiple of the font's own underline thickness (about 1px at
            // 16px), so roughly the 2px in the spec. U2 may draw it instead.
            decorationThickness: 2,
          ),
      promptLabel: isLaptop
          ? dm(14, 20, 500, color: AppColors.textMuted)
          : dm(13, 18, 500, color: AppColors.textMuted),
      option: isLaptop ? dm(20, 28, 500) : dm(18, 24, 500),
      optionPhrase: isLaptop ? dm(18, 26, 500) : dm(16, 22, 500),
      answerField: isLandscape
          ? dm(16, 24, 400, color: AppColors.textPrimary)
          : dm(18, 26, 400, color: AppColors.textPrimary),
      explanationLabel: isLandscape
          ? dm(11, 14, 600, color: AppColors.textMuted, letterSpacing: 0.6)
          : dm(12, 16, 600, color: AppColors.textMuted, letterSpacing: 0.6),
      ruleChip: isLandscape
          ? dm(16, 20, 600, color: AppColors.textPrimary)
          : dm(17, 22, 600, color: AppColors.textPrimary),
      rulePlaceholder: isLandscape ? dm(14, 20, 400) : dm(15, 22, 400),
      explanationRowLabel: isLandscape
          ? dm(13, 20, 400, color: AppColors.textMuted)
          : dm(13, 22, 400, color: AppColors.textMuted),
      explanationRowValue: isLandscape ? dm(14, 20, 400) : dm(15, 22, 400),
      body: isLandscape ? dm(14, 22, 400) : dm(15, 24, 400),
      cardDescription: isLaptop
          ? dm(15, 22, 400, color: AppColors.textMuted)
          : dm(14, 20, 400, color: AppColors.textMuted),
      caption: isLaptop
          ? dm(14, 20, 400, color: AppColors.textMuted)
          : dm(13, 18, 400, color: AppColors.textMuted),
      chip: dm(12, 16, 500),
      homeBrand: sora(13, 18, 600, color: AppColors.accent),
      homeCount: sora(20, 28, 600),
    );
  }

  @override
  AppTypography copyWith() => this;

  @override
  AppTypography lerp(AppTypography? other, double t) =>
      other == null || t < 0.5 ? this : other;
}
