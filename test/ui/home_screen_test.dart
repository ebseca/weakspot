import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weakspot/core/model.dart';
import 'package:weakspot/core/store.dart';
import 'package:weakspot/main.dart';

import '../core/store_test.dart' show FakeStore, fakeAssets;

Future<void> pumpApp(WidgetTester tester, LibraryRepository repo) async {
  await tester.pumpWidget(WeakspotApp(repository: repo));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists the bundled decks', (tester) async {
    final repo = LibraryRepository(store: FakeStore(), assetLoader: fakeAssets);
    await pumpApp(tester, repo);

    expect(find.text('Weakspot'), findsOneWidget);
    expect(find.text('YOUR LIBRARIES'), findsOneWidget);
    expect(find.text('Hiragana'), findsOneWidget);
    expect(find.text('Katakana'), findsOneWidget);
  });

  testWidgets('an untouched deck says so', (tester) async {
    final repo = LibraryRepository(store: FakeStore(), assetLoader: fakeAssets);
    await pumpApp(tester, repo);

    expect(find.textContaining('Not started'), findsNWidgets(2));
    expect(find.text('No answers recorded yet'), findsNWidgets(2));
  });

  testWidgets('a started deck shows its unlock count and bands',
      (tester) async {
    final store = FakeStore();
    final repo = LibraryRepository(store: store, assetLoader: fakeAssets);
    await repo.loadAll();

    var library = store.saved.first.copyWith(unlockedIds: {"あ"});
    for (var i = 0; i < 10; i++) {
      library = library.recording('あ', Direction.forward, true);
    }
    await repo.save(library);

    await pumpApp(tester, repo);

    expect(find.text('1 of 1 unlocked'), findsOneWidget);
    expect(find.text('1 mastered'), findsOneWidget);
  });

  testWidgets('an empty list offers a way forward, not a dead end',
      (tester) async {
    final repo = LibraryRepository(
      store: FakeStore(),
      assetLoader: (_) async => 'nothing usable here',
    );
    await pumpApp(tester, repo);

    expect(find.textContaining('Nothing here yet'), findsOneWidget);
    expect(find.text('Create a library'), findsOneWidget);
  });

  testWidgets('offers creating a library alongside the bundled decks',
      (tester) async {
    final repo = LibraryRepository(store: FakeStore(), assetLoader: fakeAssets);
    await pumpApp(tester, repo);

    expect(find.text('Create a library'), findsOneWidget);

    await tester.tap(find.text('Create a library'));
    await tester.pumpAndSettle();

    expect(find.text('New library'), findsOneWidget);
    expect(find.text('What do you want to learn?'), findsOneWidget);
  });

  testWidgets('a bundled deck cannot be deleted', (tester) async {
    final repo = LibraryRepository(store: FakeStore(), assetLoader: fakeAssets);
    await pumpApp(tester, repo);

    await tester.longPress(find.text('Hiragana'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Delete'), findsNothing);
  });

  testWidgets('a deck you made can be deleted, after confirming',
      (tester) async {
    final store = FakeStore()
      ..saved.add(const Library(id: 'thai', name: 'Thai', notes: []));
    final repo = LibraryRepository(store: store, assetLoader: fakeAssets);
    await pumpApp(tester, repo);

    await tester.longPress(find.text('Thai'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Thai?'), findsOneWidget);

    await tester.tap(find.text('Keep it'));
    await tester.pumpAndSettle();
    expect(find.text('Thai'), findsOneWidget);

    await tester.longPress(find.text('Thai'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Thai'), findsNothing);
    expect(store.saved.map((l) => l.id), isNot(contains('thai')));
  });

  testWidgets('the band bar paints segments with real height',
      (tester) async {
    final store = FakeStore();
    final repo = LibraryRepository(store: store, assetLoader: fakeAssets);
    await repo.loadAll();

    var library = store.saved.first.copyWith(unlockedIds: {"あ"});
    for (var i = 0; i < 10; i++) {
      library = library.recording('あ', Direction.forward, true);
    }
    await repo.save(library);
    await pumpApp(tester, repo);

    final segments = find.byType(ColoredBox);
    expect(segments, findsWidgets);
    for (final element in segments.evaluate()) {
      final size = tester.getSize(find.byWidget(element.widget));
      expect(size.height, greaterThan(0),
          reason: 'a zero-height segment renders as an empty track');
      expect(size.width, greaterThan(0));
    }
  });

  testWidgets('tapping a deck opens session setup', (tester) async {
    final repo = LibraryRepository(store: FakeStore(), assetLoader: fakeAssets);
    await pumpApp(tester, repo);

    await tester.tap(find.text('Hiragana'));
    await tester.pumpAndSettle();

    expect(find.text('HOW MANY QUESTIONS'), findsOneWidget);
    expect(find.text('WHICH WAY ROUND'), findsOneWidget);
    expect(find.text('Start session'), findsOneWidget);
    for (final length in ['10', '20', '40']) {
      expect(find.text(length), findsOneWidget);
    }
  });

  testWidgets('says how much will be in play, capped by the deck',
      (tester) async {
    final repo = LibraryRepository(store: FakeStore(), assetLoader: fakeAssets);
    await pumpApp(tester, repo);

    await tester.tap(find.text('Hiragana'));
    await tester.pumpAndSettle();

    // The stub deck has a single note, so that is all there is to open —
    // and it reads as "1 card", not "1 cards".
    expect(
      find.textContaining('Opens with 1 card', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('1 cards', findRichText: true),
      findsNothing,
    );
  });

  testWidgets('setup offers the three game modes', (tester) async {
    final repo = LibraryRepository(store: FakeStore(), assetLoader: fakeAssets);
    await pumpApp(tester, repo);

    await tester.tap(find.text('Hiragana'));
    await tester.pumpAndSettle();

    expect(find.text('MODE'), findsOneWidget);
    expect(find.text('Practice'), findsOneWidget);
    expect(find.text('Timed'), findsOneWidget);
    expect(find.text('Random'), findsOneWidget);
    expect(find.textContaining('Drills whatever you are worst at'),
        findsOneWidget);
  });

  testWidgets('picking Timed swaps question count for a duration',
      (tester) async {
    final repo = LibraryRepository(store: FakeStore(), assetLoader: fakeAssets);
    await pumpApp(tester, repo);

    await tester.tap(find.text('Hiragana'));
    await tester.pumpAndSettle();
    expect(find.text('HOW MANY QUESTIONS'), findsOneWidget);

    await tester.tap(find.text('Timed'));
    await tester.pumpAndSettle();

    expect(find.text('HOW LONG'), findsOneWidget);
    expect(find.text('HOW MANY QUESTIONS'), findsNothing);
    expect(find.text('minutes'), findsWidgets);
    expect(find.textContaining('against the clock'), findsOneWidget);
  });

  testWidgets('setup offers all three directions without scrolling',
      (tester) async {
    final repo = LibraryRepository(store: FakeStore(), assetLoader: fakeAssets);
    await pumpApp(tester, repo);

    await tester.tap(find.text('Katakana'));
    await tester.pumpAndSettle();

    expect(find.text('Reading'), findsOneWidget);
    expect(find.text('Writing'), findsOneWidget);
    expect(find.text('Mixed'), findsOneWidget);

    // Pinned above Start rather than at the end of the scrolling list, so
    // switching to mixed never means scrolling past the group picker.
    final start = tester.getTopLeft(find.text('Start session')).dy;
    final mixed = tester.getTopLeft(find.text('Mixed')).dy;
    expect(mixed, lessThan(start));

    await tester.tap(find.text('Mixed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('scored separately'), findsOneWidget);
  });

  testWidgets('renders without overflowing a small phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = LibraryRepository(store: FakeStore(), assetLoader: fakeAssets);
    await pumpApp(tester, repo);

    expect(tester.takeException(), isNull);
  });
}
