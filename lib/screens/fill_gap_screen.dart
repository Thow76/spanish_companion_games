/// Fill the gap (phase 2, B14): a new sentence on a pattern Andrew has
/// already corrected, with a gap. If the question has `options`, he picks
/// one; if not, he types the missing word. Check; the gap shows the right
/// word, the explanation and "Next question"; a score for the session.
///
/// Same frame as Choose a correction (B3): GameTopBar, ChipRow/CategoryChip,
/// PromptCard (gap form), an OptionGrid of AnswerOptions (option mode) or
/// the AnswerField (typed mode, U13) where the options would be,
/// ExplanationCard, PrimaryButton, the result toast (phones) and the Session
/// and Feedback panels (laptop). UI spec sections 5, 6, 8 and 10.
///
/// The mode is decided per question, so one session can mix both. Checking
/// uses [isAcceptedAnswer] (trim, ignore case and final punctuation, accents
/// must match). The end-of-session summary is B7's; until then the screen
/// ends with the same short stand-in as B3 and B5 ([_SessionEndView]).
library;

import 'package:flutter/material.dart';

import '../models/answer_check.dart';
import '../models/question.dart';
import '../theme/app_layout.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import '../widgets/widgets.dart';

/// Plays a session of Fill the gap questions, in the order given.
///
/// Questions from other games, and fill-the-gap questions without a `___`
/// (the parser already rejects those), are skipped.
class FillGapScreen extends StatefulWidget {
  const FillGapScreen({super.key, required this.questions});

  final List<Question> questions;

  /// Instructions above the prompt card (spec section 8).
  static const String chooseInstruction = 'Choose the missing word';
  static const String typeInstruction = 'Type the missing word';

  /// Whether [question] is played by picking an option (true) or by
  /// typing (false).
  static bool hasOptionMode(Question question) => question.hasOptions;

  @override
  State<FillGapScreen> createState() => _FillGapScreenState();
}

class _FillGapScreenState extends State<FillGapScreen> {
  late final List<Question> _questions;

  /// Index of the question on screen.
  int _index = 0;

  /// Option mode: the option picked, before and after checking.
  String? _chosen;

  /// Typed mode: the field. Starts empty for each question.
  final TextEditingController _controller = TextEditingController();

  /// Whether the current question has been checked.
  bool _checked = false;

  /// Whether the current question was answered right (set when checked).
  bool _correct = false;

  /// What the learner gave when they checked (option or typed word).
  String _given = '';

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
        .where((q) => q.game == GameType.fillGap && q.prompt.contains('___'))
        .toList();
    _results = List<bool?>.filled(_questions.length, null);
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
  bool get _optionMode => FillGapScreen.hasOptionMode(_question);

  /// What the learner has given so far: the option picked, or the typed
  /// text (trimmed). Null when nothing yet.
  String? get _answer {
    if (_optionMode) return _chosen;
    final typed = _controller.text.trim();
    return typed.isEmpty ? null : typed;
  }

  bool get _canCheck =>
      !_checked && _answer != null && normaliseAnswer(_answer!).isNotEmpty;

  void _choose(String option) {
    if (_checked) return;
    setState(() => _chosen = option);
  }

  void _onChanged(String _) {
    // Rebuild so Check turns on or off, and the gap shows what is typed.
    setState(() {});
  }

  void _check() {
    if (!_canCheck) return;
    final given = _answer!;
    final correct = isAcceptedAnswer(given, _question.answers);
    setState(() {
      _checked = true;
      _correct = correct;
      _given = given;
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

  void _resetQuestion() {
    _chosen = null;
    _checked = false;
    _correct = false;
    _given = '';
    _controller.clear();
  }

  void _next() {
    if (!_checked) return;
    setState(() {
      if (_isLast) {
        _finished = true;
      } else {
        _index++;
        _resetQuestion();
      }
      _toastResult = null;
    });
  }

  void _playAgain() {
    setState(() {
      _index = 0;
      _resetQuestion();
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

  /// The explanation after checking. For a wrong answer, "You wrote" puts
  /// the learner's word in place of the answer in the rule, when the rule
  /// shows the answer; otherwise (e.g. the answer is "del" and the rule is
  /// "depender de") it shows the sentence with the learner's word in the
  /// gap, struck through against the right one, rather than tacking the
  /// word onto the end of the rule ("depender de de").
  ExplanationContent _explanation(Question q) {
    ExplanationContent build({
      String? chosen,
      String? typed,
      String? against,
    }) => ExplanationContent.build(
          explanation: q.explanation,
          rule: q.rule,
          meaning: q.meaning,
          answers: q.answers,
          chosen: chosen,
          typed: typed,
          typedAgainst: against,
        );

    if (_correct) return build();
    final withChoice = build(chosen: _given);
    final rule = withChoice.rule;
    if (rule == null || rule.any((p) => p.kind == RulePartKind.answer)) {
      return withChoice;
    }
    final right = q.answers.isEmpty ? '' : q.answers.first;
    return build(
      typed: q.prompt.replaceFirst('___', _given),
      against: q.prompt.replaceFirst('___', right),
    );
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

    final laptop = FormFactor.of(context) == FormFactor.laptop;
    final type = AppTypography.of(context);
    final q = _question;
    final optionMode = _optionMode;

    // The gap: empty, then what was picked or typed (accent), then after
    // checking the first accepted answer (mint) whether right or wrong.
    final String? fill;
    final GapState gapState;
    if (_checked) {
      fill = q.answers.isEmpty ? _given : q.answers.first;
      gapState = GapState.correct;
    } else if (_answer != null) {
      fill = _answer;
      gapState = GapState.chosen;
    } else {
      fill = null;
      gapState = GapState.empty;
    }

    final content = _checked ? _explanation(q) : null;

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
      Text(
        optionMode
            ? FillGapScreen.chooseInstruction
            : FillGapScreen.typeInstruction,
        style: type.caption,
      ),
      PromptCard.gap(sentence: q.prompt, fill: fill, gapState: gapState),
      if (optionMode)
        OptionGrid.forLabels(
          labels: q.options ?? const <String>[],
          builder: (option) => AnswerOption(
            label: option,
            state: _stateOf(option),
            onPressed: _checked ? null : () => _choose(option),
          ),
        )
      else
        AnswerField(
          // A new key per question, so the field's own state starts afresh.
          key: ValueKey('fill-gap-field-${q.id}'),
          controller: _controller,
          state: !_checked
              ? AnswerFieldState.editing
              : (_correct ? AnswerFieldState.correct : AnswerFieldState.wrong),
          onChanged: _onChanged,
          onSubmitted: (_) => _check(),
          semanticLabel: 'The missing word',
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
        title: GameType.fillGap.label,
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
      topBar: GameTopBar(title: GameType.fillGap.label, onBack: onBack),
      primaryButton: PrimaryButton(label: 'Back to games', onPressed: onBack),
      children: [Text('No questions for this game yet.', style: type.body)],
    );
  }
}

/// Stand-in for the end-of-session summary (B7), the same as B3's and B5's.
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
        title: GameType.fillGap.label,
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
