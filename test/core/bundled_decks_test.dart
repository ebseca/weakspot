/// Guards the decks that ship with the app.
///
/// Reads the real asset files off disk rather than through the asset
/// bundle, so a stray comma or a dropped card fails here loudly instead of
/// quietly shrinking the alphabet at runtime.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weakspot/core/deck_import.dart';
import 'package:weakspot/core/store.dart';

void main() {
  for (final deck in bundledDecks) {
    group(deck.id, () {
      final result = parseDeck(File(deck.asset).readAsStringSync());

      test('parses with no complaints', () {
        expect(result.fatal, isNull);
        expect(result.problems, isEmpty);
        expect(result.isUsable, isTrue);
      });

      test('has all 46 kana', () {
        expect(result.notes, hasLength(46));
      });

      test('every card has a non-empty front and back', () {
        for (final note in result.notes) {
          expect(note.front, isNotEmpty, reason: 'id ${note.id}');
          expect(note.back, isNotEmpty, reason: 'id ${note.id}');
        }
      });

      test('ids are unique', () {
        final ids = result.notes.map((n) => n.id).toSet();
        expect(ids, hasLength(result.notes.length));
      });

      test('backs are unique, so distractors are never ambiguous', () {
        final backs = result.notes.map((n) => n.back).toSet();
        expect(backs, hasLength(result.notes.length));
      });

      test('every distractor is a real answer elsewhere in the deck', () {
        final backs = result.notes.map((n) => n.back).toSet();
        for (final note in result.notes) {
          for (final distractor in note.distractors) {
            expect(
              backs,
              contains(distractor),
              reason: '"$distractor" on ${note.id} is not an answer in the deck',
            );
          }
        }
      });

      test('no card lists itself as a distractor', () {
        for (final note in result.notes) {
          expect(note.distractors, isNot(contains(note.back)),
              reason: 'id ${note.id}');
        }
      });

      test('reads both ways round', () {
        expect(result.reversible, isTrue);
      });

      test('a card never has more distractors than a question has slots', () {
        for (final note in result.notes) {
          expect(note.distractors.length, lessThanOrEqualTo(4),
              reason: 'id ${note.id}');
        }
      });
    });
  }
}
