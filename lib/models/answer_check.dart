/// Answer checking shared by the games.
///
/// Rule from the build plan: trim, ignore case, ignore final punctuation.
/// Accents must match, so no accent stripping happens here.
library;

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
