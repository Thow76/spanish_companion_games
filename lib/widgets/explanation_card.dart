/// ExplanationCard (UI spec section 6), phone in both orientations. Shown
/// under the options after checking, until "Next question". `surface`,
/// radius 16, 1px hairline.
///
/// Content: "RULE" label; the rule as a row of chips (Spanish words in
/// neutral chips, the answer in a mint chip, "+" as plain muted text,
/// grammar placeholders in dashed chips); then labelled lines: "Meaning"
/// and, for wrong answers, "You wrote" with the wrong word struck through
/// in coral. If the explanation cannot be split, the label and the plain
/// text instead.
///
/// Portrait: vertical, padding 16, gap 12; chips wrap; a hairline; the
/// lines as a two-column list (label column 80).
/// Landscape: one horizontal band, padding 10/16, gap 20: label and chips
/// on the left, a full-height vertical hairline, the lines on the right.
/// If the chips do not fit on one line beside the lines, or the text is
/// scaled up, it falls back to the portrait layout.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import 'dashed_border.dart';
import 'explanation_content.dart';

class ExplanationCard extends StatelessWidget {
  const ExplanationCard({super.key, required this.content});

  final ExplanationContent content;

  /// Above this text scale the landscape band always falls back to the
  /// stacked layout (section 10: 200% text scale, nothing clipped).
  static const double _maxBandTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final landscape = FormFactor.of(context) == FormFactor.phoneLandscape;
    final card = BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.cardAll,
      border: Border.all(color: AppColors.hairline),
    );

    if (!landscape || content.isFallback) {
      return Container(
        width: double.infinity,
        padding: landscape
            ? AppInsets.explanationLandscape
            : const EdgeInsets.all(AppSpacing.s16),
        decoration: card,
        child: ExplanationBody(content: content),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final type = AppTypography.of(context);
        final scaler = MediaQuery.textScalerOf(context);
        final chipsWidth = _chipRowWidth(type, scaler);
        final inner =
            constraints.maxWidth - AppInsets.explanationLandscape.horizontal;
        final fits =
            scaler.scale(1) <= _maxBandTextScale &&
            chipsWidth +
                    AppSpacing.s20 * 2 +
                    AppStroke.resting +
                    AppSizes.explanationLandscapeMinRight <=
                inner;
        return Container(
          width: double.infinity,
          padding: fits
              ? AppInsets.explanationLandscape
              : const EdgeInsets.all(AppSpacing.s16),
          decoration: card,
          child: fits
              ? _LandscapeBand(content: content)
              : ExplanationBody(content: content),
        );
      },
    );
  }

  /// Width of the rule chips laid out on one line, landscape sizes.
  double _chipRowWidth(AppTypography type, TextScaler scaler) {
    var width = 0.0;
    final parts = content.rule ?? const <RulePart>[];
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      final style = switch (part.kind) {
        RulePartKind.word || RulePartKind.answer => type.ruleChip,
        RulePartKind.joiner || RulePartKind.placeholder => type.rulePlaceholder,
      };
      final painter = TextPainter(
        text: TextSpan(text: part.text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      width += painter.width;
      painter.dispose();
      if (part.kind != RulePartKind.joiner) {
        // Chip padding and border.
        width += AppInsets.chip.horizontal + AppStroke.strong * 2;
      }
      if (i > 0) width += AppSpacing.s8;
    }
    return width;
  }
}

/// The card's contents in the vertical (portrait) layout, without the card
/// itself. Also used inside the laptop FeedbackPanel.
class ExplanationBody extends StatelessWidget {
  const ExplanationBody({super.key, required this.content});

  final ExplanationContent content;

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    if (content.isFallback) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _RuleLabel(),
          const SizedBox(height: AppSpacing.s12),
          Text(
            content.plainText ?? '',
            style: type.explanationRowValue,
            softWrap: true,
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _RuleLabel(),
        const SizedBox(height: AppSpacing.s12),
        _RuleChips(content: content, wrap: true),
        if (content.meaning != null || content.youWrote != null) ...[
          const SizedBox(height: AppSpacing.s12),
          const Divider(height: AppStroke.resting),
          const SizedBox(height: AppSpacing.s12),
          _Lines(content: content, gap: AppSpacing.s8),
        ],
      ],
    );
  }
}

class _LandscapeBand extends StatelessWidget {
  const _LandscapeBand({required this.content});

  final ExplanationContent content;

  @override
  Widget build(BuildContext context) {
    final hasLines = content.meaning != null || content.youWrote != null;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _RuleLabel(),
              const SizedBox(height: AppSpacing.s4),
              _RuleChips(content: content, wrap: false),
            ],
          ),
          if (hasLines) ...[
            const SizedBox(width: AppSpacing.s20),
            const VerticalDivider(
              width: AppStroke.resting,
              thickness: AppStroke.resting,
              color: AppColors.hairline,
            ),
            const SizedBox(width: AppSpacing.s20),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _Lines(content: content, gap: AppSpacing.s4),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RuleLabel extends StatelessWidget {
  const _RuleLabel();

  @override
  Widget build(BuildContext context) {
    // Read as part of the rule phrase, not on its own.
    return ExcludeSemantics(
      child: Text('RULE', style: AppTypography.of(context).explanationLabel),
    );
  }
}

class _RuleChips extends StatelessWidget {
  const _RuleChips({required this.content, required this.wrap});

  final ExplanationContent content;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    final chips = [
      for (final part in content.rule ?? const <RulePart>[]) _chip(part, type),
    ];
    // Read as one phrase: "Rule: pensar en plus infinitive".
    return Semantics(
      label: 'Rule: ${content.spokenRule}',
      child: ExcludeSemantics(
        child: wrap
            ? Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: chips,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < chips.length; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.s8),
                    chips[i],
                  ],
                ],
              ),
      ),
    );
  }

  Widget _chip(RulePart part, AppTypography type) {
    switch (part.kind) {
      case RulePartKind.joiner:
        return Text(
          part.text,
          style: type.rulePlaceholder.copyWith(color: AppColors.textMuted),
        );
      case RulePartKind.placeholder:
        return DashedBorder(
          color: AppColors.placeholderStroke,
          child: Padding(
            padding: AppInsets.chip,
            child: Text(part.text, style: type.rulePlaceholder),
          ),
        );
      case RulePartKind.word:
        return Container(
          padding: AppInsets.chip,
          decoration: BoxDecoration(
            color: AppColors.fillChip,
            borderRadius: AppRadius.chipAll,
            border: Border.all(color: AppColors.stroke),
          ),
          child: Text(part.text, style: type.ruleChip),
        );
      case RulePartKind.answer:
        return Container(
          padding: AppInsets.chip,
          decoration: BoxDecoration(
            color: AppColors.correctFill,
            borderRadius: AppRadius.chipAll,
            border: Border.all(
              color: AppColors.correct,
              width: AppStroke.strong,
            ),
          ),
          child: Text(
            part.text,
            style: type.ruleChip.copyWith(color: AppColors.correct),
          ),
        );
    }
  }
}

/// "Meaning" and "You wrote" as a two-column list.
class _Lines extends StatelessWidget {
  const _Lines({required this.content, required this.gap});

  final ExplanationContent content;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    final rows = <Widget>[];
    if (content.meaning != null) {
      rows.add(
        _row(
          type,
          'Meaning',
          Text(content.meaning!, style: type.explanationRowValue),
        ),
      );
    }
    final wrote = content.youWrote;
    if (wrote != null && wrote.isNotEmpty) {
      final wrongStyle = type.explanationRowValue
          .withWeight(600)
          .copyWith(
            color: AppColors.wrong,
            decoration: TextDecoration.lineThrough,
            decorationColor: AppColors.wrong,
            decorationThickness: AppStroke.strikeMultiple,
          );
      rows.add(
        Semantics(
          label: 'You wrote: ${content.spokenYouWrote}',
          child: ExcludeSemantics(
            child: _row(
              type,
              'You wrote',
              Text.rich(
                TextSpan(
                  style: type.explanationRowValue,
                  children: [
                    for (var i = 0; i < wrote.length; i++) ...[
                      if (i > 0) const TextSpan(text: ' '),
                      TextSpan(
                        text: wrote[i].text,
                        style: wrote[i].wrong ? wrongStyle : null,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: gap),
          rows[i],
        ],
      ],
    );
  }

  Widget _row(AppTypography type, String label, Widget value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AppSizes.explanationLabelColumn,
          child: Text(label, style: type.explanationRowLabel),
        ),
        Expanded(child: value),
      ],
    );
  }
}
