/// Sets for the set picker (B24).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/models/question_sets.dart';

Question _q(String id, {String source = '', String added = ''}) => Question(
  id: id,
  game: GameType.fillGap,
  category: 'test',
  type: QuestionType.grammar,
  prompt: 'Hola ___.',
  answers: const ['x'],
  source: source,
  added: added,
);

List<String> _ids(QuestionSet s) => [for (final q in s.questions) q.id];

void main() {
  group('dates and names', () {
    test('date from the end of source, else added', () {
      expect(
        questionDate(_q('a', source: 'Work and plans, 2026-10-14')),
        DateTime.utc(2026, 10, 14),
      );
      expect(
        questionDate(_q('b', source: 'Work and plans', added: '2026-10-17')),
        DateTime.utc(2026, 10, 17),
      );
      expect(questionDate(_q('c')), isNull);
      expect(questionDate(_q('d', source: 'Chat, 2026-02-30')), isNull);
    });

    test('conversation name drops the date', () {
      expect(conversationName('Work and plans, 2026-10-14'), 'Work and plans');
      expect(conversationName('Family - 2026-10-15'), 'Family');
      expect(conversationName('Opinions'), 'Opinions');
      expect(conversationName('  '), '');
    });

    test('date ranges', () {
      final a = DateTime.utc(2026, 10, 14);
      expect(dateRangeText(a, a), '14 Oct');
      expect(dateRangeText(a, DateTime.utc(2026, 10, 16)), '14–16 Oct');
      expect(
        dateRangeText(DateTime.utc(2026, 10, 30), DateTime.utc(2026, 11, 2)),
        '30 Oct – 2 Nov',
      );
      expect(
        dateRangeText(DateTime.utc(2026, 12, 30), DateTime.utc(2027, 1, 2)),
        '30 Dec 2026 – 2 Jan 2027',
      );
    });
  });

  test('oldest first, undated last, ties keep file order', () {
    final qs = [
      _q('new', source: 'B, 2026-10-16'),
      _q('none'),
      _q('old1', source: 'A, 2026-10-14'),
      _q('mid', added: '2026-10-15'),
      _q('old2', source: 'C, 2026-10-14'),
    ];
    expect([for (final q in sortOldestFirst(qs)) q.id], [
      'old1',
      'old2',
      'mid',
      'new',
      'none',
    ]);
  });

  group('consecutive sets', () {
    final qs = [
      for (var i = 0; i < 12; i++)
        _q('q$i', source: 'Chat ${i ~/ 4}, 2026-10-${10 + i ~/ 4}'),
    ];

    test('sets of 5: 5, 5, 2', () {
      final sets = buildQuestionSets(qs, size: 5, byConversation: false);
      expect([for (final s in sets) s.length], [5, 5, 2]);
      expect(_ids(sets[0]), ['q0', 'q1', 'q2', 'q3', 'q4']);
      expect(sets[0].title, 'Chat 0 + 1 more');
      expect(sets[0].detail, '10–11 Oct');
      expect(sets[2].title, 'Chat 2');
      expect(sets[2].detail, '12 Oct');
      expect(sets.every((s) => !s.isSplit), isTrue);
    });

    test('sets of 10: 10, 2', () {
      final sets = buildQuestionSets(qs, size: 10, byConversation: false);
      expect([for (final s in sets) s.length], [10, 2]);
      expect(sets[0].title, 'Chat 0 + 2 more');
    });

    test('nothing gives no sets', () {
      expect(buildQuestionSets([], size: 5, byConversation: true), isEmpty);
    });
  });

  group('by conversation', () {
    final qs = [
      _q('w1', source: 'Work and plans, 2026-10-14'),
      _q('f1', source: 'Family, 2026-10-15'),
      for (var i = 2; i <= 7; i++)
        _q('w$i', source: 'Work and plans, 2026-10-14'),
      _q('x1'),
      _q('o1', source: 'Opinions, 2026-10-13'),
    ];

    test('one set per conversation, oldest first, split when larger', () {
      final sets = buildQuestionSets(qs, size: 5, byConversation: true);
      expect([for (final s in sets) s.title], [
        'Opinions',
        'Work and plans',
        'Work and plans',
        'Family',
        QuestionSet.noConversationLabel,
      ]);
      expect(_ids(sets[1]), ['w1', 'w2', 'w3', 'w4', 'w5']);
      expect(_ids(sets[2]), ['w6', 'w7']);
      expect(sets[1].detail, '14 Oct · 1 of 2');
      expect(sets[2].detail, '14 Oct · 2 of 2');
      expect(sets[3].detail, '15 Oct');
      expect(sets[4].detail, '');
    });

    test('size 10 keeps the conversation whole', () {
      final sets = buildQuestionSets(qs, size: 10, byConversation: true);
      expect(sets[1].length, 7);
      expect(sets[1].isSplit, isFalse);
      expect(sets[1].detail, '14 Oct');
    });

    test('same topic on two days is two conversations', () {
      final sets = buildQuestionSets(
        [_q('a', source: 'Work, 2026-10-14'), _q('b', source: 'Work, 2026-10-20')],
        size: 5,
        byConversation: true,
      );
      expect(sets.length, 2);
    });
  });
}
