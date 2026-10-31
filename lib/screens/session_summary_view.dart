/// End-of-session summary (B7): shown when the last question of a game has
/// been checked and "See results" pressed.
///
/// - "Session complete" and this round's score ("You got 2 of 3 right.").
/// - "All games so far": the score for everything answered since the app was
///   opened, split into "New corrections" (phase 1) and "Recall" (phase 2),
///   from the shared [SessionTally].
/// - "To look at again": each question got wrong this round, with the
///   right answer on its prompt card and the explanation card under it.
/// - "Play again" (bottom button on phones, the top-bar link in phone
///   landscape, under the session panel on laptop); the back chevron returns
///   to the games.
///
/// Laptop: the side panel shows the round's SessionPanel, every question
/// ticked or crossed, with "Play again" under it, so the button is on screen
/// however long the list is (U9; it used to sit below the list).
///
/// U9 (UI spec sections 1, 4, 5, 6, 8, 10; the spec has no drawing of this
/// screen, so it follows the game frame): each wrong question is one block,
/// its chip row reading "Question 2 of 3" as the laptop session panel's rows
/// do, with 24 between blocks so one question's cards are not read as the
/// next one's.
library;

import 'package:flutter/material.dart';

import '../models/answer_check.dart';
import '../models/question.dart';
import '../models/session_tally.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import '../widgets/widgets.dart';

class SessionSummaryView extends StatelessWidget {
  const SessionSummaryView({
    super.key,
    required this.game,
    required this.questions,
    required this.results,
    required this.onPlayAgain,
    required this.onBack,
    this.session,
  });

  final GameType game;

  /// The round's questions, in the order played.
  final List<Question> questions;

  /// One entry per question in [questions]: right, wrong, or null if it was
  /// never checked.
  final List<bool?> results;

  final VoidCallback onPlayAgain;
  final VoidCallback onBack;

  /// The app session's tally. Null (tests, a screen opened on its own)
  /// counts this round only.
  final SessionTally? session;

  static const String title = 'Session complete';
  static const String sessionHeading = 'All games so far';
  static const String wrongHeading = 'To look at again';
  static const String wrongCaption =
      'The questions you got wrong this round, with the answer.';
  static const String allRightText = 'You got every question right.';
  static const String alreadyCorrectText = 'This sentence was already correct.';

  static String scoreText(int score, int total) =>
      'You got $score of $total right.';

  int get _score => results.where((r) => r == true).length;

  /// The questions got wrong, with their 1-based place in the round.
  List<(int, Question)> get _wrong => [
    for (var i = 0; i < questions.length && i < results.length; i++)
      if (results[i] == false) (i + 1, questions[i]),
  ];

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    final tally = session ?? SessionTally.fromRound(questions, results);
    final wrong = _wrong;

    final rows = <Widget>[
      Semantics(header: true, child: Text(title, style: type.cardTitle)),
      Text(scoreText(_score, questions.length), style: type.body),
      _SessionScores(tally: tally),
      if (wrong.isEmpty)
        Text(allRightText, style: type.caption)
      else ...[
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(wrongHeading, style: type.phaseHeading),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(wrongCaption, style: type.caption),
            ],
          ),
        ),
        _WrongList(
          children: [
            for (final (place, q) in wrong)
              _WrongQuestion(
                question: q,
                place: place,
                total: questions.length,
              ),
          ],
        ),
      ],
    ];

    final laptop = FormFactor.of(context) == FormFactor.laptop;
    final playAgain = PrimaryButton(
      label: 'Play again',
      onPressed: onPlayAgain,
      trailingIcon: Icons.refresh_rounded,
    );
    final sessionPanel = SessionPanel(
      marks: [
        for (final r in results)
          r == true ? QuestionMark.correct : QuestionMark.wrong,
      ],
    );

    return GameFrame(
      topBar: GameTopBar(
        title: game.label,
        onBack: onBack,
        actionLabel: 'Play again',
        onAction: onPlayAgain,
      ),
      // On laptop the button goes in the side panel instead of under the
      // list, so it is never below the fold.
      primaryButton: laptop ? null : playAgain,
      sidePanel: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          sessionPanel,
          const SizedBox(height: AppSpacing.s16),
          playAgain,
        ],
      ),
      children: rows,
    );
  }
}

/// "All games so far" with one line per phase: "New corrections  2 of 3 right",
/// "Recall  None yet".
class _SessionScores extends StatelessWidget {
  const _SessionScores({required this.tally});

  final SessionTally tally;

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardAll,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(
              SessionSummaryView.sessionHeading,
              style: type.phaseHeading,
            ),
          ),
          for (final phase in QuestionPhase.values) ...[
            const SizedBox(height: AppSpacing.s8),
            _line(type, phase),
          ],
        ],
      ),
    );
  }

  Widget _line(AppTypography type, QuestionPhase phase) {
    final score = SessionTally.scoreText(tally.scoreFor(phase));
    return Semantics(
      label: '${phase.label}: $score',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text(phase.label, style: type.body)),
            const SizedBox(width: AppSpacing.s12),
            Text(score, style: type.caption),
          ],
        ),
      ),
    );
  }
}

/// The wrong questions, 24 apart: more than the 8 inside a block and the
/// frame's row gap, so each question's chip and cards read as one group.
class _WrongList extends StatelessWidget {
  const _WrongList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.s24),
          children[i],
        ],
      ],
    );
  }
}

/// One question got wrong: its chip row ("Question 2 of 3" on the right,
/// matching the laptop session panel's row), the prompt card with the right
/// answer in place, and the explanation.
class _WrongQuestion extends StatelessWidget {
  const _WrongQuestion({
    required this.question,
    required this.place,
    required this.total,
  });

  final Question question;

  /// 1-based place in the round, and the round's length.
  final int place;
  final int total;

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    final q = question;
    final alreadyCorrect =
        q.game == GameType.spotError && spotErrorSentenceIsCorrect(q);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ChipRow(
          type: q.type.jsonValue,
          category: q.category,
          current: place,
          total: total,
        ),
        if (q.game == GameType.match) ...[
          const SizedBox(height: AppSpacing.s8),
          Text(q.prompt, style: type.caption),
        ],
        const SizedBox(height: AppSpacing.s8),
        _card(q),
        if (alreadyCorrect) ...[
          const SizedBox(height: AppSpacing.s8),
          Text(SessionSummaryView.alreadyCorrectText, style: type.caption),
        ],
        const SizedBox(height: AppSpacing.s8),
        ExplanationCard(
          content: ExplanationContent.build(
            explanation: q.explanation,
            rule: q.rule,
            meaning: q.meaning,
            answers: q.game == GameType.match
                ? [for (final p in q.pairs) p.right]
                : q.answers,
          ),
        ),
      ],
    );
  }

  /// The prompt card as it looks after a right answer.
  static Widget _card(Question q) {
    final first = q.answers.isEmpty ? null : q.answers.first;
    return switch (q.game) {
      GameType.chooseCorrection || GameType.repair => PromptCard.marked(
        sentence: q.prompt,
        missingWord: q.missingWord,
        corrected: q.correctedSentence,
      ),
      GameType.fillGap => PromptCard.gap(
        sentence: q.prompt,
        fill: first,
        gapState: first == null ? GapState.empty : GapState.correct,
      ),
      GameType.order => PromptCard.plain(sentence: first ?? q.promptText),
      GameType.spotError => PromptCard.plain(
        sentence: q.promptText,
        corrected: spotErrorSentenceIsCorrect(q) ? null : first,
      ),
      GameType.match => PromptCard.plain(
        sentence: [
          for (final p in q.pairs) '${p.left} – ${p.right}',
        ].join(' · '),
      ),
    };
  }
}
