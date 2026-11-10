/// One phase's games (B23): opened from the home screen's "New
/// corrections" or "Recall" card, it lists that phase's games with their
/// question counts, as the home screen did before Flow v2. Games with no
/// questions are dimmed and can't be opened.
///
/// A stand-in: B24 replaces it with the set picker, and U18 does the look.
/// Built from existing widgets only: [HomeFrame], [AppIconButton.back] with
/// the game-title style for the top bar, [PhaseHeading] and [GameCard].
library;

import 'package:flutter/material.dart';

import '../models/question.dart';
import '../theme/app_layout.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import '../widgets/widgets.dart';

/// Opens [game] with [questions] (the phase's questions for that game).
typedef PhaseGameOpener =
    void Function(GameType game, List<Question> questions);

class PhaseGamesScreen extends StatelessWidget {
  const PhaseGamesScreen({
    super.key,
    required this.phase,
    required this.questions,
    required this.onGameSelected,
  });

  final QuestionPhase phase;

  /// The questions to play in this phase (already filtered on home). Any
  /// question from the other phase is ignored.
  final List<Question> questions;

  final PhaseGameOpener onGameSelected;

  /// Tooltip of the back button.
  static const String backLabel = 'Back';

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    final laptop = FormFactor.of(context) == FormFactor.laptop;
    final games = GameType.forPhase(phase);
    List<Question> forGame(GameType g) =>
        questions.where((q) => q.game == g).toList();

    return HomeFrame(
      topBar: Padding(
        padding: EdgeInsets.symmetric(vertical: laptop ? AppSpacing.s16 : 0),
        child: Row(
          children: [
            AppIconButton.back(
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: AppSpacing.s4),
            Expanded(
              child: Semantics(
                header: true,
                child: TitleText(phase.label, style: type.gameTitle),
              ),
            ),
          ],
        ),
      ),
      footer: HomeFrame.footerLine(context),
      children: [
        phase == QuestionPhase.noticeAndCorrect
            ? const PhaseHeading.newCorrections()
            : const PhaseHeading.recall(first: true),
        HomeCardGrid(
          laptop: laptop,
          cards: [
            for (final game in games)
              GameCard.forGame(
                key: ValueKey('game-card-${game.jsonValue}'),
                game: game.jsonValue,
                count: forGame(game).length,
                onTap: forGame(game).isEmpty
                    ? null
                    : () => onGameSelected(game, forGame(game)),
              ),
          ],
        ),
      ],
    );
  }
}

/// Home-style cards: one column on phones, a 2-column grid on laptop
/// (cards in a row share their height, so "Play →" lines up at the
/// bottom). Used by the home screen's two choices and by
/// [PhaseGamesScreen].
class HomeCardGrid extends StatelessWidget {
  const HomeCardGrid({super.key, required this.cards, required this.laptop});

  final List<Widget> cards;
  final bool laptop;

  @override
  Widget build(BuildContext context) {
    if (!laptop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: AppLayout.phoneCardGap),
            cards[i],
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cards.length; i += 2) ...[
          if (i > 0) const SizedBox(height: AppLayout.laptopCardGap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[i]),
                const SizedBox(width: AppLayout.laptopCardGap),
                Expanded(
                  child: i + 1 < cards.length
                      ? cards[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
