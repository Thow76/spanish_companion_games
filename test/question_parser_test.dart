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

    test('reads optional focus and hint', () {
      final q = questionFromJson(
        repair(
          overrides: {
            'focus': 'Verb agreement with *la gente*',
            'hint': 'Is la gente one thing or many?',
          },
        ),
      );
      expect(q.focus, 'Verb agreement with *la gente*');
      expect(q.hint, 'Is la gente one thing or many?');

      final without = questionFromJson(repair());
      expect(without.focus, isNull);
      expect(without.hint, isNull);

      // Blank or not a string: treated as absent, never a problem.
      final odd = questionFromJson(
        repair(overrides: {'focus': '  ', 'hint': 42}),
      );
      expect(odd.focus, isNull);
      expect(odd.hint, isNull);
    });

    test('focus and hint round-trip through toJson', () {
      final raw = repair(
        overrides: {'focus': 'Verb agreement', 'hint': 'One or many?'},
      );
      expect(questionFromJson(raw).toJson(), {...raw, 'stage': 3});
      expect(questionFromJson(repair()).toJson().containsKey('focus'), isFalse);
      expect(questionFromJson(repair()).toJson().containsKey('hint'), isFalse);
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
      // B26: toJson always writes the stage, worked out from the game when
      // the file has none.
      final raw = chooseCorrection();
      expect(questionFromJson(raw).toJson(), {...raw, 'stage': 1});

      final missing = chooseCorrection(
        overrides: {
          'prompt': 'Voy a **ver mis** padres.',
          'answers': ['ver a mis'],
          'options': ['ver a mis', 'ver a los'],
          'missing_word': true,
        },
      );
      expect(questionFromJson(missing).toJson(), {...missing, 'stage': 1});

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
      expect(questionFromJson(match).toJson(), {
        ...match,
        'stage': 'consolidation',
      });
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
          'must include one of the "answers"',
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
      final repairs = result.forGame(GameType.repair);
      expect(
        repairs.any((q) => q.focus != null && q.hint != null),
        isTrue,
        reason: 'sample should include a repair with a focus and a hint',
      );
      expect(
        repairs.any((q) => q.focus == null && q.hint == null),
        isTrue,
        reason: 'sample should include a repair without them (fallback)',
      );
      expect(
        result.questions.any((q) => q.type == QuestionType.note),
        isTrue,
        reason: 'sample should include a language note',
      );
      // B26: every ladder stage, a drop-back pair and both consolidation
      // games with their extra fields.
      for (final stage in LadderStage.values) {
        expect(result.countByStage[stage], greaterThan(0), reason: stage.label);
      }
      final locked = result.questions.where((q) => q.unlocksAfter != null);
      expect(locked, isNotEmpty, reason: 'sample should include a drop-back');
      for (final q in locked) {
        final opener = result.questions.firstWhere(
          (o) => o.id == q.unlocksAfter,
        );
        expect(opener.item, q.item);
        expect(opener.stage.number, q.stage.number! - 1);
      }
      expect(
        result
            .forGame(GameType.order)
            .any((q) => q.fixedStart != null && q.fixedEnd != null),
        isTrue,
        reason: 'sample should include an order with fixed start and end',
      );
      expect(
        result.forGame(GameType.match).any((q) => q.ruleId != null),
        isTrue,
        reason: 'sample should include a match with a rule bank ID',
      );
    });
  });

  group('stage ladder (B26)', () {
    Map<String, dynamic> match({Map<String, dynamic> overrides = const {}}) => {
      'id': 'FB-0001-sc1',
      'game': 'match',
      'prompt': 'Match the verb to its preposition',
      'answers': [
        ['pensar', 'en'],
        ['acordarse', 'de'],
      ],
      ...overrides,
    };

    Map<String, dynamic> order({Map<String, dynamic> overrides = const {}}) => {
      'id': 'FB-0002-sc1',
      'game': 'order',
      'prompt': 'me di cuenta de que había olvidado',
      'answers': ['me di cuenta de que había olvidado'],
      ...overrides,
    };

    test('old files: stage worked out from the game, item = id', () {
      expect(questionFromJson(chooseCorrection()).stage, LadderStage.one);
      expect(questionFromJson(fillGap()).stage, LadderStage.two);
      expect(questionFromJson(repair()).stage, LadderStage.three);
      expect(
        questionFromJson(fillGap(overrides: {'options': null})).stage,
        LadderStage.four,
      );
      expect(questionFromJson(spotError()).stage, LadderStage.five);
      expect(questionFromJson(match()).stage, LadderStage.consolidation);
      expect(questionFromJson(order()).stage, LadderStage.consolidation);
      final q = questionFromJson(repair());
      expect(q.item, q.id);
      expect(q.unlocksAfter, isNull);
    });

    test('reads stage and item', () {
      final q = questionFromJson(
        repair(overrides: {'id': 'FB-0012-s3', 'item': 'FB-0012', 'stage': 3}),
      );
      expect(q.stage, LadderStage.three);
      expect(q.item, 'FB-0012');
      expect(q.id, 'FB-0012-s3');
      // A spreadsheet may give the stage as text or as 3.0.
      expect(
        questionFromJson(repair(overrides: {'stage': '3'})).stage,
        LadderStage.three,
      );
      expect(
        questionFromJson(repair(overrides: {'stage': 3.0})).stage,
        LadderStage.three,
      );
      expect(
        questionFromJson(order(overrides: {'stage': 'Consolidation'})).stage,
        LadderStage.consolidation,
      );
      // Blank item or stage: treated as absent.
      final blank = questionFromJson(
        repair(overrides: {'item': ' ', 'stage': ''}),
      );
      expect(blank.item, blank.id);
      expect(blank.stage, LadderStage.three);
    });

    test('fill_gap is stage 2 with options and stage 4 without', () {
      expect(
        questionFromJson(fillGap(overrides: {'stage': 2})).stage,
        LadderStage.two,
      );
      expect(
        questionFromJson(
          fillGap(overrides: {'stage': 4, 'options': null}),
        ).stage,
        LadderStage.four,
      );
    });

    void rejects(Map<String, dynamic> raw, Pattern message) {
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

    test('a stage that does not fit the game is reported', () {
      rejects(
        chooseCorrection(overrides: {'stage': 2}),
        'fill_gap with options',
      );
      rejects(fillGap(overrides: {'stage': 4}), 'fill_gap with options');
      rejects(fillGap(overrides: {'stage': 2, 'options': null}), 'without');
      rejects(repair(overrides: {'stage': 'consolidation'}), 'order or match');
      rejects(match(overrides: {'stage': 5}), 'spot_error');
      rejects(repair(overrides: {'stage': 6}), '1 to 5 or "consolidation"');
      rejects(repair(overrides: {'stage': 'C'}), '1 to 5 or "consolidation"');
      rejects(repair(overrides: {'stage': 2.5}), '1 to 5 or "consolidation"');
    });

    test('item, unlocks_after and fixed text must be strings', () {
      rejects(repair(overrides: {'item': 12}), '"item" must be a string');
      rejects(
        repair(overrides: {'unlocks_after': 3}),
        '"unlocks_after" must be a string',
      );
      rejects(
        order(
          overrides: {
            'fixed_start': ['a'],
          },
        ),
        '"fixed_start" must be a string',
      );
    });

    test('unlocks_after must not be the question itself', () {
      rejects(
        repair(overrides: {'unlocks_after': '2026-10-17-005'}),
        'its own "id"',
      );
    });

    test('fixed_start and fixed_end: order only', () {
      final q = questionFromJson(
        order(
          overrides: {
            'fixed_start': 'Cuando llegué a casa anoche, ',
            'fixed_end': 'las llaves en el trabajo.',
          },
        ),
      );
      expect(q.fixedStart, 'Cuando llegué a casa anoche,');
      expect(q.fixedEnd, 'las llaves en el trabajo.');
      expect(questionFromJson(order()).fixedStart, isNull);
      rejects(
        repair(overrides: {'fixed_end': 'en el trabajo.'}),
        'only for order questions',
      );
    });

    test('rule on a match question is the rule bank ID', () {
      final q = questionFromJson(match(overrides: {'rule': 'prep-verb'}));
      expect(q.ruleId, 'prep-verb');
      expect(q.rule, isNull, reason: 'not shown as the explanation rule');
      // On the other games rule is still the display rule.
      final f = questionFromJson(fillGap(overrides: {'rule': 'depender de'}));
      expect(f.rule, 'depender de');
      expect(f.ruleId, isNull);
    });

    test('ladder fields round-trip through toJson', () {
      final raw = fillGap(
        overrides: {
          'id': 'FB-0012-s4',
          'item': 'FB-0012',
          'stage': 4,
          'unlocks_after': 'FB-0012-s3',
          'options': null,
        },
      )..remove('options');
      expect(questionFromJson(raw).toJson(), raw);

      final m = {
        ...match(overrides: {'rule': 'prep-verb', 'item': 'FB-0001'}),
        'phase': 2,
        'type': 'grammar',
        'category': '',
        'explanation': '',
        'source': '',
        'added': '',
        'stage': 'consolidation',
      };
      expect(questionFromJson(m).toJson(), m);

      final o = {
        ...order(
          overrides: {
            'fixed_start': 'Cuando llegué a casa anoche,',
            'fixed_end': 'las llaves en el trabajo.',
          },
        ),
        'phase': 2,
        'type': 'grammar',
        'category': '',
        'explanation': '',
        'source': '',
        'added': '',
        'stage': 'consolidation',
      };
      expect(questionFromJson(o).toJson(), o);
    });

    test('a question locked behind a missing question is kept (B30)', () {
      final result = parseQuestionList([
        repair(overrides: {'id': 'FB-0012-s3', 'item': 'FB-0012'}),
        fillGap(
          overrides: {
            'id': 'FB-0012-s4',
            'item': 'FB-0012',
            'options': null,
            'unlocks_after': 'FB-0012-s3',
          },
        ),
        fillGap(
          overrides: {
            'id': 'FB-0020-s2',
            'item': 'FB-0020',
            'unlocks_after': 'FB-0020-s1',
          },
        ),
        // Locked behind the one above.
        spotError(
          overrides: {
            'id': 'FB-0020-s5',
            'item': 'FB-0020',
            'unlocks_after': 'FB-0020-s2',
          },
        ),
      ]);
      // Reload rule (Andrew, 2026-11-18): the script removes a question
      // once it is answered right, so its unlocked follower must stay.
      expect(result.questions.map((q) => q.id), [
        'FB-0012-s3',
        'FB-0012-s4',
        'FB-0020-s2',
        'FB-0020-s5',
      ]);
      expect(result.questions[1].unlocksAfter, 'FB-0012-s3');
      expect(result.questions[2].unlocksAfter, 'FB-0020-s1');
      expect(result.problems, isEmpty);
    });

    test('counts and groups by stage', () {
      final result = parseQuestionList([
        chooseCorrection(),
        repair(),
        fillGap(),
        fillGap(overrides: {'id': 'typed', 'options': null}),
        match(),
      ]);
      expect(result.countByStage, {
        LadderStage.one: 1,
        LadderStage.two: 1,
        LadderStage.three: 1,
        LadderStage.four: 1,
        LadderStage.five: 0,
        LadderStage.consolidation: 1,
      });
      expect(result.forStage(LadderStage.four).single.id, 'typed');
      expect(result.byStage.keys, LadderStage.values);
      expect(result.byStage[LadderStage.five], isEmpty);
    });

    test('LadderStage values', () {
      expect(LadderStage.three.jsonValue, 3);
      expect(LadderStage.consolidation.jsonValue, 'consolidation');
      expect(LadderStage.fromJson('5'), LadderStage.five);
      expect(LadderStage.fromJson(0), isNull);
      expect(LadderStage.fromJson(null), isNull);
    });
  });

  group('one right option (B33)', () {
    String? problemOf(Map<String, dynamic> raw) {
      final result = parseQuestionList([raw]);
      if (result.questions.isNotEmpty) return null;
      expect(result.problems, hasLength(1));
      return result.problems.single.message;
    }

    test('one matching option loads (choose_correction and fill_gap)', () {
      expect(problemOf(chooseCorrection()), isNull);
      expect(problemOf(fillGap()), isNull);
    });

    test('no matching option is reported and skipped, naming the options', () {
      final message = problemOf(
        fillGap(
          overrides: {
            'options': ['de', 'en', 'a'],
          },
        ),
      );
      expect(message, contains('must include one of the "answers"'));
      expect(message, contains('"de", "en", "a"'));
    });

    test('two matching options are reported and skipped (fill_gap)', () {
      final result = parseQuestionList([
        fillGap(
          overrides: {
            'id': 'FB-0043',
            'prompt': 'Este trabajo ___ mucha responsabilidad.',
            'answers': ['implica', 'involucra'],
            'options': ['implica', 'involucra', 'implican'],
          },
        ),
      ]);
      expect(result.questions, isEmpty);
      expect(result.problems, hasLength(1));
      final problem = result.problems.single;
      expect(problem.id, 'FB-0043');
      expect(problem.message, contains('exactly one right option'));
      expect(problem.message, contains('2 are accepted answers'));
      expect(problem.message, contains('"implica", "involucra"'));
      expect(problem.message, isNot(contains('"implican"')));
    });

    test(
      'two matching options are reported and skipped (choose_correction)',
      () {
        final message = problemOf(
          chooseCorrection(
            overrides: {
              'answers': ['en', 'sobre'],
              'options': ['en', 'sobre', 'a'],
            },
          ),
        );
        expect(message, contains('exactly one right option'));
        expect(message, contains('"en", "sobre"'));
      },
    );

    test('matching uses the answer-checking rule: case and final '
        'punctuation ignored', () {
      final message = problemOf(
        fillGap(
          overrides: {
            'answers': ['del'],
            'options': ['del', 'Del.', 'de'],
          },
        ),
      );
      expect(message, contains('exactly one right option'));
      expect(message, contains('"del", "Del."'));
    });

    test('accents must match, so an unaccented option is a wrong one', () {
      expect(
        problemOf(
          chooseCorrection(
            overrides: {
              'prompt': 'La sopa **es** muy caliente.',
              'answers': ['está'],
              'options': ['está', 'esta', 'estás'],
            },
          ),
        ),
        isNull,
      );
    });

    test('other accepted wordings may stay in answers if not among the '
        'options', () {
      expect(
        problemOf(
          fillGap(
            overrides: {
              'answers': ['tranquilizar', 'calmar'],
              'options': ['tranquilizar', 'tranquilizo', 'tranquila'],
            },
          ),
        ),
        isNull,
      );
    });

    test('typed fill_gap (no options) is unchanged', () {
      expect(
        problemOf(
          fillGap(
            overrides: {
              'answers': ['implica', 'involucra'],
            },
          )..remove('options'),
        ),
        isNull,
      );
    });

    test('the other questions in the file still load', () {
      final result = parseQuestionList([
        chooseCorrection(),
        fillGap(
          overrides: {
            'answers': ['del', 'de'],
          },
        ),
      ]);
      expect(result.questions.map((q) => q.id), ['2026-10-17-001']);
      expect(result.problems.single.index, 1);
    });

    test('optionsAnswerProblem', () {
      expect(optionsAnswerProblem(['en', 'a'], ['en']), isNull);
      expect(optionsAnswerProblem(['de', 'a'], ['en']), isNotNull);
      expect(optionsAnswerProblem(['en', 'En'], ['en']), isNotNull);
    });

    test(
      'every options question in the bundled sample has one right option',
      () {
        final text = File('assets/questions.sample.json').readAsStringSync();
        final result = parseQuestions(text);
        final withOptions = result.questions.where(
          (q) => q.options != null && q.options!.isNotEmpty,
        );
        expect(withOptions, isNotEmpty);
        for (final q in withOptions) {
          expect(
            optionsAnswerProblem(q.options!, q.answers),
            isNull,
            reason: q.id,
          );
        }
      },
    );
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
