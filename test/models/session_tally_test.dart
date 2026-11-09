/// The session tally (B7): scores split by phase, each question counted
/// once with its latest result.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/models/session_tally.dart';

Question _q(String id, GameType game) => Question(
  id: id,
  game: game,
  category: 'Prepositions',
  type: QuestionType.grammar,
  prompt: game.phase == QuestionPhase.noticeAndCorrect
      ? 'Estoy pensando **de** cambiar de trabajo.'
      : 'Depende ___ tiempo que haga.',
  answers: const ['en'],
  options: game == GameType.chooseCorrection ? const ['en', 'a'] : null,
  explanation: 'pensar en + infinitive = to be thinking of doing something',
);

void main() {
  test('an empty tally reads "None yet" for both phases', () {
    final t = SessionTally();
    for (final phase in QuestionPhase.values) {
      expect(t.scoreFor(phase), (right: 0, answered: 0));
      expect(SessionTally.scoreText(t.scoreFor(phase)), 'None yet');
    }
    expect(t.answered, 0);
  });

  test('results are split by phase', () {
    final t = SessionTally()
      ..record(_q('a', GameType.chooseCorrection), true)
      ..record(_q('b', GameType.repair), false)
      ..record(_q('c', GameType.fillGap), true);
    expect(t.scoreFor(QuestionPhase.noticeAndCorrect), (right: 1, answered: 2));
    expect(t.scoreFor(QuestionPhase.recall), (right: 1, answered: 1));
    expect(
      SessionTally.scoreText(t.scoreFor(QuestionPhase.noticeAndCorrect)),
      '1 of 2 right',
    );
    expect(t.answered, 3);
  });

  test('playing a question again replaces its earlier result', () {
    final q = _q('a', GameType.chooseCorrection);
    final t = SessionTally()
      ..record(q, false)
      ..record(q, true);
    expect(t.scoreFor(QuestionPhase.noticeAndCorrect), (right: 1, answered: 1));
  });

  test('fromRound counts only the checked questions of one round', () {
    final qs = [
      _q('a', GameType.fillGap),
      _q('b', GameType.fillGap),
      _q('c', GameType.fillGap),
    ];
    final t = SessionTally.fromRound(qs, [true, false, null]);
    expect(t.scoreFor(QuestionPhase.recall), (right: 1, answered: 2));
    expect(t.scoreFor(QuestionPhase.noticeAndCorrect).answered, 0);
  });

  group('copied results (B17)', () {
    test('header, then one line per question in the order first checked', () {
      final day = DateTime(2026, 11, 1, 9, 30);
      final t = SessionTally(clock: () => day)
        ..record(_q('FB-0001', GameType.chooseCorrection), true)
        ..record(_q('FB-0007', GameType.fillGap), false)
        ..record(_q('FB-0003', GameType.repair), true);
      expect(
        t.resultsText(),
        'Spanish Games results 2026-11-01\n'
        'FB-0001, choose_correction, right, 2026-11-01\n'
        'FB-0007, fill_gap, wrong, 2026-11-01\n'
        'FB-0003, repair, right, 2026-11-01',
      );
    });

    test('a question played again keeps its place with the latest result '
        'and day', () {
      var now = DateTime(2026, 10, 31, 23, 50);
      final t = SessionTally(clock: () => now)
        ..record(_q('FB-0001', GameType.chooseCorrection), false)
        ..record(_q('FB-0002', GameType.chooseCorrection), true);
      now = DateTime(2026, 11, 1, 0, 5);
      t.record(_q('FB-0001', GameType.chooseCorrection), true);
      expect(t.resultsText().split('\n'), [
        'Spanish Games results 2026-11-01',
        'FB-0001, choose_correction, right, 2026-11-01',
        'FB-0002, choose_correction, right, 2026-10-31',
      ]);
      expect(t.entries.map((e) => e.id), ['FB-0001', 'FB-0002']);
    });

    test('right with a hint is copied as such and counts as not passed '
        '(B22)', () {
      final t = SessionTally(clock: () => DateTime(2026, 11, 9))
        ..record(_q('FB-0005', GameType.repair), false, hinted: true);
      expect(
        t.resultsText().split('\n').last,
        'FB-0005, repair, right with hint, 2026-11-09',
      );
      expect(t.scoreFor(QuestionPhase.noticeAndCorrect), (
        right: 0,
        answered: 1,
      ));
      expect(t.entries.single.hinted, isTrue);
    });

    test('an empty tally copies only the header', () {
      final t = SessionTally(clock: () => DateTime(2026, 1, 5));
      expect(t.resultsText(), 'Spanish Games results 2026-01-05');
    });

    test('dates are zero-padded', () {
      expect(SessionTally.dateText(DateTime(2026, 3, 7)), '2026-03-07');
    });
  });
}
