/// One game's part of a set (Flow v2, B25): what a game screen hands back
/// to the set player after its last question, instead of showing its own
/// summary.
///
/// The set player ([SetPlayerScreen]) plays a set as a run of rounds, one
/// game screen per round, and joins the rounds' results into one
/// end-of-set summary.
library;

import 'question.dart';

class RoundResult {
  const RoundResult({
    required this.questions,
    required this.results,
    this.hinted,
  });

  /// The questions the screen played, in order (any it skipped as not its
  /// game are left out).
  final List<Question> questions;

  /// One entry per question in [questions]: right, wrong, or null if it was
  /// never checked.
  final List<bool?> results;

  /// One entry per question in [questions]: right only after the hint
  /// (B22, Repair). Null for games without hints.
  final List<bool>? hinted;
}

/// Called by a game screen when its last question is done and the set
/// player gave it somewhere to hand back to.
typedef RoundFinished = void Function(RoundResult result);
