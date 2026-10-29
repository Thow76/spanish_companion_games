/// The home screen filter (B12): play only one type (grammar errors or
/// language notes), one phase, or one category. The three can be combined;
/// each one left empty means "all".
///
/// The filter narrows the questions every game is opened with, and the
/// counts on the home cards. It is kept for the app session (including a
/// reload) and not saved between sessions (v1).
library;

import 'question.dart';

class QuestionFilter {
  const QuestionFilter({this.type, this.phase, this.category});

  /// No filter: every question.
  static const QuestionFilter all = QuestionFilter();

  /// Only this type, or every type if null.
  final QuestionType? type;

  /// Only this phase, or both if null.
  final QuestionPhase? phase;

  /// Only this category (as written in the file, compared ignoring case and
  /// surrounding spaces), or every category if null.
  final String? category;

  bool get isAll => type == null && phase == null && category == null;

  static String _key(String category) => category.trim().toLowerCase();

  /// True if [question] passes every part of the filter that is set.
  bool matches(Question question) {
    if (type != null && question.type != type) return false;
    if (phase != null && question.phase != phase) return false;
    if (category != null && _key(question.category) != _key(category!)) {
      return false;
    }
    return true;
  }

  /// The questions that pass, in their original order.
  List<Question> apply(List<Question> questions) =>
      questions.where(matches).toList();

  /// Copies with one part changed. Pass null to clear that part (back to
  /// "all"); the parts not named are kept.
  QuestionFilter withType(QuestionType? value) =>
      QuestionFilter(type: value, phase: phase, category: category);
  QuestionFilter withPhase(QuestionPhase? value) =>
      QuestionFilter(type: type, phase: value, category: category);
  QuestionFilter withCategory(String? value) =>
      QuestionFilter(type: type, phase: phase, category: value);

  /// The same filter, with the category cleared if no question in
  /// [questions] has it (for example after a reload brought a new file).
  QuestionFilter keepingCategoryIn(List<Question> questions) {
    final c = category;
    if (c == null) return this;
    final present = questions.any((q) => _key(q.category) == _key(c));
    return present ? this : withCategory(null);
  }

  /// The categories in [questions], each once (first spelling found), in
  /// alphabetical order, ignoring empty ones.
  static List<String> categoriesOf(List<Question> questions) {
    final byKey = <String, String>{};
    for (final q in questions) {
      final k = _key(q.category);
      if (k.isEmpty) continue;
      byKey.putIfAbsent(k, () => q.category.trim());
    }
    final keys = byKey.keys.toList()..sort();
    return [for (final k in keys) byKey[k]!];
  }

  /// Short description for the filter card's heading: "All questions", or
  /// the parts that are set, joined with " · " ("Grammar errors ·
  /// Recall · Prepositions").
  String get summary {
    if (isAll) return 'All questions';
    return [
      if (type != null) typeLabel(type!),
      if (phase != null) phase!.label,
      ?category,
    ].join(' · ');
  }

  /// The choice labels: "Grammar errors", "Language notes".
  static String typeLabel(QuestionType type) => switch (type) {
    QuestionType.grammar => 'Grammar errors',
    QuestionType.note => 'Language notes',
  };

  @override
  bool operator ==(Object other) =>
      other is QuestionFilter &&
      other.type == type &&
      other.phase == phase &&
      (other.category == null) == (category == null) &&
      (category == null || _key(other.category!) == _key(category!));

  @override
  int get hashCode =>
      Object.hash(type, phase, category == null ? null : _key(category!));
}
