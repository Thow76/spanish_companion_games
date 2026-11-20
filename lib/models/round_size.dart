/// Questions per round (B32): how many of a card's open questions a game
/// plays when its card is opened, 5 or 10 (default 5), oldest first.
///
/// A question's date is the `YYYY-MM-DD` at the end of its `source`
/// ("Work and plans, 2026-10-14"), else the one at the start of `added`.
/// Questions with no date go last; questions with the same date keep their
/// file order. A card with fewer questions than the round size plays them
/// all. The card's count on home stays the total open.
///
/// Only the 5/10 choice from the reverted set picker (B24) comes back; no
/// sets, no grouping by conversation. Pure logic, no Flutter.
library;

import 'question.dart';

/// The choice of questions per round.
enum RoundSize {
  five(5),
  ten(10);

  const RoundSize(this.count);

  /// How many questions a round plays at most.
  final int count;

  /// The size used until Andrew chooses another.
  static const RoundSize standard = RoundSize.five;

  /// "5", "10": the label on the choice.
  String get label => '$count';
}

/// The questions a round plays: the first [size] of [open], oldest first.
List<Question> pickRound(List<Question> open, RoundSize size) {
  final sorted = sortOldestFirst(open);
  return sorted.length <= size.count ? sorted : sorted.sublist(0, size.count);
}

/// [questions] oldest first (see [questionDate]); undated last; ties keep
/// their order.
List<Question> sortOldestFirst(List<Question> questions) {
  final indexed = [
    for (var i = 0; i < questions.length; i++)
      (i, questionDate(questions[i]), questions[i]),
  ];
  indexed.sort((a, b) {
    final (ia, da, _) = a;
    final (ib, db, _) = b;
    if (da != null && db != null) {
      final c = da.compareTo(db);
      if (c != 0) return c;
    } else if (da != null) {
      return -1;
    } else if (db != null) {
      return 1;
    }
    return ia.compareTo(ib);
  });
  return [for (final (_, _, q) in indexed) q];
}

final RegExp _trailingDate = RegExp(r'(\d{4})-(\d{2})-(\d{2})\s*$');
final RegExp _leadingDate = RegExp(r'^\s*(\d{4})-(\d{2})-(\d{2})');

/// The question's date: the `YYYY-MM-DD` at the end of `source`, else the
/// one at the start of `added`; null if neither has a valid date.
DateTime? questionDate(Question q) =>
    _parse(_trailingDate.firstMatch(q.source)) ??
    _parse(_leadingDate.firstMatch(q.added));

DateTime? _parse(RegExpMatch? m) {
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  final date = DateTime.utc(y, mo, d);
  // Reject dates that roll over (2026-02-30).
  if (date.month != mo || date.day != d) return null;
  return date;
}
