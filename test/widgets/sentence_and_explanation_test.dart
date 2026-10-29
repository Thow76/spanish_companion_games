// Unit tests for the display helpers behind PromptCard and ExplanationCard
// (UI spec section 6).
import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/widgets/explanation_content.dart';
import 'package:spanish_companion_games/widgets/sentence_text.dart';

void main() {
  group('SentenceText', () {
    test('parses marks and never keeps the asterisks', () {
      final runs = SentenceText.parseMarks('**Me** gusta **los** libros.');
      expect(runs.map((r) => r.text).join(), 'Me gusta los libros.');
      expect(runs.where((r) => r.marked).map((r) => r.text), ['Me', 'los']);
    });

    test('an unclosed mark is plain text', () {
      final runs = SentenceText.parseMarks('Estoy **pensando de');
      expect(runs.any((r) => r.marked), isFalse);
      expect(runs.map((r) => r.text).join(), 'Estoy pensando de');
    });

    test('replaces the first marked span', () {
      expect(
        SentenceText.replaceFirstMark(
          'Estoy pensando **de** cambiar de trabajo.',
          'en',
        ),
        'Estoy pensando en cambiar de trabajo.',
      );
    });

    test('diff marks only the changed words', () {
      final diff = SentenceText.diff(
        'Me gustan los libros de historia.',
        'Me gusta los libros de historia.',
      );
      expect(diff.where((w) => w.changed).map((w) => w.word), ['gustan']);
      expect(SentenceText.isClear(diff), isTrue);
    });

    test('changedRuns gives each changed run, then its words, once', () {
      expect(
        SentenceText.changedRuns(
          'Me gustan los libros y me gustan las películas.',
          'Me gusta los libros y me gusta las películas.',
        ),
        ['gustan'],
      );
      expect(
        SentenceText.changedRuns(
          'El problema es muy difícil y la gente está cansada.',
          'El problema es muy difícil y las gentes están cansadas.',
        ),
        ['la gente está cansada.', 'la', 'gente', 'está', 'cansada.'],
      );
      expect(SentenceText.changedRuns('Igual.', 'Igual.'), isEmpty);
    });

    test('a changed word in the rule becomes the answer chip', () {
      final c = ExplanationContent.build(
        explanation:
            'me gustan + plural noun = gustar agrees with the thing liked',
        answers: SentenceText.changedRuns(
          'Me gustan los libros y me gustan las películas.',
          'Me gusta los libros y me gusta las películas.',
        ),
      );
      expect(
        c.rule!.where((p) => p.kind == RulePartKind.answer).map((p) => p.text),
        ['gustan'],
      );
    });
  });

  group('ExplanationContent', () {
    test('splits "pattern = meaning" into chips and a meaning', () {
      final c = ExplanationContent.build(
        explanation:
            'pensar en + infinitive = to be thinking of doing something.',
        answers: const ['en'],
        chosen: 'de',
      );
      expect(c.isFallback, isFalse);
      expect(c.rule!.map((p) => p.kind), [
        RulePartKind.word,
        RulePartKind.answer,
        RulePartKind.joiner,
        RulePartKind.placeholder,
      ]);
      expect(c.meaning, 'to be thinking of doing something');
      expect(c.spokenRule, 'pensar en plus infinitive');
      expect(c.spokenYouWrote, 'pensar de, wrong');
    });

    test('a choice not in the pattern is shown on its own', () {
      final c = ExplanationContent.build(
        explanation:
            'ver a + person = the personal a goes before a person who is the '
            'object',
        answers: const ['ver a mis'],
        chosen: 'ver a los',
      );
      expect(c.youWrote, [(text: 'ver a los', wrong: true)]);
      expect(c.spokenYouWrote, 'ver a los, wrong');
    });

    test('rule and meaning fields win over the explanation', () {
      final c = ExplanationContent.build(
        explanation: 'Anything at all.',
        rule: 'acordarse de + noun',
        meaning: 'to remember something',
        answers: const ['de'],
      );
      expect(c.rule!.first.text, 'acordarse');
      expect(c.meaning, 'to remember something');
    });

    test('falls back to plain text when it cannot split', () {
      final c = ExplanationContent.build(
        explanation: 'Professions take ser: ella es profesora.',
        answers: const ['es'],
      );
      expect(c.isFallback, isTrue);
      expect(c.plainText, 'Professions take ser: ella es profesora.');
    });

    test('neighbouring placeholders share one chip', () {
      final parts = ExplanationContent.parseRule('gustar + plural noun', []);
      expect(parts.last.text, 'plural noun');
      expect(parts.last.kind, RulePartKind.placeholder);
    });

    test('commas in a list of patterns become "·" joiners, not chip text', () {
      final parts = ExplanationContent.parseRule(
        'pensar en, depender de, soñar con',
        const ['en'],
      );
      expect(parts.map((p) => p.text), [
        'pensar',
        'en',
        '·',
        'depender',
        'de',
        '·',
        'soñar',
        'con',
      ]);
      expect(parts[2].kind, RulePartKind.joiner);
      // Only the first answer found is mint by default.
      expect(
        parts.where((p) => p.kind == RulePartKind.answer).map((p) => p.text),
        ['en'],
      );
    });

    test('allAnswers makes every answer in the rule a mint chip', () {
      final c = ExplanationContent.build(
        explanation:
            'prestar atención, tomar una decisión, hacer cola = fixed verb + '
            'noun pairs',
        answers: const ['atención', 'una decisión', 'cola'],
        allAnswers: true,
      );
      expect(
        c.rule!.where((p) => p.kind == RulePartKind.answer).map((p) => p.text),
        ['atención', 'una decisión', 'cola'],
      );
      expect(c.spokenRule, 'prestar atención, tomar una decisión, hacer cola');
    });
  });
}
