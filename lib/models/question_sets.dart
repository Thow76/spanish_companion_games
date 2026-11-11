/// Sets of questions for the set picker (Flow v2, B24).
///
/// The questions of one phase are put oldest first and cut into sets of the
/// chosen size (5 or 10):
///
/// - Without "by conversation": consecutive sets of that size, oldest
///   first (the last one may be smaller).
/// - With "by conversation": one set per conversation (`source`), the
///   conversations oldest first; a conversation with more questions than
///   the set size is split into sets of that size ("1 of 2", "2 of 2").
///
/// A question's date is the `YYYY-MM-DD` at the end of its `source`
/// ("Work and plans, 2026-10-14"), else its `added` date. Questions with
/// no date go last. Questions with the same date keep their file order.
///
/// Pure logic, no Flutter; the screen is `set_picker_screen.dart`.
library;

import 'question.dart';

/// The set sizes Andrew can choose from.
const List<int> setSizes = [5, 10];

/// The size chosen when the picker is first opened.
const int defaultSetSize = 5;

/// One set of questions to play.
class QuestionSet {
  const QuestionSet({
    required this.questions,
    required this.conversations,
    this.firstDate,
    this.lastDate,
    this.part = 1,
    this.parts = 1,
  });

  /// The questions, oldest first.
  final List<Question> questions;

  /// The conversation names in the set ("Work and plans"), each once, in
  /// the order first met. Empty names (no `source`) are left out.
  final List<String> conversations;

  /// The oldest and newest question dates in the set (null if none of its
  /// questions has a date).
  final DateTime? firstDate;
  final DateTime? lastDate;

  /// With "by conversation", which part of a split conversation this is
  /// ("1 of 2"); 1 of 1 otherwise.
  final int part;
  final int parts;

  int get length => questions.length;

  bool get isSplit => parts > 1;

  /// The set's title: its conversation ("Work and plans"), or for a set
  /// across several, the first and how many more ("Work and plans + 2
  /// more"); "Other mistakes" when no question says where it came from.
  String get title {
    if (conversations.isEmpty) return noConversationLabel;
    if (conversations.length == 1) return conversations.first;
    return '${conversations.first} + ${conversations.length - 1} more';
  }

  /// The line under the title: date or date range, "1 of 2" when a
  /// conversation is split ("14 Oct · 1 of 2", "14–16 Oct"). Empty if
  /// there is neither.
  String get detail {
    final parts = <String>[
      if (firstDate != null) dateRangeText(firstDate!, lastDate ?? firstDate!),
      if (isSplit) '$part of ${this.parts}',
    ];
    return parts.join(' · ');
  }

  static const String noConversationLabel = 'Other mistakes';
}

/// Cuts [questions] into sets of [size], oldest first; one conversation per
/// set (split when larger than [size]) when [byConversation] is true.
List<QuestionSet> buildQuestionSets(
  List<Question> questions, {
  required int size,
  required bool byConversation,
}) {
  assert(size > 0);
  if (size <= 0 || questions.isEmpty) return const [];
  final sorted = sortOldestFirst(questions);

  if (!byConversation) {
    return [
      for (var i = 0; i < sorted.length; i += size)
        _makeSet(sorted.sublist(i, _min(i + size, sorted.length))),
    ];
  }

  // Group by conversation, groups in the order their oldest question comes
  // (sorted is oldest first, so first met = oldest).
  final groups = <String, List<Question>>{};
  for (final q in sorted) {
    groups.putIfAbsent(conversationKey(q.source), () => []).add(q);
  }
  final sets = <QuestionSet>[];
  for (final group in groups.values) {
    final parts = (group.length + size - 1) ~/ size;
    for (var p = 0; p < parts; p++) {
      final start = p * size;
      sets.add(
        _makeSet(
          group.sublist(start, _min(start + size, group.length)),
          part: p + 1,
          parts: parts,
        ),
      );
    }
  }
  // Undated conversations last: a group's position is its oldest question,
  // and undated questions already sort last, so nothing more to do.
  return sets;
}

int _min(int a, int b) => a < b ? a : b;

QuestionSet _makeSet(List<Question> qs, {int part = 1, int parts = 1}) {
  final names = <String>[];
  final seen = <String>{};
  DateTime? first;
  DateTime? last;
  for (final q in qs) {
    final name = conversationName(q.source);
    if (name.isNotEmpty && seen.add(name.toLowerCase())) names.add(name);
    final d = questionDate(q);
    if (d != null) {
      if (first == null || d.isBefore(first)) first = d;
      if (last == null || d.isAfter(last)) last = d;
    }
  }
  return QuestionSet(
    questions: List.unmodifiable(qs),
    conversations: List.unmodifiable(names),
    firstDate: first,
    lastDate: last,
    part: part,
    parts: parts,
  );
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
final RegExp _wholeDate = RegExp(r'^\s*(\d{4})-(\d{2})-(\d{2})');

/// The question's date: the `YYYY-MM-DD` at the end of `source`, else the
/// one at the start of `added`; null if neither has a valid date.
DateTime? questionDate(Question q) =>
    _parse(_trailingDate.firstMatch(q.source)) ??
    _parse(_wholeDate.firstMatch(q.added));

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

/// The conversation part of a `source`: "Work and plans, 2026-10-14" →
/// "Work and plans" (the trailing date and the comma or dash before it are
/// dropped). Trimmed; empty when there is none.
String conversationName(String source) {
  final m = _trailingDate.firstMatch(source);
  var name = m == null ? source : source.substring(0, m.start);
  name = name.trim();
  while (name.isNotEmpty && ',;·-–—'.contains(name[name.length - 1])) {
    name = name.substring(0, name.length - 1).trim();
  }
  return name;
}

/// What groups questions into one conversation: the whole `source`
/// (conversation and date), ignoring case and spaces, so the same topic on
/// two days is two conversations.
String conversationKey(String source) =>
    source.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "14 Oct"; "14–16 Oct" within a month; "30 Oct – 2 Nov" across months;
/// with the years when they differ ("30 Dec 2026 – 2 Jan 2027").
String dateRangeText(DateTime first, DateTime last) {
  String day(DateTime d) => '${d.day} ${_months[d.month - 1]}';
  if (first.year == last.year &&
      first.month == last.month &&
      first.day == last.day) {
    return day(first);
  }
  if (first.year != last.year) {
    return '${day(first)} ${first.year} – ${day(last)} ${last.year}';
  }
  if (first.month == last.month) {
    return '${first.day}–${day(last)}';
  }
  return '${day(first)} – ${day(last)}';
}
