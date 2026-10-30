/// Home screen: the six games in two groups by phase, "New corrections"
/// (phase 1) and "Recall" (phase 2), one card per game with the number of
/// questions available for it, and a reload button in the top bar.
///
/// A filter card above the groups (B12) narrows every game to one type
/// (grammar errors or language notes), one phase, or one category, or any
/// mix of the three; the card counts follow it, and choosing a phase shows
/// only that phase's group. The filter is kept for the app session,
/// including a reload.
///
/// The questions come from [HomeScreen.source]: the bundled sample file by
/// default, or `questions.json` on Google Drive when the app is run with the
/// Drive key and file ID (B8, wired up in `main.dart`).
///
/// Look (U4, UI spec sections 5, 6 and 8): [HomeFrame] with [HomeTopBar],
/// [PhaseHeading]s and [GameCard]s; phone one column, laptop a 2-column card
/// grid per group with 32 between the groups.
library;

import 'package:flutter/material.dart';

import '../data/question_loader.dart';
import '../models/question.dart';
import '../models/question_filter.dart';
import '../models/question_parser.dart';
import '../models/session_tally.dart';
import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import '../widgets/widgets.dart';
import 'choose_correction_screen.dart';
import 'fill_gap_screen.dart';
import 'match_screen.dart';
import 'order_screen.dart';
import 'repair_screen.dart';
import 'spot_error_screen.dart';

/// Signature of the function that fetches and parses the question file.
typedef QuestionSource = Future<ParsedQuestions> Function();

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.source = loadQuestionsFromAsset,
    this.sourceName = sampleSourceName,
  });

  /// Where the questions come from. Defaults to the bundled sample file.
  /// Tests pass a fake here.
  final QuestionSource source;

  /// Short name of where the questions come from, shown in the top bar's
  /// source line ("9 questions · sample file"); "Google Drive" when loading
  /// from Drive (B8).
  final String sourceName;

  static const String sampleSourceName = 'sample file';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<ParsedQuestions> _future;

  /// Every question checked since the app was opened, across the games
  /// (B7). Kept when the questions are reloaded.
  final SessionTally _session = SessionTally();

  /// What to play (B12). Kept when the questions are reloaded.
  QuestionFilter _filter = QuestionFilter.all;

  @override
  void initState() {
    super.initState();
    _future = widget.source();
  }

  void _reload() {
    setState(() {
      _future = widget.source();
    });
  }

  void _openGame(GameType game, List<Question> questions) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => switch (game) {
          // Every game has its own screen; each records its results in the
          // session tally for the end-of-session summary (B7).
          GameType.chooseCorrection => ChooseCorrectionScreen(
            questions: questions,
            session: _session,
          ),
          GameType.repair => RepairScreen(
            questions: questions,
            session: _session,
          ),
          GameType.fillGap => FillGapScreen(
            questions: questions,
            session: _session,
          ),
          GameType.order => OrderScreen(
            questions: questions,
            session: _session,
          ),
          GameType.match => MatchScreen(
            questions: questions,
            session: _session,
          ),
          GameType.spotError => SpotErrorScreen(
            questions: questions,
            session: _session,
          ),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ParsedQuestions>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LoadingView();
        }
        if (snapshot.hasError) {
          return _ErrorView(
            message: _describeError(snapshot.error!),
            onReload: _reload,
          );
        }
        final parsed = snapshot.data!;
        // A category the new file no longer has is dropped, so a reload
        // never leaves every game empty for a reason that can't be seen.
        final filter = _filter.keepingCategoryIn(parsed.questions);
        final shown = filter.apply(parsed.questions);
        return _LoadedView(
          parsed: parsed,
          shown: shown,
          filter: filter,
          onFilterChanged: (f) => setState(() => _filter = f),
          sourceLine: _sourceLine(parsed.questions.length, widget.sourceName),
          onReload: _reload,
          onGameSelected: (game) =>
              _openGame(game, shown.where((q) => q.game == game).toList()),
        );
      },
    );
  }

  /// "9 questions · sample file", "1 question · sample file".
  static String _sourceLine(int total, String sourceName) {
    final count = total == 1 ? '1 question' : '$total questions';
    return '$count · $sourceName';
  }

  static String _describeError(Object error) {
    if (error is QuestionFileException) return error.message;
    return 'Could not load the questions: $error';
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({
    required this.parsed,
    required this.shown,
    required this.filter,
    required this.onFilterChanged,
    required this.sourceLine,
    required this.onReload,
    required this.onGameSelected,
  });

  final ParsedQuestions parsed;

  /// The questions that pass [filter], in file order.
  final List<Question> shown;
  final QuestionFilter filter;
  final ValueChanged<QuestionFilter> onFilterChanged;
  final String sourceLine;
  final VoidCallback onReload;
  final ValueChanged<GameType> onGameSelected;

  @override
  Widget build(BuildContext context) {
    final counts = <GameType, int>{for (final g in GameType.values) g: 0};
    for (final q in shown) {
      counts[q.game] = counts[q.game]! + 1;
    }
    final showNew =
        filter.phase == null || filter.phase == QuestionPhase.noticeAndCorrect;
    final showRecall =
        filter.phase == null || filter.phase == QuestionPhase.recall;
    final type = AppTypography.of(context);
    final laptop = FormFactor.of(context) == FormFactor.laptop;

    Widget group(QuestionPhase phase) => _GameGroup(
      games: GameType.forPhase(phase),
      counts: counts,
      laptop: laptop,
      onGameSelected: onGameSelected,
    );

    return HomeFrame(
      topBar: HomeTopBar(source: sourceLine, onReload: onReload),
      footer: HomeFrame.footerLine(context),
      children: [
        if (parsed.hasProblems) ...[
          SizedBox(height: laptop ? AppSpacing.s24 : AppSpacing.s16),
          _ProblemsNotice(problems: parsed.problems),
        ],
        // What to play (B12).
        SizedBox(
          height: parsed.hasProblems
              ? AppSpacing.s12
              : (laptop ? AppSpacing.s24 : AppSpacing.s16),
        ),
        _FilterCard(
          key: const ValueKey('home-filter'),
          filter: filter,
          categories: QuestionFilter.categoriesOf(parsed.questions),
          shownCount: shown.length,
          totalCount: parsed.questions.length,
          onChanged: onFilterChanged,
        ),
        if (shown.isEmpty && parsed.questions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.s12),
          Text(_FilterCard.noMatchText, style: type.caption),
        ],
        if (showNew) ...[
          // Phase 1: Andrew's own sentences with the mistake marked.
          const PhaseHeading.newCorrections(),
          group(QuestionPhase.noticeAndCorrect),
        ],
        // Laptop: 32 between the groups (the heading brings 24 of it).
        if (laptop && showNew && showRecall)
          const SizedBox(height: AppLayout.laptopGroupGap - AppSpacing.s24),
        if (showRecall) ...[
          // Phase 2: points already corrected, in new sentences.
          const PhaseHeading.recall(),
          group(QuestionPhase.recall),
        ],
      ],
    );
  }
}

/// The cards of one phase group, in home order: one column on phones, a
/// 2-column grid on laptop (cards in a row share their height, so "Play →"
/// lines up at the bottom).
class _GameGroup extends StatelessWidget {
  const _GameGroup({
    required this.games,
    required this.counts,
    required this.laptop,
    required this.onGameSelected,
  });

  final List<GameType> games;
  final Map<GameType, int> counts;
  final bool laptop;
  final ValueChanged<GameType> onGameSelected;

  @override
  Widget build(BuildContext context) {
    final cards = [
      for (final game in games)
        GameCard.forGame(
          key: ValueKey('game-card-${game.jsonValue}'),
          game: game.jsonValue,
          count: counts[game] ?? 0,
          onTap: (counts[game] ?? 0) > 0 ? () => onGameSelected(game) : null,
        ),
    ];

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

/// The filter (B12): a quiet card like the skipped-questions notice. Shut,
/// it reads "Filter: All questions" (or what is chosen, with "5 of 15
/// questions" under it); open, it shows three rows of choices, Type, Phase
/// and Category, each starting with "All". The chosen one in each row is
/// highlighted.
///
/// The spec has no filter control; the choices use WordChip (the closest
/// shared widget: a tappable chip with a highlighted state).
class _FilterCard extends StatelessWidget {
  const _FilterCard({
    super.key,
    required this.filter,
    required this.categories,
    required this.shownCount,
    required this.totalCount,
    required this.onChanged,
  });

  final QuestionFilter filter;
  final List<String> categories;
  final int shownCount;
  final int totalCount;
  final ValueChanged<QuestionFilter> onChanged;

  static const String allLabel = 'All';
  static const String noMatchText =
      'No questions match this filter. Choose "All" in a row to widen it.';

  static String countText(int shown, int total) =>
      '$shown of ${total == 1 ? '1 question' : '$total questions'}';

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);

    Widget row<T>(
      String label,
      List<T> values,
      String Function(T) labelOf,
      T? chosen,
      bool Function(T, T) same,
      QuestionFilter Function(T?) change,
    ) {
      Widget chip(String text, bool selected, T? value) => WordChip(
        key: ValueKey('filter-$label-$text'),
        label: text,
        state: selected ? WordChipState.placed : WordChipState.toPlace,
        onPressed: selected ? null : () => onChanged(change(value)),
      );
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(header: true, child: Text(label, style: type.caption)),
            const SizedBox(height: AppSpacing.s8),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                chip(allLabel, chosen == null, null),
                for (final v in values)
                  chip(labelOf(v), chosen != null && same(v, chosen), v),
              ],
            ),
          ],
        ),
      );
    }

    return Material(
      color: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: AppColors.textMuted,
        collapsedIconColor: AppColors.textMuted,
        leading: Icon(
          Icons.filter_list_rounded,
          size: AppSizes.iconSmall,
          color: filter.isAll ? AppColors.textMuted : AppColors.accent,
        ),
        title: Text(
          'Filter: ${filter.summary}',
          style: type.caption.copyWith(color: AppColors.textSecondary),
        ),
        subtitle: filter.isAll
            ? null
            : Text(countText(shownCount, totalCount), style: type.caption),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          0,
          AppSpacing.s16,
          AppSpacing.s16,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row<QuestionType>(
            'Type',
            QuestionType.values,
            QuestionFilter.typeLabel,
            filter.type,
            (a, b) => a == b,
            filter.withType,
          ),
          row<QuestionPhase>(
            'Phase',
            QuestionPhase.values,
            (p) => p.label,
            filter.phase,
            (a, b) => a == b,
            filter.withPhase,
          ),
          if (categories.isNotEmpty)
            row<String>(
              'Category',
              categories,
              (c) => c,
              filter.category,
              (a, b) => a.trim().toLowerCase() == b.trim().toLowerCase(),
              filter.withCategory,
            ),
        ],
      ),
    );
  }
}

/// Questions the parser skipped: a quiet card that opens to list them.
class _ProblemsNotice extends StatelessWidget {
  const _ProblemsNotice({required this.problems});

  final List<QuestionProblem> problems;

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    final n = problems.length;
    return Material(
      color: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: AppColors.textMuted,
        collapsedIconColor: AppColors.textMuted,
        leading: const Icon(
          Icons.info_outline_rounded,
          size: AppSizes.iconSmall,
          color: AppColors.textMuted,
        ),
        title: Text(
          n == 1
              ? '1 question was skipped because of a format problem'
              : '$n questions were skipped because of format problems',
          style: type.caption.copyWith(color: AppColors.textSecondary),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.s16,
          0,
          AppSpacing.s16,
          AppSpacing.s16,
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final problem in problems)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s4),
              child: Text(problem.toString(), style: type.caption),
            ),
        ],
      ),
    );
  }
}

/// While the file loads: the top bar (reload off) and a spinner.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  static const String sourceLine = 'Loading questions…';

  @override
  Widget build(BuildContext context) {
    return const HomeFrame(
      topBar: HomeTopBar(source: sourceLine, onReload: null),
      children: [
        SizedBox(height: AppSpacing.s48),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

/// The file could not be read at all: the reason and a reload button.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onReload});

  final String message;
  final VoidCallback onReload;

  static const String sourceLine = 'No questions loaded';

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    return HomeFrame(
      topBar: HomeTopBar(source: sourceLine, onReload: onReload),
      children: [
        const SizedBox(height: AppSpacing.s48),
        const Icon(
          Icons.error_outline_rounded,
          size: AppSizes.glyph,
          color: AppColors.textMuted,
        ),
        const SizedBox(height: AppSpacing.s12),
        Text(message, style: type.body, textAlign: TextAlign.center),
        const SizedBox(height: AppSpacing.s24),
        Center(
          child: PrimaryButton(label: 'Reload questions', onPressed: onReload),
        ),
      ],
    );
  }
}
