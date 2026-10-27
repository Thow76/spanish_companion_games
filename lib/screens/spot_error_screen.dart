/// Spot the error (phase 2, B15): a new sentence with nothing marked. The
/// learner says "It's correct" or "It needs fixing"; if it needs fixing, a
/// text field prefilled with the sentence appears and they correct it;
/// check both steps; the corrected sentence (if it was wrong), the
/// explanation and "Next question"; a score for the session.
///
/// Same frame as the other games (B3/B5): GameTopBar, ChipRow/CategoryChip,
/// PromptCard (plain form), SpotErrorChoice with an AnswerField (U13) where
/// the options would be, ExplanationCard, PrimaryButton, the result toast
/// (phones) and the Session and Feedback panels (laptop). UI spec sections
/// 5, 6, 8 and 10.
///
/// Checking uses [checkSpotError] from `lib/models/answer_check.dart`: the
/// sentence is correct when it matches one of `answers`; both steps must be
/// right to score. The end-of-session summary is B7's; until then the
/// screen ends with a short stand-in ([_SessionEndView]), the same as the
/// other games.
library;

import 'package:flutter/material.dart';

import '../models/answer_check.dart';
import '../models/question.dart';
import '../theme/app_layout.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import '../widgets/widgets.dart';

/// Plays a session of Spot the error questions, in the order given.
///
/// Questions from other games are skipped.
class SpotErrorScreen extends StatefulWidget {
  const SpotErrorScreen({super.key, required this.questions});

  final List<Question> questions;

  /// Instruction above the prompt card (spec section 8).
  static const String instruction = 'Is this sentence correct?';

  @override
  State<SpotErrorScreen> createState() => _SpotErrorScreenState();
}

class _SpotErrorScreenState extends State<SpotErrorScreen> {
  late final List<Question> _questions;

  /// Index of the question on screen.
  int _index = 0;

  /// "It's correct" or "It needs fixing", or null before choosing.
  SpotErrorPick? _picked;

  /// The field, prefilled with the current question's sentence. Kept when
  /// the learner switches between the two choices.
  late TextEditingController _controller;

  /// Whether the current question has been checked.
  bool _checked = false;

  /// Whether the current question was answered right (set when checked).
  bool _correct = false;

  /// What the field held when they checked (only used for "It needs
  /// fixing").
  String _typed = '';

  /// One entry per question: null until checked, then right or wrong.
  late List<bool?> _results;

  /// Whether the last question has been checked and "See results" pressed.
  bool _finished = false;

  /// Toast control, as in B3.
  bool? _toastResult;
  int _toastId = 0;

  /// "Next question" gets keyboard focus after checking (spec section 10).
  final FocusNode _nextButtonFocus = FocusNode(debugLabel: 'Next question');
  final FocusNode _topBarActionFocus = FocusNode(
    debugLabel: 'Top bar action',
  );

  @override
  void initState() {
    super.initState();
    _questions = widget.questions
        .where((q) => q.game == GameType.spotError)
        .toList();
    _results = List<bool?>.filled(_questions.length, null);
    _controller = TextEditingController(
      text: _questions.isEmpty ? '' : _questions.first.promptText,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _nextButtonFocus.dispose();
    _topBarActionFocus.dispose();
    super.dispose();
  }

  Question get _question => _questions[_index];
  int get _total => _questions.length;
  bool get _isLast => _index == _total - 1;
  int get _score => _results.where((r) => r == true).length;

  /// Check is enabled once "It's correct" is chosen, or once the field
  /// differs from the sentence after "It needs fixing" (spec section 6).
  bool get _canCheck {
    if (_checked) return false;
    if (_picked == SpotErrorPick.needsFixing &&
        normaliseAnswer(_controller.text).isEmpty) {
      return false;
    }
    return SpotErrorChoice.canCheck(
      _picked,
      fieldText: _controller.text,
      sentence: _question.promptText,
    );
  }

  void _resetField() {
    _controller.dispose();
    _controller = TextEditingController(text: _question.promptText);
  }

  void _onPicked(SpotErrorPick pick) {
    if (_checked) return;
    setState(() => _picked = pick);
  }

  void _onChanged(String _) {
    // Rebuild so Check turns on or off as the text changes.
    setState(() {});
  }

  void _check() {
    if (!_canCheck) return;
    final saidCorrect = _picked == SpotErrorPick.correct;
    final typed = _controller.text;
    final correct = checkSpotError(
      _question,
      saidCorrect: saidCorrect,
      typed: saidCorrect ? null : typed,
    );
    setState(() {
      _checked = true;
      _correct = correct;
      _typed = typed;
      _results[_index] = correct;
      _toastResult = correct;
      _toastId++;
    });
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

  void _clearQuestion() {
    _picked = null;
    _checked = false;
    _correct = false;
    _typed = '';
    _resetField();
  }

  void _next() {
    if (!_checked) return;
    setState(() {
      if (_isLast) {
        _finished = true;
      } else {
        _index++;
        _clearQuestion();
      }
      _toastResult = null;
    });
  }

  void _playAgain() {
    setState(() {
      _index = 0;
      _results = List<bool?>.filled(_questions.length, null);
      _finished = false;
      _toastResult = null;
      _clearQuestion();
    });
  }

  void _goHome() => Navigator.of(context).maybePop();

  List<QuestionMark> get _marks => [
    for (var i = 0; i < _total; i++)
      switch (_results[i]) {
        true => QuestionMark.correct,
        false => QuestionMark.wrong,
        null => i == _index ? QuestionMark.current : QuestionMark.upcoming,
      },
  ];

  /// The learner's version of the sentence for the "You wrote" line: the
  /// sentence as shown if they said "It's correct", else what they typed.
  String get _learnerSentence =>
      _picked == SpotErrorPick.correct ? _question.promptText : _typed.trim();

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

    final laptop = FormFactor.of(context) == FormFactor.laptop;
    final type = AppTypography.of(context);
    final q = _question;
    final sentenceWasCorrect = spotErrorSentenceIsCorrect(q);
    // The first accepted sentence; for a correct sentence, the sentence
    // itself.
    final accepted = q.correctedSentence ?? q.promptText;

    final content = _checked
        ? ExplanationContent.build(
            explanation: q.explanation,
            rule: q.rule,
            meaning: q.meaning,
            // The answers are whole sentences, so the rule's answer chip
            // (spec section 6) comes from the words that changed, as in
            // Repair (U7).
            answers: [
              if (!sentenceWasCorrect)
                ...SentenceText.changedRuns(accepted, q.promptText),
              ...q.answers,
            ],
            typed: _correct ? null : _learnerSentence,
            typedAgainst: _correct ? null : accepted,
          )
        : null;

    final rows = <Widget>[
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
      Text(SpotErrorScreen.instruction, style: type.caption),
      PromptCard.plain(
        sentence: q.promptText,
        // After checking, a wrong sentence shows "Corrected version".
        corrected: _checked && !sentenceWasCorrect ? accepted : null,
      ),
      SpotErrorChoice(
        picked: _picked,
        onPicked: _checked ? null : _onPicked,
        sentenceWasCorrect: _checked ? sentenceWasCorrect : null,
        field: AnswerField(
          // A new key per question, so the field's own state starts afresh.
          key: ValueKey('spot-error-field-${q.id}'),
          controller: _controller,
          state: !_checked
              ? AnswerFieldState.editing
              : (_correct ? AnswerFieldState.correct : AnswerFieldState.wrong),
          caption: AnswerField.spotErrorCaption,
          onChanged: _onChanged,
          onSubmitted: (_) => _check(),
          semanticLabel: 'Your corrected sentence',
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
      onAction = _canCheck ? _check : null;
    }

    return GameFrame(
      topBar: GameTopBar(
        title: GameType.spotError.label,
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

/// Shown when the session has no playable questions (safety net; the home
/// screen does not open a game with none).
class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    return GameFrame(
      topBar: GameTopBar(title: GameType.spotError.label, onBack: onBack),
      primaryButton: PrimaryButton(label: 'Back to games', onPressed: onBack),
      children: [Text('No questions for this game yet.', style: type.body)],
    );
  }
}

/// Stand-in for the end-of-session summary (B7), the same as the other
/// games'.
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

  @override
  Widget build(BuildContext context) {
    final type = AppTypography.of(context);
    return GameFrame(
      topBar: GameTopBar(
        title: GameType.spotError.label,
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
          child: Text('Session complete', style: type.cardTitle),
        ),
        Text('You got $score of $total right.', style: type.body),
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
