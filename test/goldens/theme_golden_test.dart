/// Screenshots of the theme (U1): every colour token and game accent, and
/// every text role at the sizes for each screen. UI spec sections 2–4.
///
/// - `theme_colours_<size>.png`: the colour tokens and the six game accents.
/// - `theme_type_<size>.png`: each text role, with Spanish accents, at the
///   sizes for that screen (phone, phone landscape, laptop).
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/theme/app_colors.dart';
import 'package:spanish_companion_games/theme/app_spacing.dart';
import 'package:spanish_companion_games/theme/app_theme.dart';
import 'package:spanish_companion_games/theme/app_typography.dart';
import 'package:spanish_companion_games/theme/form_factor.dart';

import 'golden_helpers.dart';

void main() {
  setUpAll(setUpGoldens);

  for (final size in ScreenSize.values) {
    testWidgets('theme colours, ${size.name}', (tester) async {
      setScreenSize(tester, size);
      await tester.pumpWidget(_GalleryApp(size: size, child: const _Colours()));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(_GalleryApp),
        matchesGoldenFile(goldenName('theme', 'colours', size)),
      );
    });

    testWidgets('theme type, ${size.name}', (tester) async {
      setScreenSize(tester, size);
      await tester.pumpWidget(_GalleryApp(size: size, child: const _Type()));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(_GalleryApp),
        matchesGoldenFile(goldenName('theme', 'type', size)),
      );
    });
  }
}

class _GalleryApp extends StatelessWidget {
  const _GalleryApp({required this.size, required this.child});

  final ScreenSize size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: appTheme(FormFactor.fromSize(size.size)),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: child,
        ),
      ),
    );
  }
}

/// Lays [children] out in as many columns of at least [minWidth] as fit.
class _Columns extends StatelessWidget {
  const _Columns({required this.minWidth, required this.children});

  final double minWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / minWidth).floor().clamp(1, 6);
        final width =
            (constraints.maxWidth - AppSpacing.s12 * (columns - 1)) / columns;
        return Wrap(
          spacing: AppSpacing.s12,
          runSpacing: AppSpacing.s8,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _Colours extends StatelessWidget {
  const _Colours();

  static const _tokens = <(String, Color)>[
    ('background', AppColors.background),
    ('surface', AppColors.surface),
    ('hairline', AppColors.hairline),
    ('stroke', AppColors.stroke),
    ('fillNeutral', AppColors.fillNeutral),
    ('fillSubtle', AppColors.fillSubtle),
    ('fillChip', AppColors.fillChip),
    ('textPrimary', AppColors.textPrimary),
    ('textSecondary', AppColors.textSecondary),
    ('textMuted', AppColors.textMuted),
    ('divider', AppColors.divider),
    ('accent', AppColors.accent),
    ('accent12', AppColors.accent12),
    ('accent40', AppColors.accent40),
    ('correct', AppColors.correct),
    ('correctFill', AppColors.correctFill),
    ('wrong', AppColors.wrong),
    ('wrongFill', AppColors.wrongFill),
    ('mark', AppColors.mark),
    ('markFill', AppColors.markFill),
  ];

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Colours', style: type.phaseHeading),
        const SizedBox(height: AppSpacing.s8),
        _Columns(
          minWidth: 180,
          children: [
            for (final (name, colour) in _tokens)
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colour,
                      borderRadius: AppRadius.chipAll,
                      border: Border.all(color: AppColors.stroke),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(child: Text(name, style: type.caption)),
                ],
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        Text('Game accents', style: type.phaseHeading),
        const SizedBox(height: AppSpacing.s8),
        _Columns(
          minWidth: 180,
          children: [
            for (final entry in AppColors.gameAccents.entries)
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.gameTileFill(entry.value),
                      borderRadius: AppRadius.controlAll,
                      border: Border.all(
                        color: AppColors.gameTileStroke(entry.value),
                      ),
                    ),
                    child: Text(
                      '3',
                      style: type.homeCount.copyWith(color: entry.value),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(child: Text(entry.key, style: type.caption)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _Type extends StatelessWidget {
  const _Type();

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    final rows = <(String, TextStyle, String)>[
      ('Screen title', type.screenTitle, 'Games'),
      ('Phase heading', type.phaseHeading, 'New corrections'),
      ('Card title', type.cardTitle, 'Choose a correction'),
      ('Game title', type.gameTitle, 'Fill the gap'),
      ('Top-bar action', type.topBarAction, 'Next question ›'),
      ('Feedback heading', type.feedbackHeading, 'Not quite'),
      ('Button', type.button, 'Check'),
      ('Prompt', type.prompt, '¿Qué piensas? ¡Sí! Niño, pingüino.'),
      ('Prompt label', type.promptLabel, 'Original version'),
      ('Option', type.option, 'en'),
      ('Option, phrase', type.optionPhrase, 'me acuerdo de'),
      ('Answer field', type.answerField, 'Estoy pensando en ir'),
      ('Card label', type.explanationLabel, 'RULE'),
      ('Rule chip', type.ruleChip, 'pensar en'),
      ('Rule placeholder', type.rulePlaceholder, 'infinitive'),
      ('Row label', type.explanationRowLabel, 'Meaning'),
      ('Row value', type.explanationRowValue, 'to be thinking of doing'),
      ('Body', type.body, 'New questions arrive from your companion.'),
      ('Card description', type.cardDescription, 'Complete a new sentence.'),
      ('Caption', type.caption, 'Question 2 of 3'),
      ('Chip', type.chip, 'Grammar error · Prepositions'),
      ('Home label', type.homeBrand, 'Spanish Companion'),
      ('Home count', type.homeCount, '12'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Type: ${type.formFactor.name}',
          style: type.caption.copyWith(color: AppColors.accent),
        ),
        const SizedBox(height: AppSpacing.s8),
        // Marked words in Andrew's sentence (phase 1). The fill is the
        // prompt card's job (U2); shown here to check the colours together.
        Text.rich(
          TextSpan(
            style: type.prompt,
            children: [
              const TextSpan(text: 'Estoy pensando '),
              TextSpan(
                text: 'de',
                style: type.promptMarked.copyWith(
                  backgroundColor: AppColors.markFill,
                ),
              ),
              const TextSpan(text: ' cambiar de trabajo. Él está aquí.'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        _Columns(
          minWidth: 270,
          children: [
            for (final (role, style, sample) in rows)
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      role,
                      style: type.chip.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                  Expanded(child: Text(sample, style: style)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
