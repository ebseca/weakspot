import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:weakspot/core/model.dart';
import 'package:weakspot/core/rules.dart';
import 'package:weakspot/core/session.dart';

/// A small deck whose fronts and backs are easy to tell apart.
const List<Note> _kanaNotes = [
        Note(id: 'na', front: 'な', back: 'na'),
        Note(id: 'ni', front: 'に', back: 'ni'),
        Note(id: 'nu', front: 'ぬ', back: 'nu'),
        Note(
          id: 'ne',
          front: 'ね',
          back: 'ne',
          hint: 'Vertical spine, then a loop',
          distractors: ['nu', 're'],
        ),
  Note(id: 'no', front: 'の', back: 'no'),
  Note(id: 're', front: 'れ', back: 're'),
];

Library kana({int unlocked = 5}) => Library(
      id: 'kana',
      name: 'Kana',
      notes: _kanaNotes,
      unlockedIds: _kanaNotes.take(unlocked).map((n) => n.id).toSet(),
    );

Note noteWithId(Library library, String id) =>
    library.notes.firstWhere((n) => n.id == id);

/// Record [attempts] answers on one card, [correct] of them right.
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

/// Answer the current question, clearing an introduction first if the card
/// is one the session has just shown for the first time.
void answerWith(Session session, String option) {
  if (session.isIntroducing) session.acknowledgeIntroduction();
  session.submit(option);
}

/// Ranked deck: nu/ni/na are weak, ne/no/re are mastered.
Library ranked() {
  var library = kana(unlocked: 6);
  const scores = {
    'nu': 2,
    'ni': 3,
    'na': 4,
    'ne': 10,
    'no': 10,
    're': 10,
  };
  scores.forEach((id, correct) {
    library = answerCard(library, id, Direction.forward, correct: correct);
  });
  return library;
}

/// Play a whole session, answering [correct], and tally what was asked.
Map<String, int> tallyAsked(Session session, {required bool correct}) {
  final counts = <String, int>{};
  var guard = 0;
  while (!session.isComplete && guard++ < 500) {
    final question = session.current;
    counts.update(question.note.id, (v) => v + 1, ifAbsent: () => 1);
    answerWith(session, 
      correct
          ? question.answer
          : question.options.firstWhere((o) => o != question.answer),
    );
    session.advance();
  }
  return counts;
}

void main() {
  group('buildOptions', () {
    test('always contains the answer and fills every slot', () {
      final library = kana();
      for (final direction in Direction.values) {
        for (final note in library.notes) {
          final options = buildOptions(
            library: library,
            note: note,
            direction: direction,
            random: Random(7),
          );
          expect(options, contains(note.answer(direction)));
          expect(options, hasLength(optionCount));
          expect(options.toSet(), hasLength(optionCount),
              reason: 'no duplicate options');
        }
      }
    });

    test('prefers the distractors the deck author supplied', () {
      final library = kana();
      final options = buildOptions(
        library: library,
        note: noteWithId(library, 'ne'),
        direction: Direction.forward,
        random: Random(1),
      );
      expect(options, containsAll(['ne', 'nu', 're']));
    });

    test('maps authored distractors through for a reverse question', () {
      // Distractors are written as wrong *backs*. Asked the other way
      // round, the wrong options must be the matching characters.
      final library = kana();
      final options = buildOptions(
        library: library,
        note: noteWithId(library, 'ne'),
        direction: Direction.reverse,
        random: Random(1),
      );
      expect(options, contains('ね'), reason: 'the answer');
      expect(options, containsAll(['ぬ', 'れ']),
          reason: 'the same confusion, the right way round');
      expect(options.any((o) => o == 'nu' || o == 're'), isFalse,
          reason: 'romaji must not leak into a character question');
    });

    test('never offers the answer as its own distractor', () {
      final library = kana();
      final options = buildOptions(
        library: library,
        note: noteWithId(library, 'ne'),
        direction: Direction.forward,
        random: Random(3),
      );
      expect(options.where((o) => o == 'ne'), hasLength(1));
    });

    test('runs short when a deck reuses the same answer', () {
      // Thai romanises ข ค ฆ all as "kor". Two options that both read
      // "kor" would make the question unanswerable, so duplicates collapse
      // — and a deck with only three distinct answers can only ever offer
      // three choices, however many cards it has.
      const thai = Library(
        id: 'thai',
        name: 'Thai',
        unlockedIds: {'g', 'k1', 'k2', 'k3', 'ng'},
        notes: [
          Note(id: 'g', front: 'ก', back: 'gor'),
          Note(id: 'k1', front: 'ข', back: 'kor'),
          Note(id: 'k2', front: 'ค', back: 'kor'),
          Note(id: 'k3', front: 'ฆ', back: 'kor'),
          Note(id: 'ng', front: 'ง', back: 'ngor'),
        ],
      );

      final forward = buildOptions(
        library: thai,
        note: thai.notes.first,
        direction: Direction.forward,
        random: Random(1),
      );
      expect(forward.toSet(), hasLength(forward.length));
      expect(forward, hasLength(3), reason: 'gor, kor, ngor and no more');

      // Asked the other way the answers are characters, which are unique,
      // so the same deck fills all four slots.
      final reverse = buildOptions(
        library: thai,
        note: thai.notes.first,
        direction: Direction.reverse,
        random: Random(1),
      );
      expect(reverse, hasLength(optionCount));
    });

    test('copes with a deck smaller than the option count', () {
      const tiny = Library(
        id: 't',
        name: 'T',
        unlockedIds: {'a', 'i'},
        notes: [
          Note(id: 'a', front: 'あ', back: 'a'),
          Note(id: 'i', front: 'い', back: 'i'),
        ],
      );
      final options = buildOptions(
        library: tiny,
        note: tiny.notes.first,
        direction: Direction.forward,
        random: Random(1),
      );
      expect(options, contains('a'));
      expect(options.length, lessThanOrEqualTo(optionCount));
      expect(options.toSet(), hasLength(options.length));
    });
  });

  group('game modes', () {
    Session start(GameMode game, {int length = 30, int seed = 5}) => Session(
          library: ranked(),
          config: SessionConfig(
            length: length,
            mode: DirectionMode.forward,
            game: game,
            duration: game.isTimed ? const Duration(minutes: 1) : null,
          ),
          random: Random(seed),
        );

    test('practice keeps mastered cards to the review slots', () {
      final counts = tallyAsked(start(GameMode.practice), correct: false);
      final strong = ['ne', 'no', 're']
          .map((id) => counts[id] ?? 0)
          .reduce((a, b) => a + b);
      expect(strong, lessThanOrEqualTo(reviewSlotsFor(30)));
    });

    test('random mode ignores how well you know things', () {
      final counts = tallyAsked(start(GameMode.random), correct: false);
      final strong = ['ne', 'no', 're']
          .map((id) => counts[id] ?? 0)
          .reduce((a, b) => a + b);

      // A straight shuffle over six cards should land on the three strong
      // ones far more often than practice's handful of review slots.
      expect(strong, greaterThan(reviewSlotsFor(30)));
    });

    test('random mode has no review slots at all', () {
      final session = start(GameMode.random);
      var guard = 0;
      while (!session.isComplete && guard++ < 100) {
        expect(session.current.isReview, isFalse);
        answerWith(session, session.current.answer);
        session.advance();
      }
    });

    test('a timed run does not stop on a question count', () {
      final session = start(GameMode.timed, length: 3);
      for (var i = 0; i < 12; i++) {
        expect(session.isComplete, isFalse);
        answerWith(session, session.current.answer);
        session.advance();
      }
      expect(session.asked, 12, reason: 'well past the length of 3');
    });

    test('stopping the clock ends a timed run', () {
      final session = start(GameMode.timed);
      answerWith(session, session.current.answer);
      session.advance();

      session.stop();
      expect(session.isComplete, isTrue);
      expect(() => session.current, throwsStateError);
    });

    test('stopping mid-reveal keeps the answer just given', () {
      final session = start(GameMode.timed);
      answerWith(session, session.current.answer);
      expect(session.isRevealing, isTrue);

      session.stop();
      expect(session.asked, 1);
      expect(session.correct, 1);
      expect(session.isComplete, isTrue);
    });

    test('a timed run still counts up on screen', () {
      final session = start(GameMode.timed, length: 3);
      expect(session.position, 1);
      for (var i = 0; i < 5; i++) {
        answerWith(session, session.current.answer);
        session.advance();
      }
      expect(session.position, 6, reason: 'not clamped to the length');
    });

    test('every mode still records answers the same way', () {
      for (final game in GameMode.values) {
        final session = start(game, length: 4);
        final question = session.current;
        answerWith(session, question.answer);
        expect(
          session.library.stateOf(question.note.id, question.direction).history.last,
          isTrue,
        );
      }
    });
  });

  group('Session', () {
    Session start({
      int length = 4,
      DirectionMode mode = DirectionMode.forward,
      Library? library,
      int seed = 5,
    }) =>
        Session(
          library: library ?? kana(),
          config: SessionConfig(length: length, mode: mode),
          random: Random(seed),
        );

    test('opens the pool for the chosen length', () {
      final session = Session(
        library: kana(unlocked: 0),
        config: const SessionConfig(length: 10, mode: DirectionMode.forward),
        random: Random(1),
      );
      expect(session.library.unlockedCount, 5);
    });

    test('never shrinks a pool that is already bigger', () {
      final session = Session(
        library: kana(unlocked: 6),
        config: const SessionConfig(length: 10, mode: DirectionMode.forward),
        random: Random(1),
      );
      expect(session.library.unlockedCount, 6);
    });

    test('counts positions from one', () {
      final session = start();
      expect(session.position, 1);
      expect(session.asked, 0);
      expect(session.isRevealing, isFalse);
    });

    test('a right answer scores and reveals', () {
      final session = start();
      answerWith(session, session.current.answer);

      expect(session.isRevealing, isTrue);
      expect(session.wasCorrect, isTrue);
      expect(session.correct, 1);
      expect(session.asked, 1);
    });

    test('a wrong answer reveals without scoring', () {
      final session = start();
      final question = session.current;
      final wrong = question.options.firstWhere((o) => o != question.answer);
      answerWith(session, wrong);

      expect(session.wasCorrect, isFalse);
      expect(session.picked, wrong);
      expect(session.correct, 0);
      expect(session.asked, 1);
    });

    test('records the answer against the right card and direction', () {
      final session = start();
      final question = session.current;
      answerWith(session, question.answer);

      final state =
          session.library.stateOf(question.note.id, question.direction);
      expect(state.history, [true]);
      expect(
        session.library.stateOf(question.note.id, question.direction.opposite)
            .attempts,
        0,
      );
    });

    test('a second submit while revealing is ignored', () {
      final session = start();
      final question = session.current;
      answerWith(session, question.answer);
      answerWith(session, question.answer);
      expect(session.asked, 1);
    });

    test('advancing before answering is ignored', () {
      final session = start();
      session.advance();
      expect(session.asked, 0);
      expect(session.isRevealing, isFalse);
    });

    test('runs exactly the chosen number of questions', () {
      final session = start(length: 6);
      var guard = 0;
      while (!session.isComplete && guard++ < 50) {
        answerWith(session, session.current.answer);
        session.advance();
      }
      expect(session.isComplete, isTrue);
      expect(session.asked, 6);
      expect(session.correct, 6);
    });

    test('does not ask the same card twice in a row', () {
      final session = start(length: 30);
      String? previous;
      var guard = 0;
      while (!session.isComplete && guard++ < 100) {
        final id = session.current.note.id;
        expect(id, isNot(previous));
        previous = id;
        answerWith(session, session.current.answer);
        session.advance();
      }
    });

    test('forward mode only ever asks forward', () {
      final session = start(length: 20, mode: DirectionMode.forward);
      var guard = 0;
      while (!session.isComplete && guard++ < 50) {
        expect(session.current.direction, Direction.forward);
        answerWith(session, session.current.answer);
        session.advance();
      }
    });

    test('reverse mode only ever asks reverse', () {
      final session = start(length: 20, mode: DirectionMode.reverse);
      var guard = 0;
      while (!session.isComplete && guard++ < 50) {
        expect(session.current.direction, Direction.reverse);
        answerWith(session, session.current.answer);
        session.advance();
      }
    });

    test('mixed mode uses both directions', () {
      final session = start(length: 40, mode: DirectionMode.mixed, seed: 11);
      final seen = <Direction>{};
      var guard = 0;
      while (!session.isComplete && guard++ < 100) {
        seen.add(session.current.direction);
        answerWith(session, session.current.answer);
        session.advance();
      }
      expect(seen, containsAll(Direction.values));
    });

    test('asking for the question after the end is a clear error', () {
      final session = start(length: 1);
      answerWith(session, session.current.answer);
      session.advance();
      expect(session.isComplete, isTrue);
      expect(() => session.current, throwsStateError);
    });

    test('goes to the weakest cards, not the strong ones', () {
      // nu/ni/na sit at 0.2/0.3/0.4 — all inside the band above the worst.
      // ne/no/re are mastered, so they should only appear in review slots.
      final session = Session(
        library: ranked(),
        config: const SessionConfig(length: 20, mode: DirectionMode.forward),
        random: Random(9),
      );
      final counts = tallyAsked(session, correct: false);
      final weak = ['nu', 'ni', 'na']
          .map((id) => counts[id] ?? 0)
          .reduce((a, b) => a + b);
      final strong = ['ne', 'no', 're']
          .map((id) => counts[id] ?? 0)
          .reduce((a, b) => a + b);

      expect(weak, greaterThan(strong));
      expect(strong, lessThanOrEqualTo(reviewSlotsFor(20)),
          reason: 'mastered cards only come up in review slots');
    });

    test('spends review slots on mastered cards', () {
      final session = Session(
        library: ranked(),
        config: const SessionConfig(length: 20, mode: DirectionMode.forward),
        random: Random(9),
      );
      var reviews = 0;
      var guard = 0;
      while (!session.isComplete && guard++ < 100) {
        if (session.current.isReview) {
          reviews += 1;
          final state = session.library
              .stateOf(session.current.note.id, session.current.direction);
          expect(state.winRate, greaterThanOrEqualTo(masteredFloor));
        }
        answerWith(session, session.current.answer);
        session.advance();
      }
      expect(reviews, greaterThan(0));
      expect(reviews, lessThanOrEqualTo(reviewSlotsFor(20)));
    });

    test('a review slot falls back to a weak card when nothing is mastered',
        () {
      final session = Session(
        library: kana(unlocked: 5),
        config: const SessionConfig(length: 20, mode: DirectionMode.forward),
        random: Random(4),
      );
      // Answering wrong throughout means nothing ever reaches mastered,
      // so every review slot has to fall back.
      var guard = 0;
      while (!session.isComplete && guard++ < 100) {
        expect(session.current.isReview, isFalse);
        final question = session.current;
        answerWith(session, question.options.firstWhere((o) => o != question.answer));
        session.advance();
      }
    });

    test('introduces untested cards ahead of tested ones', () {
      var library = kana(unlocked: 6);
      // Everything mastered except 'no', which has never been tried.
      for (final note in library.notes) {
        if (note.id == 'no') continue;
        library =
            answerCard(library, note.id, Direction.forward, correct: 10);
      }
      final session = Session(
        library: library,
        config: const SessionConfig(length: 12, mode: DirectionMode.forward),
        random: Random(6),
      );
      final counts = tallyAsked(session, correct: false);

      // Its fair share of 12 questions across 6 cards would be 2.
      expect(counts['no'] ?? 0, greaterThanOrEqualTo(4));
    });

    test('unlocks the next batch when the session clears it', () {
      var library = kana(unlocked: 5);
      // Four of five already clear; the fifth needs this session.
      for (final id in ['na', 'ni', 'nu', 'ne']) {
        library = answerCard(library, id, Direction.forward, correct: 10);
      }
      library = answerCard(library, 'no', Direction.forward,
          attempts: 3, correct: 3);

      final session = Session(
        library: library,
        config: const SessionConfig(length: 6, mode: DirectionMode.forward),
        random: Random(2),
      );
      tallyAsked(session, correct: true);

      expect(session.isComplete, isTrue);
      expect(session.library.unlockedCount, 6);
      expect(session.newlyUnlocked.map((n) => n.id), ['re']);
    });

    test('does not unlock when the batch is still weak', () {
      final session = Session(
        library: kana(unlocked: 5),
        config: const SessionConfig(length: 10, mode: DirectionMode.forward),
        random: Random(2),
      );
      tallyAsked(session, correct: false);

      expect(session.library.unlockedCount, 5);
      expect(session.newlyUnlocked, isEmpty);
    });

    test('opens nothing until something is actually mastered', () {
      final session = start(length: 8);
      expect(session.newlyUnlocked, isEmpty);

      // One correct answer is a 100% win rate but proves nothing, so it
      // must not retire the card and pull in the next one.
      answerWith(session, session.current.answer);
      expect(session.newlyUnlocked, isEmpty);
    });

    /// Five cards in play, every one of them one answer short of mastered.
    /// The pool is exactly at target, so nothing opens until a card tips
    /// over.
    Library onTheBrink() {
      var library = kana(unlocked: 5);
      for (final note in library.unlocked) {
        library = answerCard(library, note.id, Direction.forward,
            attempts: minAttemptsToMaster - 1,
            correct: minAttemptsToMaster - 1);
      }
      return library;
    }

    test('opens new material mid-session, the moment it is earned', () {
      final session = Session(
        library: onTheBrink(),
        config: const SessionConfig(length: 20, mode: DirectionMode.forward),
        random: Random(3),
      );
      expect(session.library.unlockedCount, 5, reason: 'already at target');
      expect(session.newlyUnlocked, isEmpty);

      answerWith(session, session.current.answer);

      expect(session.newlyUnlocked, isNotEmpty);
      expect(session.isComplete, isFalse,
          reason: 'it arrived while still playing, not at the end');
    });

    test('quitting early keeps what was opened', () {
      final session = Session(
        library: onTheBrink(),
        config: const SessionConfig(length: 40, mode: DirectionMode.forward),
        random: Random(3),
      );
      answerWith(session, session.current.answer);

      // Walk away right here: the library already carries the new card.
      expect(session.library.unlockedCount, greaterThan(5));
    });

    test('mixed mode targets the weaker direction of a card', () {
      var library = kana(unlocked: 6);
      for (final note in library.notes) {
        library =
            answerCard(library, note.id, Direction.forward, correct: 10);
        library = answerCard(library, note.id, Direction.reverse,
            correct: note.id == 'ne' ? 1 : 9);
      }
      final session = Session(
        library: library,
        config: const SessionConfig(length: 12, mode: DirectionMode.mixed),
        random: Random(8),
      );
      final directions = <Direction>[];
      var guard = 0;
      while (!session.isComplete && guard++ < 100) {
        if (!session.current.isReview) {
          directions.add(session.current.direction);
        }
        answerWith(session, session.current.answer);
        session.advance();
      }
      expect(
        directions.where((d) => d == Direction.reverse).length,
        greaterThan(directions.where((d) => d == Direction.forward).length),
        reason: 'writing is the weak direction here',
      );
    });

    test('the hint rides along with the question', () {
      final library = kana();
      final session = Session(
        library: library,
        config: const SessionConfig(length: 30, mode: DirectionMode.forward),
        random: Random(2),
      );
      var sawHint = false;
      var guard = 0;
      while (!session.isComplete && guard++ < 100) {
        if (session.current.note.id == 'ne') {
          expect(session.current.hint, 'Vertical spine, then a loop');
          sawHint = true;
        }
        answerWith(session, session.current.answer);
        session.advance();
      }
      expect(sawHint, isTrue);
    });
  });
}
