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
}
