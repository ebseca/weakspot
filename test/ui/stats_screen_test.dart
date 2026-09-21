import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weakspot/core/model.dart';
import 'package:weakspot/core/store.dart';
import 'package:weakspot/ui/stats_screen.dart';
import 'package:weakspot/ui/theme.dart';

import '../core/store_test.dart' show FakeStore;

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

Future<void> pumpStats(
  WidgetTester tester,
  Library library, {
  LibraryRepository? repository,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: StatsScreen(library: library, repository: repository),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('says there is nothing to show yet', (tester) async {
    await pumpStats(tester, kana());

    expect(find.textContaining('Nothing recorded yet'), findsOneWidget);
    expect(find.textContaining('Play a session'), findsOneWidget);
    expect(find.text('BY DIRECTION'), findsNothing);
  });

  testWidgets('splits reading from writing', (tester) async {
    var library = kana();
    for (final note in library.unlocked) {
      library = answerCard(library, note.id, Direction.forward, correct: 10);
      library = answerCard(library, note.id, Direction.reverse, correct: 3);
    }
    await pumpStats(tester, library);

    expect(find.text('Reading'), findsOneWidget);
    expect(find.text('Writing'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('30%'), findsOneWidget);
  });

  testWidgets('says when a direction has never been practised',
      (tester) async {
    var library = kana();
    library = answerCard(library, 'na', Direction.forward, correct: 5);
    await pumpStats(tester, library);

    expect(find.text('—'), findsOneWidget);
    expect(find.text('Never practised this way round'), findsOneWidget);
  });

  testWidgets('lists weak cards with their recent record', (tester) async {
    var library = kana();
    library = answerCard(library, 'nu', Direction.forward, correct: 2);
    library = answerCard(library, 'ne', Direction.forward, correct: 5);
    await pumpStats(tester, library);

    expect(find.text('NEEDS WORK'), findsOneWidget);
    expect(find.text('2/10'), findsOneWidget);
    expect(find.text('5/10'), findsOneWidget);
    expect(find.text('→ reading'), findsNWidgets(2));
  });

  testWidgets('names the weak direction, not just the card', (tester) async {
    var library = kana();
    library = answerCard(library, 'ne', Direction.forward, correct: 10);
    library = answerCard(library, 'ne', Direction.reverse, correct: 1);
    await pumpStats(tester, library);

    expect(find.text('← writing'), findsOneWidget);
    expect(find.text('→ reading'), findsNothing,
        reason: 'the reading side is mastered, so it is not a weak spot');
  });

  testWidgets('says so when nothing is weak', (tester) async {
    var library = kana();
    library = answerCard(library, 'na', Direction.forward, correct: 10);
    await pumpStats(tester, library);

    expect(find.textContaining('Nothing weak right now'), findsOneWidget);
  });

  testWidgets('shows the whole deck as a grid', (tester) async {
    var library = kana();
    library = answerCard(library, 'na', Direction.forward, correct: 8);
    await pumpStats(tester, library);

    expect(find.text('ALL 6 CARDS'), findsOneWidget);
    for (final note in library.notes) {
      expect(find.text(note.front), findsWidgets);
    }
  });

  testWidgets('counts answers and unlocked cards in the header',
      (tester) async {
    var library = kana(unlocked: 5);
    library =
        answerCard(library, 'na', Direction.forward, attempts: 4, correct: 3);
    await pumpStats(tester, library);

    expect(find.textContaining('4 answers recorded'), findsOneWidget);
    expect(find.textContaining('5 of 6 unlocked'), findsOneWidget);
  });

  testWidgets('offers no unlock control without somewhere to save it',
      (tester) async {
    await pumpStats(tester, kana());
    expect(find.textContaining('Open '), findsNothing);
  });

  testWidgets('opens more cards by hand, and saves it', (tester) async {
    final store = FakeStore();
    final repo = LibraryRepository(
      store: store,
      assetLoader: (_) async => throw UnimplementedError(),
    );
    await pumpStats(tester, kana(unlocked: 1), repository: repo);

    // Five locked of six; only one can open at a time here.
    expect(find.text('Open 5 more cards'), findsOneWidget);
    await tester.tap(find.text('Open 5 more cards'));
    await tester.pumpAndSettle();

    expect(find.textContaining('6 of 6 unlocked'), findsOneWidget);
    expect(store.saved.single.unlockedCount, 6);
    expect(find.textContaining('Open '), findsNothing,
        reason: 'nothing left to open');
  });

  testWidgets('a locked card can be opened on its own, out of order',
      (tester) async {
    final store = FakeStore();
    final repo = LibraryRepository(
      store: store,
      assetLoader: (_) async => throw UnimplementedError(),
    );
    await pumpStats(tester, kana(unlocked: 1), repository: repo);

    // れ is last in the deck and still locked.
    await tester.tap(find.text('れ').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Not in play yet'), findsOneWidget);
    await tester.tap(find.text('Open this card now'));
    await tester.pumpAndSettle();

    final saved = store.saved.single;
    expect(saved.isUnlocked('re'), isTrue);
    expect(saved.isUnlocked('ni'), isFalse,
        reason: 'nothing in front of it came along');
    expect(saved.unlockedCount, 2);
  });

  testWidgets('an unlocked card offers no unlock button', (tester) async {
    final repo = LibraryRepository(
      store: FakeStore(),
      assetLoader: (_) async => throw UnimplementedError(),
    );
    await pumpStats(tester, kana(unlocked: 6), repository: repo);

    await tester.tap(find.text('ね').last);
    await tester.pumpAndSettle();

    expect(find.text('Open this card now'), findsNothing);
  });

  testWidgets('a read-only sheet cannot unlock', (tester) async {
    await pumpStats(tester, kana(unlocked: 1));

    await tester.tap(find.text('れ').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Not in play yet'), findsOneWidget);
    expect(find.text('Open this card now'), findsNothing);
  });

  testWidgets('tapping a card in the grid opens it', (tester) async {
    var library = kana();
    library = answerCard(library, 'ne', Direction.forward, correct: 6);
    await pumpStats(tester, library);

    await tester.tap(find.text('ね').last);
    await tester.pumpAndSettle();

    expect(find.text('RECENT ANSWERS'), findsOneWidget);
    expect(find.text('→ reading'), findsWidgets);
    expect(find.text('6/10'), findsWidgets);
  });

  testWidgets('a one-way deck shows only the reading score', (tester) async {
    var library = kana().copyWith();
    library = answerCard(library, 'na', Direction.forward, correct: 8);
    await pumpStats(
      tester,
      Library(
        id: library.id,
        name: library.name,
        notes: library.notes,
        unlockedIds: library.unlockedIds,
        cards: library.cards,
        reversible: false,
      ),
    );

    expect(find.text('Reading'), findsOneWidget);
    expect(find.text('Writing'), findsNothing);
  });

  testWidgets('long card text does not overflow the weak list',
      (tester) async {
    var library = const Library(
      id: 'vocab',
      name: 'Vocab',
      unlockedIds: {'q1', 'q2'},
      notes: [
        Note(
          id: 'q1',
          front: 'What does a torque wrench actually measure when you '
              'tighten a bolt with it?',
          back: 'The rotational force applied to the fastener',
        ),
        Note(id: 'q2', front: 'Short one', back: 'Brief'),
      ],
    );
    library = answerCard(library, 'q1', Direction.forward, correct: 2);
    await pumpStats(tester, library);

    expect(tester.takeException(), isNull);
    expect(find.text('2/10'), findsOneWidget);
  });

  testWidgets('fits a small phone without overflowing', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var library = kana();
    for (final note in library.unlocked) {
      library = answerCard(library, note.id, Direction.forward, correct: 4);
      library = answerCard(library, note.id, Direction.reverse, correct: 2);
    }
    await pumpStats(tester, library);

    expect(tester.takeException(), isNull);
  });
}
