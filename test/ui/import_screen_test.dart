import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weakspot/core/model.dart';
import 'package:weakspot/core/store.dart';
import 'package:weakspot/ui/import_screen.dart';
import 'package:weakspot/ui/theme.dart';

import '../core/store_test.dart' show FakeStore, fakeAssets;

const String _reply = '''
{"deck":"Thai consonants","cards":[
  {"front":"ก","back":"gor","hint":"Chicken","distractors":["kor","dor"]},
  {"front":"ข","back":"kor"},
  {"front":"ด","back":"dor"}
]}
''';

late FakeStore store;
Library? popped;

Future<void> pumpImport(
  WidgetTester tester, {
  String topic = '',
  List<Library> seed = const [],
}) async {
  store = FakeStore()..saved.addAll(seed);
  popped = null;
  final repository =
      LibraryRepository(store: store, assetLoader: fakeAssets);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            popped = await Navigator.of(context).push<Library>(
              MaterialPageRoute(
                builder: (_) =>
                    ImportScreen(repository: repository, topic: topic),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> paste(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('starts on the paste tab with nothing to judge', (tester) async {
    await pumpImport(tester);

    expect(find.text('Paste text'), findsOneWidget);
    expect(find.text('Import a file'), findsOneWidget);
    expect(find.text('Create library'), findsOneWidget);

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull, reason: 'nothing pasted yet');
  });

  testWidgets('a good reply reports the deck and its counts', (tester) async {
    await pumpImport(tester);
    await paste(tester, _reply);

    expect(find.text('Thai consonants — ready to create'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('cards'), findsOneWidget);
    expect(find.text('with hints'), findsOneWidget);
    expect(find.text('with distractors'), findsOneWidget);
    expect(find.text('Create library with 3 cards'), findsOneWidget);
  });

  testWidgets('names the exact bad card rather than just failing',
      (tester) async {
    await pumpImport(tester);
    await paste(tester, '''
{"deck":"D","cards":[
  {"front":"ก","back":"gor"},
  {"front":"ข"},
  {"front":"ก","back":"again"}
]}
''');

    expect(find.text('2 cards skipped'), findsOneWidget);
    expect(find.textContaining('Card 2'), findsOneWidget);
    expect(find.textContaining('Card 3'), findsOneWidget);
    expect(find.text('Create library with 1 cards'), findsOneWidget);
  });

  testWidgets('says plainly when it cannot read the reply', (tester) async {
    await pumpImport(tester);
    await paste(tester, 'Sorry, I cannot help with that.');

    expect(find.text("Can't read that"), findsOneWidget);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
  });

  testWidgets('tolerates a fenced reply with chatter round it',
      (tester) async {
    await pumpImport(tester);
    await paste(tester, "Here you go!\n\n```json\n$_reply\n```\n\nEnjoy.");

    expect(find.text('Thai consonants — ready to create'), findsOneWidget);
  });

  testWidgets('falls back to the topic when the reply names no deck',
      (tester) async {
    await pumpImport(tester, topic: 'Thai alphabet');
    await paste(tester, '{"cards":[{"front":"ก","back":"gor"}]}');

    expect(find.text('Thai alphabet — ready to create'), findsOneWidget);
  });

  testWidgets('creating saves the library and hands it back', (tester) async {
    await pumpImport(tester);
    await paste(tester, _reply);

    await tester.tap(find.text('Create library with 3 cards'));
    await tester.pumpAndSettle();

    // The store also holds the bundled decks, seeded while looking up
    // which ids are already taken.
    expect(store.saved.map((l) => l.id), contains('thai-consonants'));
    final saved = store.saved.firstWhere((l) => l.id == 'thai-consonants');
    expect(saved.name, 'Thai consonants');
    expect(saved.notes, hasLength(3));
    expect(saved.bundled, isFalse);
    expect(saved.unlockedCount, 0, reason: 'the first session opens the pool');

    expect(popped?.id, 'thai-consonants');
  });

  testWidgets('a new deck never overwrites one with the same name',
      (tester) async {
    await pumpImport(tester, seed: const [
      Library(id: 'thai-consonants', name: 'Something else', notes: []),
    ]);

    await paste(tester, _reply);
    await tester.tap(find.text('Create library with 3 cards'));
    await tester.pumpAndSettle();

    expect(store.saved.map((l) => l.id),
        containsAll(['thai-consonants', 'thai-consonants-2']));
  });

  testWidgets('warns when an answer repeats its question', (tester) async {
    await pumpImport(tester);
    await paste(tester,
        '{"deck":"Thai","cards":[{"front":"ฏ","back":"t - th tao ฏ"}]}');

    expect(find.textContaining('repeats the question'), findsOneWidget);
    expect(find.textContaining('give themselves away'), findsOneWidget);
    // Still importable — it is a warning, not a rejection.
    expect(find.text('Create library with 1 cards'), findsOneWidget);
  });

  testWidgets('warns when several cards share an answer', (tester) async {
    await pumpImport(tester);
    await paste(tester, '''
{"deck":"Thai","cards":[
  {"front":"ข","back":"kor"},
  {"front":"ค","back":"kor"},
  {"front":"ก","back":"gor"}
]}
''');

    expect(find.textContaining('used by more than one card'), findsOneWidget);
    expect(find.textContaining('fewer than 4 options'), findsOneWidget);
  });

  testWidgets('a clean deck gets no warnings', (tester) async {
    await pumpImport(tester);
    await paste(tester, _reply);

    expect(find.textContaining('repeats the question'), findsNothing);
    expect(find.textContaining('used by more than one card'), findsNothing);
  });

  testWidgets('offers to replace a deck of the same name, keeping progress',
      (tester) async {
    await pumpImport(tester, seed: [
      const Library(
        id: 'thai-consonants',
        name: 'Thai consonants',
        notes: [Note(id: 'ก', front: 'ก', back: 'old')],
        unlockedIds: {'ก'},
      ).recording('ก', Direction.forward, true),
    ]);

    await paste(tester, _reply);
    expect(find.text('Replace Thai consonants'), findsOneWidget);

    await tester.tap(find.text('Replace Thai consonants'));
    await tester.pumpAndSettle();

    final saved =
        store.saved.firstWhere((l) => l.id == 'thai-consonants');
    expect(saved.notes, hasLength(3), reason: 'new content');
    expect(saved.stateOf('ก', Direction.forward).history, [true],
        reason: 'old progress');
    expect(saved.isUnlocked('ก'), isTrue);
    expect(store.saved.where((l) => l.name == 'Thai consonants'), hasLength(1),
        reason: 'replaced, not duplicated');
  });

  testWidgets('can still make a separate deck instead', (tester) async {
    await pumpImport(tester, seed: const [
      Library(id: 'thai-consonants', name: 'Thai consonants', notes: []),
    ]);

    await paste(tester, _reply);
    await tester.tap(find.text('Create a separate deck instead'));
    await tester.pumpAndSettle();

    expect(store.saved.map((l) => l.id),
        containsAll(['thai-consonants', 'thai-consonants-2']));
  });

  testWidgets('a bundled deck is never offered for replacement',
      (tester) async {
    await pumpImport(tester, seed: const [
      Library(id: 'hiragana', name: 'Hiragana', bundled: true, notes: []),
    ]);

    await paste(tester, '{"deck":"Hiragana","cards":[{"front":"あ","back":"a"}]}');
    expect(find.textContaining('Replace'), findsNothing);
  });

  testWidgets('the file tab offers a picker', (tester) async {
    await pumpImport(tester);

    await tester.tap(find.text('Import a file'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a file'), findsOneWidget);
    expect(find.textContaining('too long to paste'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('fits a small phone without overflowing', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpImport(tester);
    await paste(tester, _reply);

    expect(tester.takeException(), isNull);
  });
}
