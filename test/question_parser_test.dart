import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spanish_companion_games/models/answer_check.dart';
import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/models/question_parser.dart';

Map<String, dynamic> fillGap({Map<String, dynamic> overrides = const {}}) => {
  'id': '2026-10-14-001',
  'game': 'fill_gap',
  'category': 'prepositions',
  'severity': 'error',
  'prompt': 'Estoy pensando ___ cambiar de trabajo.',
  'answers': ['en'],
  'options': ['en', 'de', 'a', 'por'],
  'explanation': 'pensar en + infinitive.',
  'source': 'chat 2026-10-14',
  'added': '2026-10-14',
  ...overrides,
};

void main() {
  group('questionFromJson', () {
    test('parses a full fill_gap question', () {
      final q = questionFromJson(fillGap());
      expect(q.id, '2026-10-14-001');
      expect(q.game, GameType.fillGap);
      expect(q.category, 'prepositions');
      expect(q.severity, Severity.error);
      expect(q.prompt, contains('___'));
      expect(q.answers, ['en']);
      expect(q.options, ['en', 'de', 'a', 'por']);
      expect(q.hasOptions, isTrue);
      expect(q.pairs, isEmpty);
      expect(q.explanation, 'pensar en + infinitive.');
      expect(q.source, 'chat 2026-10-14');
      expect(q.added, '2026-10-14');
    });

    test('fill_gap without options means the learner types', () {
      final q = questionFromJson(fillGap(overrides: {'options': null}));
      expect(q.options, isNull);
      expect(q.hasOptions, isFalse);
    });

    test('severity defaults to error when missing', () {
      final raw = fillGap()..remove('severity');
      expect(questionFromJson(raw).severity, Severity.error);
    });

    test('parses a match question into pairs', () {
      final q = questionFromJson({
        'id': 'm1',
        'game': 'match',
        'prompt': 'Match the verb to its noun',
        'answers': [
          ['prestar', 'atención'],
          ['tomar', 'una decisión'],
        ],
      });
      expect(q.game, GameType.match);
      expect(q.answers, isEmpty);
      expect(q.pairs, [
        const MatchPair('prestar', 'atención'),
        const MatchPair('tomar', 'una decisión'),
      ]);
    });

    test('parses order and repair answers as sentences', () {
      final order = questionFromJson({
        'id': 'o1',
        'game': 'order',
        'prompt': 'Siempre me levanto a las siete.',
        'answers': ['Siempre me levanto a las siete.'],
      });
      expect(order.game, GameType.order);
      expect(order.answers, ['Siempre me levanto a las siete.']);

      final repair = questionFromJson({
        'id': 'r1',
        'game': 'repair',
        'prompt': 'La sopa es muy caliente.',
        'answers': ['La sopa está muy caliente.'],
      });
      expect(repair.game, GameType.repair);
      expect(repair.answers, ['La sopa está muy caliente.']);
    });

    test('toJson round-trips', () {
      final raw = fillGap();
      expect(questionFromJson(raw).toJson(), raw);

      final match = {
        'id': 'm1',
        'game': 'match',
        'category': 'collocation',
        'severity': 'suggestion',
        'prompt': 'Match',
        'answers': [
          ['prestar', 'atención'],
          ['tomar', 'una decisión'],
        ],
        'explanation': '',
        'source': '',
        'added': '',
      };
      expect(questionFromJson(match).toJson(), match);
    });

    group('rejects', () {
      void rejects(Object? raw, Pattern message) {
        expect(
          () => questionFromJson(raw),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains(message),
            ),
          ),
        );
      }

      test('a non-object', () => rejects('hello', 'expected an object'));
      test('missing id', () => rejects(fillGap()..remove('id'), '"id"'));
      test('empty id', () => rejects(fillGap(overrides: {'id': ' '}), '"id"'));
      test(
        'unknown game',
        () => rejects(fillGap(overrides: {'game': 'quiz'}), '"game"'),
      );
      test(
        'unknown severity',
        () => rejects(fillGap(overrides: {'severity': 'bad'}), '"severity"'),
      );
      test(
        'fill_gap prompt without ___',
        () => rejects(fillGap(overrides: {'prompt': 'No gap here.'}), '___'),
      );
      test(
        'empty answers',
        () => rejects(fillGap(overrides: {'answers': []}), '"answers"'),
      );
      test(
        'answers that are not strings',
        () => rejects(
          fillGap(
            overrides: {
              'answers': [1],
            },
          ),
          '"answers"',
        ),
      );
      test(
        'options that do not include an answer',
        () => rejects(
          fillGap(
            overrides: {
              'options': ['de', 'a'],
            },
          ),
          'at least one of the "answers"',
        ),
      );
      test(
        'options on a non fill_gap game',
        () => rejects({
          'id': 'r1',
          'game': 'repair',
          'prompt': 'x',
          'answers': ['y'],
          'options': ['y'],
        }, 'only allowed for fill_gap'),
      );
      test(
        'match answers that are not pairs',
        () => rejects({
          'id': 'm1',
          'game': 'match',
          'prompt': 'Match',
          'answers': ['prestar', 'atención'],
        }, '[left, right]'),
      );
      test(
        'match with only one pair',
        () => rejects({
          'id': 'm1',
          'game': 'match',
          'prompt': 'Match',
          'answers': [
            ['a', 'b'],
          ],
        }, 'at least two pairs'),
      );
    });
  });

  group('parseQuestions', () {
    test('keeps good questions and reports bad ones', () {
      final text = jsonEncode([
        fillGap(),
        fillGap(overrides: {'id': 'bad', 'game': 'quiz'}),
        fillGap(overrides: {'id': '2026-10-14-001'}), // duplicate id
        'not an object',
      ]);
      final result = parseQuestions(text);
      expect(result.questions.map((q) => q.id), ['2026-10-14-001']);
      expect(result.problems, hasLength(3));
      expect(result.problems[0].index, 1);
      expect(result.problems[0].id, 'bad');
      expect(result.problems[1].index, 2);
      expect(result.problems[1].message, 'duplicate id');
      expect(result.problems[2].index, 3);
      expect(result.problems[2].id, isNull);
      expect(result.problems[2].toString(), startsWith('question 4:'));
    });

    test('throws when the file is not JSON', () {
      expect(
        () => parseQuestions('{ not json'),
        throwsA(isA<QuestionFileException>()),
      );
    });

    test('throws when the top level is not an array', () {
      expect(
        () => parseQuestions('{"id": "x"}'),
        throwsA(isA<QuestionFileException>()),
      );
    });

    test('an empty array is fine', () {
      final result = parseQuestions('[]');
      expect(result.questions, isEmpty);
      expect(result.hasProblems, isFalse);
    });

    test('bundled sample covers all four games with no problems', () {
      final text = File('assets/questions.sample.json').readAsStringSync();
      final result = parseQuestions(text);
      expect(result.problems, isEmpty, reason: result.problems.join('\n'));
      final counts = result.countByGame;
      for (final game in GameType.values) {
        expect(counts[game], greaterThan(0), reason: game.jsonValue);
      }
      expect(result.forGame(GameType.match).first.pairs, isNotEmpty);
      expect(
        result.questions
            .where((q) => q.game == GameType.fillGap)
            .any((q) => !q.hasOptions),
        isTrue,
        reason: 'sample should include a typed fill_gap question',
      );
    });
  });

  group('answer checking', () {
    test('trims, ignores case and final punctuation', () {
      expect(normaliseAnswer('  EN. '), 'en');
      expect(
        normaliseAnswer('¿Se lo has dicho a tu madre?'),
        'se lo has dicho a tu madre',
      );
      expect(
        normaliseAnswer('La sopa   está caliente!'),
        'la sopa está caliente',
      );
    });

    test('accents must match', () {
      expect(isAcceptedAnswer('esta', ['está']), isFalse);
      expect(isAcceptedAnswer('Está', ['está']), isTrue);
    });

    test('matches any accepted answer', () {
      const accepted = [
        'Siempre me levanto a las siete.',
        'Me levanto siempre a las siete.',
      ];
      expect(
        isAcceptedAnswer('me levanto siempre a las siete', accepted),
        isTrue,
      );
      expect(
        isAcceptedAnswer('Me levanto a las siete siempre', accepted),
        isFalse,
      );
      expect(isAcceptedAnswer('', accepted), isFalse);
    });
  });
}
