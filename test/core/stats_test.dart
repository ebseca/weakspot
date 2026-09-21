import 'package:flutter_test/flutter_test.dart';
import 'package:weakspot/core/model.dart';
import 'package:weakspot/core/rules.dart';
import 'package:weakspot/core/stats.dart';

const List<Note> _kanaNotes = [
        Note(id: 'na', front: 'な', back: 'na'),
        Note(id: 'ni', front: 'に', back: 'ni'),
        Note(id: 'nu', front: 'ぬ', back: 'nu'),
        Note(id: 'ne', front: 'ね', back: 'ne'),
  Note(id: 'no', front: 'の', back: 'no'),
  Note(id: 're', front: 'れ', back: 're'),
];

Library kana({int unlocked = 5}) => Library(
      id: 'kana',
      name: 'Kana',
      notes: _kanaNotes,
      unlockedIds: _kanaNotes.take(unlocked).map((n) => n.id).toSet(),
    );

Library answerCard(
  Library library,
  String noteId,
  Direction direction, {
  int attempts = historyWindow,
  required int correct,
}) {
  var next = library;
  for (var i = 0; i < attempts; i++) {
    next = next.recording(noteId, direction, i < correct);
  }
  return next;
}

DirectionStats statsFor(Library library, Direction direction) =>
    directionStats(library).firstWhere((s) => s.direction == direction);

void main() {
  group('directionStats', () {
    test('always returns both directions, even untested', () {
      final stats = directionStats(kana());
      expect(stats.map((s) => s.direction), Direction.values);
      expect(stats.every((s) => !s.hasData), isTrue);
      expect(stats.first.accuracy, 0);
    });

    test('counts recent answers, not cards', () {
      var library = kana();
      library = answerCard(library, 'na', Direction.forward, correct: 8);
      library = answerCard(library, 'ni', Direction.forward, correct: 6);

      final forward = statsFor(library, Direction.forward);
      expect(forward.cardsTested, 2);
      expect(forward.attempts, 20);
      expect(forward.correct, 14);
      expect(forward.percent, 70);
    });

    test('keeps reading and writing apart', () {
      var library = kana();
      for (final note in library.notes) {
        library =
            answerCard(library, note.id, Direction.forward, correct: 10);
        library = answerCard(library, note.id, Direction.reverse, correct: 3);
      }

      expect(statsFor(library, Direction.forward).percent, 100);
      expect(statsFor(library, Direction.reverse).percent, 30);
    });

    test('names each direction in the player\'s terms', () {
      final stats = directionStats(kana());
      expect(stats.firstWhere((s) => s.direction == Direction.forward).name,
          'Reading');
      expect(stats.firstWhere((s) => s.direction == Direction.reverse).name,
          'Writing');
    });
  });

  group('weakestCards', () {
    test('is empty before anything is answered', () {
      expect(weakestCards(kana()), isEmpty);
    });

    test('lists the worst first', () {
      var library = kana();
      library = answerCard(library, 'na', Direction.forward, correct: 7);
      library = answerCard(library, 'ni', Direction.forward, correct: 2);
      library = answerCard(library, 'nu', Direction.forward, correct: 5);

      expect(
        weakestCards(library).map((c) => c.note.id),
        ['ni', 'nu', 'na'],
      );
    });

    test('leaves out mastered cards', () {
      var library = kana();
      library = answerCard(library, 'na', Direction.forward, correct: 10);
      library = answerCard(library, 'ni', Direction.forward, correct: 4);

      expect(weakestCards(library).map((c) => c.note.id), ['ni']);
    });

    test('leaves out cards never tried', () {
      var library = kana();
      library = answerCard(library, 'na', Direction.forward, correct: 3);

      final weak = weakestCards(library);
      expect(weak, hasLength(1));
      expect(weak.single.direction, Direction.forward);
    });

    test('treats the two directions of a card separately', () {
      var library = kana();
      library = answerCard(library, 'ne', Direction.forward, correct: 10);
      library = answerCard(library, 'ne', Direction.reverse, correct: 1);

      final weak = weakestCards(library);
      expect(weak, hasLength(1));
      expect(weak.single.note.id, 'ne');
      expect(weak.single.direction, Direction.reverse);
      expect(weak.single.prompt, 'ne');
      expect(weak.single.answer, 'ね');
      expect(weak.single.directionLabel, contains('writing'));
    });

    test('ignores cards that are still locked', () {
      var library = kana(unlocked: 1);
      library = answerCard(library, 'na', Direction.forward, correct: 2);
      library = answerCard(library, 're', Direction.forward, correct: 0);

      expect(weakestCards(library).map((c) => c.note.id), ['na']);
    });

    test('respects the limit', () {
      var library = kana(unlocked: 6);
      for (final note in library.notes) {
        library = answerCard(library, note.id, Direction.forward, correct: 2);
      }
      expect(weakestCards(library, limit: 3), hasLength(3));
    });

    test('a better-established weakness outranks a tied newcomer', () {
      var library = kana();
      library = answerCard(library, 'na', Direction.forward,
          attempts: 10, correct: 5);
      library = answerCard(library, 'ni', Direction.forward,
          attempts: 2, correct: 1);

      // Both at 50%; the one with more answers behind it comes first.
      expect(weakestCards(library).first.note.id, 'na');
    });
  });

  group('totalAnswers', () {
    test('is zero for an untouched library', () {
      expect(totalAnswers(kana()), 0);
    });

    test('adds up both directions', () {
      var library = kana();
      library =
          answerCard(library, 'na', Direction.forward, attempts: 6, correct: 3);
      library =
          answerCard(library, 'na', Direction.reverse, attempts: 4, correct: 4);
      expect(totalAnswers(library), 10);
    });

    test('counts only what the window keeps', () {
      var library = kana();
      library = answerCard(library, 'na', Direction.forward,
          attempts: 25, correct: 25);
      expect(totalAnswers(library), historyWindow);
    });
  });

  group('pool status', () {
    test('an untouched pool is entirely unmastered', () {
      expect(unmasteredCount(kana()), 5);
      expect(lockedCount(kana()), 1);
    });

    test('mastering a card drops it out of the count', () {
      var library = kana();
      library = answerCard(library, 'na', Direction.forward, correct: 10);
      expect(unmasteredCount(library), 4);
    });

    test('a card weak in either direction still counts', () {
      var library = kana();
      library = answerCard(library, 'na', Direction.forward, correct: 10);
      library = answerCard(library, 'na', Direction.reverse, correct: 2);
      expect(unmasteredCount(library), 5);
    });
  });
}