/// Reading a library's history back as something worth looking at.
///
/// Pure Dart. Everything here is derived from card histories — nothing is
/// stored separately, so the numbers can never drift from the answers.
library;

import 'model.dart';
import 'rules.dart';

/// How one direction is going across a whole library.
class DirectionStats {
  const DirectionStats({
    required this.direction,
    required this.attempts,
    required this.correct,
    required this.cardsTested,
  });

  final Direction direction;

  /// Answers recorded, counting only the last [historyWindow] per card.
  final int attempts;

  final int correct;

  /// Cards with at least one answer in this direction.
  final int cardsTested;

  bool get hasData => attempts > 0;

  /// Share of recent answers that were right, 0 when untested.
  double get accuracy => attempts == 0 ? 0 : correct / attempts;

  int get percent => (accuracy * 100).round();

  /// What this direction is testing, in the player's terms.
  String get name =>
      direction == Direction.forward ? 'Reading' : 'Writing';

  String get glyph => direction == Direction.forward ? '→' : '←';
}

/// Reading and writing side by side.
///
/// Both are always returned, even untested, so the screen can show that a
/// direction has never been practised rather than hiding it.
List<DirectionStats> directionStats(Library library) {
  return [
    for (final direction in Direction.values)
      () {
        var attempts = 0;
        var correct = 0;
        var tested = 0;
        for (final note in library.notes) {
          final state = library.stateOf(note.id, direction);
          if (state.attempts == 0) continue;
          tested += 1;
          attempts += state.attempts;
          correct += state.correct;
        }
        return DirectionStats(
          direction: direction,
          attempts: attempts,
          correct: correct,
          cardsTested: tested,
        );
      }(),
  ];
}

/// One card that needs work, with enough to draw a row.
class ScoredCard {
  const ScoredCard({
    required this.note,
    required this.direction,
    required this.state,
  });

  final Note note;
  final Direction direction;
  final CardState state;

  /// What the player is shown when this card comes up.
  String get prompt => note.prompt(direction);

  /// What they have to produce.
  String get answer => note.answer(direction);

  Band get band => bandForCard(state);

  String get directionLabel =>
      direction == Direction.forward ? '→ reading' : '← writing';
}

/// The cards you are worst at, weakest first.
///
/// Only cards with answers recorded — an untested card is not a weak spot,
/// it is simply one you have not met yet.
List<ScoredCard> weakestCards(Library library, {int limit = 8}) {
  final scored = <ScoredCard>[
    for (final note in library.unlocked)
      for (final direction in Direction.values)
        if (library.stateOf(note.id, direction).attempts > 0)
          ScoredCard(
            note: note,
            direction: direction,
            state: library.stateOf(note.id, direction),
          ),
  ];

  scored.sort((a, b) {
    final byRate = a.state.winRate.compareTo(b.state.winRate);
    if (byRate != 0) return byRate;
    // More attempts at the same rate is the better-established weakness.
    return b.state.attempts.compareTo(a.state.attempts);
  });

  return scored.where((c) => c.band != Band.mastered).take(limit).toList();
}

/// Total answers recorded across the library, both directions.
int totalAnswers(Library library) {
  var total = 0;
  for (final state in library.cards.values) {
    total += state.attempts;
  }
  return total;
}
