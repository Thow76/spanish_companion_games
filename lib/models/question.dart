/// Question model for the Spanish Companion games.
///
/// Mirrors the `questions.json` format described in the build plan
/// (2026-10-17 version, with phases):
///
/// ```json
/// {
///   "id": "2026-10-17-001",
///   "phase": 1,
///   "game": "choose_correction",
///   "type": "grammar",
///   "category": "Prepositions",
///   "prompt": "Estoy pensando **de** cambiar de trabajo.",
///   "answers": ["en"],
///   "options": ["en", "a", "por"],
///   "explanation": "pensar en + infinitive = to be thinking of doing something",
///   "source": "Work and plans, 2026-10-14",
///   "added": "2026-10-17"
/// }
/// ```
///
/// Phase 1 prompts are Andrew's own sentence with the problem words wrapped
/// in `**…**`; the model parses those into [Question.promptRuns] and
/// [Question.markedSpans]. Phase 2 prompts never contain `**`.
library;

/// The two phases. Every game belongs to exactly one phase.
enum QuestionPhase {
  /// Phase 1, notice and correct: Andrew's own sentence with the problem
  /// words marked, for him to correct.
  noticeAndCorrect(1, 'New corrections'),

  /// Phase 2, recall: points already corrected, in new sentences on the
  /// same pattern, with nothing marked.
  recall(2, 'Recall');

  const QuestionPhase(this.number, this.label);

  /// Value of the `phase` field in the JSON file: 1 or 2.
  final int number;

  /// The home screen group heading for this phase.
  final String label;

  /// Returns the phase for a JSON value (1 or 2), or `null` otherwise.
  static QuestionPhase? fromJson(Object? value) {
    for (final phase in QuestionPhase.values) {
      if (phase.number == value) return phase;
    }
    return null;
  }
}

/// The six games, in home-screen order (phase 1 first). [jsonValue] is the
/// string used in `questions.json`.
enum GameType {
  chooseCorrection(
    'choose_correction',
    'Choose a correction',
    QuestionPhase.noticeAndCorrect,
  ),
  repair('repair', 'Repair the sentence', QuestionPhase.noticeAndCorrect),
  fillGap('fill_gap', 'Fill the gap', QuestionPhase.recall),
  match('match', 'Matching', QuestionPhase.recall),
  order('order', 'Sentence ordering', QuestionPhase.recall),
  spotError('spot_error', 'Spot the error', QuestionPhase.recall);

  const GameType(this.jsonValue, this.label, this.phase);

  /// Value of the `game` field in the JSON file.
  final String jsonValue;

  /// Human-readable name for buttons and headings.
  final String label;

  /// The phase this game belongs to.
  final QuestionPhase phase;

  /// True for the phase 1 games, whose prompts carry marked words.
  bool get isPhase1 => phase == QuestionPhase.noticeAndCorrect;

  /// Returns the game for a JSON value, or `null` if it is not one of the six.
  static GameType? fromJson(String? value) {
    for (final game in GameType.values) {
      if (game.jsonValue == value) return game;
    }
    return null;
  }

  /// The games of one phase, in home-screen order.
  static List<GameType> forPhase(QuestionPhase phase) =>
      GameType.values.where((g) => g.phase == phase).toList();
}

/// What kind of point the question makes. Replaced `severity` on 2026-10-17.
enum QuestionType {
  /// A grammatical mistake: prepositions, tense, mood, ser/estar, agreement,
  /// articles, pronouns, word order, ...
  grammar('grammar', 'Grammar error'),

  /// Possible, but not what a native speaker would say: calque, unnatural
  /// phrasing, collocation, false friend, word choice, register.
  note('note', 'Language note');

  const QuestionType(this.jsonValue, this.label);

  /// Value of the `type` field in the JSON file.
  final String jsonValue;

  /// The label shown on the category chip ("Grammar error · Prepositions").
  final String label;

  /// Returns the type for a JSON value, or `null` if it is not one of the two.
  static QuestionType? fromJson(String? value) {
    for (final type in QuestionType.values) {
      if (type.jsonValue == value) return type;
    }
    return null;
  }

  /// Reads the pre-2026-10-17 `severity` values: `error` is a [grammar]
  /// point and `suggestion` a [note]. Returns `null` for anything else.
  static QuestionType? fromLegacySeverity(String? value) => switch (value) {
    'error' => QuestionType.grammar,
    'suggestion' => QuestionType.note,
    _ => null,
  };
}

/// One run of a prompt sentence: its text, and whether it was inside `**…**`.
///
/// The asterisks are never part of [text].
class PromptRun {
  const PromptRun(this.text, {required this.marked});

  final String text;

  /// True for the problem words of a phase 1 prompt.
  final bool marked;

  @override
  bool operator ==(Object other) =>
      other is PromptRun && other.text == text && other.marked == marked;

  @override
  int get hashCode => Object.hash(text, marked);

  @override
  String toString() => marked ? 'PromptRun(**$text**)' : 'PromptRun($text)';
}

/// One pair for the `match` game, e.g. `pensar` / `en`.
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
/// For every game but `match`, [answers] holds the accepted answers and
/// [pairs] is empty. For `match`, [pairs] holds the pairs to match and
/// [answers] is empty.
class Question {
  /// Builds a question. [promptRuns] is worked out from [prompt] when not
  /// given, so the marks in a phase 1 prompt are available straight away.
  Question({
    required this.id,
    required this.game,
    required this.category,
    required this.type,
    required this.prompt,
    this.answers = const [],
    this.pairs = const [],
    this.options,
    this.missingWord = false,
    this.explanation = '',
    this.rule,
    this.meaning,
    this.source = '',
    this.added = '',
    List<PromptRun>? promptRuns,
  }) : promptRuns = promptRuns ?? parsePromptMarks(prompt);

  /// Unique, date-prefixed id, e.g. `2026-10-17-001`.
  final String id;

  final GameType game;

  /// The phase, which is the game's phase.
  QuestionPhase get phase => game.phase;

  /// Plain-English label chosen by the companion: Prepositions, Verb forms,
  /// Sentence structure, Calque, ... Never the answer pattern.
  final String category;

  final QuestionType type;

  /// The prompt exactly as written in the file, marks included:
  /// - `choose_correction`: Andrew's original sentence, one span marked.
  /// - `repair`: Andrew's original sentence, problem words marked (one span
  ///   or several).
  /// - `fill_gap`: a new sentence containing `___`.
  /// - `match`: a short instruction, e.g. "Match the verb to its preposition".
  /// - `order`: the correct sentence (the app shuffles the words).
  /// - `spot_error`: the sentence as shown, correct or not.
  ///
  /// For display use [promptRuns] or [promptText], which never show the
  /// asterisks.
  final String prompt;

  /// [prompt] split into plain and marked runs. Phase 2 prompts are one
  /// plain run.
  final List<PromptRun> promptRuns;

  /// [prompt] without its marks: the sentence as the learner sees it.
  String get promptText => promptRuns.map((r) => r.text).join();

  /// The marked words of a phase 1 prompt, in order. Empty in phase 2.
  List<String> get markedSpans => [
    for (final run in promptRuns)
      if (run.marked) run.text,
  ];

  /// True when the prompt has marked words (phase 1).
  bool get hasMarks => promptRuns.any((r) => r.marked);

  /// Accepted answers:
  /// - `choose_correction`: the correct replacement(s) for the marked span.
  /// - `repair`: one or more full corrected sentences.
  /// - `fill_gap`: accepted fills.
  /// - `order`: the correct sentence, alternatives allowed.
  /// - `spot_error`: corrected sentence(s); the sentence itself if it was
  ///   already correct.
  ///
  /// Empty for `match`.
  final List<String> answers;

  /// Pairs for `match`. Empty for the other games.
  final List<MatchPair> pairs;

  /// `choose_correction` (always present) and `fill_gap` (optional: if
  /// `null` the learner types). Never includes the learner's unchanged
  /// original.
  final List<String>? options;

  /// Phase 1 only. True when the mistake is an omitted word: the marked
  /// words are the ones around the omission, and the screen says a word is
  /// missing.
  final bool missingWord;

  /// Shown after answering, in the form "pattern = meaning" where possible.
  final String explanation;

  /// Optional (UI spec section 13): the rule as a short pattern, e.g.
  /// "pensar en + infinitive". When absent the explanation card splits
  /// [explanation] on " = " instead.
  final String? rule;

  /// Optional (UI spec section 13): what the rule means, e.g. "to be
  /// thinking of doing something".
  final String? meaning;

  /// Where the mistake came from: conversation topic and date.
  final String source;

  /// When the question was written, e.g. `2026-10-17`.
  final String added;

  /// True when there are options to choose from (always for
  /// `choose_correction`; `fill_gap` with options).
  bool get hasOptions => options != null && options!.isNotEmpty;

  /// The corrected sentence to show after checking, or `null` for games
  /// that have none (`fill_gap`, `match`, `order`):
  /// - `choose_correction`: the prompt with the marked span replaced by the
  ///   first accepted answer.
  /// - `repair` and `spot_error`: the first accepted sentence.
  String? get correctedSentence {
    if (answers.isEmpty) return null;
    return switch (game) {
      GameType.chooseCorrection => replaceMarkedSpans(answers.first),
      GameType.repair || GameType.spotError => answers.first,
      _ => null,
    };
  }

  /// The prompt text with its marked words replaced. With one marked span,
  /// [replacement] takes its place. With several (a `repair` prompt), the
  /// whole stretch from the first marked word to the last is replaced.
  String replaceMarkedSpans(String replacement) {
    final first = promptRuns.indexWhere((r) => r.marked);
    if (first < 0) return promptText;
    final last = promptRuns.lastIndexWhere((r) => r.marked);
    final out = StringBuffer();
    for (var i = 0; i < promptRuns.length; i++) {
      if (i == first) {
        out.write(replacement);
      } else if (i < first || i > last) {
        out.write(promptRuns[i].text);
      }
    }
    return out.toString();
  }

  /// Converts back to the JSON shape used in `questions.json`.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phase': phase.number,
      'game': game.jsonValue,
      'type': type.jsonValue,
      'category': category,
      'prompt': prompt,
      'answers': game == GameType.match
          ? pairs.map((p) => p.toJson()).toList()
          : answers,
      if (options != null) 'options': options,
      if (missingWord) 'missing_word': true,
      'explanation': explanation,
      if (rule != null) 'rule': rule,
      if (meaning != null) 'meaning': meaning,
      'source': source,
      'added': added,
    };
  }

  @override
  String toString() => 'Question($id, ${game.jsonValue})';
}

/// The marker around the problem words of a phase 1 prompt.
const String promptMark = '**';

/// Splits [prompt] into plain and marked runs on `**`.
///
/// Lenient: an unclosed `**` is treated as plain text (the parser rejects
/// it separately with [promptMarkProblem]). Empty runs are dropped.
List<PromptRun> parsePromptMarks(String prompt) {
  final parts = prompt.split(promptMark);
  final closed = parts.length.isOdd;
  final runs = <PromptRun>[];
  for (var i = 0; i < parts.length; i++) {
    final marked = i.isOdd && (closed || i < parts.length - 1);
    if (parts[i].isEmpty) continue;
    runs.add(PromptRun(parts[i], marked: marked));
  }
  return runs;
}

/// Checks the `**…**` marks of a prompt for [game]. Returns a plain-English
/// problem, or `null` when the marks are as the format requires:
/// - phase 1 (`choose_correction`, `repair`): every `**` closed, no empty
///   span, at least one marked span; exactly one for `choose_correction`.
/// - phase 2: no `**` at all.
String? promptMarkProblem(String prompt, GameType game) {
  final parts = prompt.split(promptMark);
  final markCount = parts.length - 1;
  if (!game.isPhase1) {
    return markCount == 0
        ? null
        : 'a ${game.jsonValue} "prompt" must not contain ** marks '
              '(nothing is marked in phase 2)';
  }
  if (markCount == 0) {
    return 'a ${game.jsonValue} "prompt" must mark the problem words '
        'with **…**';
  }
  if (markCount.isOdd) {
    return '"prompt" has an unclosed ** mark';
  }
  for (var i = 1; i < parts.length; i += 2) {
    if (parts[i].trim().isEmpty) {
      return '"prompt" has an empty ** ** mark';
    }
  }
  final spans = markCount ~/ 2;
  if (game == GameType.chooseCorrection && spans != 1) {
    return 'a choose_correction "prompt" must mark exactly one span, '
        'got $spans';
  }
  return null;
}
