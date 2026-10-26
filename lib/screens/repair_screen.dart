/// Repair the sentence (phase 1, B5): Andrew's own sentence with the problem
/// words marked; a text field prefilled with the sentence (without the
/// marks); he corrects it, either by editing the whole sentence or by
/// typing only the replacement for the marked words; check; the corrected
/// sentence, the explanation and "Next question"; a score for the session.
///
/// Same frame as Choose a correction (B3): GameTopBar, ChipRow/CategoryChip,
/// PromptCard (marked form), AnswerField (U13) where the options would be,
/// ExplanationCard, PrimaryButton, the result toast (phones) and the Session
/// and Feedback panels (laptop). UI spec sections 5, 6, 8 and 10.
///
/// Checking uses [checkRepair] from `lib/models/answer_check.dart`. The
/// end-of-session summary is B7's; until then the screen ends with a short
/// stand-in ([_SessionEndView]), the same as B3's.
library;

import 'package:flutter/material.dart';

import '../models/answer_check.dart';
import '../models/question.dart';
import '../theme/app_layout.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import '../widgets/widgets.dart';

/// Plays a session of Repair the sentence questions, in the order given.
///
/// Questions from other games, and repair questions with nothing marked,
/// are skipped (the parser already rejects the latter).
class RepairScreen extends StatefulWidget {
  const RepairScreen({super.key, required this.questions});

  final List<Question> questions;

  /// Instruction above the prompt card (spec section 8).
  static const String instruction = 'Correct the marked words';

  /// The learner's sentence for the "You wrote" line. If [typed] is no
  /// longer than the marked stretch (the learner typed only the part), it
  /// is put in place of the marked words; otherwise it is taken as the
  /// whole sentence.
  static String learnerSentence(Question question, String typed) {
    final part = normaliseAnswer(typed);
    if (part.isEmpty || !question.hasMarks) return typed.trim();
    final whole = _wordCount(question.promptText);
    final rest = _wordCount(question.replaceMarkedSpans(''));
    final stretch = whole - rest;
    if (_wordCount(part) <= stretch) {
      return question.replaceMarkedSpans(part);
    }
    return typed.trim();
  }

  static int _wordCount(String s) =>
      s.trim().isEmpty ? 0 : s.trim().split(RegExp(r'\s+')).length;

  @override
  State<RepairScreen> createState() => _RepairScreenState();
}

class _RepairScreenState extends State<RepairScreen> {
  late final List<Question> _questions;

  /// Index of the question on screen.
  int _index = 0;

  /// The field, prefilled with the current question's sentence.
  late TextEditingController _controller;

  /// Whether the current question has been checked.
  bool _checked = false;

  /// Whether the current question was answered right (set when checked).
  bool _correct = false;

  /// What the learner had typed when they checked.
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
        .where((q) => q.game == GameType.repair && q.hasMarks)
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

  /// Check is enabled once the field differs from the prefilled sentence
  /// (spec section 6).
  bool get _canCheck =>
      !_checked &&
      AnswerField.isChanged(_controller.text, _question.promptText) &&
      normaliseAnswer(_controller.text).isNotEmpty;

  void _resetField() {
    _controller.dispose();
    _controller = TextEditingController(text: _question.promptText);
  }

  void _onChanged(String _) {
    // Rebuild so Check turns on or off as the text changes.
    setState(() {});
  }

  void _check() {
    if (!_canCheck) return;
    final typed = _controller.text;
    final correct = checkRepair(_question, typed);
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

  void _next() {
    if (!_checked) return;
    setState(() {
      if (_isLast) {
        _finished = true;
      } else {
        _index++;
        _checked = false;
        _correct = false;
        _typed = '';
        _resetField();
      }
      _toastResult = null;
    });
  }

  void _playAgain() {
    setState(() {
      _index = 0;
      _checked = false;
      _correct = false;
      _typed = '';
      _results = List<bool?>.filled(_questions.length, null);
      _finished = false;
      _toastResult = null;
      _resetField();
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
    final corrected = q.correctedSentence;

    final content = _checked
        ? ExplanationContent.build(
            explanation: q.explanation,
            rule: q.rule,
            meaning: q.meaning,
            // The answers are whole sentences, so the rule's answer chip
            // (spec section 6) comes from the words that changed.
            answers: [
              if (corrected != null)
                ...SentenceText.changedRuns(corrected, q.promptText),
              ...q.answers,
            ],
            typed: _correct ? null : RepairScreen.learnerSentence(q, _typed),
            typedAgainst: _correct ? null : corrected,
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
      Text(RepairScreen.instruction, style: type.caption),
      PromptCard.marked(
        sentence: q.prompt,
        missingWord: q.missingWord,
        corrected: _checked ? corrected : null,
      ),
      AnswerField(
        // A new key per question, so the field's own state starts afresh.
        key: ValueKey('repair-field-${q.id}'),
        controller: _controller,
        state: !_checked
            ? AnswerFieldState.editing
            : (_correct ? AnswerFieldState.correct : AnswerFieldState.wrong),
        caption: AnswerField.repairCaption,
        onChanged: _onChanged,
        onSubmitted: (_) => _check(),
        semanticLabel: 'Your corrected sentence',
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
        title: GameType.repair.label,
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
      topBar: GameTopBar(title: GameType.repair.label, onBack: onBack),
      primaryButton: PrimaryButton(label: 'Back to games', onPressed: onBack),
      children: [Text('No questions for this game yet.', style: type.body)],
    );
  }
}

/// Stand-in for the end-of-session summary (B7), the same as B3's.
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
        title: GameType.repair.label,
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
