import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:spanish_companion_games/models/answer_check.dart';
import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/models/question_parser.dart';

Map<String, dynamic> chooseCorrection({
  Map<String, dynamic> overrides = const {},
}) => {
  'id': '2026-10-17-001',
  'phase': 1,
  'game': 'choose_correction',
  'type': 'grammar',
  'category': 'Prepositions',
  'prompt': 'Estoy pensando **de** cambiar de trabajo.',
  'answers': ['en'],
  'options': ['en', 'a', 'por'],
  'explanation': 'pensar en + infinitive = to be thinking of doing something',
  'source': 'Work and plans, 2026-10-14',
  'added': '2026-10-17',
  ...overrides,
};

Map<String, dynamic> fillGap({Map<String, dynamic> overrides = const {}}) => {
  'id': '2026-10-17-008',
  'phase': 2,
  'game': 'fill_gap',
  'type': 'grammar',
  'category': 'Prepositions',
  'prompt': 'Depende ___ tiempo que haga.',
  'answers': ['del'],
  'options': ['del', 'de', 'en'],
  'explanation': 'depender de = to depend on',
  'source': 'Weekend plans, 2026-10-16',
  'added': '2026-10-17',
  ...overrides,
};

Map<String, dynamic> repair({Map<String, dynamic> overrides = const {}}) => {
  'id': '2026-10-17-005',
  'phase': 1,
  'game': 'repair',
  'type': 'grammar',
  'category': 'Agreement',
  'prompt': 'El problema es difícil y **la gente están** cansada.',
  'answers': ['El problema es difícil y la gente está cansada.'],
  'explanation': 'la gente + singular verb = people',
  'source': 'Work and plans, 2026-10-14',
  'added': '2026-10-17',
  ...overrides,
};

Map<String, dynamic> spotError({Map<String, dynamic> overrides = const {}}) => {
  'id': '2026-10-17-014',
  'phase': 2,
  'game': 'spot_error',
  'type': 'grammar',
  'category': 'Prepositions',
  'prompt': 'Estoy pensando de mudarme a Glasgow.',
  'answers': ['Estoy pensando en mudarme a Glasgow.'],
  'explanation': 'pensar en + infinitive = to be thinking of doing something',
  'source': 'Work and plans, 2026-10-14',
  'added': '2026-10-17',
  ...overrides,
};

void main() {
  group('questionFromJson', () {
    test('parses a full choose_correction question', () {
      final q = questionFromJson(chooseCorrection());
      expect(q.id, '2026-10-17-001');
      expect(q.game, GameType.chooseCorrection);
      expect(q.phase, QuestionPhase.noticeAndCorrect);
      expect(q.type, QuestionType.grammar);
      expect(q.category, 'Prepositions');
      expect(q.prompt, 'Estoy pensando **de** cambiar de trabajo.');
      expect(q.promptText, 'Estoy pensando de cambiar de trabajo.');
      expect(q.markedSpans, ['de']);
      expect(q.promptRuns, [
        const PromptRun('Estoy pensando ', marked: false),
        const PromptRun('de', marked: true),
        const PromptRun(' cambiar de trabajo.', marked: false),
      ]);
      expect(q.answers, ['en']);
      expect(q.options, ['en', 'a', 'por']);
      expect(q.hasOptions, isTrue);
      expect(q.missingWord, isFalse);
      expect(q.pairs, isEmpty);
      expect(q.rule, isNull);
      expect(q.meaning, isNull);
      expect(q.correctedSentence, 'Estoy pensando en cambiar de trabajo.');
      expect(q.source, 'Work and plans, 2026-10-14');
      expect(q.added, '2026-10-17');
    });

    test('parses a full fill_gap question', () {
      final q = questionFromJson(fillGap());
      expect(q.game, GameType.fillGap);
      expect(q.phase, QuestionPhase.recall);
      expect(q.prompt, contains('___'));
      expect(q.markedSpans, isEmpty);
      expect(q.hasMarks, isFalse);
      expect(q.answers, ['del']);
      expect(q.options, ['del', 'de', 'en']);
      expect(q.correctedSentence, isNull);
    });

    test('fill_gap without options means the learner types', () {
      final q = questionFromJson(fillGap(overrides: {'options': null}));
      expect(q.options, isNull);
      expect(q.hasOptions, isFalse);
    });

    test('phase is taken from the game when missing', () {
      final q1 = questionFromJson(chooseCorrection()..remove('phase'));
      expect(q1.phase, QuestionPhase.noticeAndCorrect);
      final q2 = questionFromJson(fillGap()..remove('phase'));
      expect(q2.phase, QuestionPhase.recall);
    });

    test('type note, and the old severity values', () {
      expect(
        questionFromJson(fillGap(overrides: {'type': 'note'})).type,
        QuestionType.note,
      );
      final old = fillGap()..remove('type');
      expect(
        questionFromJson({...old, 'severity': 'error'}).type,
        QuestionType.grammar,
      );
      expect(
        questionFromJson({...old, 'severity': 'suggestion'}).type,
        QuestionType.note,
      );
      expect(questionFromJson(old).type, QuestionType.grammar);
    });

    test('type wins over severity when both are given', () {
      final q = questionFromJson(
        fillGap(overrides: {'type': 'note', 'severity': 'error'}),
      );
      expect(q.type, QuestionType.note);
    });

    test('missing_word on a phase 1 question', () {
      final q = questionFromJson(
        chooseCorrection(
          overrides: {
            'prompt': 'Voy a **ver mis** padres.',
            'answers': ['ver a mis'],
            'options': ['ver a mis', 'ver a los'],
            'missing_word': true,
          },
        ),
      );
      expect(q.missingWord, isTrue);
      expect(q.correctedSentence, 'Voy a ver a mis padres.');
    });

    test('missing_word false is fine anywhere', () {
      final q = questionFromJson(fillGap(overrides: {'missing_word': false}));
      expect(q.missingWord, isFalse);
    });

    test('parses a repair question with several marked spans', () {
      final q = questionFromJson(
        repair(
          overrides: {
            'prompt': '**Me gusta** los libros y **me gusta** las películas.',
            'answers': ['Me gustan los libros y me gustan las películas.'],
          },
        ),
      );
      expect(q.markedSpans, ['Me gusta', 'me gusta']);
      expect(q.promptText, 'Me gusta los libros y me gusta las películas.');
      expect(
        q.correctedSentence,
        'Me gustan los libros y me gustan las películas.',
      );
    });

    test('parses a spot_error question', () {
      final q = questionFromJson(spotError());
      expect(q.game, GameType.spotError);
      expect(q.phase, QuestionPhase.recall);
      expect(q.correctedSentence, 'Estoy pensando en mudarme a Glasgow.');
    });

    test('reads optional rule and meaning', () {
      final q = questionFromJson(
        fillGap(overrides: {'rule': 'depender de', 'meaning': 'to depend on'}),
      );
      expect(q.rule, 'depender de');
      expect(q.meaning, 'to depend on');
      expect(questionFromJson(fillGap(overrides: {'rule': ' '})).rule, isNull);
    });

    test('parses a match question into pairs', () {
      final q = questionFromJson({
        'id': 'm1',
        'game': 'match',
        'prompt': 'Match the verb to its preposition',
        'answers': [
          ['pensar', 'en'],
          ['depender', 'de'],
        ],
      });
      expect(q.game, GameType.match);
      expect(q.answers, isEmpty);
      expect(q.pairs, [
        const MatchPair('pensar', 'en'),
        const MatchPair('depender', 'de'),
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

      final r = questionFromJson(repair());
      expect(r.game, GameType.repair);
      expect(r.markedSpans, ['la gente están']);
      expect(r.answers, ['El problema es difícil y la gente está cansada.']);
    });

    test('toJson round-trips', () {
      final raw = chooseCorrection();
      expect(questionFromJson(raw).toJson(), raw);

      final missing = chooseCorrection(
        overrides: {
          'prompt': 'Voy a **ver mis** padres.',
          'answers': ['ver a mis'],
          'options': ['ver a mis', 'ver a los'],
          'missing_word': true,
        },
      );
      expect(questionFromJson(missing).toJson(), missing);

      final match = {
        'id': 'm1',
        'phase': 2,
        'game': 'match',
        'type': 'note',
        'category': 'Collocation',
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
        'phase that is not 1 or 2',
        () => rejects(fillGap(overrides: {'phase': 3}), '"phase"'),
      );
      test(
        'phase that does not match the game',
        () => rejects(fillGap(overrides: {'phase': 1}), 'phase 2 game'),
      );
      test(
        'unknown type',
        () => rejects(fillGap(overrides: {'type': 'bad'}), '"type"'),
      );
      test(
        'unknown old severity',
        () => rejects({
          ...(fillGap()..remove('type')),
          'severity': 'bad',
        }, '"severity"'),
      );
      test(
        'fill_gap prompt without ___',
        () => rejects(fillGap(overrides: {'prompt': 'No gap here.'}), '___'),
      );
      test(
        'phase 1 prompt with nothing marked',
        () => rejects(
          chooseCorrection(overrides: {'prompt': 'Estoy pensando de cambiar.'}),
          'must mark the problem words',
        ),
      );
      test(
        'unclosed mark',
        () => rejects(
          chooseCorrection(
            overrides: {'prompt': 'Estoy pensando **de cambiar.'},
          ),
          'unclosed',
        ),
      );
      test(
        'empty mark',
        () => rejects(
          chooseCorrection(overrides: {'prompt': 'Estoy pensando ** ** de.'}),
          'empty',
        ),
      );
      test(
        'choose_correction with two marked spans',
        () => rejects(
          chooseCorrection(
            overrides: {'prompt': '**Estoy** pensando **de** cambiar.'},
          ),
          'exactly one span',
        ),
      );
      test(
        'phase 2 prompt with marks',
        () => rejects(
          spotError(overrides: {'prompt': 'Estoy pensando **de** mudarme.'}),
          'must not contain **',
        ),
      );
      test(
        'missing_word on a phase 2 question',
        () => rejects(
          fillGap(overrides: {'missing_word': true}),
          'only for phase 1',
        ),
      );
      test(
        'missing_word that is not a boolean',
        () => rejects(
          chooseCorrection(overrides: {'missing_word': 'yes'}),
          '"missing_word"',
        ),
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
        'choose_correction without options',
        () => rejects(
          chooseCorrection()..remove('options'),
          'must have "options"',
        ),
      );
      test(
        'choose_correction with one option',
        () => rejects(
          chooseCorrection(
            overrides: {
              'options': ['en'],
            },
          ),
          'at least two',
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
        'choose_correction options that include the original words',
        () => rejects(
          chooseCorrection(
            overrides: {
              'options': ['en', 'de', 'a'],
            },
          ),
          'marked words unchanged',
        ),
      );
      test(
        'options on a repair question',
        () => rejects(
          repair(
            overrides: {
              'options': ['y'],
            },
          ),
          'only allowed for choose_correction and fill_gap',
        ),
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
        fillGap(overrides: {'id': '2026-10-17-008'}), // duplicate id
        'not an object',
      ]);
      final result = parseQuestions(text);
      expect(result.questions.map((q) => q.id), ['2026-10-17-008']);
      expect(result.problems, hasLength(3));
      expect(result.problems[0].index, 1);
      expect(result.problems[0].id, 'bad');
      expect(result.problems[1].index, 2);
      expect(result.problems[1].message, 'duplicate id');
      expect(result.problems[2].index, 3);
      expect(result.problems[2].id, isNull);
      expect(result.problems[2].toString(), startsWith('question 4:'));
    });

    test('still loads a file in the pre-2026-10-17 format', () {
      final text = jsonEncode([
        {
          'id': '2026-10-14-001',
          'game': 'fill_gap',
          'category': 'prepositions',
          'severity': 'suggestion',
          'prompt': 'Estoy pensando ___ cambiar de trabajo.',
          'answers': ['en'],
          'options': ['en', 'de', 'a', 'por'],
          'explanation': 'pensar en + infinitive.',
          'source': 'sample',
          'added': '2026-10-14',
        },
        {
          'id': '2026-10-14-006',
          'game': 'repair',
          'severity': 'error',
          'prompt': 'La sopa es muy caliente hoy.',
          'answers': ['La sopa está muy caliente hoy.'],
        },
      ]);
      final result = parseQuestions(text);
      expect(result.questions, hasLength(1));
      expect(result.questions.single.type, QuestionType.note);
      expect(result.questions.single.phase, QuestionPhase.recall);
      // An old repair question has no marked words, so it is reported.
      expect(result.problems, hasLength(1));
      expect(result.problems.single.id, '2026-10-14-006');
      expect(result.problems.single.message, contains('mark'));
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

    test('counts by phase and lists by phase', () {
      final result = parseQuestionList([
        chooseCorrection(),
        repair(),
        fillGap(),
      ]);
      expect(result.countByPhase, {
        QuestionPhase.noticeAndCorrect: 2,
        QuestionPhase.recall: 1,
      });
      expect(result.forPhase(QuestionPhase.recall).map((q) => q.game), [
        GameType.fillGap,
      ]);
      expect(GameType.forPhase(QuestionPhase.noticeAndCorrect), [
        GameType.chooseCorrection,
        GameType.repair,
      ]);
    });

    test('bundled sample covers all six games with no problems', () {
      final text = File('assets/questions.sample.json').readAsStringSync();
      final result = parseQuestions(text);
      expect(result.problems, isEmpty, reason: result.problems.join('\n'));
      final counts = result.countByGame;
      for (final game in GameType.values) {
        expect(counts[game], greaterThan(0), reason: game.jsonValue);
      }
      for (final phase in QuestionPhase.values) {
        expect(result.countByPhase[phase], greaterThan(0), reason: phase.name);
      }
      expect(result.forGame(GameType.match).first.pairs, isNotEmpty);
      expect(
        result.forGame(GameType.fillGap).any((q) => !q.hasOptions),
        isTrue,
        reason: 'sample should include a typed fill_gap question',
      );
      expect(
        result.questions.any((q) => q.missingWord),
        isTrue,
        reason: 'sample should include a missing-word question',
      );
      expect(
        result.forGame(GameType.repair).any((q) => q.markedSpans.length > 1),
        isTrue,
        reason: 'sample should include a repair with several marked spans',
      );
      final spot = result.forGame(GameType.spotError);
      expect(
        spot.any(spotErrorSentenceIsCorrect),
        isTrue,
        reason: 'sample should include a correct spot_error sentence',
      );
      expect(
        spot.any((q) => !spotErrorSentenceIsCorrect(q)),
        isTrue,
        reason: 'sample should include a spot_error sentence that needs fixing',
      );
      expect(
        result.questions.any((q) => q.type == QuestionType.note),
        isTrue,
        reason: 'sample should include a language note',
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

    test('repair accepts the whole sentence or just the marked part', () {
      final q = questionFromJson(repair());
      expect(
        checkRepair(q, 'El problema es difícil y la gente está cansada'),
        isTrue,
      );
      expect(checkRepair(q, 'la gente está'), isTrue);
      expect(checkRepair(q, 'La gente está.'), isTrue);
      expect(checkRepair(q, 'la gente estan'), isFalse);
      expect(checkRepair(q, 'la gente están'), isFalse);
      expect(checkRepair(q, '   '), isFalse);
    });

    test('repair with several marked spans replaces the whole stretch', () {
      final q = questionFromJson(
        repair(
          overrides: {
            'prompt': '**Me gusta** los libros y **me gusta** las películas.',
            'answers': ['Me gustan los libros y me gustan las películas.'],
          },
        ),
      );
      expect(
        checkRepair(q, 'Me gustan los libros y me gustan las películas.'),
        isTrue,
      );
      expect(checkRepair(q, 'Me gustan los libros y me gustan'), isTrue);
      expect(checkRepair(q, 'Me gustan'), isFalse);
    });

    test('spot_error needs both steps right', () {
      final wrong = questionFromJson(spotError());
      expect(spotErrorSentenceIsCorrect(wrong), isFalse);
      expect(checkSpotError(wrong, saidCorrect: true), isFalse);
      expect(checkSpotError(wrong, saidCorrect: false), isFalse);
      expect(
        checkSpotError(
          wrong,
          saidCorrect: false,
          typed: 'Estoy pensando de mudarme a Glasgow.',
        ),
        isFalse,
      );
      expect(
        checkSpotError(
          wrong,
          saidCorrect: false,
          typed: 'estoy pensando en mudarme a glasgow',
        ),
        isTrue,
      );

      final right = questionFromJson(
        spotError(
          overrides: {
            'prompt': 'Depende del tiempo que haga.',
            'answers': ['Depende del tiempo que haga.'],
          },
        ),
      );
      expect(spotErrorSentenceIsCorrect(right), isTrue);
      expect(checkSpotError(right, saidCorrect: true), isTrue);
      expect(
        checkSpotError(
          right,
          saidCorrect: false,
          typed: 'Depende del tiempo que haga.',
        ),
        isFalse,
      );
    });

    test('matching pairs', () {
      final q = questionFromJson({
        'id': 'm1',
        'game': 'match',
        'prompt': 'Match the verb to its preposition',
        'answers': [
          ['pensar', 'en'],
          ['depender', 'de'],
        ],
      });
      expect(isMatchingPair(q, 'pensar', 'en'), isTrue);
      expect(isMatchingPair(q, 'Pensar', 'EN'), isTrue);
      expect(isMatchingPair(q, 'pensar', 'de'), isFalse);
      expect(isMatchingPair(q, 'en', 'pensar'), isFalse);
    });
  });
}
