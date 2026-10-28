/// Home screen: the six games in two groups by phase, "New corrections"
/// (phase 1) and "Recall" (phase 2), one card per game with the number of
/// questions available for it, and a reload button in the top bar.
///
/// For now the questions come from the bundled sample file. B8 will replace
/// the loader with the Drive file and pass its name as [HomeScreen.sourceName].
///
/// Look (U4, UI spec sections 5, 6 and 8): [HomeFrame] with [HomeTopBar],
/// [PhaseHeading]s and [GameCard]s; phone one column, laptop a 2-column card
/// grid per group with 32 between the groups.
library;

import 'package:flutter/material.dart';

import '../data/question_loader.dart';
import '../models/question.dart';
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
  /// source line ("9 questions · sample file"). B8 passes the Drive file's
  /// name.
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
          // Sentence ordering joins the tally once UI PR #23 (which changes
          // order_screen.dart) is merged; until then it keeps its stand-in.
          GameType.order => OrderScreen(questions: questions),
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
        return _LoadedView(
          parsed: parsed,
          sourceLine: _sourceLine(parsed.questions.length, widget.sourceName),
          onReload: _reload,
          onGameSelected: (game) => _openGame(game, parsed.forGame(game)),
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
    required this.sourceLine,
    required this.onReload,
    required this.onGameSelected,
  });

  final ParsedQuestions parsed;
  final String sourceLine;
  final VoidCallback onReload;
  final ValueChanged<GameType> onGameSelected;

  @override
  Widget build(BuildContext context) {
    final counts = parsed.countByGame;
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
        // Phase 1: Andrew's own sentences with the mistake marked.
        const PhaseHeading.newCorrections(),
        group(QuestionPhase.noticeAndCorrect),
        // Laptop: 32 between the groups (the heading brings 24 of it).
        if (laptop)
          const SizedBox(height: AppLayout.laptopGroupGap - AppSpacing.s24),
        // Phase 2: points already corrected, in new sentences.
        const PhaseHeading.recall(),
        group(QuestionPhase.recall),
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
