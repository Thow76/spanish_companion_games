/// Matching (phase 2, B6): short pairs Andrew has already met, e.g. a verb
/// and its preposition, in two columns. He taps one tile on each side to
/// pair them: a right pair turns mint with a tick and stays; a wrong
/// pairing flashes coral with a cross and both tiles go back. Once every
/// pair is matched the question is done: the result (right only if no
/// wrong pairing was tried), the explanation and "Next question"; a score
/// for the session.
///
/// Same frame as Choose a correction (B3) and Sentence ordering (B4):
/// GameTopBar, ChipRow/CategoryChip, the question's `prompt` as the
/// instruction (spec section 8), the tiles where the options would be,
/// ExplanationCard, PrimaryButton, the result toast (phones) and the
/// Session and Feedback panels (laptop). UI spec sections 5, 6, 8 and 10.
///
/// The tiles use [AnswerOption] (spec section 6: "matching tiles as answer
/// options in two columns"): `resting`, `selected` while waiting for its
/// partner, `correct` once matched, `wrong` during the flash. There is no
/// prompt card: the prompt is a short instruction, shown as the caption.
/// There is no Check step either, because each pairing is checked as it
/// is made; the primary action reads "Next question" (muted) until every
/// pair is matched.
///
/// The left column keeps the file's order; the right column is shuffled so
/// it does not start lined up. Pairs are checked with [isMatchingPair]
/// (trim, ignore case and final punctuation, accents must match), so two
/// tiles with the same text are interchangeable. The session ends
/// with the summary ([SessionSummaryView], B7).
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/answer_check.dart';
import '../models/question.dart';
import '../models/session_tally.dart';
import '../theme/app_layout.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../theme/form_factor.dart';
import '../widgets/widgets.dart';
import 'session_summary_view.dart';

/// Plays a session of Matching questions, in the order given.
///
/// Questions from other games, and match questions with fewer than two
/// pairs, are skipped. [random] shuffles the right column; tests pass a
/// seeded one so the order is the same every run.
class MatchScreen extends StatefulWidget {
  const MatchScreen({
    super.key,
    required this.questions,
    this.random,
    this.session,
  });

  final List<Question> questions;

  /// The app session's tally (B7), shared by every game and kept by the
  /// home screen. Each checked question is recorded in it. Null (tests)
  /// means the summary counts this round only.
  final SessionTally? session;
  final Random? random;

  /// How long a wrong pairing shows coral before both tiles go back.
  static const Duration wrongFlash = Duration(milliseconds: 700);

  /// [rights] shuffled with [random] so that, where it can be avoided, no
  /// tile starts level with its own partner's row (compared by text, so
  /// repeated words count as the same).
  static List<String> shuffle(List<String> rights, Random random) {
    final out = List<String>.of(rights);
    if (out.toSet().length < 2) return out;
    var best = List<String>.of(out);
    var bestLevel = rights.length + 1;
    for (var attempt = 0; attempt < 30; attempt++) {
      out.shuffle(random);
      var level = 0;
      for (var i = 0; i < out.length; i++) {
        if (out[i] == rights[i]) level++;
      }
      if (level < bestLevel) {
        best = List<String>.of(out);
        bestLevel = level;
      }
      if (level == 0) break;
    }
    return best;
  }

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  late final List<Question> _questions;
  late final Random _random;

  /// Index of the question on screen.
  int _index = 0;

  /// The tiles of the current question. Tiles are keyed by position, so
  /// repeated words stay separate.
  List<String> _lefts = const [];
  List<String> _rights = const [];

  /// The tile waiting for a partner on each side, if any.
  int? _pickedLeft;
  int? _pickedRight;

  /// Tiles already matched.
  final Set<int> _matchedLeft = {};
  final Set<int> _matchedRight = {};

  /// For each matched left tile, the right tile it was matched with. Used
  /// only for display: once every pair is matched, each right tile moves
  /// into its partner's row, so the finished question reads pair by pair
  /// (U8).
  final Map<int, int> _partnerOfLeft = {};

  /// The pair flashing coral after a wrong pairing, if any.
  int? _wrongLeft;
  int? _wrongRight;
  Timer? _flashTimer;

  /// Wrong pairings tried on this question, in order, without repeats, for
  /// the "You wrote" line.
  final List<MatchPair> _wrongTries = [];

  /// Whether every pair of the current question is matched.
  bool _done = false;

  /// One entry per question: null until done, then right or wrong.
  late List<bool?> _results;

  /// Whether the last question is done and "See results" pressed.
  bool _finished = false;

  /// Toast control, as in B3.
  bool? _toastResult;
  int _toastId = 0;

  /// "Next question" gets keyboard focus once the question is done (spec
  /// section 10).
  final FocusNode _nextButtonFocus = FocusNode(debugLabel: 'Next question');
  final FocusNode _topBarActionFocus = FocusNode(
    debugLabel: 'Top bar action',
  );

  @override
  void initState() {
    super.initState();
    _random = widget.random ?? Random();
    _questions = widget.questions
        .where((q) => q.game == GameType.match && q.pairs.length >= 2)
        .toList();
    _results = List<bool?>.filled(_questions.length, null);
    if (_questions.isNotEmpty) _resetQuestion();
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _nextButtonFocus.dispose();
    _topBarActionFocus.dispose();
    super.dispose();
  }

  Question get _question => _questions[_index];
  int get _total => _questions.length;
  bool get _isLast => _index == _total - 1;
  bool get _correct => _wrongTries.isEmpty;

  /// Ends a wrong flash early (the next tap does not wait for it).
  void _clearFlash() {
    _flashTimer?.cancel();
    _flashTimer = null;
    _wrongLeft = null;
    _wrongRight = null;
  }

  void _tapLeft(int i) {
    if (_done || _matchedLeft.contains(i)) return;
    setState(() {
      _clearFlash();
      _pickedLeft = _pickedLeft == i ? null : i;
      _tryPair();
    });
  }

  void _tapRight(int i) {
    if (_done || _matchedRight.contains(i)) return;
    setState(() {
      _clearFlash();
      _pickedRight = _pickedRight == i ? null : i;
      _tryPair();
    });
  }

  /// Called inside setState once a tile is picked on each side.
  void _tryPair() {
    final l = _pickedLeft;
    final r = _pickedRight;
    if (l == null || r == null) return;
    _pickedLeft = null;
    _pickedRight = null;
    if (isMatchingPair(_question, _lefts[l], _rights[r])) {
      _matchedLeft.add(l);
      _matchedRight.add(r);
      _partnerOfLeft[l] = r;
      if (_matchedLeft.length == _lefts.length) _finishQuestion();
      return;
    }
    final tried = MatchPair(_lefts[l], _rights[r]);
    if (!_wrongTries.contains(tried)) _wrongTries.add(tried);
    _wrongLeft = l;
    _wrongRight = r;
    _flashTimer = Timer(MatchScreen.wrongFlash, () {
      if (!mounted) return;
      setState(_clearFlash);
    });
  }

  /// Called inside setState when the last pair is matched.
  void _finishQuestion() {
    _done = true;
    _results[_index] = _correct;
    widget.session?.record(_question, _correct);
    _toastResult = _correct;
    _toastId++;
    // Portrait waits for the toast to go (see [_onToastHidden]); landscape
    // and laptop move focus straight away, after this frame is built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final f = FormFactor.of(context);
      if (f == FormFactor.phoneLandscape) {
        _topBarActionFocus.requestFocus();
      } else if (f == FormFactor.laptop) {
        _nextButtonFocus.requestFocus();
      }
    });
  }

  void _onToastHidden() {
    if (!mounted || !_done) return;
    if (FormFactor.of(context) == FormFactor.phone) {
      _nextButtonFocus.requestFocus();
    }
  }

  /// Fresh state for the question at [_index], with the right column
  /// shuffled.
  void _resetQuestion() {
    final q = _question;
    _lefts = [for (final p in q.pairs) p.left];
    _rights = MatchScreen.shuffle([for (final p in q.pairs) p.right], _random);
    _pickedLeft = null;
    _pickedRight = null;
    _matchedLeft.clear();
    _matchedRight.clear();
    _partnerOfLeft.clear();
    _clearFlash();
    _wrongTries.clear();
    _done = false;
  }

  void _next() {
    if (!_done) return;
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

  AnswerState _leftState(int i) {
    if (_matchedLeft.contains(i)) return AnswerState.correct;
    if (_wrongLeft == i) return AnswerState.wrong;
    if (_pickedLeft == i) return AnswerState.selected;
    return AnswerState.resting;
  }

  AnswerState _rightState(int i) {
    if (_matchedRight.contains(i)) return AnswerState.correct;
    if (_wrongRight == i) return AnswerState.wrong;
    if (_pickedRight == i) return AnswerState.selected;
    return AnswerState.resting;
  }

  /// The explanation once the question is done. The right-hand words are
  /// the answers, so they are the mint chips where the rule lists them.
  /// After a wrong pairing, "You wrote" lists each wrong pair tried, the
  /// wrong partner struck through: "pensar ~~de~~ · soñar ~~en~~".
  ExplanationContent _explanation(Question q) {
    final base = ExplanationContent.build(
      explanation: q.explanation,
      rule: q.rule,
      meaning: q.meaning,
      answers: [for (final p in q.pairs) p.right],
      allAnswers: true,
    );
    if (_correct) return base;
    final wrote = <WrotePart>[];
    for (final t in _wrongTries) {
      if (wrote.isNotEmpty) wrote.add((text: '·', wrong: false));
      wrote.add((text: t.left, wrong: false));
      wrote.add((text: t.right, wrong: true));
    }
    return ExplanationContent(
      rule: base.rule,
      meaning: base.meaning,
      plainText: base.plainText,
      youWrote: wrote,
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

  /// Which right tile sits in each row: the shuffled order while playing;
  /// once every pair is matched, each left tile's partner in its row.
  List<int> get _rightRows {
    final rows = [for (var i = 0; i < _rights.length; i++) i];
    if (!_done || _partnerOfLeft.length != _lefts.length) return rows;
    return [for (var i = 0; i < _lefts.length; i++) _partnerOfLeft[i]!];
  }

  /// The two columns, one row per pair; the two tiles in a row share a
  /// height, so a tile that wraps does not knock the columns out of line.
  /// Tiles keep their key when they change rows, keyed by the tile, not
  /// the row.
  Widget _tiles(Question q) {
    final rightRows = _rightRows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _lefts.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.s8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: AnswerOption(
                    key: ValueKey('match-left-${q.id}-$i'),
                    label: _lefts[i],
                    state: _leftState(i),
                    onPressed: _done || _matchedLeft.contains(i)
                        ? null
                        : () => _tapLeft(i),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(child: _rightTile(q, rightRows[i])),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _rightTile(Question q, int r) => AnswerOption(
    key: ValueKey('match-right-${q.id}-$r'),
    label: _rights[r],
    state: _rightState(r),
    onPressed: _done || _matchedRight.contains(r) ? null : () => _tapRight(r),
  );

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return _EmptyView(onBack: _goHome);
    }
    if (_finished) {
      return SessionSummaryView(
        game: GameType.match,
        questions: _questions,
        results: _results,
        session: widget.session,
        onPlayAgain: _playAgain,
        onBack: _goHome,
      );
    }

    final laptop = FormFactor.of(context) == FormFactor.laptop;
    final type = AppTypography.of(context);
    final q = _question;
    final content = _done ? _explanation(q) : null;

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
      Text(q.prompt, style: type.caption),
      _tiles(q),
    ];

    final VoidCallback? onAction = _done ? _next : null;

    return GameFrame(
      topBar: GameTopBar(
        title: GameType.match.label,
        onBack: _goHome,
        current: _index + 1,
        total: _total,
        actionLabel: _isLast ? 'See results' : 'Next question',
        onAction: onAction,
        actionFocusNode: _topBarActionFocus,
      ),
      explanation: content == null ? null : ExplanationCard(content: content),
      primaryButton: PrimaryButton.next(
        onPressed: onAction,
        last: _isLast,
        focusNode: _nextButtonFocus,
      ),
      sidePanel: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SessionPanel(
            marks: _marks,
            showPlaceholder: !_done,
            placeholder: SessionPanel.matchingPlaceholderText,
          ),
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
      topBar: GameTopBar(title: GameType.match.label, onBack: onBack),
      primaryButton: PrimaryButton(label: 'Back to games', onPressed: onBack),
      children: [Text('No questions for this game yet.', style: type.body)],
    );
  }
}
