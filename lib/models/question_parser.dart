/// Parses and validates `questions.json`.
///
/// The file is a JSON array with one object per question. Questions that fail
/// validation are reported in [ParsedQuestions.problems] and left out, so one
/// bad entry does not stop the rest of the file from loading.
library;

import 'dart:convert';

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

  /// Valid questions for one game.
  List<Question> forGame(GameType game) =>
      questions.where((q) => q.game == game).toList();
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

  final category = _optionalString(raw['category']) ?? '';

  final severityValue = _optionalString(raw['severity']);
  final Severity severity;
  if (severityValue == null || severityValue.isEmpty) {
    severity = Severity.error;
  } else {
    final parsed = Severity.fromJson(severityValue);
    if (parsed == null) {
      throw FormatException(
        '"severity" must be "error" or "suggestion", got "$severityValue"',
      );
    }
    severity = parsed;
  }

  final prompt = _requiredString(raw, 'prompt');
  if (game == GameType.fillGap && !prompt.contains('___')) {
    throw const FormatException(
      'a fill_gap "prompt" must contain ___ where the gap goes',
    );
  }

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

  List<String>? options;
  if (raw.containsKey('options') && raw['options'] != null) {
    if (game != GameType.fillGap) {
      throw FormatException(
        '"options" is only allowed for fill_gap questions, '
        'not ${game.jsonValue}',
      );
    }
    final rawOptions = raw['options'];
    if (rawOptions is! List || rawOptions.isEmpty) {
      throw const FormatException(
        '"options" must be a non-empty list of strings when present',
      );
    }
    options = _stringList(rawOptions, 'options');
    final hasCorrectOption = answers.any(options.contains);
    if (!hasCorrectOption) {
      throw const FormatException(
        '"options" must include at least one of the "answers"',
      );
    }
  }

  return Question(
    id: id,
    game: game,
    category: category,
    severity: severity,
    prompt: prompt,
    answers: answers,
    pairs: pairs,
    options: options,
    explanation: _optionalString(raw['explanation']) ?? '',
    source: _optionalString(raw['source']) ?? '',
    added: _optionalString(raw['added']) ?? '',
  );
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

String _describe(Object? value) {
  if (value == null) return 'null';
  if (value is String) return 'a string';
  if (value is num) return 'a number';
  if (value is bool) return 'a boolean';
  if (value is List) return 'a list of ${value.length}';
  if (value is Map) return 'an object';
  return value.runtimeType.toString();
}
