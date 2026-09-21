/// Every number the app tunes, and the logic derived from them.
///
/// This file is the spec. If a progression rule is argued about, it is
/// settled here and nowhere else.
library;

import 'model.dart';

/// How well a card is known, from its last [historyWindow] answers.
enum Band {
  /// Never answered — either locked, or unlocked but not yet seen.
  fresh,

  /// Under [strugglingCeiling].
  struggling,

  /// Between [strugglingCeiling] and [masteredFloor].
  learning,

  /// [masteredFloor] or better. Only these are drawn for review slots.
  mastered,
}

/// Notes unlocked at a time by the manual "open more" control.
const int batchSize = 5;

/// How many unmastered cards to keep in play.
///
/// This is what paces the app. Master one card and another opens, so there
/// is always something to work on and the session never degenerates into
/// reshuffling material you already know. Batches only survive as the
/// manual override.
const int unmasteredTarget = 5;

/// Win rate at or above which a card counts as mastered.
const double masteredFloor = 0.9;

/// Answers a card needs before it is allowed to count as mastered.
///
/// One correct answer is a win rate of 100%, and without this a single
/// lucky guess would retire a card and pull the next one into play. Four
/// is enough to mean something without feeling like a grind.
const int minAttemptsToMaster = 4;

/// Win rate below which a card counts as struggling.
const double strugglingCeiling = 0.5;

/// Share of a session spent on already-mastered cards so they don't rot.
const double reviewSlotShare = 0.2;

/// How far above the worst win rate a card can sit and still be picked.
///
/// Targeting only the single worst card would drill that one card over and
/// over until it improved, which is exhausting. Over a window of
/// [historyWindow], 0.2 means "within two answers of the worst", so a
/// handful of genuinely weak cards stay in rotation and the choice among
/// them is random.
const double selectionBand = 0.2;

/// The fewest cards the picker tries to choose between.
///
/// Two, not more: when a single card is far worse than everything else,
/// widening to three would dilute it to a third of the questions, which is
/// barely more than its fair share. At two, the picker alternates between
/// the worst card and the next worst — hard targeting, with just enough
/// breathing room that you are never asked the same card twice running.
const int minSelectionCandidates = 2;

/// Session lengths offered on the start screen.
const List<int> sessionLengths = [10, 20, 40];

/// Lengths, in minutes, offered for a timed run.
const List<int> timedMinutes = [1, 3, 5];

/// How many answer options a question shows.
const int optionCount = 4;


/// Band for a win rate that is known to come from at least one attempt.
Band bandForRate(double winRate) {
  if (winRate >= masteredFloor) return Band.mastered;
  if (winRate < strugglingCeiling) return Band.struggling;
  return Band.learning;
}

/// Band for a card, accounting for never having been tried and for not
/// having been tried enough.
Band bandForCard(CardState state) {
  if (state.attempts == 0) return Band.fresh;

  final band = bandForRate(state.winRate);
  if (band == Band.mastered && state.attempts < minAttemptsToMaster) {
    return Band.learning;
  }
  return band;
}

/// A note's record with both directions added together.
({int attempts, int correct}) noteRecord(Library library, String noteId) {
  var attempts = 0;
  var correct = 0;
  for (final direction in Direction.values) {
    final state = library.stateOf(noteId, direction);
    attempts += state.attempts;
    correct += state.correct;
  }
  return (attempts: attempts, correct: correct);
}

/// Band for a whole note, pooling both directions into one record.
///
/// Pooled rather than worst-of: taking the worst direction meant that
/// answering a freshly started direction twice dropped a note that had
/// been green for weeks straight back to yellow, because a card with
/// fewer than [minAttemptsToMaster] answers cannot be mastered yet. A
/// handful of new answers should nudge a long record, not overwrite it.
///
/// The per-direction scores are untouched and still drive everything that
/// should be direction-aware: what gets asked next, the needs-work list,
/// and the reading-against-writing split.
Band bandForNote(Library library, String noteId) {
  final record = noteRecord(library, noteId);
  if (record.attempts == 0) return Band.fresh;

  final band = bandForRate(record.correct / record.attempts);
  if (band == Band.mastered && record.attempts < minAttemptsToMaster) {
    return Band.learning;
  }
  return band;
}

/// Questions in a session of [sessionLength] reserved for mastered cards.
int reviewSlotsFor(int sessionLength) =>
    (sessionLength * reviewSlotShare).round();

/// Unlocked notes that are not yet mastered, counting untested ones.
int unmasteredCount(Library library) => library.unlocked
    .where((note) => bandForNote(library, note.id) != Band.mastered)
    .length;

/// Open notes until [target] of them are unmastered.
///
/// Takes them from the front of what is still locked, so pacing follows
/// deck order even when cards have been opened out of it by hand. Every
/// note this opens is untested, and therefore unmastered, so the count
/// lands exactly on the target. Called after each answer, which is what
/// turns mastering a card into new material arriving immediately rather
/// than at the end of a session you might never finish.
///
/// [target] defaults to [unmasteredTarget] and is overridden by the
/// player's pacing setting.
Library topUpPool(Library library, {int target = unmasteredTarget}) {
  final needed = target - unmasteredCount(library);
  if (needed <= 0) return library;
  return openNext(library, needed);
}

/// Notes still locked away.
int lockedCount(Library library) =>
    library.notes.length - library.unlockedCount;

/// Open the next [count] locked notes in deck order.
Library openNext(Library library, int count) {
  if (count <= 0) return library;
  final next = library.locked.take(count).map((n) => n.id).toList();
  if (next.isEmpty) return library;
  return library.unlocking(next);
}

/// Open [batchSize] more notes regardless of how the current ones are
/// going.
///
/// The manual override behind the "open more" control, for when you would
/// rather have material than pacing — cramming before something.
Library openNextBatch(Library library) => openNext(library, batchSize);

/// Open one specific card, wherever it sits in the deck.
///
/// Nothing before it is dragged in: reaching the ら row early should not
/// mean carrying the thirty cards in front of it.
Library unlockNote(Library library, String noteId) =>
    library.isUnlocked(noteId) ? library : library.unlocking([noteId]);


/// How many notes in [library] sit in each band.
///
/// Locked notes count as [Band.fresh] — the results grid shows the whole
/// alphabet, so what is still ahead reads as "not yet" rather than absent.
Map<Band, int> bandCounts(Library library) {
  final counts = {for (final band in Band.values) band: 0};
  for (final note in library.notes) {
    final band = bandForNote(library, note.id);
    counts[band] = counts[band]! + 1;
  }
  return counts;
}
