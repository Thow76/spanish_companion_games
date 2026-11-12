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
/// Look (U18, proposed for the spec): [HomeFrame] without the laptop
/// "Choose a game" title, the B23 top bar (back chevron and the phase name
/// in the game-title style), a [SetOptionsCard] (questions per set, 5 or
/// 10, and "By conversation"), the filter card, then "3 sets" as a phase
/// heading and a [SetCard] per set (count in the phase's accent; a 2-column
/// grid on laptop).
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

  static const String sizeLabel = 'Questions per set';
  static const String byConversationLabel = 'By conversation';
  static const String byConversationHint =
      'Each set comes from one conversation.';

  /// The size choices' labels: "5 questions", "10 questions".
  static String sizeText(int size) => '$size questions';

  /// The line over the list: "3 sets", "1 set".
  static String setCountText(int n) => n == 1 ? '1 set' : '$n sets';

  /// The `game` value whose accent the phase uses (U18): the accent of its
  /// card on home, also used for the set cards' counts.
  static String accentGame(QuestionPhase phase) =>
      phase == QuestionPhase.noticeAndCorrect
      ? 'choose_correction'
      : 'fill_gap';

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
    final accent = AppColors.gameAccent(
      SetPickerScreen.accentGame(widget.phase),
    );

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
      // The bar already names the phase; no "Choose a game" on laptop.
      showLaptopTitle: false,
      children: [
        // On laptop the frame's own top padding is enough (no title here).
        if (!laptop) const SizedBox(height: AppSpacing.s16),
        // How the sets are made (U18): size and "by conversation" in one
        // card, then the filter.
        SetOptionsCard(
          sizes: setSizes,
          size: _choices.size,
          onSizeChanged: (n) => _change(_choices.copyWith(size: n)),
          byConversation: _choices.byConversation,
          onByConversationChanged: (on) =>
              _change(_choices.copyWith(byConversation: on)),
          sizeLabel: SetPickerScreen.sizeLabel,
          byConversationLabel: SetPickerScreen.byConversationLabel,
          byConversationHint: SetPickerScreen.byConversationHint,
          switchKey: const ValueKey('set-by-conversation'),
        ),
        const SizedBox(height: AppSpacing.s12),
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
        SizedBox(height: laptop ? AppSpacing.s32 : AppSpacing.s24),
        if (sets.isEmpty)
          Text(
            phaseQuestions.isEmpty
                ? GameCard.countText(0)
                : QuestionFilterCard.noMatchText,
            style: type.caption,
          )
        else ...[
          Semantics(
            header: true,
            child: Text(
              SetPickerScreen.setCountText(sets.length),
              style: type.phaseHeading,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          HomeCardGrid(
            laptop: laptop,
            cards: [
              for (var i = 0; i < sets.length; i++)
                SetCard(
                  key: ValueKey('set-card-$i'),
                  title: sets[i].title,
                  detail: sets[i].detail,
                  count: sets[i].length,
                  accent: accent,
                  onTap: () => widget.onSetSelected(sets[i]),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
