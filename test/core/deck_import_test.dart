import 'package:flutter_test/flutter_test.dart';
import 'package:weakspot/core/deck_import.dart';

void main() {
  group('parseDeck', () {
    const good = '''
{"deck":"Hiragana","cards":[
  {"front":"あ","back":"a"},
  {"front":"ね","back":"ne","hint":"Vertical spine, then a loop",
   "distractors":["nu","re"]}
]}
''';

    test('reads a clean reply', () {
      final result = parseDeck(good);
      expect(result.isUsable, isTrue);
      expect(result.deckName, 'Hiragana');
      expect(result.notes.length, 2);
      expect(result.problems, isEmpty);
      expect(result.notes[1].hint, 'Vertical spine, then a loop');
      expect(result.notes[1].distractors, ['nu', 're']);
    });

    test('strips a markdown fence', () {
      final result = parseDeck('```json\n$good\n```');
      expect(result.isUsable, isTrue);
      expect(result.notes.length, 2);
    });

    test('strips a fence with no language tag', () {
      final result = parseDeck('```\n$good\n```');
      expect(result.isUsable, isTrue);
      expect(result.notes.length, 2);
    });

    test('ignores chatter around the JSON', () {
      final result = parseDeck(
        "Sure! Here's your deck:\n\n$good\n\nLet me know if you want more.",
      );
      expect(result.isUsable, isTrue);
      expect(result.notes.length, 2);
    });

    test('skips a card with no back and names it', () {
      final result = parseDeck('''
{"deck":"D","cards":[
  {"front":"あ","back":"a"},
  {"front":"い"},
  {"front":"う","back":"u"}
]}
''');
      expect(result.notes.length, 2);
      expect(result.problems, hasLength(1));
      expect(result.problems.single, contains('Card 2'));
      expect(result.problems.single, contains('back'));
    });

    test('skips a duplicate front and points at the original', () {
      final result = parseDeck('''
{"deck":"D","cards":[
  {"front":"や","back":"ya"},
  {"front":"ゆ","back":"yu"},
  {"front":"や","back":"ya again"}
]}
''');
      expect(result.notes.length, 2);
      expect(result.problems.single, contains('Card 3'));
      expect(result.problems.single, contains('card 1'));
    });

    test('skips an entry that is not an object', () {
      final result = parseDeck('{"cards":[{"front":"a","back":"b"},"oops"]}');
      expect(result.notes.length, 1);
      expect(result.problems.single, contains('Card 2'));
    });

    test('falls back when the reply names no deck', () {
      final result = parseDeck(
        '{"cards":[{"front":"a","back":"b"}]}',
        fallbackName: 'Thai alphabet',
      );
      expect(result.deckName, 'Thai alphabet');
    });

    test('reports no JSON at all', () {
      final result = parseDeck('I am afraid I cannot do that.');
      expect(result.isUsable, isFalse);
      expect(result.fatal, contains("Couldn't find any JSON"));
    });

    test('reports malformed JSON', () {
      final result = parseDeck('{"cards":[{"front":"a","back":}]}');
      expect(result.isUsable, isFalse);
      expect(result.fatal, contains('malformed'));
    });

    test('reports a missing cards list', () {
      final result = parseDeck('{"deck":"D"}');
      expect(result.isUsable, isFalse);
      expect(result.fatal, contains('cards'));
    });

    test('reports when nothing survived', () {
      final result = parseDeck('{"cards":[{"front":"あ"},{"back":"b"}]}');
      expect(result.isUsable, isFalse);
      expect(result.fatal, contains('usable'));
      expect(result.problems, hasLength(2));
    });

    test('an empty paste is not a crash', () {
      expect(parseDeck('   ').isUsable, isFalse);
    });

    test('a deck is reversible unless the reply says otherwise', () {
      expect(parseDeck(good).reversible, isTrue);
      expect(
        parseDeck('{"reversible":false,"cards":[{"front":"a","back":"b"}]}')
            .reversible,
        isFalse,
      );
    });

    test('one-way carries through to the library', () {
      final library =
          parseDeck('{"reversible":false,"cards":[{"front":"a","back":"b"}]}')
              .toLibrary(id: 'quiz');
      expect(library.reversible, isFalse);
    });

    test('the prompt asks whether the deck reverses', () {
      expect(buildDeckPrompt('thai alphabet'), contains('"reversible"'));
    });

    test('spots an answer that repeats the question', () {
      // A real Thai deck did this: the back listed the character again,
      // so asked in reverse the prompt handed over its own answer.
      final result = parseDeck('''
{"deck":"Thai","cards":[
  {"front":"ฏ","back":"t - th tao ฏ"},
  {"front":"ก","back":"gor gai"}
]}
''');
      expect(result.selfAnswering.map((n) => n.front), ['ฏ']);
    });

    test('a coincidental letter is not a leak', () {
      // "a" turning up inside "apple" is not the front giving itself away.
      final result = parseDeck(
        '{"cards":[{"front":"a","back":"apple"},{"front":"b","back":"bat"}]}',
      );
      expect(result.selfAnswering, isEmpty);
    });

    test('a longer front inside the back is a leak', () {
      final result =
          parseDeck('{"cards":[{"front":"cat","back":"a small cat"}]}');
      expect(result.selfAnswering, hasLength(1));
    });

    test('identical sides are not counted as a leak', () {
      // Pointless, but not this check\'s problem to report.
      final result = parseDeck('{"cards":[{"front":"ก","back":"ก"}]}');
      expect(result.selfAnswering, isEmpty);
    });

    test('reports answers shared by several cards', () {
      final result = parseDeck('''
{"deck":"Thai","cards":[
  {"front":"ข","back":"kor"},
  {"front":"ค","back":"kor"},
  {"front":"ก","back":"gor"}
]}
''');
      expect(result.duplicateAnswers, ['kor']);
      expect(result.distinctAnswers, 2);
    });

    test('a deck with distinct answers reports none', () {
      expect(parseDeck(good).duplicateAnswers, isEmpty);
      expect(parseDeck(good).distinctAnswers, 2);
    });

    test('the prompt warns the model off both mistakes', () {
      final prompt = buildDeckPrompt('thai alphabet');
      expect(prompt, contains('distinct from every other'));
      expect(prompt, contains('never put the front inside the back'));
    });

    test('counts what the deck actually carries', () {
      final result = parseDeck(good);
      expect(result.notes.length, 2);
      expect(result.withHints, 1);
      expect(result.withDistractors, 1);
    });

    test('counts are zero for a bare deck', () {
      final result = parseDeck('{"cards":[{"front":"a","back":"b"}]}');
      expect(result.withHints, 0);
      expect(result.withDistractors, 0);
    });

    test('builds a library with nothing unlocked yet', () {
      final library = parseDeck(good).toLibrary(id: 'hiragana');
      expect(library.id, 'hiragana');
      expect(library.name, 'Hiragana');
      expect(library.unlockedCount, 0);
      expect(library.bundled, isFalse);
    });
  });

  group('buildDeckPrompt', () {
    test('carries the topic through', () {
      expect(
        buildDeckPrompt('I would like to learn hiragana'),
        contains('Topic: I would like to learn hiragana'),
      );
    });

    test('asks for the JSON shape the parser accepts', () {
      final prompt = buildDeckPrompt('thai alphabet');
      expect(prompt, contains('"deck"'));
      expect(prompt, contains('"cards"'));
      expect(prompt, contains('"front"'));
      expect(prompt, contains('"back"'));
      expect(prompt, contains('"hint"'));
      expect(prompt, contains('"distractors"'));
    });

    test('has a placeholder when nothing was typed', () {
      expect(buildDeckPrompt('  '), contains('[what you want to learn]'));
    });

    test('asks for a language only when one is given', () {
      expect(buildDeckPrompt('thai alphabet'), isNot(contains('write every')));

      final turkish =
          buildDeckPrompt('thai alphabet', language: 'Turkish');
      expect(turkish, contains('write every "back" and every "hint" in '
          'Turkish'));
      expect(turkish, contains('The "front" stays in'));
    });

    test('a language does not disturb the shape the parser reads', () {
      final prompt = buildDeckPrompt('kana', language: 'Turkish');
      expect(prompt, contains('"cards"'));
      expect(prompt, contains('"reversible"'));
    });
  });
}
