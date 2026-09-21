import 'package:flutter_test/flutter_test.dart';
import 'package:weakspot/core/model.dart';
import 'package:weakspot/core/rules.dart';

/// A deck of [count] throwaway notes, ids "n0", "n1", …
Library deck(int count, {int unlocked = 0}) {
  final notes = [
    for (var i = 0; i < count; i++)
      Note(id: 'n$i', front: 'f$i', back: 'b$i'),
  ];
  return Library(
    id: 'test',
    name: 'Test',
    notes: notes,
    unlockedIds: notes.take(unlocked).map((n) => n.id).toSet(),
  );
}

/// Record [attempts] answers on one card, [correct] of them right.
Library answer(
  Library library,
  String noteId,
  Direction direction, {
  required int attempts,
  required int correct,
}) {
  var next = library;
  for (var i = 0; i < attempts; i++) {
    next = next.recording(noteId, direction, i < correct);
  }
  return next;
}

void main() {
  group('bands', () {
    test('a card with no attempts is fresh, not struggling', () {
      expect(bandForCard(const CardState()), Band.fresh);
    });

    test('thresholds fall on the documented sides', () {
      expect(bandForRate(1.0), Band.mastered);
      expect(bandForRate(masteredFloor), Band.mastered);
      expect(bandForRate(masteredFloor - 0.01), Band.learning);
      expect(bandForRate(strugglingCeiling), Band.learning);
      expect(bandForRate(strugglingCeiling - 0.01), Band.struggling);
      expect(bandForRate(0), Band.struggling);
    });

    test('a note pools both directions into one record', () {
      var library = deck(1, unlocked: 1);
      library =
          answer(library, 'n0', Direction.forward, attempts: 10, correct: 8);
      library =
          answer(library, 'n0', Direction.reverse, attempts: 10, correct: 4);

      final record = noteRecord(library, 'n0');
      expect(record.attempts, 20);
      expect(record.correct, 12);
      expect(bandForNote(library, 'n0'), Band.learning);
    });

    test('starting a new direction does not undo a long record', () {
      var library = deck(1, unlocked: 1);
      library = answer(library, 'n0', Direction.forward,
          attempts: 10, correct: 10);
      expect(bandForNote(library, 'n0'), Band.mastered);

      // Two correct answers the other way round. Under the old worst-of
      // rule this dropped to learning purely because two attempts is too
      // few to master — the whole grid turned yellow on switching mode.
      library =
          answer(library, 'n0', Direction.reverse, attempts: 2, correct: 2);
      expect(bandForNote(library, 'n0'), Band.mastered);
    });

    test('but real failures still pull a note down', () {
      var library = deck(1, unlocked: 1);
      library = answer(library, 'n0', Direction.forward,
          attempts: 10, correct: 10);
      library =
          answer(library, 'n0', Direction.reverse, attempts: 10, correct: 2);

      // 12 of 20 overall: getting it wrong still costs you.
      expect(bandForNote(library, 'n0'), Band.learning);
    });

    test('a note with no answers at all is fresh', () {
      expect(noteRecord(deck(1, unlocked: 1), 'n0').attempts, 0);
      expect(bandForNote(deck(1, unlocked: 1), 'n0'), Band.fresh);
    });

    test('too few pooled answers cannot count as mastered', () {
      var library = deck(1, unlocked: 1);
      library = answer(library, 'n0', Direction.forward,
          attempts: minAttemptsToMaster - 1,
          correct: minAttemptsToMaster - 1);
      expect(bandForNote(library, 'n0'), Band.learning);
    });

    test('an untested direction does not drag a note down', () {
      var library = deck(1, unlocked: 1);
      library = answer(library, 'n0', Direction.forward,
          attempts: 10, correct: 10);
      expect(bandForNote(library, 'n0'), Band.mastered);
    });

    test('counts cover every note, locked ones included', () {
      var library = deck(10, unlocked: 5);
      library =
          answer(library, 'n0', Direction.forward, attempts: 10, correct: 10);
      final counts = bandCounts(library);

      expect(counts[Band.mastered], 1);
      expect(counts[Band.fresh], 9);
      expect(counts.values.reduce((a, b) => a + b), 10);
    });
  });


  test('review slots are $reviewSlotShare of the session', () {
    expect(reviewSlotsFor(10), 2);
    expect(reviewSlotsFor(20), 4);
    expect(reviewSlotsFor(40), 8);
  });

  group('keeping material flowing', () {
    test('an untouched pool is already at the target', () {
      final library = deck(46, unlocked: unmasteredTarget);
      expect(unmasteredCount(library), unmasteredTarget);
      expect(topUpPool(library).unlockedCount, unmasteredTarget);
    });

    test('mastering one card opens exactly one more', () {
      var library = deck(46, unlocked: 5);
      library = answer(library, 'n0', Direction.forward,
          attempts: 10, correct: 10);

      expect(unmasteredCount(library), 4);
      expect(topUpPool(library).unlockedCount, 6);
      expect(unmasteredCount(topUpPool(library)), unmasteredTarget);
    });

    test('mastering several opens several', () {
      var library = deck(46, unlocked: 5);
      for (final id in ['n0', 'n1', 'n2']) {
        library =
            answer(library, id, Direction.forward, attempts: 10, correct: 10);
      }
      expect(topUpPool(library).unlockedCount, 8);
    });

    test('a weak card holds nothing back', () {
      // The old gate blocked the whole batch on one bad card. Now a weak
      // card simply stays in the pool and new material still arrives.
      var library = deck(46, unlocked: 5);
      library =
          answer(library, 'n0', Direction.forward, attempts: 10, correct: 1);
      library =
          answer(library, 'n1', Direction.forward, attempts: 10, correct: 10);

      expect(topUpPool(library).unlockedCount, 6);
    });

    test('never opens past the end of the deck', () {
      var library = deck(6, unlocked: 6);
      for (final note in library.notes) {
        library = answer(library, note.id, Direction.forward,
            attempts: 10, correct: 10);
      }
      expect(topUpPool(library).unlockedCount, 6);
      expect(lockedCount(topUpPool(library)), 0);
    });

    test('an untested card counts as unmastered', () {
      final library = deck(46, unlocked: 3);
      expect(unmasteredCount(library), 3);
      expect(topUpPool(library).unlockedCount, unmasteredTarget);
    });

    test('a card mastered one way but not the other stays in play', () {
      var library = deck(46, unlocked: 5);
      library =
          answer(library, 'n0', Direction.forward, attempts: 10, correct: 10);
      library =
          answer(library, 'n0', Direction.reverse, attempts: 10, correct: 2);

      expect(unmasteredCount(library), 5, reason: 'n0 is not done yet');
      expect(topUpPool(library).unlockedCount, 5);
    });
  });

  group('opening one card out of order', () {
    test('opens only that card', () {
      final library = unlockNote(deck(46, unlocked: 5), 'n30');

      expect(library.isUnlocked('n30'), isTrue);
      expect(library.isUnlocked('n29'), isFalse,
          reason: 'nothing in front of it comes along');
      expect(library.unlockedCount, 6);
    });

    test('opening one already in play changes nothing', () {
      final library = deck(46, unlocked: 5);
      expect(unlockNote(library, 'n0').unlockedCount, 5);
    });

    test('pacing still works down the deck around it', () {
      // n30 opened by hand, then two cards mastered so the pool is one
      // under target. The top-up should take the next locked card in deck
      // order, not carry on from where the hand-opened one sits.
      var library = unlockNote(deck(46, unlocked: 5), 'n30');
      for (final id in ['n0', 'n1']) {
        library =
            answer(library, id, Direction.forward, attempts: 10, correct: 10);
      }
      expect(unmasteredCount(library), unmasteredTarget - 1);

      final topped = topUpPool(library);
      expect(topped.isUnlocked('n5'), isTrue);
      expect(topped.isUnlocked('n31'), isFalse);
    });

    test('a hand-opened card counts toward the unmastered target', () {
      final library = unlockNote(deck(46, unlocked: 5), 'n30');
      expect(unmasteredCount(library), 6);
      expect(topUpPool(library).unlockedCount, 6,
          reason: 'already over target, so nothing more opens');
    });
  });

  group('opening more by hand', () {
    test('opens a batch whatever the pool looks like', () {
      expect(openNextBatch(deck(46, unlocked: 5)).unlockedCount, 10);
    });

    test('stops at the end of the deck', () {
      expect(openNextBatch(deck(8, unlocked: 6)).unlockedCount, 8);
      expect(openNextBatch(deck(8, unlocked: 8)).unlockedCount, 8);
    });

    test('lockedCount tracks what is left', () {
      expect(lockedCount(deck(46, unlocked: 10)), 36);
      expect(lockedCount(deck(46, unlocked: 46)), 0);
    });
  });
}
