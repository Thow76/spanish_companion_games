/// Sentence ordering (phase 2, B4): the words of a sentence Andrew has
/// already met, shuffled into chips. He taps them into order, checks, and
/// sees the right sentence, the explanation and "Next question"; a score
/// for the session.
///
/// Same frame as Choose a correction (B3) and Fill the gap (B14):
/// GameTopBar, ChipRow/CategoryChip, a PromptCard (plain form) showing the
/// sentence as it is built, the word chips where the options would be,
/// ExplanationCard, PrimaryButton, the result toast (phones) and the
/// Session and Feedback panels (laptop). UI spec sections 5, 6, 8 and 10.
///
/// The word chips use [AnswerOption] (there is no shared word-chip widget
/// yet): a word still to place is `resting`, a placed word `selected`.
/// Tapping a word adds it to the end of the sentence; tapping a placed
/// word takes it out again. Check is on once every word is placed.
///
/// The words are the question's `prompt` split on spaces, punctuation kept
/// on its word, then shuffled so they never start in the right order.
/// Checking uses [isAcceptedAnswer] against `answers` (trim, ignore case
/// and final punctuation, accents must match), so alternatives listed in
/// `answers` are accepted. The end-of-session summary is B7's; until then
/// the screen ends with the same short stand-in as B3, B5 and B14.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../models/answer_check.dart';
import '../models/question.dart';
import '../theme/app_layout.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import '../widgets/widgets.dart';

/// Plays a session of Sentence ordering questions, in the order given.
///
/// Questions from other games are skipped. [random] shuffles the words;
/// tests pass a seeded one so the order is the same every run.
class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key, required this.questions, this.random});

  final List<Question> questions;
  final Random? random;

  /// Instruction above the prompt card (spec section 8).
  static const String instruction = 'Put the words in order';

  /// The words of [question] to put in order: its `prompt` split on white
  /// space, punctuation kept on its word.
  static List<String> wordsOf(Question question) =>
      SentenceText.words(question.prompt);

  /// The accepted sentences for [question]: its `answers`, or the prompt
  /// itself if `answers` is empty.
  static List<String> acceptedOf(Question question) =>
      question.answers.isEmpty ? [question.prompt] : question.answers;

  /// [words] shuffled with [random]. If the shuffle comes out already
  /// right (the sentence or one of the accepted answers), it tries again,
  /// a few times; a sentence whose words can only go one way (one word, or
  /// all the same) is left as it is.
  static List<String> shuffle(
    List<String> words,
    List<String> accepted,
    Random random,
  ) {
    final out = List<String>.of(words);
    if (out.toSet().length < 2) return out;
    for (var attempt = 0; attempt < 20; attempt++) {
      out.shuffle(random);
      if (!isAcceptedAnswer(out.join(' '), accepted) &&
          out.join(' ') != words.join(' ')) {
        return out;
      }
    }
    return out;
  }

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  late final List<Question> _questions;
  late final Random _random;

  /// Index of the question on screen.
  int _index = 0;

  /// The current question's words, shuffled. Chips are keyed by position
  /// in this list, so repeated words ("de ... de") stay separate.
  List<String> _words = const [];

  /// Positions in [_words] of the placed words, in sentence order.
  final List<int> _placed = [];

  /// Whether the current question has been checked.
  bool _checked = false;

  /// Whether the current question was answered right (set when checked).
  bool _correct = false;

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
    _random = widget.random ?? Random();
    _questions = widget.questions
        .where(
          (q) => q.game == GameType.order && OrderScreen.wordsOf(q).isNotEmpty,
        )
        .toList();
    _results = List<bool?>.filled(_questions.length, null);
    if (_questions.isNotEmpty) _resetQuestion();
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

  /// The sentence as built so far.
  String get _built => _placed.map((i) => _words[i]).join(' ');

  bool get _canCheck =>
      !_checked && _words.isNotEmpty && _placed.length == _words.length;

  void _tapWord(int position) {
    if (_checked) return;
    setState(() {
      if (_placed.contains(position)) {
        _placed.remove(position);
      } else {
        _placed.add(position);
      }
    });
  }

  void _check() {
    if (!_canCheck) return;
    final correct = isAcceptedAnswer(_built, OrderScreen.acceptedOf(_question));
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

  /// Fresh state for the question at [_index], with its words shuffled.
  void _resetQuestion() {
    final q = _question;
    _words = OrderScreen.shuffle(
      OrderScreen.wordsOf(q),
      OrderScreen.acceptedOf(q),
      _random,
    );
    _placed.clear();
    _checked = false;
    _correct = false;
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

  /// Before checking: placed words `selected`, the rest `resting`. After
  /// checking every word is `dimmed` and disabled; the result is on the
  /// prompt card, the explanation and the toast or feedback panel.
  AnswerState _stateOf(int position) {
    if (_checked) return AnswerState.dimmed;
    return _placed.contains(position)
        ? AnswerState.selected
        : AnswerState.resting;
  }

  /// The explanation after checking. For a wrong answer, "You wrote" shows
  /// the learner's sentence with the words out of place struck through,
  /// compared with the first accepted sentence.
  ExplanationContent _explanation(Question q) => ExplanationContent.build(
    explanation: q.explanation,
    rule: q.rule,
    meaning: q.meaning,
    answers: q.answers,
    typed: _correct ? null : _built,
    typedAgainst: _correct ? null : OrderScreen.acceptedOf(q).first,
  );

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
      Text(OrderScreen.instruction, style: type.caption),
      // The sentence as built; after a wrong check, "Corrected version"
      // with the first accepted sentence and the moved words in mint.
      PromptCard.plain(
        key: ValueKey('order-card-${q.id}'),
        sentence: _built,
        corrected: _checked && !_correct
            ? OrderScreen.acceptedOf(q).first
            : null,
      ),
      Wrap(
        spacing: AppSpacing.s8,
        runSpacing: AppSpacing.s8,
        children: [
          for (var i = 0; i < _words.length; i++)
            AnswerOption(
              key: ValueKey('order-word-${q.id}-$i'),
              label: _words[i],
              state: _stateOf(i),
              onPressed: _checked ? null : () => _tapWord(i),
            ),
        ],
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
        title: GameType.order.label,
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
      topBar: GameTopBar(title: GameType.order.label, onBack: onBack),
      primaryButton: PrimaryButton(label: 'Back to games', onPressed: onBack),
      children: [Text('No questions for this game yet.', style: type.body)],
    );
  }
}

/// Stand-in for the end-of-session summary (B7), the same as B3's, B5's
/// and B14's.
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
        title: GameType.order.label,
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
