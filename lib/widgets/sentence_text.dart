/// Text helpers for the Spanish sentence: the `**…**` marks of a phase 1
/// prompt, and a plain word-by-word comparison used to show which words
/// changed (UI spec section 6, PromptCard and ExplanationCard).
///
/// Display only: answer checking lives in `lib/models/`.
library;

/// One run of a phase 1 prompt: text, and whether it was inside `**…**`.
typedef MarkedRun = ({String text, bool marked});

/// One word of a sentence, and whether it differs from the other sentence.
typedef DiffWord = ({String word, bool changed});

abstract final class SentenceText {
  static const String _mark = '**';

  /// Splits [sentence] into plain and marked runs. The asterisks are never
  /// part of the text. An unclosed `**` is dropped and the rest is plain.
  static List<MarkedRun> parseMarks(String sentence) {
    final parts = sentence.split(_mark);
    final closed = parts.length.isOdd;
    final runs = <MarkedRun>[];
    for (var i = 0; i < parts.length; i++) {
      final marked = i.isOdd && (closed || i < parts.length - 1);
      if (parts[i].isEmpty) continue;
      runs.add((text: parts[i], marked: marked));
    }
    return runs;
  }

  /// [sentence] without its marks.
  static String stripMarks(String sentence) => sentence.replaceAll(_mark, '');

  /// [sentence] with its first marked span replaced by [replacement] and
  /// the marks removed: the corrected sentence in Choose a correction.
  static String replaceFirstMark(String sentence, String replacement) {
    final runs = parseMarks(sentence);
    final out = StringBuffer();
    var replaced = false;
    for (final run in runs) {
      if (run.marked && !replaced) {
        out.write(replacement);
        replaced = true;
      } else {
        out.write(run.text);
      }
    }
    return out.toString();
  }

  /// The words of [sentence] split on white space.
  static List<String> words(String sentence) =>
      sentence.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

  static String _key(String word) =>
      word.toLowerCase().replaceAll(RegExp(r'^[¿¡"«(]+|[.,;:!?"»)]+$'), '');

  /// The words of [target], each marked `changed` if it is not part of the
  /// longest run of words shared with [other] (case and edge punctuation
  /// ignored, accents kept).
  static List<DiffWord> diff(String target, String other) {
    final a = words(target);
    final b = words(other);
    final ka = a.map(_key).toList();
    final kb = b.map(_key).toList();
    // Longest common subsequence table.
    final table = List.generate(
      a.length + 1,
      (_) => List<int>.filled(b.length + 1, 0),
    );
    for (var i = a.length - 1; i >= 0; i--) {
      for (var j = b.length - 1; j >= 0; j--) {
        table[i][j] = ka[i] == kb[j]
            ? table[i + 1][j + 1] + 1
            : (table[i + 1][j] > table[i][j + 1]
                  ? table[i + 1][j]
                  : table[i][j + 1]);
      }
    }
    final kept = List<bool>.filled(a.length, false);
    var i = 0;
    var j = 0;
    while (i < a.length && j < b.length) {
      if (ka[i] == kb[j]) {
        kept[i] = true;
        i++;
        j++;
      } else if (table[i + 1][j] >= table[i][j + 1]) {
        i++;
      } else {
        j++;
      }
    }
    return [for (var k = 0; k < a.length; k++) (word: a[k], changed: !kept[k])];
  }

  /// Whether a diff is clear enough to show word by word: something
  /// changed, and no more than half the words did.
  static bool isClear(List<DiffWord> diff) {
    final changed = diff.where((w) => w.changed).length;
    return changed > 0 && changed * 2 <= diff.length;
  }

  /// The words that changed in [target] compared with [other], for finding
  /// the answer chip in a rule when the answer is a whole sentence (Repair,
  /// Spot the error). Each run of neighbouring changed words comes first
  /// ("me llamo"), then each changed word on its own ("llamo"), without
  /// repeats (case and edge punctuation ignored).
  static List<String> changedRuns(String target, String other) {
    final diff = SentenceText.diff(target, other);
    final runs = <List<String>>[];
    var current = <String>[];
    for (final w in diff) {
      if (w.changed) {
        current.add(w.word);
      } else if (current.isNotEmpty) {
        runs.add(current);
        current = <String>[];
      }
    }
    if (current.isNotEmpty) runs.add(current);

    final seen = <String>{};
    final out = <String>[];
    void add(List<String> words) {
      final text = words.join(' ');
      final key = words.map(_key).join(' ');
      if (key.trim().isEmpty || !seen.add(key)) return;
      out.add(text);
    }

    for (final run in runs) {
      add(run);
    }
    for (final run in runs) {
      if (run.length < 2) continue;
      for (final word in run) {
        add([word]);
      }
    }
    return out;
  }
}
