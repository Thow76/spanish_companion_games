/// Home screen: the six games in two groups on the stage ladder (B30),
/// "Your mistakes" (Choose a correction, Fill the gap, Repair the sentence,
/// Spot the error) and "Consolidation" (Sentence ordering, Matching), one
/// card per game with the number of questions it plays now, and a reload
/// button in the top bar.
///
/// Padlocks (B30, `ladder_locks.dart`): a question whose `unlocks_after`
/// question has not yet been answered right this session is held back; a
/// card with only held-back questions, or an empty card after an earlier
/// stage that has questions, is locked, and tapping it shows the locked
/// message. A card with open and held-back questions shows its open count
/// and "n locked". Counts are worked out again on coming back from a game,
/// so a stage unlocks straight away.
///
/// A filter card above the groups (B12) narrows every game to one type
/// (grammar errors or language notes), one phase, or one category, or any
/// mix of the three; the card counts follow it, and choosing a phase shows
/// only that phase's games. The filter is kept for the app session,
/// including a reload.
///
/// Questions per round (B32): a 5 or 10 choice under the filter (default 5,
/// kept for the app session, including a reload). Opening a card plays the
/// first 5 or 10 of its open questions, oldest first (`round_size.dart`);
/// the card's count stays the total open. "Finish" on the end-of-round
/// summary comes back here and reloads the questions, as Reload does. The
/// choice is a [RoundSizeCard] under the filter card (U22).
///
/// The questions come from [HomeScreen.source]: the bundled sample file by
/// default, or `questions.json` on Google Drive when the app is run with the
/// Drive key and file ID (B8, wired up in `main.dart`).
///
/// The state of the loop (B20): with Drive, the source line also says when
/// the file was last changed ("68 questions · Google Drive · updated 7 Nov,
/// 04:50", from [HomeScreen.updatedSource]; left out if that request
/// fails). When results are waiting to reach the Test Review sheet (B18),
/// a line under the top bar says how many, with "Send again".
///
/// Look (U4, UI spec sections 5, 6 and 8): [HomeFrame] with [HomeTopBar],
/// [PhaseHeading]s and [GameCard]s; phone one column, laptop a 2-column card
/// grid per group with 32 between the groups. The locked state and the
/// "n locked" line are stand-ins (a dimmed [GameCard] and a caption line
/// under the card) until the UI task's U19.
library;

import 'package:flutter/material.dart';

import '../data/drive_source.dart';
import '../data/question_loader.dart';
import '../data/results_sync.dart';
import '../models/ladder_locks.dart';
import '../models/question.dart';
import '../models/question_filter.dart';
import '../models/question_parser.dart';
import '../models/round_size.dart';
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
import 'session_summary_view.dart';
import 'spot_error_screen.dart';

/// Signature of the function that fetches and parses the question file.
typedef QuestionSource = Future<ParsedQuestions> Function();

/// Signature of the function that says when the question file last
/// changed (B20).
typedef UpdatedSource = Future<DateTime> Function();

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.source = loadQuestionsFromAsset,
    this.sourceName = sampleSourceName,
    this.resultsSync,
    this.updatedSource,
  });

  /// Where the questions come from. Defaults to the bundled sample file.
  /// Tests pass a fake here.
  final QuestionSource source;

  /// Short name of where the questions come from, shown in the top bar's
  /// source line ("9 questions · sample file"); "Google Drive" when loading
  /// from Drive (B8).
  final String sourceName;

  /// Sends each checked question's result to the Test Review sheet (B18),
  /// when the app is run with `RESULTS_URL`; null otherwise.
  final ResultsSync? resultsSync;

  /// When the question file was last changed (B20): Drive's `modifiedTime`
  /// when loading from Drive; null otherwise (sample file, tests). Asked
  /// again on every reload. A failure only leaves the time out of the
  /// source line.
  final UpdatedSource? updatedSource;

  static const String sampleSourceName = 'sample file';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<ParsedQuestions> _future;

  /// Every question checked since the app was opened, across the games
  /// (B7). Kept when the questions are reloaded.
  late final SessionTally _session = SessionTally(sync: widget.resultsSync);

  /// What to play (B12). Kept when the questions are reloaded.
  QuestionFilter _filter = QuestionFilter.all;

  /// Questions per round (B32). Kept when the questions are reloaded.
  RoundSize _roundSize = RoundSize.standard;

  /// When the question file was last changed (B20), once known.
  DateTime? _updatedAt;

  /// Counts the requests for [_updatedAt], so an answer to an older
  /// request (before a reload) is ignored.
  int _updatedRequest = 0;

  @override
  void initState() {
    super.initState();
    _future = widget.source();
    _loadUpdated();
  }

  void _reload() {
    setState(() {
      _future = widget.source();
      _loadUpdated();
    });
  }

  /// Asks when the file was last changed; the questions never wait for it.
  void _loadUpdated() {
    final source = widget.updatedSource;
    _updatedAt = null;
    if (source == null) return;
    final request = ++_updatedRequest;
    Future<DateTime>.sync(source).then(
      (time) {
        if (mounted && request == _updatedRequest) {
          setState(() => _updatedAt = time);
        }
      },
      // Any failure: the source line just has no time.
      onError: (Object _) {},
    );
  }

  /// Opens [game] with the first [_roundSize] of its open questions, oldest
  /// first (B32).
  void _openGame(GameType game, List<Question> open) {
    final questions = pickRound(open, _roundSize);
    Navigator.of(context)
        .push<Object?>(
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
        )
        // Back on home: a question answered right may have unlocked
        // another (B30), so the counts and padlocks are worked out again.
        // "Finish" on the summary (B32) also reloads the questions.
        .then((result) {
          if (!mounted) return;
          if (result == RoundEnd.finish) {
            _reload();
          } else {
            setState(() {});
          }
        });
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
          final (message, detail) = describeLoadError(snapshot.error!);
          return _ErrorView(
            message: message,
            detail: detail,
            onReload: _reload,
            resultsSync: widget.resultsSync,
          );
        }
        final parsed = snapshot.data!;
        // A category the new file no longer has is dropped, so a reload
        // never leaves every game empty for a reason that can't be seen.
        final filter = _filter.keepingCategoryIn(parsed.questions);
        final shown = filter.apply(parsed.questions);
        final cards = cardStates(
          shown,
          fileIds: {for (final q in parsed.questions) q.id},
          passed: _session.passed,
        );
        return _LoadedView(
          parsed: parsed,
          shown: shown,
          cards: cards,
          filter: filter,
          onFilterChanged: (f) => setState(() => _filter = f),
          roundSize: _roundSize,
          onRoundSizeChanged: (r) => setState(() => _roundSize = r),
          sourceLine: sourceLineText(
            parsed.questions.length,
            widget.sourceName,
            updatedAt: _updatedAt,
          ),
          onReload: _reload,
          resultsSync: widget.resultsSync,
          // Only the questions open now (B30).
          onGameSelected: (game) => _openGame(game, cards[game]!.open),
        );
      },
    );
  }
}

/// The top bar's source line: "9 questions · sample file",
/// "1 question · sample file", or with [updatedAt] (B20)
/// "68 questions · Google Drive · updated 7 Nov, 04:50" (local time).
String sourceLineText(int total, String sourceName, {DateTime? updatedAt}) {
  final count = total == 1 ? '1 question' : '$total questions';
  final updated = updatedAt == null
      ? ''
      : ' · updated ${updatedTimeText(updatedAt.toLocal())}';
  return '$count · $sourceName$updated';
}

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "7 Nov, 04:50": day, short month, 24-hour time, for [time] as given
/// (the caller converts to local time).
String updatedTimeText(DateTime time) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${time.day} ${_months[time.month - 1]}, '
      '${two(time.hour)}:${two(time.minute)}';
}

/// The error view's text for a failed load (B9): a plain message, and an
/// optional smaller detail line (Drive's own words, or the parser's).
///
/// Drive failures each have their own message ([DriveLoadException]). The
/// error itself is never printed for anything else, because `http`'s
/// errors carry the request URL, which holds the API key.
(String, String?) describeLoadError(Object error) {
  if (error is DriveLoadException) {
    return (error.message(webAddress: _webAddress()), error.detail);
  }
  if (error is QuestionFileException) return (error.message, null);
  return ('Could not load the questions. Reload to try again.', null);
}

/// Where the app is running, e.g. `http://localhost:5000`; null when not
/// served over http(s) (tests, desktop).
String? _webAddress() {
  final base = Uri.base;
  if (base.scheme != 'http' && base.scheme != 'https') return null;
  return base.origin;
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({
    required this.parsed,
    required this.shown,
    required this.cards,
    required this.filter,
    required this.onFilterChanged,
    required this.roundSize,
    required this.onRoundSizeChanged,
    required this.sourceLine,
    required this.onReload,
    required this.onGameSelected,
    this.resultsSync,
  });

  final ParsedQuestions parsed;

  /// The questions that pass [filter], in file order.
  final List<Question> shown;

  /// Each card's open questions and padlock (B30).
  final Map<GameType, CardState> cards;
  final QuestionFilter filter;
  final ValueChanged<QuestionFilter> onFilterChanged;
  final RoundSize roundSize;
  final ValueChanged<RoundSize> onRoundSizeChanged;
  final String sourceLine;
  final VoidCallback onReload;
  final ValueChanged<GameType> onGameSelected;
  final ResultsSync? resultsSync;

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    final laptop = FormFactor.of(context) == FormFactor.laptop;

    // A chosen phase shows only that phase's games; a group left with no
    // games is not shown.
    List<GameType> gamesOf(HomeGroup group) => [
      for (final g in group.games)
        if (filter.phase == null || g.phase == filter.phase) g,
    ];
    final mistakes = gamesOf(HomeGroup.yourMistakes);
    final consolidation = gamesOf(HomeGroup.consolidation);

    Widget group(List<GameType> games) => _GameGroup(
      games: games,
      cards: cards,
      laptop: laptop,
      onGameSelected: onGameSelected,
    );

    return HomeFrame(
      topBar: HomeTopBar(source: sourceLine, onReload: onReload),
      footer: HomeFrame.footerLine(context),
      children: [
        // Results waiting to reach the Test Review sheet (B20).
        if (resultsSync != null) UnsavedResultsLine(sync: resultsSync!),
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
        // Questions per round (B32).
        const SizedBox(height: AppSpacing.s12),
        RoundSizeChoice(value: roundSize, onChanged: onRoundSizeChanged),
        if (mistakes.isNotEmpty) ...[
          // Stages 1–5 of each mistake (B30).
          PhaseHeading(
            key: const ValueKey('home-group-your-mistakes'),
            title: HomeGroup.yourMistakes.title,
            description: HomeGroup.yourMistakes.description,
            first: true,
          ),
          group(mistakes),
        ],
        // Laptop: 32 between the groups (the heading brings 24 of it).
        if (laptop && mistakes.isNotEmpty && consolidation.isNotEmpty)
          const SizedBox(height: AppLayout.laptopGroupGap - AppSpacing.s24),
        if (consolidation.isNotEmpty) ...[
          // After Stage 5 (B30).
          PhaseHeading(
            key: const ValueKey('home-group-consolidation'),
            title: HomeGroup.consolidation.title,
            description: HomeGroup.consolidation.description,
            first: mistakes.isEmpty,
          ),
          group(consolidation),
        ],
      ],
    );
  }
}

/// The cards of one group, in home order: one column on phones, a
/// 2-column grid on laptop (cards in a row share their height, so "Play →"
/// lines up at the bottom).
///
/// B30: a locked card is a dimmed [GameCard] (as for 0 questions) that
/// shows [lockedCardMessage] when tapped, with a "Locked" line under it; a
/// part-locked card shows its open count and "n locked" under it.
/// Stand-ins until U19.
class _GameGroup extends StatelessWidget {
  const _GameGroup({
    required this.games,
    required this.cards,
    required this.laptop,
    required this.onGameSelected,
  });

  final List<GameType> games;
  final Map<GameType, CardState> cards;
  final bool laptop;
  final ValueChanged<GameType> onGameSelected;

  void _showLocked(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(lockedCardMessage)));
  }

  /// One card with its lock line; [fill] lets the card take the cell's
  /// height in the laptop grid.
  Widget _cell(BuildContext context, GameType game, {required bool fill}) {
    final state = cards[game]!;
    final open = state.open.length;
    Widget card = GameCard.forGame(
      key: ValueKey('game-card-${game.jsonValue}'),
      game: game.jsonValue,
      count: open,
      onTap: open > 0 ? () => onGameSelected(game) : null,
    );
    if (state.lock == CardLock.locked) {
      final title = GameCard.copy[game.jsonValue]?.$1 ?? game.label;
      // The dimmed card does not take taps itself, so they reach here.
      card = Semantics(
        key: ValueKey('game-card-locked-${game.jsonValue}'),
        button: true,
        label: '$title. Locked. $lockedCardMessage',
        excludeSemantics: true,
        onTap: () => _showLocked(context),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showLocked(context),
          child: card,
        ),
      );
    }
    final line = switch (state.lock) {
      CardLock.locked => LockLine.lockedText,
      CardLock.partLocked => LockLine.partText(state.locked),
      _ => null,
    };
    if (line == null) return card;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (fill) Expanded(child: card) else card,
        LockLine(key: ValueKey('lock-line-${game.jsonValue}'), text: line),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!laptop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < games.length; i++) ...[
            if (i > 0) const SizedBox(height: AppLayout.phoneCardGap),
            _cell(context, games[i], fill: false),
          ],
        ],
      );
    }

    final cells = [for (final game in games) _cell(context, game, fill: true)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cells.length; i += 2) ...[
          if (i > 0) const SizedBox(height: AppLayout.laptopCardGap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cells[i]),
                const SizedBox(width: AppLayout.laptopCardGap),
                Expanded(
                  child: i + 1 < cells.length
                      ? cells[i + 1]
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

/// Questions per round (B32): "Questions per round" and a 5 / 10 choice.
/// Look from U22: the shared [RoundSizeCard].
class RoundSizeChoice extends StatelessWidget {
  const RoundSizeChoice({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final RoundSize value;
  final ValueChanged<RoundSize> onChanged;

  static const String label = RoundSizeCard.defaultLabel;

  @override
  Widget build(BuildContext context) {
    return RoundSizeCard(
      key: const ValueKey('home-round-size'),
      sizes: [for (final size in RoundSize.values) size.count],
      value: value.count,
      onChanged: (n) =>
          onChanged(RoundSize.values.firstWhere((s) => s.count == n)),
      buttonKey: (n) => ValueKey('round-size-$n'),
    );
  }
}

/// Under a locked or part-locked card (B30): a small padlock and "Locked"
/// or "2 locked", muted caption. A stand-in until U19.
class LockLine extends StatelessWidget {
  const LockLine({super.key, required this.text});

  final String text;

  static const String lockedText = 'Locked';

  /// "1 locked", "2 locked".
  static String partText(int locked) => '$locked locked';

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s8, left: AppSpacing.s4),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: AppSizes.iconSmall,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: AppSpacing.s4),
          Flexible(child: Text(text, style: type.caption)),
        ],
      ),
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
  const _ErrorView({
    required this.message,
    required this.onReload,
    this.detail,
    this.resultsSync,
  });

  final String message;

  /// Smaller line under the message (Drive's own words), if any.
  final String? detail;
  final VoidCallback onReload;
  final ResultsSync? resultsSync;

  static const String sourceLine = 'No questions loaded';

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    return HomeFrame(
      topBar: HomeTopBar(source: sourceLine, onReload: onReload),
      children: [
        if (resultsSync != null) UnsavedResultsLine(sync: resultsSync!),
        const SizedBox(height: AppSpacing.s48),
        const Icon(
          Icons.error_outline_rounded,
          size: AppSizes.glyph,
          color: AppColors.textMuted,
        ),
        const SizedBox(height: AppSpacing.s12),
        Text(message, style: type.body, textAlign: TextAlign.center),
        if (detail != null) ...[
          const SizedBox(height: AppSpacing.s8),
          Text(detail!, style: type.caption, textAlign: TextAlign.center),
        ],
        const SizedBox(height: AppSpacing.s24),
        Center(
          child: PrimaryButton(label: 'Reload questions', onPressed: onReload),
        ),
      ],
    );
  }
}

/// Under the top bar (B20): "2 results not saved yet" and a "Send again"
/// button while results wait to reach the Test Review sheet (B18), using
/// [ResultsSync.send]; "Saving 2 results…" while a send is on its way.
/// Nothing at all when every result is saved. Muted caption, as the spec
/// has no copy for it.
class UnsavedResultsLine extends StatelessWidget {
  const UnsavedResultsLine({super.key, required this.sync});

  final ResultsSync sync;

  static const String retryLabel = 'Send again';

  /// "1 result not saved yet", "2 results not saved yet".
  static String unsavedText(int count) =>
      '$count ${count == 1 ? 'result' : 'results'} not saved yet';

  /// "Saving 2 results…".
  static String savingText(int count) =>
      'Saving $count ${count == 1 ? 'result' : 'results'}…';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) {
        final count = sync.pending;
        if (count == 0) return const SizedBox.shrink();
        final type = AppTypography.of(context);
        final sending = sync.state == ResultsSyncState.sending;
        return Padding(
          key: const ValueKey('home-unsaved-results'),
          padding: const EdgeInsets.only(top: AppSpacing.s12),
          child: Semantics(
            liveRegion: true,
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.s8,
              children: [
                Text(
                  sending ? savingText(count) : '${unsavedText(count)} ·',
                  style: type.caption,
                ),
                if (!sending)
                  TextButton(
                    onPressed: sync.send,
                    child: const Text(retryLabel),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
