/// What the ExplanationCard and FeedbackPanel show, built from a question
/// (UI spec section 6, ExplanationCard "Data", and section 13's default):
///
/// 1. The question's optional `rule` and `meaning` fields, if present.
/// 2. Otherwise, if `explanation` has the shape "pattern = meaning", split
///    it there: the left side becomes the rule chips (the word matching the
///    accepted answer is the mint chip; grammar words such as "infinitive"
///    become placeholder chips; "+" stays plain), the right side "Meaning".
/// 3. Otherwise the plain `explanation` text.
///
/// A rule that lists several patterns ("pensar en, depender de") keeps each
/// comma or semicolon out of the chips: it becomes a "·" joiner between
/// them.
///
/// Display only; answer checking lives in `lib/models/`.
library;

import 'sentence_text.dart';

enum RulePartKind {
  /// A Spanish word of the pattern: neutral chip.
  word,

  /// The word that answers the question: mint chip.
  answer,

  /// A joining symbol such as "+": plain muted text.
  joiner,

  /// A grammatical placeholder such as "infinitive": dashed chip.
  placeholder,
}

typedef RulePart = ({String text, RulePartKind kind});

/// One run of the "You wrote" line; [wrong] runs are struck through in
/// coral.
typedef WrotePart = ({String text, bool wrong});

class ExplanationContent {
  const ExplanationContent({
    this.rule,
    this.meaning,
    this.youWrote,
    this.plainText,
  });

  /// The rule as chips. Null means the plain-text fallback.
  final List<RulePart>? rule;

  /// The "Meaning" line.
  final String? meaning;

  /// The "You wrote" line, for wrong answers only.
  final List<WrotePart>? youWrote;

  /// The fallback text, shown when there are no chips.
  final String? plainText;

  bool get isFallback => rule == null || rule!.isEmpty;

  /// Grammar words shown as placeholder chips, not Spanish words.
  static const Set<String> placeholderWords = {
    'infinitive',
    'subjunctive',
    'indicative',
    'gerund',
    'participle',
    'plural',
    'singular',
    'noun',
    'verb',
    'adjective',
    'adverb',
    'pronoun',
    'object',
    'clause',
    'person',
    'thing',
    'place',
    'time',
    'something',
    'someone',
    'sth',
    'sb',
  };

  /// The joiner a comma or semicolon in a rule becomes ("pensar en ·
  /// depender de").
  static const String listSeparator = '·';

  static const Set<String> _joiners = {
    '+',
    '/',
    '→',
    '...',
    '…',
    listSeparator,
  };

  /// Builds the content for a question.
  ///
  /// [answers] are the question's accepted answers. For a wrong choice pass
  /// [chosen] (the option picked); for a wrong typed answer pass [typed]
  /// (the learner's text) and [typedAgainst] (the accepted sentence it is
  /// compared with). Leave both null for a right answer.
  ///
  /// [allAnswers] makes every answer that appears in the rule a mint chip,
  /// not just the first one found (Matching, where each right-hand word is
  /// an answer).
  factory ExplanationContent.build({
    required String explanation,
    String? rule,
    String? meaning,
    List<String> answers = const [],
    String? chosen,
    String? typed,
    String? typedAgainst,
    bool allAnswers = false,
  }) {
    var ruleText = rule?.trim();
    var meaningText = meaning?.trim();
    if (ruleText == null || ruleText.isEmpty) {
      final split = explanation.indexOf(' = ');
      if (split > 0) {
        ruleText = explanation.substring(0, split).trim();
        meaningText ??= explanation.substring(split + 3).trim();
      }
    }
    if (ruleText == null || ruleText.isEmpty) {
      return ExplanationContent(plainText: explanation.trim());
    }

    final parts = parseRule(ruleText, answers, allAnswers: allAnswers);
    if (parts.isEmpty) {
      return ExplanationContent(plainText: explanation.trim());
    }

    List<WrotePart>? youWrote;
    if (chosen != null) {
      youWrote = _youWroteChoice(parts, chosen);
    } else if (typed != null) {
      youWrote = _youWroteTyped(typed, typedAgainst ?? '');
    }

    return ExplanationContent(
      rule: parts,
      meaning: (meaningText == null || meaningText.isEmpty)
          ? null
          : _trimFullStop(meaningText),
      youWrote: youWrote,
    );
  }

  static String _trimFullStop(String s) =>
      s.endsWith('.') && !s.endsWith('...') ? s.substring(0, s.length - 1) : s;

  static String _key(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'^[¿¡"«(]+|[.,;:!?"»)]+$'), '');

  /// Splits a rule such as "pensar en + infinitive" into chips. A
  /// multi-word answer ("me acuerdo de") becomes one mint chip. A comma or
  /// semicolon at the end of a word becomes a [listSeparator] joiner, so
  /// the chips never carry it ("en," → [en] ·).
  ///
  /// By default only the first accepted answer found in the rule is mint;
  /// with [allAnswers] every place an answer appears is.
  static List<RulePart> parseRule(
    String rule,
    List<String> answers, {
    bool allAnswers = false,
  }) {
    final tokens = <String>[];
    for (final word in SentenceText.words(_trimFullStop(rule.trim()))) {
      final listEnd =
          word.length > 1 && (word.endsWith(',') || word.endsWith(';'));
      if (!listEnd) {
        tokens.add(word);
        continue;
      }
      tokens.add(word.substring(0, word.length - 1));
      tokens.add(listSeparator);
    }
    while (tokens.isNotEmpty && tokens.last == listSeparator) {
      tokens.removeLast();
    }
    final keys = tokens.map(_key).toList();
    final parts = <RulePart>[];

    final answerWords = [
      for (final answer in answers)
        SentenceText.words(answer).map(_key).toList(),
    ].where((w) => w.isNotEmpty).toList();

    bool matchesAt(List<String> words, int i) {
      if (i + words.length > keys.length) return false;
      for (var k = 0; k < words.length; k++) {
        if (keys[i + k] != words[k]) return false;
      }
      return true;
    }

    // Where the answers sit: start index → number of words.
    final answerAt = <int, int>{};
    if (allAnswers) {
      // Longest answers first, so "una decisión" wins over "una".
      final longestFirst = List<List<String>>.of(answerWords)
        ..sort((a, b) => b.length.compareTo(a.length));
      for (var i = 0; i < keys.length; i++) {
        for (final words in longestFirst) {
          if (matchesAt(words, i)) {
            answerAt[i] = words.length;
            i += words.length - 1;
            break;
          }
        }
      }
    } else {
      // The first accepted answer that appears in the rule.
      for (final words in answerWords) {
        for (var i = 0; i < keys.length; i++) {
          if (matchesAt(words, i)) {
            answerAt[i] = words.length;
            break;
          }
        }
        if (answerAt.isNotEmpty) break;
      }
    }

    for (var i = 0; i < tokens.length; i++) {
      final answerLength = answerAt[i];
      if (answerLength != null) {
        parts.add((
          text: tokens.sublist(i, i + answerLength).join(' '),
          kind: RulePartKind.answer,
        ));
        i += answerLength - 1;
        continue;
      }
      final token = tokens[i];
      final key = _key(token);
      final kind = _joiners.contains(token)
          ? RulePartKind.joiner
          : (placeholderWords.contains(key) ||
                (token.startsWith('(') && token.endsWith(')')) ||
                (token.startsWith('<') && token.endsWith('>')))
          ? RulePartKind.placeholder
          : RulePartKind.word;
      // Neighbouring placeholders ("plural noun") share one chip.
      if (kind == RulePartKind.placeholder &&
          parts.isNotEmpty &&
          parts.last.kind == RulePartKind.placeholder) {
        final previous = parts.removeLast();
        parts.add((
          text: '${previous.text} $token',
          kind: RulePartKind.placeholder,
        ));
        continue;
      }
      parts.add((text: token, kind: kind));
    }
    return parts;
  }

  /// "pensar ~~de~~": the Spanish words of the pattern with the learner's
  /// choice in place of the answer. If the answer is not in the pattern
  /// (rule "ver a + person", answer "ver a mis"), just the choice, struck
  /// through, rather than tacking it onto the pattern ("ver a ver a los").
  static List<WrotePart> _youWroteChoice(List<RulePart> parts, String chosen) {
    if (!parts.any((p) => p.kind == RulePartKind.answer)) {
      return [(text: chosen, wrong: true)];
    }
    final out = <WrotePart>[];
    for (final part in parts) {
      switch (part.kind) {
        case RulePartKind.word:
          out.add((text: part.text, wrong: false));
        case RulePartKind.answer:
          out.add((text: chosen, wrong: true));
        case RulePartKind.joiner:
        case RulePartKind.placeholder:
          break;
      }
    }
    return out;
  }

  /// The learner's sentence with the words that differ from the accepted
  /// answer struck through.
  static List<WrotePart> _youWroteTyped(String typed, String against) => [
    for (final w in SentenceText.diff(typed, against))
      (text: w.word, wrong: w.changed),
  ];

  /// The rule read as one phrase: "pensar en plus infinitive"; a list
  /// separator is read as a comma ("pensar en, depender de").
  String get spokenRule {
    final out = StringBuffer();
    for (final p in rule ?? const <RulePart>[]) {
      if (p.text == listSeparator && p.kind == RulePartKind.joiner) {
        out.write(',');
        continue;
      }
      if (out.isNotEmpty) out.write(' ');
      out.write(p.text == '+' ? 'plus' : p.text);
    }
    return out.toString();
  }

  /// "pensar de, wrong" for the "You wrote" line.
  String get spokenYouWrote {
    final parts = youWrote ?? const <WrotePart>[];
    final text = parts.map((p) => p.text).join(' ');
    return parts.any((p) => p.wrong) ? '$text, wrong' : text;
  }
}
