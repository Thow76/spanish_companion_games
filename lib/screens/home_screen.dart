/// Home screen (Flow v2, B23): two choices, "New corrections" (phase 1)
/// and "Recall" (phase 2), each with the number of questions in it (0 =
/// dimmed, can't be opened), and a reload button in the top bar. Tapping a
/// choice opens [PhaseGamesScreen], which lists that phase's games as the
/// home screen used to; B24 replaces it with the set picker.
///
/// A filter card above the choices (B12) narrows the questions to one type
/// (grammar errors or language notes), one phase, or one category, or any
/// mix of the three; the counts follow it, and choosing a phase shows only
/// that phase's choice. The filter is kept for the app session, including a
/// reload. (B24 moves it to the set picker and drops its Phase row.)
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
/// Look: [HomeFrame] with [HomeTopBar]. The two choices are [GameCard]s
/// standing in until U18 (phase 1 with the Choose a correction icon and
/// accent, phase 2 with Fill the gap's), with the [PhaseHeading] copy as
/// their descriptions; phone one column, laptop side by side.
library;

import 'package:flutter/material.dart';

import '../data/drive_source.dart';
import '../data/question_loader.dart';
import '../data/results_sync.dart';
import '../models/question.dart';
import '../models/question_filter.dart';
import '../models/question_parser.dart';
import '../models/session_tally.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import '../widgets/widgets.dart';
import 'choose_correction_screen.dart';
import 'fill_gap_screen.dart';
import 'match_screen.dart';
import 'order_screen.dart';
import 'phase_games_screen.dart';
import 'repair_screen.dart';
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

  /// Opens [phase]'s games (B23), with the questions that pass the filter.
  void _openPhase(QuestionPhase phase, List<Question> questions) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PhaseGamesScreen(
          phase: phase,
          questions: questions,
          onGameSelected: _openGame,
        ),
      ),
    );
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
        return _LoadedView(
          parsed: parsed,
          shown: shown,
          filter: filter,
          onFilterChanged: (f) => setState(() => _filter = f),
          sourceLine: sourceLineText(
            parsed.questions.length,
            widget.sourceName,
            updatedAt: _updatedAt,
          ),
          onReload: _reload,
          resultsSync: widget.resultsSync,
          onPhaseSelected: (phase) => _openPhase(
            phase,
            shown.where((q) => q.game.phase == phase).toList(),
          ),
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
    required this.filter,
    required this.onFilterChanged,
    required this.sourceLine,
    required this.onReload,
    required this.onPhaseSelected,
    this.resultsSync,
  });

  final ParsedQuestions parsed;

  /// The questions that pass [filter], in file order.
  final List<Question> shown;
  final QuestionFilter filter;
  final ValueChanged<QuestionFilter> onFilterChanged;
  final String sourceLine;
  final VoidCallback onReload;
  final ValueChanged<QuestionPhase> onPhaseSelected;
  final ResultsSync? resultsSync;

  /// The two choices' titles and descriptions (the [PhaseHeading] copy),
  /// and the game whose icon and accent each card borrows until U18.
  static const Map<QuestionPhase, (String, String, String)> choiceCopy = {
    QuestionPhase.noticeAndCorrect: (
      'New corrections',
      'Your own mistakes, marked. Put them right.',
      'choose_correction',
    ),
    QuestionPhase.recall: (
      'Recall',
      "Points you've corrected, in new sentences.",
      'fill_gap',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final counts = <QuestionPhase, int>{
      for (final p in QuestionPhase.values) p: 0,
    };
    for (final q in shown) {
      counts[q.game.phase] = counts[q.game.phase]! + 1;
    }
    final showNew =
        filter.phase == null || filter.phase == QuestionPhase.noticeAndCorrect;
    final showRecall =
        filter.phase == null || filter.phase == QuestionPhase.recall;
    final type = AppTypography.of(context);
    final laptop = FormFactor.of(context) == FormFactor.laptop;

    Widget choice(QuestionPhase phase) {
      final (title, description, game) = choiceCopy[phase]!;
      final count = counts[phase]!;
      return GameCard(
        key: ValueKey('phase-card-${phase.number}'),
        game: game,
        title: title,
        description: description,
        count: count,
        onTap: count > 0 ? () => onPhaseSelected(phase) : null,
      );
    }

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
        // The two choices (B23): phase 1, Andrew's own sentences with the
        // mistake marked; phase 2, points already corrected, in new
        // sentences.
        SizedBox(height: laptop ? AppSpacing.s24 : AppSpacing.s16),
        HomeCardGrid(
          laptop: laptop,
          cards: [
            if (showNew) choice(QuestionPhase.noticeAndCorrect),
            if (showRecall) choice(QuestionPhase.recall),
          ],
        ),
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
