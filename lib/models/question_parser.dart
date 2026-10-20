/// Parses and validates `questions.json` (2026-10-17 format, with phases).
///
/// The file is a JSON array with one object per question. Questions that fail
/// validation are reported in [ParsedQuestions.problems] and left out, so one
/// bad entry does not stop the rest of the file from loading.
///
/// Files written before 2026-10-17 still load: a missing `phase` is taken
/// from the game, and `severity: "error"` / `"suggestion"` is read as
/// `type: "grammar"` / `"note"`.
library;

import 'dart:convert';

import 'answer_check.dart';
import 'question.dart';

/// A problem found while validating one question.
class QuestionProblem {
  const QuestionProblem({
    required this.index,
    required this.id,
    required this.message,
  });

  /// Position of the question in the array (0-based).
  final int index;

  /// The question's `id` if it had one, otherwise `null`.
  final String? id;

  final String message;

  @override
  String toString() {
    final where = id == null ? 'question ${index + 1}' : 'question "$id"';
    return '$where: $message';
  }
}

/// The result of parsing a question file.
class ParsedQuestions {
  const ParsedQuestions({required this.questions, required this.problems});

  /// Questions that passed validation, in file order.
  final List<Question> questions;

  /// One entry for each question that was left out, in file order.
  final List<QuestionProblem> problems;

  bool get hasProblems => problems.isNotEmpty;

  /// Number of valid questions per game.
  Map<GameType, int> get countByGame {
    final counts = <GameType, int>{for (final g in GameType.values) g: 0};
    for (final q in questions) {
      counts[q.game] = counts[q.game]! + 1;
    }
    return counts;
  }

  /// Number of valid questions per phase.
  Map<QuestionPhase, int> get countByPhase {
    final counts = <QuestionPhase, int>{
      for (final p in QuestionPhase.values) p: 0,
    };
    for (final q in questions) {
      counts[q.phase] = counts[q.phase]! + 1;
    }
    return counts;
  }

  /// Valid questions for one game.
  List<Question> forGame(GameType game) =>
      questions.where((q) => q.game == game).toList();

  /// Valid questions for one phase.
  List<Question> forPhase(QuestionPhase phase) =>
      questions.where((q) => q.phase == phase).toList();
}

/// Thrown when the file as a whole cannot be read: not JSON, or not an array.
class QuestionFileException implements Exception {
  const QuestionFileException(this.message);

  final String message;

  @override
  String toString() => 'QuestionFileException: $message';
}

/// Parses the text of a `questions.json` file.
///
/// Throws [QuestionFileException] if the text is not JSON or the top level is
/// not an array. Individual invalid questions do not throw; they are reported
/// in [ParsedQuestions.problems].
ParsedQuestions parseQuestions(String jsonText) {
  final Object? decoded;
  try {
    decoded = jsonDecode(jsonText);
  } on FormatException catch (e) {
    throw QuestionFileException('File is not valid JSON: ${e.message}');
  }
  return parseQuestionList(decoded);
}

/// Parses an already-decoded JSON value (the result of `jsonDecode`).
ParsedQuestions parseQuestionList(Object? decoded) {
  if (decoded is! List) {
    throw QuestionFileException(
      'File must be a JSON array of questions, '
      'but the top level is ${_describe(decoded)}.',
    );
  }

  final questions = <Question>[];
  final problems = <QuestionProblem>[];
  final seenIds = <String>{};

  for (var i = 0; i < decoded.length; i++) {
    final raw = decoded[i];
    final id = raw is Map ? _optionalString(raw['id']) : null;
    try {
      final question = questionFromJson(raw);
      if (!seenIds.add(question.id)) {
        throw const FormatException('duplicate id');
      }
      questions.add(question);
    } on FormatException catch (e) {
      problems.add(QuestionProblem(index: i, id: id, message: e.message));
    }
  }

  return ParsedQuestions(questions: questions, problems: problems);
}

/// Builds one [Question] from its JSON object.
///
/// Throws [FormatException] with a plain-English message if the object does
/// not match the format.
Question questionFromJson(Object? raw) {
  if (raw is! Map) {
    throw FormatException('expected an object, got ${_describe(raw)}');
  }

  final id = _requiredString(raw, 'id');

  final gameValue = _requiredString(raw, 'game');
  final game = GameType.fromJson(gameValue);
  if (game == null) {
    throw FormatException(
      '"game" must be one of ${_gameValues()}, got "$gameValue"',
    );
  }

  // phase: optional (taken from the game when absent), but if given it must
  // be 1 or 2 and match the game's phase.
  if (raw.containsKey('phase') && raw['phase'] != null) {
    final rawPhase = raw['phase'];
    final phase = QuestionPhase.fromJson(rawPhase);
    if (phase == null) {
      throw FormatException('"phase" must be 1 or 2, got ${_show(rawPhase)}');
    }
    if (phase != game.phase) {
      throw FormatException(
        '${game.jsonValue} is a phase ${game.phase.number} game, '
        'but "phase" is ${phase.number}',
      );
    }
  }

  final category = _optionalString(raw['category']) ?? '';

  final type = _parseType(raw);

  final prompt = _requiredString(raw, 'prompt');
  if (game == GameType.fillGap && !prompt.contains('___')) {
    throw const FormatException(
      'a fill_gap "prompt" must contain ___ where the gap goes',
    );
  }
  final markProblem = promptMarkProblem(prompt, game);
  if (markProblem != null) throw FormatException(markProblem);
  final promptRuns = parsePromptMarks(prompt);

  final rawAnswers = raw['answers'];
  if (rawAnswers is! List || rawAnswers.isEmpty) {
    throw const FormatException('"answers" must be a non-empty list');
  }

  var answers = const <String>[];
  var pairs = const <MatchPair>[];
  if (game == GameType.match) {
    pairs = _parsePairs(rawAnswers);
  } else {
    answers = _stringList(rawAnswers, 'answers');
  }

  final options = _parseOptions(raw, game, answers, promptRuns);

  var missingWord = false;
  if (raw.containsKey('missing_word') && raw['missing_word'] != null) {
    final rawMissing = raw['missing_word'];
    if (rawMissing is! bool) {
      throw FormatException(
        '"missing_word" must be true or false, got ${_describe(rawMissing)}',
      );
    }
    if (rawMissing && !game.isPhase1) {
      throw FormatException(
        '"missing_word" is only for phase 1 questions, not ${game.jsonValue}',
      );
    }
    missingWord = rawMissing;
  }

  return Question(
    id: id,
    game: game,
    category: category,
    type: type,
    prompt: prompt,
    promptRuns: promptRuns,
    answers: answers,
    pairs: pairs,
    options: options,
    missingWord: missingWord,
    explanation: _optionalString(raw['explanation']) ?? '',
    rule: _optionalText(raw['rule']),
    meaning: _optionalText(raw['meaning']),
    source: _optionalString(raw['source']) ?? '',
    added: _optionalString(raw['added']) ?? '',
  );
}

/// `type` ("grammar" / "note"); the old `severity` ("error" / "suggestion")
/// is read when `type` is absent. Missing both defaults to `grammar`.
QuestionType _parseType(Map<dynamic, dynamic> raw) {
  final typeValue = _optionalString(raw['type']);
  if (typeValue != null && typeValue.isNotEmpty) {
    final type = QuestionType.fromJson(typeValue);
    if (type == null) {
      throw FormatException(
        '"type" must be "grammar" or "note", got "$typeValue"',
      );
    }
    return type;
  }
  final severityValue = _optionalString(raw['severity']);
  if (severityValue != null && severityValue.isNotEmpty) {
    final type = QuestionType.fromLegacySeverity(severityValue);
    if (type == null) {
      throw FormatException(
        '"severity" (old format) must be "error" or "suggestion", '
        'got "$severityValue"',
      );
    }
    return type;
  }
  return QuestionType.grammar;
}

/// `options`: required for `choose_correction` (at least two), optional for
/// `fill_gap`, not allowed elsewhere. Must include an accepted answer and,
/// for `choose_correction`, must not include the marked words unchanged.
List<String>? _parseOptions(
  Map<dynamic, dynamic> raw,
  GameType game,
  List<String> answers,
  List<PromptRun> promptRuns,
) {
  final present = raw.containsKey('options') && raw['options'] != null;
  if (!present) {
    if (game == GameType.chooseCorrection) {
      throw const FormatException(
        'a choose_correction question must have "options" to choose from',
      );
    }
    return null;
  }
  if (game != GameType.fillGap && game != GameType.chooseCorrection) {
    throw FormatException(
      '"options" is only allowed for choose_correction and fill_gap '
      'questions, not ${game.jsonValue}',
    );
  }
  final rawOptions = raw['options'];
  if (rawOptions is! List || rawOptions.isEmpty) {
    throw const FormatException(
      '"options" must be a non-empty list of strings when present',
    );
  }
  final options = _stringList(rawOptions, 'options');
  if (game == GameType.chooseCorrection && options.length < 2) {
    throw const FormatException(
      'a choose_correction question needs at least two "options"',
    );
  }
  if (!answers.any((a) => isAcceptedAnswer(a, options))) {
    throw const FormatException(
      '"options" must include at least one of the "answers"',
    );
  }
  if (game == GameType.chooseCorrection) {
    final marked = [
      for (final run in promptRuns)
        if (run.marked) run.text,
    ];
    if (options.any((o) => isAcceptedAnswer(o, marked))) {
      throw const FormatException(
        '"options" must not include the marked words unchanged',
      );
    }
  }
  return options;
}

List<MatchPair> _parsePairs(List<dynamic> rawAnswers) {
  final pairs = <MatchPair>[];
  for (var i = 0; i < rawAnswers.length; i++) {
    final item = rawAnswers[i];
    if (item is! List || item.length != 2) {
      throw FormatException(
        'match "answers" must be a list of [left, right] pairs; '
        'pair ${i + 1} is ${_describe(item)}',
      );
    }
    final left = item[0];
    final right = item[1];
    if (left is! String ||
        right is! String ||
        left.trim().isEmpty ||
        right.trim().isEmpty) {
      throw FormatException(
        'match "answers" pair ${i + 1} must hold two non-empty strings',
      );
    }
    pairs.add(MatchPair(left, right));
  }
  if (pairs.length < 2) {
    throw const FormatException('a match question needs at least two pairs');
  }
  return pairs;
}

String _requiredString(Map<dynamic, dynamic> raw, String key) {
  final value = raw[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('"$key" is required and must be a non-empty string');
  }
  return value;
}

String? _optionalString(Object? value) => value is String ? value : null;

/// An optional string that is `null` when absent or blank.
String? _optionalText(Object? value) {
  final s = _optionalString(value);
  if (s == null || s.trim().isEmpty) return null;
  return s;
}

List<String> _stringList(List<dynamic> list, String key) {
  final result = <String>[];
  for (var i = 0; i < list.length; i++) {
    final item = list[i];
    if (item is! String || item.trim().isEmpty) {
      throw FormatException(
        '"$key" must contain only non-empty strings; '
        'item ${i + 1} is ${_describe(item)}',
      );
    }
    result.add(item);
  }
  return result;
}

String _gameValues() =>
    GameType.values.map((g) => '"${g.jsonValue}"').join(', ');

String _show(Object? value) {
  if (value is String) return '"$value"';
  if (value is num || value is bool) return '$value';
  return _describe(value);
}

String _describe(Object? value) {
  if (value == null) return 'null';
  if (value is String) return 'a string';
  if (value is num) return 'a number';
  if (value is bool) return 'a boolean';
  if (value is List) return 'a list of ${value.length}';
  if (value is Map) return 'an object';
  return value.runtimeType.toString();
}
