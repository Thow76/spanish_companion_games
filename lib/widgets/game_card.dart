/// GameCard (UI spec section 6): one game on the home screen.
///
/// Phone (and phone landscape, 600–1023): a row, min height 88, padding 16:
/// icon tile 48, title and description, count in the game accent over
/// "questions". Laptop: a column card, min height 196, padding 24: icon tile
/// 56, count pill top right, title, description, "Play →" at the bottom.
/// The whole card is the tap target. With 0 questions the card is dimmed
/// (title and icon muted, no accent), not tappable, and reads
/// "No questions yet".
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import 'focus_ring.dart';
import 'game_icon.dart';

class GameCard extends StatelessWidget {
  const GameCard({
    super.key,
    required this.game,
    required this.title,
    required this.description,
    required this.count,
    required this.onTap,
  });

  /// The `game` value, e.g. `choose_correction`. Picks the accent and icon.
  final String game;
  final String title;
  final String description;

  /// Number of questions for this game. 0 dims the card.
  final int count;

  /// Ignored when [count] is 0.
  final VoidCallback? onTap;

  /// Home card titles and descriptions (section 8), by `game` value.
  static const Map<String, (String, String)> copy = {
    'choose_correction': (
      'Choose a correction',
      'Pick the right words for the marked part.',
    ),
    'repair': ('Repair the sentence', 'Rewrite the marked part yourself.'),
    'fill_gap': ('Fill the gap', 'Complete a new sentence.'),
    'match': ('Matching', 'Pair each word with its partner.'),
    'order': ('Sentence ordering', 'Put the words in order.'),
    'spot_error': ('Spot the error', 'Is it right? Fix it if not.'),
  };

  /// A card for [game] with the section 8 title and description.
  factory GameCard.forGame({
    Key? key,
    required String game,
    required int count,
    required VoidCallback? onTap,
  }) {
    final (title, description) = copy[game] ?? (game, '');
    return GameCard(
      key: key,
      game: game,
      title: title,
      description: description,
      count: count,
      onTap: onTap,
    );
  }

  /// "3 questions", "1 question", "No questions yet".
  static String countText(int count) => switch (count) {
    0 => 'No questions yet',
    1 => '1 question',
    _ => '$count questions',
  };

  bool get _enabled => count > 0 && onTap != null;

  @override
  Widget build(BuildContext context) {
    final laptop = FormFactor.of(context) == FormFactor.laptop;
    final accent = count > 0 ? AppColors.gameAccent(game) : AppColors.textMuted;

    return FocusRing(
      radius: AppRadius.card,
      child: Semantics(
        button: true,
        enabled: _enabled,
        label: '$title. $description ${countText(count)}.',
        excludeSemantics: true,
        onTap: _enabled ? onTap : null,
        child: Material(
          color: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadius.cardAll,
            side: BorderSide(color: AppColors.hairline),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _enabled ? onTap : null,
            child: laptop
                ? _LaptopContent(card: this, accent: accent)
                : _PhoneContent(card: this, accent: accent),
          ),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.game,
    required this.accent,
    required this.size,
    required this.enabled,
  });

  final String game;
  final Color accent;
  final double size;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: enabled ? AppColors.gameTileFill(accent) : AppColors.fillSubtle,
        borderRadius: AppRadius.controlAll,
        border: Border.all(
          color: enabled ? AppColors.gameTileStroke(accent) : AppColors.stroke,
        ),
      ),
      child: GameIcon(game: game, color: accent),
    );
  }
}

class _PhoneContent extends StatelessWidget {
  const _PhoneContent({required this.card, required this.accent});

  final GameCard card;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    final hasQuestions = card.count > 0;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.gameCardPhone),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Row(
          children: [
            _IconTile(
              game: card.game,
              accent: accent,
              size: AppSizes.gameTilePhone,
              enabled: hasQuestions,
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    card.title,
                    style: hasQuestions
                        ? type.cardTitle
                        : type.cardTitle.copyWith(color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(card.description, style: type.cardDescription),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            if (hasQuestions)
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${card.count}',
                    style: type.homeCount.copyWith(color: accent),
                  ),
                  Text(
                    card.count == 1 ? 'question' : 'questions',
                    style: type.caption,
                  ),
                ],
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSizes.gameCardCountMaxWidth,
                ),
                child: Text(
                  GameCard.countText(0),
                  style: type.caption,
                  textAlign: TextAlign.end,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LaptopContent extends StatelessWidget {
  const _LaptopContent({required this.card, required this.accent});

  final GameCard card;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    final hasQuestions = card.count > 0;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: AppSizes.gameCardLaptop),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconTile(
                  game: card.game,
                  accent: accent,
                  size: AppSizes.gameTileLaptop,
                  enabled: hasQuestions,
                ),
                const Spacer(),
                Container(
                  padding: AppInsets.chip,
                  decoration: BoxDecoration(
                    color: hasQuestions
                        ? AppColors.gameTileFill(accent)
                        : AppColors.fillChip,
                    borderRadius: AppRadius.pillAll,
                  ),
                  child: Text(
                    GameCard.countText(card.count),
                    style: type.chip.copyWith(
                      color: hasQuestions ? accent : AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(
              card.title,
              style: hasQuestions
                  ? type.cardTitle
                  : type.cardTitle.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(card.description, style: type.cardDescription),
            if (hasQuestions) ...[
              const SizedBox(height: AppSpacing.s16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Play', style: type.button.copyWith(color: accent)),
                  const SizedBox(width: AppSpacing.s4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: AppSizes.iconSmall,
                    color: accent,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
