// B20: the home screen shows when the questions were updated and any
// results not yet saved to the Test Review sheet.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:spanish_companion_games/data/results_sync.dart';
import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/models/question_parser.dart';
import 'package:spanish_companion_games/models/session_tally.dart';
import 'package:spanish_companion_games/screens/home_screen.dart';

Question _q(String id) => Question(
  id: id,
  game: GameType.fillGap,
  category: 'test',
  type: QuestionType.grammar,
  prompt: 'Hola ___.',
  answers: const ['x'],
);

ParsedQuestions _sample() =>
    ParsedQuestions(questions: [_q('a'), _q('b')], problems: const []);

Widget _app({
  QuestionSource? source,
  UpdatedSource? updated,
  ResultsSync? sync,
}) => MaterialApp(
  home: HomeScreen(
    source: source ?? () async => _sample(),
    sourceName: 'Google Drive',
    updatedSource: updated,
    resultsSync: sync,
  ),
);

/// A fake Test Review web app that fails until [fail] is false.
class _FakeScript {
  bool fail = true;
  int posts = 0;

  MockClient get client => MockClient((request) async {
    posts++;
    if (fail) return http.Response('error', 500);
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final ids = [for (final r in body['results'] as List) r['id']];
    return http.Response(
      jsonEncode({'ok': true, 'saved': ids, 'unknown': []}),
      200,
    );
  });
}

void main() {
  group('updatedTimeText and sourceLineText', () {
    test('day, short month and 24-hour time', () {
      expect(updatedTimeText(DateTime(2026, 11, 7, 4, 50)), '7 Nov, 04:50');
      expect(updatedTimeText(DateTime(2026, 1, 21, 14, 5)), '21 Jan, 14:05');
    });

    test('the time is left out when not known', () {
      expect(sourceLineText(2, 'Google Drive'), '2 questions · Google Drive');
      expect(sourceLineText(1, 'sample file'), '1 question · sample file');
    });

    test('the time is shown in local time', () {
      final utc = DateTime.utc(2026, 11, 5, 22, 29);
      expect(
        sourceLineText(68, 'Google Drive', updatedAt: utc),
        '68 questions · Google Drive · updated '
        '${updatedTimeText(utc.toLocal())}',
      );
    });
  });

  testWidgets('the source line says when the file was updated', (tester) async {
    final time = DateTime(2026, 11, 7, 4, 50);
    await tester.pumpWidget(_app(updated: () async => time));
    await tester.pumpAndSettle();

    expect(
      find.text('2 questions · Google Drive · updated 7 Nov, 04:50'),
      findsOneWidget,
    );
  });

  testWidgets('if the time cannot be had, the questions still load', (
    tester,
  ) async {
    await tester.pumpWidget(_app(updated: () async => throw Exception('403')));
    await tester.pumpAndSettle();

    expect(find.text('2 questions · Google Drive'), findsOneWidget);
    expect(find.text('Fill the gap'), findsOneWidget);
  });

  testWidgets('a slow time request does not hold up the questions', (
    tester,
  ) async {
    final slow = Completer<DateTime>();
    await tester.pumpWidget(_app(updated: () => slow.future));
    await tester.pumpAndSettle();
    expect(find.text('2 questions · Google Drive'), findsOneWidget);

    slow.complete(DateTime(2026, 11, 7, 9, 3));
    await tester.pumpAndSettle();
    expect(
      find.text('2 questions · Google Drive · updated 7 Nov, 09:03'),
      findsOneWidget,
    );
  });

  testWidgets('reload asks for the time again', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _app(
        updated: () async {
          calls++;
          return DateTime(2026, 11, 7, 10, calls);
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('updated 7 Nov, 10:01'), findsOneWidget);

    await tester.tap(find.byTooltip('Reload questions'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.textContaining('updated 7 Nov, 10:02'), findsOneWidget);
  });

  testWidgets('no unsaved line when nothing is waiting', (tester) async {
    final script = _FakeScript();
    final sync = ResultsSync(
      const ResultsConfig('https://example.com/exec'),
      client: script.client,
    );
    await tester.pumpWidget(_app(sync: sync));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-unsaved-results')), findsNothing);
    expect(find.text(UnsavedResultsLine.retryLabel), findsNothing);
  });

  testWidgets('unsaved results are counted and "Send again" sends them', (
    tester,
  ) async {
    final script = _FakeScript();
    final sync = ResultsSync(
      const ResultsConfig('https://example.com/exec'),
      client: script.client,
    );
    final tally = SessionTally(sync: sync);
    await tester.runAsync(() async {
      tally.record(_q('FB-0001'), true);
      tally.record(_q('FB-0002'), false);
      // Let both failed sends finish.
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    expect(sync.pending, 2);
    expect(sync.state, ResultsSyncState.failed);

    await tester.pumpWidget(_app(sync: sync));
    await tester.pumpAndSettle();
    expect(find.text('${UnsavedResultsLine.unsavedText(2)} ·'), findsOneWidget);
    expect(UnsavedResultsLine.unsavedText(1), '1 result not saved yet');

    script.fail = false;
    final postsBefore = script.posts;
    await tester.tap(find.text(UnsavedResultsLine.retryLabel));
    await tester.runAsync(() async {
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();

    expect(script.posts, greaterThan(postsBefore));
    expect(sync.pending, 0);
    expect(find.byKey(const ValueKey('home-unsaved-results')), findsNothing);
  });
}
