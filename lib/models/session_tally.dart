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
///
/// B17: the tally also keeps each question's game and the day it was
/// checked, so the summary can copy a plain-text list of results
/// ([resultsText]) for Andrew to paste into the ChatGPT companion, which
/// updates the Test Review sheet. The question `id` is the sheet's Item ID
/// (FB-0001, …), so each line maps back to a sheet row.
///
/// B18: when the app is run with `RESULTS_URL`, the tally also hands each
/// result to its [sync], which sends it straight to the Test Review sheet.
///
/// B22: a Repair question right only on the second try, after the hint, is
/// recorded as not passed (`right: false`) with `hinted: true`, so the item
/// comes back; Copy results writes it as "right with hint".
library;

import '../data/results_sync.dart';
import 'question.dart';

/// Right and answered counts for one phase.
typedef PhaseScore = ({int right, int answered});

/// One checked question, as kept by the tally.
typedef TallyEntry = ({
  String id,
  GameType game,
  QuestionPhase phase,
  bool right,
  bool hinted,
  DateTime checkedAt,
});

class SessionTally {
  /// [clock] gives the time a question is checked; tests pass a fixed one.
  SessionTally({DateTime Function()? clock, this.sync})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  /// Sends each result to the Test Review sheet (B18). Null when the app
  /// was run without `RESULTS_URL`, and in tests.
  final ResultsSync? sync;

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

  /// Latest result per question id. A map keeps the order in which each id
  /// was first checked, even when a later result replaces an earlier one.
  final Map<String, TallyEntry> _results = {};

  /// Records the result of a checked question. [hinted]: right only after
  /// the hint (B22); pass `right: false` with it, as it counts as not passed.
  void record(Question question, bool right, {bool hinted = false}) {
    final entry = (
      id: question.id,
      game: question.game,
      phase: question.phase,
      right: right && !hinted,
      hinted: hinted,
      checkedAt: _clock(),
    );
    _results[question.id] = entry;
    sync?.add(entry);
  }

  /// Every question checked this session, in the order first checked, each
  /// with its latest result.
  List<TallyEntry> get entries => List.unmodifiable(_results.values);

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

  /// Header of the copied results ("Spanish Games results 2026-11-01").
  static String resultsHeader(DateTime day) =>
      'Spanish Games results ${dateText(day)}';

  /// The plain-text list copied by "Copy results" (B17): a header line,
  /// then one line per question checked this session, in the order first
  /// checked:
  ///
  /// ```
  /// Spanish Games results 2026-11-01
  /// FB-0001, choose_correction, right, 2026-11-01
  /// FB-0007, fill_gap, wrong, 2026-11-01
  /// ```
  ///
  /// Fields are the question's `id`, its `game` value as in
  /// `questions.json`, "right", "wrong" or "right with hint" (B22: right on
  /// the second try, after the hint, which counts as not passed), and the
  /// day it was checked
  /// (local time, YYYY-MM-DD). [now] is the day in the header (default: the
  /// tally's clock).
  String resultsText({DateTime? now}) {
    final lines = <String>[resultsHeader(now ?? _clock())];
    for (final e in _results.values) {
      lines.add(
        '${e.id}, ${e.game.jsonValue}, ${resultWord(e)}, '
        '${dateText(e.checkedAt)}',
      );
    }
    return lines.join('\n');
  }

  /// "right", "wrong" or "right with hint" for the copied results.
  static String resultWord(TallyEntry e) =>
      e.hinted ? 'right with hint' : (e.right ? 'right' : 'wrong');

  /// YYYY-MM-DD in local time.
  static String dateText(DateTime t) {
    final local = t.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }
}
