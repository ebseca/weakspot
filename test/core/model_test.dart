import 'package:flutter_test/flutter_test.dart';
import 'package:weakspot/core/model.dart';

void main() {
  group('CardState', () {
    test('starts empty and untested', () {
      const state = CardState();
      expect(state.attempts, 0);
      expect(state.winRate, 0);
    });

    test('records answers in order', () {
      final state = const CardState().record(true).record(false);
      expect(state.history, [true, false]);
      expect(state.attempts, 2);
      expect(state.winRate, 0.5);
    });

    test('keeps only the last $historyWindow answers', () {
      var state = const CardState();
      // Twelve wrong, then two right: the two oldest must fall out.
      for (var i = 0; i < 12; i++) {
        state = state.record(false);
      }
      state = state.record(true).record(true);

      expect(state.attempts, historyWindow);
      expect(state.history.last, isTrue);
      expect(state.correct, 2);
      expect(state.winRate, closeTo(0.2, 1e-9));
    });

    test('an old mistake leaves the window once it is pushed out', () {
      var state = const CardState().record(false);
      for (var i = 0; i < historyWindow; i++) {
        state = state.record(true);
      }
      expect(state.winRate, 1.0);
    });

    test('round-trips through JSON', () {
      final state = const CardState().record(true).record(false).record(true);
      expect(CardState.fromJson(state.toJson()).history, state.history);
    });
  });

  group('Note', () {
    test('falls back to the front as its id', () {
      final note = Note.fromJson({'front': 'ね', 'back': 'ne'});
      expect(note.id, 'ね');
      expect(note.hint, isNull);
      expect(note.distractors, isEmpty);
    });

    test('keeps an explicit id, hint and distractors', () {
      final note = Note.fromJson({
        'id': 'ne',
        'front': 'ね',
        'back': 'ne',
        'hint': 'Vertical spine, then a loop',
        'distractors': ['nu', 're', '', '  '],
      });
      expect(note.id, 'ne');
      expect(note.hint, 'Vertical spine, then a loop');
      expect(note.distractors, ['nu', 're']);
    });

    test('prompt and answer swap with direction', () {
      const note = Note(id: 'ne', front: 'ね', back: 'ne');
      expect(note.prompt(Direction.forward), 'ね');
      expect(note.answer(Direction.forward), 'ne');
      expect(note.prompt(Direction.reverse), 'ne');
      expect(note.answer(Direction.reverse), 'ね');
    });
  });

  group('Library', () {
    Library build() => const Library(
          id: 'kana',
          name: 'Kana',
          notes: [
            Note(id: 'a', front: 'あ', back: 'a'),
            Note(id: 'i', front: 'い', back: 'i'),
          ],
          unlockedIds: {'a'},
        );

    test('reports untested cards as empty state', () {
      expect(build().stateOf('a', Direction.forward).attempts, 0);
    });

    test('recording touches only the one direction', () {
      final library = build().recording('a', Direction.forward, true);
      expect(library.stateOf('a', Direction.forward).attempts, 1);
      expect(library.stateOf('a', Direction.reverse).attempts, 0);
      expect(library.stateOf('i', Direction.forward).attempts, 0);
    });

    test('round-trips through JSON', () {
      final library = build()
          .recording('a', Direction.forward, true)
          .recording('a', Direction.reverse, false);
      final restored = Library.fromJson(library.toJson());

      expect(restored.id, 'kana');
      expect(restored.name, 'Kana');
      expect(restored.notes.length, 2);
      expect(restored.unlockedCount, 1);
      expect(restored.stateOf('a', Direction.forward).history, [true]);
      expect(restored.stateOf('a', Direction.reverse).history, [false]);
    });

    test('drops untested cards when serialising', () {
      final json = build().recording('a', Direction.forward, true).toJson();
      expect((json['cards'] as Map).keys, [cardKey('a', Direction.forward)]);
    });

    test('an unseen card needs introducing', () {
      expect(build().needsIntroduction('a', Direction.forward), isTrue);
    });

    test('introducing is remembered, per direction', () {
      final library = build().introducing('a', Direction.forward);
      expect(library.needsIntroduction('a', Direction.forward), isFalse);
      expect(library.needsIntroduction('a', Direction.reverse), isTrue,
          reason: 'seeing あ → a does not teach you a → あ');
    });

    test('a card with answers behind it never needs introducing', () {
      // This is what lets libraries saved before introductions existed
      // carry on without re-teaching everything.
      final library = build().recording('a', Direction.forward, true);
      expect(library.needsIntroduction('a', Direction.forward), isFalse);
    });

    test('introductions survive a save and reload', () {
      final library = build().introducing('i', Direction.reverse);
      final restored = Library.fromJson(library.toJson());
      expect(restored.needsIntroduction('i', Direction.reverse), isFalse);
      expect(restored.needsIntroduction('i', Direction.forward), isTrue);
    });

    test('an answered card is not also stored as introduced', () {
      final library = build()
          .introducing('a', Direction.forward)
          .recording('a', Direction.forward, true);
      final json = library.toJson();
      expect(json['introduced'], isEmpty,
          reason: 'its history already proves it was shown');
      expect(
        Library.fromJson(json).needsIntroduction('a', Direction.forward),
        isFalse,
      );
    });

    test('reads progress stored as a count, from before ids', () {
      final restored = Library.fromJson({
        'id': 'kana',
        'name': 'Kana',
        'unlockedNotes': 2,
        'notes': [
          {'id': 'a', 'front': 'あ', 'back': 'a'},
          {'id': 'i', 'front': 'い', 'back': 'i'},
          {'id': 'u', 'front': 'う', 'back': 'u'},
        ],
      });

      expect(restored.unlockedCount, 2);
      expect(restored.isUnlocked('a'), isTrue);
      expect(restored.isUnlocked('i'), isTrue);
      expect(restored.isUnlocked('u'), isFalse);
    });

    test('a stored id list wins over a stored count', () {
      final restored = Library.fromJson({
        'id': 'kana',
        'name': 'Kana',
        'unlockedNotes': 1,
        'unlocked': ['u'],
        'notes': [
          {'id': 'a', 'front': 'あ', 'back': 'a'},
          {'id': 'u', 'front': 'う', 'back': 'u'},
        ],
      });
      expect(restored.isUnlocked('u'), isTrue);
      expect(restored.isUnlocked('a'), isFalse);
    });

    test('an id left over from a changed deck does not inflate the count',
        () {
      const library = Library(
        id: 'kana',
        name: 'Kana',
        notes: [Note(id: 'a', front: 'あ', back: 'a')],
        unlockedIds: {'a', 'deleted'},
      );
      expect(library.unlockedCount, 1);
      expect(library.unlocked.map((n) => n.id), ['a']);
    });

    test('locked lists what is left, in deck order', () {
      final library = build().copyWith(unlockedIds: {'i'});
      expect(library.locked.map((n) => n.id), ['a']);
      expect(library.unlocking(['a']).locked, isEmpty);
    });

    test('clamps an unlock count larger than the deck', () {
      final restored = Library.fromJson({
        'id': 'kana',
        'name': 'Kana',
        'unlockedNotes': 99,
        'notes': [
          {'front': 'あ', 'back': 'a'},
        ],
      });
      expect(restored.unlockedCount, 1);
    });

    test('skips cards missing a front or back', () {
      final restored = Library.fromJson({
        'id': 'kana',
        'name': 'Kana',
        'notes': [
          {'front': 'あ', 'back': 'a'},
          {'front': 'い'},
          {'back': 'u'},
        ],
      });
      expect(restored.notes.length, 1);
    });
  });
}
