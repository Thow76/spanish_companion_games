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
/// session ends with the summary ([SessionSummaryView], B7).
///
/// B22 (Flow v2, stage 1): a focus line above the field names the language
/// point (the question's `focus`, else its category), never the answer. A
/// wrong first Check does not end the question: it shows the "Not quite"
/// toast and a hint under the field (the question's `hint`, else "Look
/// again at the marked words: `category`"), keeps the field editable and
/// allows a second try, which must differ from the first. A wrong second
/// try ends the question as before (corrected version, explanation, "You
/// wrote"). Right on the second try shows "Right with a hint" and is
/// recorded as not passed (`hinted`), so the item comes back.
///
/// Look (U18, proposed for the spec): the focus line is a [FocusLine]
/// grouped with the field as its label; the hint is a [HintCard]; "Right
/// with a hint" is a [HintedResultNote] on phones and the FeedbackPanel's
/// heading on laptop, where the session panel marks the question with a
/// lightbulb rather than a cross.
library;

import 'package:flutter/material.dart';

import '../models/answer_check.dart';
import '../models/question.dart';
import '../models/round_result.dart';
import '../models/session_tally.dart';
import '../theme/app_layout.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import '../widgets/widgets.dart';
import 'session_summary_view.dart';

/// Plays a session of Repair the sentence questions, in the order given.
///
/// Questions from other games, and repair questions with nothing marked,
/// are skipped (the parser already rejects the latter).
class RepairScreen extends StatefulWidget {
  const RepairScreen({
    super.key,
    required this.questions,
    this.session,
    this.onFinished,
    this.lastInSet = true,
  });

  final List<Question> questions;

  /// The app session's tally (B7), shared by every game and kept by the
  /// home screen. Each checked question is recorded in it. Null (tests)
  /// means the summary counts this round only.
  final SessionTally? session;

  /// B25: set by the set player. After the last question the screen hands
  /// its round back through this instead of showing its own summary. Null
  /// (a game opened on its own, tests): the screen ends with its summary.
  final RoundFinished? onFinished;

  /// B25, with [onFinished]: whether this round is the set's last, so its
  /// last question reads "See results"; otherwise "Next question".
  final bool lastInSet;

  /// Instruction above the prompt card (spec section 8).
  static const String instruction = 'Correct the marked words';

  /// Shown after a right second try, under the field (B22).
  static const String rightWithHintText = SessionSummaryView.rightWithHintText;

  /// The line under it.
  static const String rightWithHintCaption =
      'It counts as not passed yet, so it will come back.';

  /// The focus line above the field: the question's `focus`, else its
  /// category (B22).
  static String focusText(Question q) {
    final focus = q.focus?.trim();
    return focus == null || focus.isEmpty ? q.category : focus;
  }

  /// The hint after a wrong first try: the question's `hint`, else a
  /// pointer back to the marked words with the category (B22).
  static String hintText(Question q) {
    final hint = q.hint?.trim();
    return hint == null || hint.isEmpty
        ? 'Look again at the marked words: ${q.category}'
        : hint;
  }

  /// [text] split into plain and emphasised runs: words between single
  /// asterisks (`*espero que*`, as the plan's examples write them) are
  /// emphasised and the asterisks are not shown. A stray asterisk is shown
  /// as written.
  static List<({String text, bool emphasis})> emphasisRuns(String text) {
    final s = text.replaceAll('**', '*');
    final runs = <({String text, bool emphasis})>[];
    var i = 0;
    for (final m in RegExp(r'\*([^*]+)\*').allMatches(s)) {
      if (m.start > i) {
        runs.add((text: s.substring(i, m.start), emphasis: false));
      }
      runs.add((text: m.group(1)!, emphasis: true));
      i = m.end;
    }
    if (i < s.length) runs.add((text: s.substring(i), emphasis: false));
    return runs;
  }

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

  /// Whether the current question's first try was wrong, so the hint is
  /// showing and this is the second try (B22).
  bool _hintShown = false;

  /// The first, wrong try; the second must differ from it.
  String _firstTry = '';

  /// Whether the current question was right on the second try.
  bool _hinted = false;

  /// One entry per question: null until checked, then passed or not. A
  /// question right with a hint counts as not passed (false).
  late List<bool?> _results;

  /// One entry per question: right on the second try, after the hint.
  late List<bool> _hintedResults;

  /// Whether the last question has been checked and "See results" pressed.
  bool _finished = false;

  /// Toast control, as in B3.
  bool? _toastResult;
  int _toastId = 0;

  /// "Next question" gets keyboard focus after checking (spec section 10).
  final FocusNode _nextButtonFocus = FocusNode(debugLabel: 'Next question');
  final FocusNode _topBarActionFocus = FocusNode(debugLabel: 'Top bar action');

  /// The field, focused again after a wrong first try (not on phones,
  /// where it would bring the keyboard up over the hint).
  final FocusNode _fieldFocus = FocusNode(debugLabel: 'Repair field');

  @override
  void initState() {
    super.initState();
    _questions = widget.questions
        .where((q) => q.game == GameType.repair && q.hasMarks)
        .toList();
    _results = List<bool?>.filled(_questions.length, null);
    _hintedResults = List<bool>.filled(_questions.length, false);
    _controller = TextEditingController(
      text: _questions.isEmpty ? '' : _questions.first.promptText,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _nextButtonFocus.dispose();
    _topBarActionFocus.dispose();
    _fieldFocus.dispose();
    super.dispose();
  }

  Question get _question => _questions[_index];
  int get _total => _questions.length;
  bool get _isLast => _index == _total - 1;

  /// The last question ends with "See results", unless the set player
  /// (B25) has more rounds to come.
  bool get _seeResults =>
      _isLast && (widget.onFinished == null || widget.lastInSet);

  /// Check is enabled once the field differs from the prefilled sentence
  /// (spec section 6) and, on the second try, from the first try (B22).
  bool get _canCheck =>
      !_checked &&
      AnswerField.isChanged(_controller.text, _question.promptText) &&
      normaliseAnswer(_controller.text).isNotEmpty &&
      !(_hintShown &&
          normaliseAnswer(_controller.text) == normaliseAnswer(_firstTry));

  /// The field's look: after a wrong first try it is coral with a cross
  /// (still editable) until the text is changed from that try, mirroring
  /// the mint border and tick of a right answer (U18 fix, Andrew
  /// 2026-11-12).
  AnswerFieldState get _fieldState {
    if (_checked) {
      return _correct ? AnswerFieldState.correct : AnswerFieldState.wrong;
    }
    if (_hintShown &&
        normaliseAnswer(_controller.text) == normaliseAnswer(_firstTry)) {
      return AnswerFieldState.tryAgain;
    }
    return AnswerFieldState.editing;
  }

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
    final f = FormFactor.of(context);

    // A wrong first try: the hint and a second try (B22). Nothing is
    // recorded yet.
    if (!correct && !_hintShown) {
      setState(() {
        _hintShown = true;
        _firstTry = typed;
        _toastResult = false;
        _toastId++;
      });
      if (f != FormFactor.phone) _fieldFocus.requestFocus();
      return;
    }

    final hinted = correct && _hintShown;
    final passed = correct && !_hintShown;
    setState(() {
      _checked = true;
      _correct = correct;
      _hinted = hinted;
      _typed = typed;
      _results[_index] = passed;
      _hintedResults[_index] = hinted;
      widget.session?.record(_question, passed, hinted: hinted);
      _toastResult = correct;
      _toastId++;
    });
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
    if (_isLast && widget.onFinished != null) {
      widget.onFinished!(
        RoundResult(
          questions: _questions,
          results: List.of(_results),
          hinted: List.of(_hintedResults),
        ),
      );
      return;
    }
    setState(() {
      if (_isLast) {
        _finished = true;
      } else {
        _index++;
        _checked = false;
        _correct = false;
        _typed = '';
        _clearHint();
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
      _clearHint();
      _results = List<bool?>.filled(_questions.length, null);
      _hintedResults = List<bool>.filled(_questions.length, false);
      _finished = false;
      _toastResult = null;
      _resetField();
    });
  }

  void _clearHint() {
    _hintShown = false;
    _firstTry = '';
    _hinted = false;
  }

  void _goHome() => Navigator.of(context).maybePop();

  List<QuestionMark> get _marks => [
    for (var i = 0; i < _total; i++)
      switch (_results[i]) {
        // Right with a hint (U18): its own mark, not a cross.
        false when _hintedResults[i] => QuestionMark.hinted,
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
      return SessionSummaryView(
        game: GameType.repair,
        questions: _questions,
        results: _results,
        hinted: _hintedResults,
        session: widget.session,
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
      // The focus line is the field's label (U18): grouped with it, 8 apart.
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          FocusLine(
            text: _EmphasisText(
              RepairScreen.focusText(q),
              style: FocusLine.textStyle(context),
              semanticsPrefix: 'Focus: ',
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          AnswerField(
            // A new key per question, so the field's own state starts
            // afresh.
            key: ValueKey('repair-field-${q.id}'),
            controller: _controller,
            state: _fieldState,
            caption: AnswerField.repairCaption,
            onChanged: _onChanged,
            onSubmitted: (_) => _check(),
            focusNode: _fieldFocus,
            semanticLabel: 'Your corrected sentence',
          ),
        ],
      ),
      if (_hintShown && !_checked)
        HintCard(
          text: _EmphasisText(
            RepairScreen.hintText(q),
            style: HintCard.textStyle(context),
            semanticsPrefix: 'Hint: ',
          ),
        )
      // On laptop "Right with a hint" is the feedback panel's heading.
      else if (_checked && _hinted && !laptop)
        const HintedResultNote(
          heading: RepairScreen.rightWithHintText,
          caption: RepairScreen.rightWithHintCaption,
        ),
    ];

    final String actionLabel;
    final VoidCallback? onAction;
    if (_checked) {
      actionLabel = _seeResults ? 'See results' : 'Next question';
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
              last: _seeResults,
              focusNode: _nextButtonFocus,
            )
          : PrimaryButton.check(onPressed: onAction),
      sidePanel: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SessionPanel(marks: _marks, showPlaceholder: !_checked),
          if (content != null) ...[
            const SizedBox(height: AppLayout.laptopCardGap),
            FeedbackPanel(
              correct: _correct,
              content: content,
              heading: _hinted ? RepairScreen.rightWithHintText : null,
              note: _hinted ? RepairScreen.rightWithHintCaption : null,
            ),
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

/// A line of text with `*…*` runs in italics ([RepairScreen.emphasisRuns]);
/// read by screen readers as one phrase, with [semanticsPrefix] in front.
class _EmphasisText extends StatelessWidget {
  const _EmphasisText(this.text, {required this.style, this.semanticsPrefix});

  final String text;
  final TextStyle style;
  final String? semanticsPrefix;

  @override
  Widget build(BuildContext context) {
    final runs = RepairScreen.emphasisRuns(text);
    final plain = runs.map((r) => r.text).join();
    return Semantics(
      label: '${semanticsPrefix ?? ''}$plain',
      child: ExcludeSemantics(
        child: Text.rich(
          TextSpan(
            style: style,
            children: [
              for (final r in runs)
                TextSpan(
                  text: r.text,
                  style: r.emphasis
                      ? const TextStyle(fontStyle: FontStyle.italic)
                      : null,
                ),
            ],
          ),
        ),
      ),
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
