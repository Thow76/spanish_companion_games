/// Question model for the Spanish Companion games.
///
/// Mirrors the `questions.json` format described in the build plan:
///
/// ```json
/// {
///   "id": "2026-10-14-003",
///   "game": "fill_gap",
///   "category": "prepositions",
///   "severity": "error",
///   "prompt": "Estoy pensando ___ cambiar de trabajo.",
///   "answers": ["en"],
///   "options": ["en", "de", "a", "por"],
///   "explanation": "pensar en + infinitive = to be thinking of doing something.",
///   "source": "chat 2026-10-14",
///   "added": "2026-10-14"
/// }
/// ```
library;

/// The four games. [jsonValue] is the string used in `questions.json`.
enum GameType {
  fillGap('fill_gap', 'Fill the gap'),
  order('order', 'Sentence ordering'),
  repair('repair', 'Repair the sentence'),
  match('match', 'Matching');

  const GameType(this.jsonValue, this.label);

  /// Value of the `game` field in the JSON file.
  final String jsonValue;

  /// Human-readable name for buttons and headings.
  final String label;

  /// Returns the game for a JSON value, or `null` if it is not one of the four.
  static GameType? fromJson(String? value) {
    for (final game in GameType.values) {
      if (game.jsonValue == value) return game;
    }
    return null;
  }
}

/// Whether the question came from a genuine mistake or an optional improvement.
enum Severity {
  error('error'),
  suggestion('suggestion');

  const Severity(this.jsonValue);

  final String jsonValue;

  static Severity? fromJson(String? value) {
    for (final severity in Severity.values) {
      if (severity.jsonValue == value) return severity;
    }
    return null;
  }
}

/// One pair for the `match` game, e.g. `prestar` / `atención`.
class MatchPair {
  const MatchPair(this.left, this.right);

  final String left;
  final String right;

  List<String> toJson() => [left, right];

  @override
  bool operator ==(Object other) =>
      other is MatchPair && other.left == left && other.right == right;

  @override
  int get hashCode => Object.hash(left, right);

  @override
  String toString() => 'MatchPair($left, $right)';
}

/// One question from `questions.json`, already validated.
///
/// For `fill_gap`, `order` and `repair`, [answers] holds the accepted answers
/// and [pairs] is empty. For `match`, [pairs] holds the pairs to match and
/// [answers] is empty.
class Question {
  const Question({
    required this.id,
    required this.game,
    required this.category,
    required this.severity,
    required this.prompt,
    this.answers = const [],
    this.pairs = const [],
    this.options,
    this.explanation = '',
    this.source = '',
    this.added = '',
  });

  /// Unique, date-prefixed id, e.g. `2026-10-14-003`.
  final String id;

  final GameType game;

  /// Free text chosen by the companion: prepositions, ser/estar, ...
  final String category;

  final Severity severity;

  /// `fill_gap`: sentence containing `___`.
  /// `order`: the correct sentence (the app shuffles the words).
  /// `repair`: the faulty sentence.
  /// `match`: a short instruction, e.g. "Match the verb to its noun".
  final String prompt;

  /// Accepted answers for `fill_gap`, `order` and `repair`. Empty for `match`.
  final List<String> answers;

  /// Pairs for `match`. Empty for the other games.
  final List<MatchPair> pairs;

  /// `fill_gap` only. If `null` the learner types the answer.
  final List<String>? options;

  /// Shown after answering.
  final String explanation;

  /// Where the companion created the question, e.g. `chat 2026-10-14`.
  final String source;

  /// When the companion created the question, e.g. `2026-10-14`.
  final String added;

  /// True when this is a `fill_gap` question with options to choose from.
  bool get hasOptions => options != null && options!.isNotEmpty;

  /// Converts back to the JSON shape used in `questions.json`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'game': game.jsonValue,
      'category': category,
      'severity': severity.jsonValue,
      'prompt': prompt,
      'answers': game == GameType.match
          ? pairs.map((p) => p.toJson()).toList()
          : answers,
      if (options != null) 'options': options,
      'explanation': explanation,
      'source': source,
      'added': added,
    };
  }

  @override
  String toString() => 'Question($id, ${game.jsonValue})';
}
