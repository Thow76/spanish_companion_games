/// Padlocks on the home screen (B30; stage ladder approved 2026-11-16, see
/// `claude/Spanish Games Ladder Draft.md` section 1, call A).
///
/// Home groups the six cards on the ladder: **Your mistakes** (Choose a
/// correction, Fill the gap, Repair the sentence, Spot the error) and
/// **Consolidation** (Sentence ordering, Matching).
///
/// A question is locked while its `unlocks_after` question is still in the
/// file and has not been answered right this session (the drop-back case:
/// passing stage N−1 unlocks stage N straight away). Reload rule (Andrew,
/// 2026-11-18): when the `unlocks_after` question is no longer in the file
/// (the script removed it after a right answer), the question is open.
///
/// A card is:
/// - **locked** when it has nothing to play now but holds locked
///   questions, or when it is empty and the questions on show include one
///   at an earlier ladder stage than the card's first stage;
/// - **part-locked** when it has open and locked questions;
/// - **empty** ("No questions yet") when it has nothing and nothing comes
///   before it;
/// - **open** otherwise.
///
/// "Earlier" goes by ladder stage, not card position: Choose a correction 1,
/// Fill the gap 2 (it also plays 4), Repair 3, Spot the error 5, Sentence
/// ordering and Matching after 5. So Sentence ordering and Matching never
/// lock each other, and a Fill the gap card holding only stage 4 questions
/// does not lock an empty Repair card.
library;

import 'question.dart';

/// The two home groups on the ladder, in screen order.
enum HomeGroup {
  yourMistakes('Your mistakes', 'Each mistake, one step at a time.', [
    GameType.chooseCorrection,
    GameType.fillGap,
    GameType.repair,
    GameType.spotError,
  ]),
  consolidation(
    'Consolidation',
    'Practise the rule once a mistake has passed every step.',
    [GameType.order, GameType.match],
  );

  const HomeGroup(this.title, this.description, this.games);

  /// The group heading.
  final String title;

  /// The line under the heading.
  final String description;

  /// The group's cards, in screen order.
  final List<GameType> games;
}

/// How a home card shows.
enum CardLock { open, partLocked, locked, empty }

/// One home card: the questions it plays now, how many are locked, and
/// whether it is locked.
class CardState {
  const CardState({
    required this.game,
    required this.open,
    required this.locked,
    required this.lock,
  });

  final GameType game;

  /// The questions the card plays now, in file order.
  final List<Question> open;

  /// Questions held back by `unlocks_after`.
  final int locked;

  final CardLock lock;
}

/// The locked message, shown when a locked card is tapped (Andrew's
/// wording, 2026-11-14).
const String lockedCardMessage =
    'Please complete the necessary steps before this card is unlocked.';

/// The ladder rank of a stage: 1–5, consolidation 6.
int stageRank(LadderStage stage) => stage.number ?? 6;

/// The first ladder stage a card plays.
int cardFirstStage(GameType game) => switch (game) {
  GameType.chooseCorrection => 1,
  GameType.fillGap => 2,
  GameType.repair => 3,
  GameType.spotError => 5,
  GameType.order || GameType.match => 6,
};

/// Whether [question] is held back now. [fileIds]: every question id in
/// the loaded file (before any filter). [passed]: whether a question id
/// was answered right this session.
bool isQuestionLocked(
  Question question, {
  required Set<String> fileIds,
  required bool Function(String id) passed,
}) {
  final after = question.unlocksAfter;
  if (after == null) return false;
  if (passed(after)) return false;
  // Not in the file any more: the script has already moved the item on.
  return fileIds.contains(after);
}

/// The state of every card for the questions on show ([shown], already
/// filtered). See the library comment for the rules.
Map<GameType, CardState> cardStates(
  List<Question> shown, {
  required Set<String> fileIds,
  required bool Function(String id) passed,
}) {
  final open = <GameType, List<Question>>{
    for (final g in GameType.values) g: [],
  };
  final locked = <GameType, int>{for (final g in GameType.values) g: 0};
  var earliest = 7;
  for (final q in shown) {
    final rank = stageRank(q.stage);
    if (rank < earliest) earliest = rank;
    if (isQuestionLocked(q, fileIds: fileIds, passed: passed)) {
      locked[q.game] = locked[q.game]! + 1;
    } else {
      open[q.game]!.add(q);
    }
  }
  return {
    for (final g in GameType.values)
      g: CardState(
        game: g,
        open: open[g]!,
        locked: locked[g]!,
        lock: switch ((open[g]!.length, locked[g]!)) {
          (0, > 0) => CardLock.locked,
          (> 0, > 0) => CardLock.partLocked,
          (> 0, _) => CardLock.open,
          _ => earliest < cardFirstStage(g) ? CardLock.locked : CardLock.empty,
        },
      ),
  };
}
