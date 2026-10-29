import 'package:flutter_test/flutter_test.dart';

import 'package:spanish_companion_games/models/question.dart';
import 'package:spanish_companion_games/models/question_filter.dart';

Question _q(String id, GameType game, QuestionType type, String category) =>
    Question(
      id: id,
      game: game,
      category: category,
      type: type,
      prompt: game == GameType.fillGap ? 'Hola ___.' : 'Hola.',
      answers: const ['x'],
    );

final _questions = [
  _q('a', GameType.fillGap, QuestionType.grammar, 'Prepositions'),
  _q('b', GameType.order, QuestionType.grammar, 'Word order'),
  _q('c', GameType.fillGap, QuestionType.note, 'Calque'),
  _q('d', GameType.repair, QuestionType.grammar, 'prepositions '),
];

List<String> _ids(List<Question> qs) => [for (final q in qs) q.id];

void main() {
  test('all lets every question through', () {
    expect(QuestionFilter.all.isAll, isTrue);
    expect(_ids(QuestionFilter.all.apply(_questions)), ['a', 'b', 'c', 'd']);
    expect(QuestionFilter.all.summary, 'All questions');
  });

  test('type, phase and category each narrow, and combine', () {
    const grammar = QuestionFilter(type: QuestionType.grammar);
    expect(_ids(grammar.apply(_questions)), ['a', 'b', 'd']);

    const phase1 = QuestionFilter(phase: QuestionPhase.noticeAndCorrect);
    expect(_ids(phase1.apply(_questions)), ['d']);

    // Case and surrounding spaces are ignored.
    const preps = QuestionFilter(category: 'Prepositions');
    expect(_ids(preps.apply(_questions)), ['a', 'd']);

    final both = preps.withPhase(QuestionPhase.recall);
    expect(_ids(both.apply(_questions)), ['a']);
    expect(both.summary, 'Recall · Prepositions');

    expect(_ids(grammar.withType(QuestionType.note).apply(_questions)), ['c']);
    expect(grammar.withType(null).isAll, isTrue);
  });

  test('categories are listed once each, sorted, first spelling kept', () {
    expect(QuestionFilter.categoriesOf(_questions), [
      'Calque',
      'Prepositions',
      'Word order',
    ]);
  });

  test('a category the questions no longer have is dropped', () {
    const gone = QuestionFilter(
      type: QuestionType.grammar,
      category: 'Subjunctive',
    );
    final kept = gone.keepingCategoryIn(_questions);
    expect(kept.category, isNull);
    expect(kept.type, QuestionType.grammar);

    const here = QuestionFilter(category: 'calque');
    expect(here.keepingCategoryIn(_questions), here);
  });

  test('summary names every part that is set', () {
    const f = QuestionFilter(
      type: QuestionType.note,
      phase: QuestionPhase.recall,
      category: 'Calque',
    );
    expect(f.summary, 'Language notes · Recall · Calque');
  });
}
