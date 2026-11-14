/// The set picker for one phase (Flow v2, B24): opened from the home
/// screen's "New corrections" or "Recall" card.
///
/// From the top: the filter (B12, type and category only; the phase is this
/// screen's), the set size (5 or 10 questions, default 5), a "By
/// conversation" switch, then the list of sets, oldest first (see
/// `question_sets.dart`). Each set shows its conversation (or "+ 2 more"
/// when it spans several), its date or date range, "1 of 2" when a
/// conversation is split, and how many questions it has.
///
/// The choices are kept for the app session: they live on the home screen,
/// which passes them in and is told of every change.
///
/// Tapping a set calls [SetPickerScreen.onSetSelected]; until B25's player
/// the home screen opens the game of the set's first question with the
/// set's questions for that game.
///
/// A stand-in look until U18, from existing widgets only: [HomeFrame], the
/// B23 top bar ([AppIconButton.back] with the game-title style),
/// [WordChip]s for the size (as the filter's choices), the theme's
/// [SwitchListTile], and a [GameCard] per set (borrowing the phase card's
/// icon and accent).
library;

import 'package:flutter/material.dart';

import '../models/question.dart';
import '../models/question_filter.dart';
import '../models/question_sets.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import '../widgets/widgets.dart';
import 'home_card_grid.dart';
import 'question_filter_card.dart';

/// What the picker remembers for the app session.
class SetChoices {
  const SetChoices({
    this.filter = QuestionFilter.all,
    this.size = defaultSetSize,
    this.byConversation = false,
  });

  /// Type and category are used here; the home screen's phase is left as
  /// it was.
  final QuestionFilter filter;
  final int size;
  final bool byConversation;

  SetChoices copyWith({
    QuestionFilter? filter,
    int? size,
    bool? byConversation,
  }) => SetChoices(
    filter: filter ?? this.filter,
    size: size ?? this.size,
    byConversation: byConversation ?? this.byConversation,
  );
}

class SetPickerScreen extends StatefulWidget {
  const SetPickerScreen({
    super.key,
    required this.phase,
    required this.questions,
    required this.choices,
    required this.onChoicesChanged,
    required this.onSetSelected,
  });

  final QuestionPhase phase;

  /// Every question of this phase in the file (not yet filtered). Any
  /// question from the other phase is ignored.
  final List<Question> questions;

  /// The choices to start with (kept by the home screen).
  final SetChoices choices;

  /// Told of every change, so the home screen keeps the choices.
  final ValueChanged<SetChoices> onChoicesChanged;

  /// A set was tapped.
  final ValueChanged<QuestionSet> onSetSelected;

  /// Tooltip of the back button.
  static const String backLabel = 'Back';

  static const String sizeLabel = 'Set size';
  static const String byConversationLabel = 'By conversation';
  static const String byConversationHint =
      'Each set comes from one conversation.';

  /// The size choices' labels: "5 questions", "10 questions".
  static String sizeText(int size) => '$size questions';

  /// The line over the list: "3 sets", "1 set".
  static String setCountText(int n) => n == 1 ? '1 set' : '$n sets';

  /// The `game` value whose icon and accent the set cards borrow until U18
  /// (the same as the phase's card on home).
  static String borrowedGame(QuestionPhase phase) =>
      phase == QuestionPhase.noticeAndCorrect ? 'choose_correction' : 'fill_gap';

  @override
  State<SetPickerScreen> createState() => _SetPickerScreenState();
}

class _SetPickerScreenState extends State<SetPickerScreen> {
  late SetChoices _choices = widget.choices;

  void _change(SetChoices next) {
    setState(() => _choices = next);
    widget.onChoicesChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    final laptop = FormFactor.of(context) == FormFactor.laptop;
    final phaseQuestions = widget.questions
        .where((q) => q.game.phase == widget.phase)
        .toList();

    // Only type and category apply here; a category this phase lacks is
    // ignored rather than emptying the list.
    final filter = _choices.filter
        .withPhase(null)
        .keepingCategoryIn(phaseQuestions);
    final shown = filter.apply(phaseQuestions);
    // Categories offered: those of this phase's questions of the chosen
    // type, so no choice leads to an empty list (PR #26 review note).
    final categories = QuestionFilter.categoriesOf(
      filter.withCategory(null).apply(phaseQuestions),
    );
    final sets = buildQuestionSets(
      shown,
      size: _choices.size,
      byConversation: _choices.byConversation,
    );
    final game = SetPickerScreen.borrowedGame(widget.phase);

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
                child: TitleText(widget.phase.label, style: type.gameTitle),
              ),
            ),
          ],
        ),
      ),
      footer: HomeFrame.footerLine(context),
      children: [
        SizedBox(height: laptop ? AppSpacing.s24 : AppSpacing.s16),
        QuestionFilterCard(
          key: const ValueKey('set-filter'),
          filter: filter,
          categories: categories,
          shownCount: shown.length,
          totalCount: phaseQuestions.length,
          showPhase: false,
          onChanged: (f) => _change(
            _choices.copyWith(
              // Keep home's phase choice; change only type and category.
              filter: f.withPhase(_choices.filter.phase),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s24),
        Semantics(
          header: true,
          child: Text(SetPickerScreen.sizeLabel, style: type.caption),
        ),
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: [
            for (final size in setSizes)
              WordChip(
                key: ValueKey('set-size-$size'),
                label: SetPickerScreen.sizeText(size),
                state: size == _choices.size
                    ? WordChipState.placed
                    : WordChipState.toPlace,
                onPressed: size == _choices.size
                    ? null
                    : () => _change(_choices.copyWith(size: size)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        SwitchListTile(
          key: const ValueKey('set-by-conversation'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            SetPickerScreen.byConversationLabel,
            style: type.body.copyWith(color: AppColors.textPrimary),
          ),
          subtitle: Text(
            SetPickerScreen.byConversationHint,
            style: type.caption,
          ),
          value: _choices.byConversation,
          onChanged: (on) => _change(_choices.copyWith(byConversation: on)),
        ),
        const SizedBox(height: AppSpacing.s16),
        if (sets.isEmpty)
          Text(
            phaseQuestions.isEmpty
                ? GameCard.countText(0)
                : QuestionFilterCard.noMatchText,
            style: type.caption,
          )
        else ...[
          Text(SetPickerScreen.setCountText(sets.length), style: type.caption),
          const SizedBox(height: AppSpacing.s12),
          HomeCardGrid(
            laptop: laptop,
            cards: [
              for (var i = 0; i < sets.length; i++)
                GameCard(
                  key: ValueKey('set-card-$i'),
                  game: game,
                  title: sets[i].title,
                  description: sets[i].detail,
                  count: sets[i].length,
                  onTap: () => widget.onSetSelected(sets[i]),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
