/// Plays a set (Flow v2, B25): opened from the set picker when a set is
/// tapped.
///
/// The set is played as a run of rounds, each in its own game screen:
/// - New corrections: the Choose a correction questions first, then the
///   Repair ones (each in set order).
/// - Recall: in set order; questions of the same game next to each other
///   share one round, so the game's "Question 1 of 2" counts that run.
///
/// Each game screen hands its round back after its last question
/// ([RoundFinished]) instead of showing its own summary; only the set's
/// last round ends with "See results". Then one end-of-set summary (the
/// existing [SessionSummaryView]) with every round's questions, titled with
/// the phase name, with "Play again" (the same set from the start) and
/// "Next set" (the next set in the picker's list, when there is one).
///
/// Every check is still recorded in the app session's tally as it happens
/// (results sending and Copy results unchanged). The back chevron on any
/// screen returns to the set picker.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../models/question.dart';
import '../models/question_sets.dart';
import '../models/round_result.dart';
import '../models/session_tally.dart';
import 'choose_correction_screen.dart';
import 'fill_gap_screen.dart';
import 'match_screen.dart';
import 'order_screen.dart';
import 'repair_screen.dart';
import 'session_summary_view.dart';
import 'spot_error_screen.dart';

class SetPlayerScreen extends StatefulWidget {
  const SetPlayerScreen({
    super.key,
    required this.phase,
    required this.sets,
    this.index = 0,
    this.session,
    this.random,
  });

  /// The phase being played; its name is the summary's title.
  final QuestionPhase phase;

  /// The set picker's list of sets when one was tapped, so "Next set" can
  /// move on.
  final List<QuestionSet> sets;

  /// The set to play first, in [sets].
  final int index;

  /// The app session's tally, kept by the home screen.
  final SessionTally? session;

  /// Shuffles Matching and Sentence ordering; tests pass a seeded one.
  final Random? random;

  /// The rounds [questions] are played in, for [phase]: New corrections
  /// puts Choose a correction before Repair (and any other game after,
  /// though phase 1 has no others); Recall keeps the set's order. Then
  /// questions of the same game next to each other make one round.
  static List<List<Question>> roundsFor(
    QuestionPhase phase,
    List<Question> questions,
  ) {
    final ordered = phase == QuestionPhase.noticeAndCorrect
        ? _byGameThenOrder(questions)
        : questions;
    final rounds = <List<Question>>[];
    for (final q in ordered) {
      if (rounds.isNotEmpty && rounds.last.first.game == q.game) {
        rounds.last.add(q);
      } else {
        rounds.add([q]);
      }
    }
    return rounds;
  }

  /// Choose a correction first, then Repair, then any other game in home
  /// order; set order kept within each game (a stable sort).
  static List<Question> _byGameThenOrder(List<Question> questions) {
    int rank(GameType game) => switch (game) {
      GameType.chooseCorrection => 0,
      GameType.repair => 1,
      _ => 2 + GameType.values.indexOf(game),
    };
    final indexed = [
      for (var i = 0; i < questions.length; i++) (i, questions[i]),
    ];
    indexed.sort((a, b) {
      final byGame = rank(a.$2.game).compareTo(rank(b.$2.game));
      return byGame != 0 ? byGame : a.$1.compareTo(b.$1);
    });
    return [for (final (_, q) in indexed) q];
  }

  @override
  State<SetPlayerScreen> createState() => _SetPlayerScreenState();
}

class _SetPlayerScreenState extends State<SetPlayerScreen> {
  /// The set being played, in [SetPlayerScreen.sets].
  late int _setIndex = widget.index;

  /// The set's rounds, and the one on screen.
  late List<List<Question>> _rounds;
  int _round = 0;

  /// Counts each start of a set (first play, "Play again", "Next set"), so
  /// every game screen starts fresh even when the same game comes again.
  int _play = 0;

  /// The finished rounds, joined in the order played.
  final List<Question> _questions = [];
  final List<bool?> _results = [];
  final List<bool> _hinted = [];

  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _startSet(widget.index);
  }

  void _startSet(int index) {
    _setIndex = index;
    _rounds = SetPlayerScreen.roundsFor(
      widget.phase,
      widget.sets[index].questions,
    );
    _round = 0;
    _play++;
    _questions.clear();
    _results.clear();
    _hinted.clear();
    // A set with nothing to play goes straight to its (empty) summary.
    _finished = _rounds.isEmpty;
  }

  bool get _hasNextSet => _setIndex + 1 < widget.sets.length;

  void _roundDone(RoundResult round) {
    setState(() {
      _questions.addAll(round.questions);
      _results.addAll(round.results);
      final hinted = round.hinted;
      for (var i = 0; i < round.questions.length; i++) {
        _hinted.add(hinted != null && i < hinted.length && hinted[i]);
      }
      if (_round + 1 < _rounds.length) {
        _round++;
      } else {
        _finished = true;
      }
    });
  }

  void _playAgain() => setState(() => _startSet(_setIndex));

  void _nextSet() {
    if (!_hasNextSet) return;
    setState(() => _startSet(_setIndex + 1));
  }

  void _back() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    if (_finished) {
      return SessionSummaryView(
        key: ValueKey('set-summary-$_play'),
        game: _questions.isEmpty
            ? GameType.forPhase(widget.phase).first
            : _questions.first.game,
        topBarTitle: widget.phase.label,
        questions: List.of(_questions),
        results: List.of(_results),
        hinted: List.of(_hinted),
        session: widget.session,
        onPlayAgain: _playAgain,
        onBack: _back,
        onNextSet: _hasNextSet ? _nextSet : null,
      );
    }

    final questions = _rounds[_round];
    final lastInSet = _round == _rounds.length - 1;
    final key = ValueKey('set-round-$_play-$_round');
    return switch (questions.first.game) {
      GameType.chooseCorrection => ChooseCorrectionScreen(
        key: key,
        questions: questions,
        session: widget.session,
        onFinished: _roundDone,
        lastInSet: lastInSet,
      ),
      GameType.repair => RepairScreen(
        key: key,
        questions: questions,
        session: widget.session,
        onFinished: _roundDone,
        lastInSet: lastInSet,
      ),
      GameType.fillGap => FillGapScreen(
        key: key,
        questions: questions,
        session: widget.session,
        onFinished: _roundDone,
        lastInSet: lastInSet,
      ),
      GameType.order => OrderScreen(
        key: key,
        questions: questions,
        random: widget.random,
        session: widget.session,
        onFinished: _roundDone,
        lastInSet: lastInSet,
      ),
      GameType.match => MatchScreen(
        key: key,
        questions: questions,
        random: widget.random,
        session: widget.session,
        onFinished: _roundDone,
        lastInSet: lastInSet,
      ),
      GameType.spotError => SpotErrorScreen(
        key: key,
        questions: questions,
        session: widget.session,
        onFinished: _roundDone,
        lastInSet: lastInSet,
      ),
    };
  }
}
