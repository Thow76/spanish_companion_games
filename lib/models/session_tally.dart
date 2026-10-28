/// The score for the whole app session (B7): every question checked since
/// the app was opened, across all the games played, split by phase ("New
/// corrections" and "Recall").
///
/// The home screen holds one [SessionTally] and passes it to each game
/// screen, which calls [record] when a question is checked. The
/// end-of-session summary reads it. Nothing is kept between app sessions
/// (v1).
///
/// Each question counts once: if it is played again ("Play again"), the
/// latest result replaces the earlier one, so the tally says where Andrew
/// stands now rather than how many attempts he has made.
library;

import 'question.dart';

/// Right and answered counts for one phase.
typedef PhaseScore = ({int right, int answered});

class SessionTally {
  SessionTally();

  /// A tally of one round only, for a game screen opened without a shared
  /// tally (tests, or a screen opened on its own). [results] holds one
  /// entry per question in [questions]: null if not checked.
  factory SessionTally.fromRound(
    List<Question> questions,
    List<bool?> results,
  ) {
    final tally = SessionTally();
    for (var i = 0; i < questions.length && i < results.length; i++) {
      final r = results[i];
      if (r != null) tally.record(questions[i], r);
    }
    return tally;
  }

  /// Latest result per question id, with the question's phase.
  final Map<String, ({QuestionPhase phase, bool right})> _results = {};

  /// Records the result of a checked question.
  void record(Question question, bool right) {
    _results[question.id] = (phase: question.phase, right: right);
  }

  /// The score for one phase.
  PhaseScore scoreFor(QuestionPhase phase) {
    var right = 0;
    var answered = 0;
    for (final r in _results.values) {
      if (r.phase != phase) continue;
      answered++;
      if (r.right) right++;
    }
    return (right: right, answered: answered);
  }

  /// Every question answered this session, all phases.
  int get answered => _results.length;

  /// "2 of 3 right", or "None yet" when nothing in that phase has been
  /// answered.
  static String scoreText(PhaseScore score) => score.answered == 0
      ? 'None yet'
      : '${score.right} of ${score.answered} right';
}
