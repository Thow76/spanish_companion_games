/// Questions per round (B32): oldest first, first 5 or 10, fewer = all.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/models/round_size.dart';

Question _q(String id, {String source = '', String added = ''}) => Question(
  id: id,
  game: GameType.fillGap,
  category: 'Prepositions',
  type: QuestionType.grammar,
  prompt: 'Depende ___ tiempo.',
  answers: const ['del'],
  source: source,
  added: added,
);

List<String> _ids(List<Question> qs) => [for (final q in qs) q.id];

void main() {
  test('default is 5; labels', () {
    expect(RoundSize.standard, RoundSize.five);
    expect(RoundSize.five.count, 5);
    expect(RoundSize.ten.count, 10);
    expect(RoundSize.ten.label, '10');
  });

  test('date from the end of source, else added, else none', () {
    expect(
      questionDate(_q('a', source: 'Work and plans, 2026-10-14')),
      DateTime.utc(2026, 10, 14),
    );
    expect(
      questionDate(_q('b', source: 'Work and plans', added: '2026-10-17')),
      DateTime.utc(2026, 10, 17),
    );
    expect(questionDate(_q('c', source: 'Chat, 2026-02-30')), isNull);
    expect(questionDate(_q('d')), isNull);
  });

  test('oldest first; same date keeps file order; undated last', () {
    final qs = [
      _q('undated'),
      _q('new', source: 'Chat, 2026-11-12'),
      _q('old1', source: 'Chat, 2026-10-14'),
      _q('added', added: '2026-10-15'),
      _q('old2', source: 'Other, 2026-10-14'),
    ];
    expect(_ids(sortOldestFirst(qs)), [
      'old1',
      'old2',
      'added',
      'new',
      'undated',
    ]);
  });

  test('plays the first 5 or 10, oldest first', () {
    final qs = [
      for (var i = 12; i >= 1; i--)
        _q('q$i', source: 'Chat, 2026-10-${i.toString().padLeft(2, '0')}'),
    ];
    expect(_ids(pickRound(qs, RoundSize.five)), ['q1', 'q2', 'q3', 'q4', 'q5']);
    expect(pickRound(qs, RoundSize.ten).length, 10);
    expect(pickRound(qs, RoundSize.ten).last.id, 'q10');
  });

  test('fewer than the round size plays them all', () {
    final qs = [_q('a'), _q('b'), _q('c')];
    expect(_ids(pickRound(qs, RoundSize.five)), ['a', 'b', 'c']);
    expect(pickRound(const [], RoundSize.ten), isEmpty);
  });
}
