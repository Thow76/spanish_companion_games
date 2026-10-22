/// Choose a correction (phase 1, B3): Andrew's own sentence with the problem
/// words marked; pick the right replacement from the options; check; the
/// corrected sentence, the explanation and "Next question"; a score for the
/// session.
///
/// The look is all from the shared widgets (U2) on the responsive frame
/// (U3): GameTopBar, ChipRow/CategoryChip, PromptCard (marked form),
/// OptionGrid of AnswerOptions, ExplanationCard, PrimaryButton, the result
/// toast (phones) and the Session and Feedback panels (laptop). This file
/// only decides what they show and when (UI spec sections 5, 6, 8 and 10).
///
/// Answer checking uses the shared rule in `lib/models/answer_check.dart`.
/// The end-of-session summary is B7's; until then [ChooseCorrectionScreen]
/// ends with a short stand-in ([_SessionEndView]) that shows the score and
/// offers "Play again".
library;

import 'package:flutter/material.dart';

import '../models/answer_check.dart';
import '../models/question.dart';
import '../theme/app_layout.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import '../widgets/widgets.dart';

/// Plays a session of Choose a correction questions, in the order given.
///
/// [questions] should all be `choose_correction` questions with options
/// (the parser guarantees that for the sample file and Drive file); any
/// other question is skipped.
class ChooseCorrectionScreen extends StatefulWidget {
  const ChooseCorrectionScreen({super.key, required this.questions});

  final List<Question> questions;

  /// Instruction above the prompt card (spec section 8).
  static const String instruction =
      'Choose the correction for the marked words';

  @override
  State<ChooseCorrectionScreen> createState() => _ChooseCorrectionScreenState();
}

class _ChooseCorrectionScreenState extends State<ChooseCorrectionScreen> {
  late final List<Question> _questions;

  /// Index of the question on screen.
  int _index = 0;

  /// The option picked for the current question, before and after checking.
  String? _chosen;

  /// Whether the current question has been checked.
  bool _checked = false;

  /// Whether the current question was answered right (set when checked).
  bool _correct = false;

  /// One entry per question: null until checked, then right or wrong.
  late List<bool?> _results;

  /// Whether the last question has been checked and "See results" pressed.
  bool _finished = false;

  /// Toast control: the result to show on phones, and a new id per check so
  /// the host shows it again for the next question.
  bool? _toastResult;
  int _toastId = 0;

  /// "Next question" gets keyboard focus after checking (spec section 10):
  /// the bottom button in portrait and on laptop, the top-bar link in phone
  /// landscape.
  final FocusNode _nextButtonFocus = FocusNode(debugLabel: 'Next question');
  final FocusNode _topBarActionFocus = FocusNode(
    debugLabel: 'Top bar action',
  );

  @override
  void initState() {
    super.initState();
    _questions = widget.questions
        .where((q) => q.game == GameType.chooseCorrection && q.hasOptions)
        .toList();
    _results = List<bool?>.filled(_questions.length, null);
  }

  @override
  void dispose() {
    _nextButtonFocus.dispose();
    _topBarActionFocus.dispose();
    super.dispose();
  }

  Question get _question => _questions[_index];
  int get _total => _questions.length;
  bool get _isLast => _index == _total - 1;
  int get _score => _results.where((r) => r == true).length;

  void _choose(String option) {
    if (_checked) return;
    setState(() => _chosen = option);
  }

  void _check() {
    final chosen = _chosen;
    if (chosen == null || _checked) return;
    final correct = isAcceptedAnswer(chosen, _question.answers);
    setState(() {
      _checked = true;
      _correct = correct;
      _results[_index] = correct;
      _toastResult = correct;
      _toastId++;
    });
    // Portrait waits for the toast to go (see [_onToastHidden]); landscape
    // and laptop move focus straight away.
    final f = FormFactor.of(context);
    if (f == FormFactor.phoneLandscape) {
      _topBarActionFocus.requestFocus();
    } else if (f == FormFactor.laptop) {
      _nextButtonFocus.requestFocus();
    }
  }

  void _onToastHidden() {
    if (!mounted || !_checked) return;
    if (FormFactor.of(context) == FormFactor.phone) {
      _nextButtonFocus.requestFocus();
    }
  }

  void _next() {
    if (!_checked) return;
    setState(() {
      if (_isLast) {
        _finished = true;
      } else {
        _index++;
        _chosen = null;
        _checked = false;
        _correct = false;
      }
      _toastResult = null;
    });
  }

  void _playAgain() {
    setState(() {
      _index = 0;
      _chosen = null;
      _checked = false;
      _correct = false;
      _results = List<bool?>.filled(_questions.length, null);
      _finished = false;
      _toastResult = null;
    });
  }

  void _goHome() => Navigator.of(context).maybePop();

  AnswerState _stateOf(String option) {
    if (!_checked) {
      return option == _chosen ? AnswerState.selected : AnswerState.resting;
    }
    if (isAcceptedAnswer(option, _question.answers)) {
      return AnswerState.correct;
    }
    if (option == _chosen) return AnswerState.wrong;
    return AnswerState.dimmed;
  }

  List<QuestionMark> get _marks => [
    for (var i = 0; i < _total; i++)
      switch (_results[i]) {
        true => QuestionMark.correct,
        false => QuestionMark.wrong,
        null => i == _index ? QuestionMark.current : QuestionMark.upcoming,
      },
  ];

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return _EmptyView(onBack: _goHome);
    }
    if (_finished) {
      return _SessionEndView(
        score: _score,
        total: _total,
        onPlayAgain: _playAgain,
        onBack: _goHome,
      );
    }

    final f = FormFactor.of(context);
    final laptop = f == FormFactor.laptop;
    final type = AppTypography.of(context);
    final q = _question;
    final options = q.options ?? const <String>[];

    final content = _checked
        ? ExplanationContent.build(
            explanation: q.explanation,
            rule: q.rule,
            meaning: q.meaning,
            answers: q.answers,
            chosen: _correct ? null : _chosen,
          )
        : null;

    final rows = <Widget>[
      // Category chip; the count sits beside it on phones and in the top
      // bar on laptop (spec section 6, Count).
      if (laptop)
        Align(
          alignment: Alignment.centerLeft,
          child: CategoryChip(type: q.type.jsonValue, category: q.category),
        )
      else
        ChipRow(
          type: q.type.jsonValue,
          category: q.category,
          current: _index + 1,
          total: _total,
        ),
      Text(ChooseCorrectionScreen.instruction, style: type.caption),
      PromptCard.marked(
        sentence: q.prompt,
        missingWord: q.missingWord,
        // Once an option is picked the marked span shows it in accent;
        // after checking the card shows the corrected sentence.
        replacement: _checked ? null : _chosen,
        corrected: _checked ? q.correctedSentence : null,
      ),
      OptionGrid.forLabels(
        labels: options,
        builder: (option) => AnswerOption(
          label: option,
          state: _stateOf(option),
          onPressed: _checked ? null : () => _choose(option),
        ),
      ),
    ];

    final String actionLabel;
    final VoidCallback? onAction;
    if (_checked) {
      actionLabel = _isLast ? 'See results' : 'Next question';
      onAction = _next;
    } else {
      actionLabel = 'Check';
      onAction = _chosen == null ? null : _check;
    }

    return GameFrame(
      topBar: GameTopBar(
        title: GameType.chooseCorrection.label,
        onBack: _goHome,
        current: _index + 1,
        total: _total,
        actionLabel: actionLabel,
        onAction: onAction,
        actionFocusNode: _topBarActionFocus,
      ),
      explanation: content == null ? null : ExplanationCard(content: content),
      primaryButton: _checked
          ? PrimaryButton.next(
              onPressed: _next,
              last: _isLast,
              focusNode: _nextButtonFocus,
            )
          : PrimaryButton.check(onPressed: onAction),
      sidePanel: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SessionPanel(marks: _marks, showPlaceholder: !_checked),
          if (content != null) ...[
            const SizedBox(height: AppLayout.laptopCardGap),
            FeedbackPanel(correct: _correct, content: content),
          ],
        ],
      ),
      toastResult: _toastResult,
      toastId: _toastId,
      onToastHidden: _onToastHidden,
      children: rows,
    );
  }
}

/// Shown when the session has no playable questions (the home screen does
/// not open a game with none, so this is only a safety net).
class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    return GameFrame(
      topBar: GameTopBar(
        title: GameType.chooseCorrection.label,
        onBack: onBack,
      ),
      primaryButton: PrimaryButton(label: 'Back to games', onPressed: onBack),
      children: [
        Text('No questions for this game yet.', style: type.body),
      ],
    );
  }
}

/// Stand-in for the end-of-session summary (B7): the score for the session
/// and "Play again". B7 replaces it with the full summary (score split by
/// phase, the questions got wrong with their explanations).
class _SessionEndView extends StatelessWidget {
  const _SessionEndView({
    required this.score,
    required this.total,
    required this.onPlayAgain,
    required this.onBack,
  });

  final int score;
  final int total;
  final VoidCallback onPlayAgain;
  final VoidCallback onBack;

  static const String title = 'Session complete';

  static String scoreText(int score, int total) =>
      'You got $score of $total right.';

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    return GameFrame(
      topBar: GameTopBar(
        title: GameType.chooseCorrection.label,
        onBack: onBack,
        actionLabel: 'Play again',
        onAction: onPlayAgain,
      ),
      primaryButton: PrimaryButton(
        label: 'Play again',
        onPressed: onPlayAgain,
        trailingIcon: Icons.refresh_rounded,
      ),
      children: [
        Semantics(
          header: true,
          child: Text(title, style: type.cardTitle),
        ),
        Text(scoreText(score, total), style: type.body),
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s8),
          child: Text(
            'The full summary comes in a later step.',
            style: type.caption,
          ),
        ),
      ],
    );
  }
}
