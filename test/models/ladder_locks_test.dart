/// Padlocks on the home screen (B30).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/ladder_locks.dart';
import 'package:spanish_companion_games/models/question.dart';

Question _q(
  String id,
  GameType game, {
  bool options = false,
  String? unlocksAfter,
}) => Question(
  id: id,
  game: game,
  category: 'test',
  type: QuestionType.grammar,
  prompt: game == GameType.fillGap ? 'Hola ___.' : 'Hola.',
  answers: const ['x'],
  options: options ? const ['x', 'y'] : null,
  unlocksAfter: unlocksAfter,
);

bool _none(String _) => false;

Map<GameType, CardState> _states(
  List<Question> qs, {
  bool Function(String) passed = _none,
  Set<String>? fileIds,
}) => cardStates(
  qs,
  fileIds: fileIds ?? {for (final q in qs) q.id},
  passed: passed,
);

void main() {
  group('isQuestionLocked', () {
    final s4 = _q('FB-1-s4', GameType.fillGap, unlocksAfter: 'FB-1-s3');

    test('no unlocks_after: open', () {
      expect(
        isQuestionLocked(
          _q('a', GameType.repair),
          fileIds: {'a'},
          passed: _none,
        ),
        isFalse,
      );
    });

    test('its question in the file and not yet passed: locked', () {
      expect(
        isQuestionLocked(s4, fileIds: {'FB-1-s3', 'FB-1-s4'}, passed: _none),
        isTrue,
      );
    });

    test('its question answered right this session: open', () {
      expect(
        isQuestionLocked(
          s4,
          fileIds: {'FB-1-s3', 'FB-1-s4'},
          passed: (id) => id == 'FB-1-s3',
        ),
        isFalse,
      );
    });

    test('reload rule: its question gone from the file, passed this session: '
        'open', () {
      expect(
        isQuestionLocked(
          s4,
          fileIds: {'FB-1-s4'},
          passed: (id) => id == 'FB-1-s3',
        ),
        isFalse,
      );
    });

    test('reload rule: its question gone from the file, not answered this '
        'session: open (the script has moved the item on)', () {
      expect(
        isQuestionLocked(s4, fileIds: {'FB-1-s4'}, passed: _none),
        isFalse,
      );
    });
  });

  group('cardStates', () {
    test('Andrew\'s groups and order', () {
      expect(HomeGroup.yourMistakes.games, [
        GameType.chooseCorrection,
        GameType.fillGap,
        GameType.repair,
        GameType.spotError,
      ]);
      expect(HomeGroup.consolidation.games, [GameType.order, GameType.match]);
      expect(HomeGroup.yourMistakes.title, 'Your mistakes');
      expect(HomeGroup.consolidation.title, 'Consolidation');
    });

    test('nothing at all: every card empty', () {
      final states = _states([]);
      for (final g in GameType.values) {
        expect(states[g]!.lock, CardLock.empty, reason: g.label);
      }
    });

    test('stage 1 only: later cards locked, Choose a correction open', () {
      final states = _states([_q('a', GameType.chooseCorrection)]);
      expect(states[GameType.chooseCorrection]!.lock, CardLock.open);
      expect(states[GameType.chooseCorrection]!.open.length, 1);
      for (final g in [
        GameType.fillGap,
        GameType.repair,
        GameType.spotError,
        GameType.order,
        GameType.match,
      ]) {
        expect(states[g]!.lock, CardLock.locked, reason: g.label);
        expect(states[g]!.locked, 0, reason: g.label);
      }
    });

    test('an empty card with nothing earlier says "No questions yet"', () {
      // Only Repair (stage 3): Choose a correction and Fill the gap come
      // before it, so they are empty, not locked.
      final states = _states([_q('a', GameType.repair)]);
      expect(states[GameType.chooseCorrection]!.lock, CardLock.empty);
      expect(states[GameType.fillGap]!.lock, CardLock.empty);
      expect(states[GameType.repair]!.lock, CardLock.open);
      expect(states[GameType.spotError]!.lock, CardLock.locked);
    });

    test('stage 4 in Fill the gap does not lock an empty Repair', () {
      final states = _states([_q('a', GameType.fillGap)]);
      expect(states[GameType.repair]!.lock, CardLock.empty);
      expect(states[GameType.spotError]!.lock, CardLock.locked);
    });

    test('Sentence ordering and Matching do not lock each other', () {
      final states = _states([_q('a', GameType.order)]);
      expect(states[GameType.order]!.lock, CardLock.open);
      expect(states[GameType.match]!.lock, CardLock.empty);
    });

    test('the drop-back pair: N−1 open, N locked, then unlocked', () {
      final qs = [
        _q('FB-1-s3', GameType.repair),
        _q('FB-1-s4', GameType.fillGap, unlocksAfter: 'FB-1-s3'),
      ];
      var states = _states(qs);
      expect(states[GameType.repair]!.lock, CardLock.open);
      expect(states[GameType.fillGap]!.lock, CardLock.locked);
      expect(states[GameType.fillGap]!.locked, 1);
      expect(states[GameType.fillGap]!.open, isEmpty);

      states = _states(qs, passed: (id) => id == 'FB-1-s3');
      expect(states[GameType.fillGap]!.lock, CardLock.open);
      expect(states[GameType.fillGap]!.open.map((q) => q.id), ['FB-1-s4']);
      expect(states[GameType.fillGap]!.locked, 0);
    });

    test('some open, some locked: part-locked with the open questions', () {
      final states = _states([
        _q('FB-1-s3', GameType.repair),
        _q('FB-2-s2', GameType.fillGap, options: true),
        _q('FB-1-s4', GameType.fillGap, unlocksAfter: 'FB-1-s3'),
      ]);
      final fill = states[GameType.fillGap]!;
      expect(fill.lock, CardLock.partLocked);
      expect(fill.open.map((q) => q.id), ['FB-2-s2']);
      expect(fill.locked, 1);
    });

    test(
      'after a reload without the passed question, its follower is open',
      () {
        final states = _states([
          _q('FB-1-s4', GameType.fillGap, unlocksAfter: 'FB-1-s3'),
        ], passed: (id) => id == 'FB-1-s3');
        expect(states[GameType.fillGap]!.lock, CardLock.open);
        expect(states[GameType.fillGap]!.open.length, 1);
      },
    );
  });
}
