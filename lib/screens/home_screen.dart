/// Home screen: the six games in two groups by phase, "New corrections"
/// (phase 1) and "Recall" (phase 2), one large button per game with the
/// number of questions available for it, and a "Reload questions" button.
///
/// For now the questions come from the bundled sample file. B8 will replace
/// the loader with the Drive file. The look (cards, top bar, source line)
/// is U4's; this screen only does the grouping and the counts.
library;

import 'package:flutter/material.dart';

import '../data/question_loader.dart';
import '../models/question.dart';
import '../models/question_parser.dart';
import '../widgets/phase_heading.dart';
import 'choose_correction_screen.dart';
import 'game_placeholder_screen.dart';

/// Signature of the function that fetches and parses the question file.
typedef QuestionSource = Future<ParsedQuestions> Function();

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.source = loadQuestionsFromAsset});

  /// Where the questions come from. Defaults to the bundled sample file.
  /// Tests pass a fake here.
  final QuestionSource source;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<ParsedQuestions> _future;

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
          // The games built so far; the rest still open the placeholder.
          GameType.chooseCorrection => ChooseCorrectionScreen(
            questions: questions,
          ),
          _ => GamePlaceholderScreen(game: game, questions: questions),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spanish Companion Games'),
        actions: [
          IconButton(
            tooltip: 'Reload questions',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<ParsedQuestions>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
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
            onReload: _reload,
            onGameSelected: (game) => _openGame(game, parsed.forGame(game)),
          );
        },
      ),
    );
  }

  static String _describeError(Object error) {
    if (error is QuestionFileException) return error.message;
    return 'Could not load the questions: $error';
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({
    required this.parsed,
    required this.onReload,
    required this.onGameSelected,
  });

  final ParsedQuestions parsed;
  final VoidCallback onReload;
  final ValueChanged<GameType> onGameSelected;

  @override
  Widget build(BuildContext context) {
    final counts = parsed.countByGame;
    final total = parsed.questions.length;
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final twoColumns = constraints.maxWidth >= 600;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    total == 1
                        ? '1 question loaded from the sample file'
                        : '$total questions loaded from the sample file',
                    style: textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  if (parsed.hasProblems) ...[
                    const SizedBox(height: 8),
                    _ProblemsNotice(problems: parsed.problems),
                  ],
                  // Phase 1: Andrew's own sentences with the mistake marked.
                  const PhaseHeading.newCorrections(),
                  _GameGroup(
                    games: GameType.forPhase(QuestionPhase.noticeAndCorrect),
                    counts: counts,
                    twoColumns: twoColumns,
                    onGameSelected: onGameSelected,
                  ),
                  // Phase 2: points already corrected, in new sentences.
                  const PhaseHeading.recall(),
                  _GameGroup(
                    games: GameType.forPhase(QuestionPhase.recall),
                    counts: counts,
                    twoColumns: twoColumns,
                    onGameSelected: onGameSelected,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.tonalIcon(
                    onPressed: onReload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reload questions'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The buttons of one phase group, in home order.
class _GameGroup extends StatelessWidget {
  const _GameGroup({
    required this.games,
    required this.counts,
    required this.twoColumns,
    required this.onGameSelected,
  });

  final List<GameType> games;
  final Map<GameType, int> counts;
  final bool twoColumns;
  final ValueChanged<GameType> onGameSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: twoColumns ? 2 : 1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: twoColumns ? 2.2 : 3.2,
      children: [
        for (final game in games)
          _GameButton(
            game: game,
            count: counts[game] ?? 0,
            onPressed: () => onGameSelected(game),
          ),
      ],
    );
  }
}

class _GameButton extends StatelessWidget {
  const _GameButton({
    required this.game,
    required this.count,
    required this.onPressed,
  });

  final GameType game;
  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = count > 0;
    final countText = switch (count) {
      0 => 'No questions yet',
      1 => '1 question',
      _ => '$count questions',
    };

    // No colours on these styles: the button supplies its own foreground
    // colour, which also greys the text out when the button is disabled.
    return FilledButton(
      onPressed: enabled ? onPressed : null,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(_iconFor(game), size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  game.label,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(countText, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Stand-in icons until U4 restyles the home screen with the game SVGs.
  static IconData _iconFor(GameType game) {
    switch (game) {
      case GameType.chooseCorrection:
        return Icons.find_replace;
      case GameType.repair:
        return Icons.build;
      case GameType.fillGap:
        return Icons.edit_note;
      case GameType.match:
        return Icons.compare_arrows;
      case GameType.order:
        return Icons.swap_horiz;
      case GameType.spotError:
        return Icons.search;
    }
  }
}

class _ProblemsNotice extends StatelessWidget {
  const _ProblemsNotice({required this.problems});

  final List<QuestionProblem> problems;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = problems.length;
    return Card(
      color: scheme.errorContainer,
      child: ExpansionTile(
        leading: Icon(Icons.warning_amber, color: scheme.onErrorContainer),
        title: Text(
          n == 1
              ? '1 question was skipped because of a format problem'
              : '$n questions were skipped because of format problems',
          style: TextStyle(color: scheme.onErrorContainer),
        ),
        children: [
          for (final problem in problems)
            ListTile(
              dense: true,
              title: Text(
                problem.toString(),
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onReload});

  final String message;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onReload,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload questions'),
            ),
          ],
        ),
      ),
    );
  }
}
