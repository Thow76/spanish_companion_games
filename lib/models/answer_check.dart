/// Answer checking shared by the games.
///
/// Rule from the build plan: trim, ignore case, ignore final punctuation.
/// Accents must match, so no accent stripping happens here. Every listed
/// answer is accepted.
///
/// Per game (build plan, "Answer checking"):
/// - `choose_correction`, `fill_gap`, `order`: the learner's answer against
///   `answers` ([isAcceptedAnswer]).
/// - `repair`: the learner may type the whole sentence or only the
///   replacement for the marked words ([checkRepair]).
/// - `spot_error`: first "It's correct" or "It needs fixing", then, if it
///   needs fixing, the corrected sentence; both steps must be right
///   ([checkSpotError]).
/// - `match`: pairs are checked one at a time ([isMatchingPair]).
library;

import 'question.dart';

/// Characters treated as "final punctuation" and ignored at the end of an
/// answer. Includes the Spanish inverted marks so a stray `¿` or `¡` at the
/// start is also ignored.
const String _punctuation = '.,;:!?¡¿…';

/// Normalises an answer for comparison: trims whitespace, lowercases, and
/// removes punctuation from the start and end. Interior punctuation (commas
/// inside a sentence, for example) is kept.
String normaliseAnswer(String text) {
  var s = text.trim().toLowerCase();
  while (s.isNotEmpty && _punctuation.contains(s[s.length - 1])) {
    s = s.substring(0, s.length - 1).trimRight();
  }
  while (s.isNotEmpty && _punctuation.contains(s[0])) {
    s = s.substring(1).trimLeft();
  }
  // Collapse runs of whitespace so "pensar  en" matches "pensar en".
  return s.replaceAll(RegExp(r'\s+'), ' ');
}

/// True if [given] matches any of [accepted] under [normaliseAnswer].
bool isAcceptedAnswer(String given, Iterable<String> accepted) {
  final normalised = normaliseAnswer(given);
  if (normalised.isEmpty) return false;
  return accepted.any((a) => normaliseAnswer(a) == normalised);
}

/// Repair the sentence: true if [typed] is one of the accepted sentences,
/// or if putting [typed] in place of the marked words gives one.
///
/// With one marked span, [typed] replaces that span. With several, it
/// replaces the whole stretch from the first marked word to the last (see
/// [Question.replaceMarkedSpans]).
bool checkRepair(Question question, String typed) {
  if (normaliseAnswer(typed).isEmpty) return false;
  if (isAcceptedAnswer(typed, question.answers)) return true;
  if (!question.hasMarks) return false;
  // The part is normalised first, so a stray full stop after it does not
  // land in the middle of the sentence.
  return isAcceptedAnswer(
    question.replaceMarkedSpans(normaliseAnswer(typed)),
    question.answers,
  );
}

/// Spot the error: true when the sentence shown is already correct, that
/// is, when it matches one of the accepted answers.
bool spotErrorSentenceIsCorrect(Question question) =>
    isAcceptedAnswer(question.promptText, question.answers);

/// Spot the error: the learner first says whether the sentence is correct
/// ([saidCorrect]) and, if they said it needs fixing, types the corrected
/// sentence ([typed]). Both steps must be right.
///
/// - Sentence correct: right only if [saidCorrect] is true.
/// - Sentence wrong: right only if [saidCorrect] is false and [typed]
///   matches an accepted answer.
bool checkSpotError(
  Question question, {
  required bool saidCorrect,
  String? typed,
}) {
  final sentenceIsCorrect = spotErrorSentenceIsCorrect(question);
  if (saidCorrect) return sentenceIsCorrect;
  if (sentenceIsCorrect || typed == null) return false;
  return isAcceptedAnswer(typed, question.answers);
}

/// Matching: true if [left] and [right] form one of the question's pairs.
bool isMatchingPair(Question question, String left, String right) {
  final l = normaliseAnswer(left);
  final r = normaliseAnswer(right);
  return question.pairs.any(
    (p) => normaliseAnswer(p.left) == l && normaliseAnswer(p.right) == r,
  );
}
