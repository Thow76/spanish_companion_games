import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:spanish_companion_games/data/results_sync.dart';
import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/models/session_tally.dart';

const _config = ResultsConfig('https://script.google.com/macros/s/test/exec');

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

/// A fake web app: records each body and answers every id as saved, except
/// those in [unknown]; [fail] makes it answer 500.
class _FakeScript {
  final List<Map<String, dynamic>> bodies = [];
  Set<String> unknown = {};
  bool fail = false;

  MockClient get client => MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    bodies.add(body);
    expect(request.method, 'POST');
    expect(request.headers['Content-Type'], startsWith('text/plain'));
    if (fail) return http.Response('error', 500);
    final ids = [for (final r in body['results'] as List) r['id'] as String];
    return http.Response(
      jsonEncode({
        'ok': true,
        'saved': ids.where((id) => !unknown.contains(id)).toList(),
        'unknown': ids.where(unknown.contains).toList(),
      }),
      200,
    );
  });
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  final day = DateTime(2026, 11, 4, 10);

  test('without --dart-define nothing is configured', () {
    expect(const ResultsConfig.fromEnvironment().isConfigured, isFalse);
    expect(_config.isConfigured, isTrue);
  });

  test(
    'a checked question is sent with id, game, phase, result and date',
    () async {
      final script = _FakeScript();
      final sync = ResultsSync(_config, client: script.client);
      SessionTally(
        clock: () => day,
        sync: sync,
      ).record(_q('FB-0001', GameType.fillGap), true);
      await _settle();
      await _settle();

      expect(script.bodies, hasLength(1));
      expect(script.bodies.single['results'], [
        {
          'id': 'FB-0001',
          'game': 'fill_gap',
          'phase': 2,
          'right': true,
          'date': '2026-11-04',
        },
      ]);
      expect(sync.state, ResultsSyncState.saved);
      expect(sync.pending, 0);
      expect(sync.saved, 1);
    },
  );

  test('a failed send keeps the result and Send again sends it', () async {
    final script = _FakeScript()..fail = true;
    final sync = ResultsSync(_config, client: script.client);
    final tally = SessionTally(clock: () => day, sync: sync);
    tally.record(_q('FB-0002', GameType.repair), false);
    await _settle();
    await _settle();
    expect(sync.state, ResultsSyncState.failed);
    expect(sync.pending, 1);

    script.fail = false;
    await sync.send();
    expect(sync.state, ResultsSyncState.saved);
    expect(sync.pending, 0);
    expect(script.bodies.last['results'], [
      {
        'id': 'FB-0002',
        'game': 'repair',
        'phase': 1,
        'right': false,
        'date': '2026-11-04',
      },
    ]);
  });

  test('an id with no row in the sheet is not sent again', () async {
    final script = _FakeScript()..unknown = {'2026-10-17-001'};
    final sync = ResultsSync(_config, client: script.client);
    final tally = SessionTally(clock: () => day, sync: sync);
    tally.record(_q('2026-10-17-001', GameType.fillGap), true);
    await _settle();
    await _settle();
    expect(sync.unknown, {'2026-10-17-001'});
    expect(sync.pending, 0);

    tally.record(_q('2026-10-17-001', GameType.fillGap), false);
    await _settle();
    expect(script.bodies, hasLength(1));
  });

  test('a check during a send is sent after it', () async {
    final script = _FakeScript();
    final sync = ResultsSync(_config, client: script.client);
    final tally = SessionTally(clock: () => day, sync: sync);
    tally
      ..record(_q('FB-0003', GameType.fillGap), true)
      ..record(_q('FB-0004', GameType.fillGap), false);
    for (var i = 0; i < 6; i++) {
      await _settle();
    }
    final sent = {
      for (final b in script.bodies)
        for (final r in b['results'] as List) r['id'],
    };
    expect(sent, {'FB-0003', 'FB-0004'});
    expect(sync.pending, 0);
    expect(sync.state, ResultsSyncState.saved);
  });

  test('not configured: nothing is queued', () async {
    final script = _FakeScript();
    final sync = ResultsSync(const ResultsConfig(''), client: script.client);
    SessionTally(
      clock: () => day,
      sync: sync,
    ).record(_q('FB-0001', GameType.fillGap), true);
    await _settle();
    expect(script.bodies, isEmpty);
    expect(sync.state, ResultsSyncState.idle);
  });
}
