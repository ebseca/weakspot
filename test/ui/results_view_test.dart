import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weakspot/core/model.dart';
import 'package:weakspot/core/session.dart';
import 'package:weakspot/ui/results_view.dart';
import 'package:weakspot/ui/theme.dart';

const List<Note> _notes = [
  Note(id: 'na', front: 'な', back: 'na'),
  Note(id: 'ni', front: 'に', back: 'ni'),
  Note(id: 'nu', front: 'ぬ', back: 'nu'),
  Note(id: 'ne', front: 'ね', back: 'ne'),
  Note(id: 'no', front: 'の', back: 'no'),
  Note(id: 're', front: 'れ', back: 're'),
  Note(id: 'ro', front: 'ろ', back: 'ro'),
];

Library library({int unlocked = 5}) => Library(
      id: 'kana',
      name: 'Kana',
      notes: _notes,
      unlockedIds: _notes.take(unlocked).map((n) => n.id).toSet(),
    );

Library answerCard(
  Library source,
  String noteId, {
  int attempts = historyWindow,
  required int correct,
}) {
  var next = source;
  for (var i = 0; i < attempts; i++) {
    next = next.recording(noteId, Direction.forward, i < correct);
  }
  return next;
}

/// Answer the current question, clearing an introduction first.
void answerWith(Session session, String option) {
  if (session.isIntroducing) session.acknowledgeIntroduction();
  session.submit(option);
}

/// Play a session to the end and return it.
Session played({
  required Library from,
  int length = 6,
  bool correct = true,
  int seed = 3,
}) {
  final session = Session(
    library: from,
    config: SessionConfig(length: length, mode: DirectionMode.forward),
    random: Random(seed),
  );
  var guard = 0;
  while (!session.isComplete && guard++ < 200) {
    final question = session.current;
    answerWith(session, correct
        ? question.answer
        : question.options.firstWhere((o) => o != question.answer));
    session.advance();
  }
  return session;
}

Future<void> pumpResults(
  WidgetTester tester,
  Session session, {
  VoidCallback? onDone,
  VoidCallback? onStats,
  VoidCallback? onReplay,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: ResultsView(
          session: session,
          onDone: onDone ?? () {},
          onStats: onStats ?? () {},
          onReplay: onReplay ?? () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the deck, the direction and the score', (tester) async {
    final session = played(from: library(), length: 6);
    await pumpResults(tester, session);

    expect(find.text('SESSION COMPLETE'), findsOneWidget);
    expect(find.text('Kana · character to sound'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(find.text('/6'), findsOneWidget);
  });

  testWidgets('draws every card in the deck, locked ones included',
      (tester) async {
    final session = played(from: library(unlocked: 5));
    await pumpResults(tester, session);

    expect(find.text('All 7 cards'.toUpperCase()), findsOneWidget);
    for (final note in _notes) {
      expect(find.text(note.front), findsWidgets,
          reason: '${note.id} should appear in the grid');
    }
  });

  testWidgets('explains what the colours mean', (tester) async {
    await pumpResults(tester, played(from: library()));

    expect(find.textContaining('Mastered'), findsOneWidget);
    expect(find.textContaining('Learning'), findsOneWidget);
    expect(find.textContaining('Struggling'), findsOneWidget);
    expect(find.text('Locked'), findsOneWidget);
  });

  testWidgets('announces what a cleared batch unlocked', (tester) async {
    // Four notes already clear; the session finishes the fifth.
    var source = library(unlocked: 5);
    for (final id in ['na', 'ni', 'nu', 'ne']) {
      source = answerCard(source, id, correct: 10);
    }
    source = answerCard(source, 'no', attempts: 3, correct: 3);

    final session = played(from: source, length: 6);
    expect(session.newlyUnlocked, isNotEmpty, reason: 'setup should unlock');

    await pumpResults(tester, session);
    expect(find.textContaining('unlocked'), findsWidgets);
    expect(find.text('れ'), findsWidgets);
  });

  testWidgets('says what is still in play when nothing opened',
      (tester) async {
    final session = played(from: library(), length: 6, correct: false);
    await pumpResults(tester, session);

    expect(find.text('Still working on'), findsOneWidget);
    expect(find.text('5 cards'), findsOneWidget);
    expect(find.textContaining('Master one'), findsOneWidget);
  });

  testWidgets('hides the lock legend once everything is unlocked',
      (tester) async {
    final session = played(from: library(unlocked: 7));
    await pumpResults(tester, session);

    expect(find.text('tap to read'), findsOneWidget);
    expect(find.text('Locked'), findsNothing);
  });

  testWidgets('every control fires', (tester) async {
    var done = 0;
    var stats = 0;
    var replay = 0;
    await pumpResults(
      tester,
      played(from: library()),
      onDone: () => done++,
      onStats: () => stats++,
      onReplay: () => replay++,
    );

    await tester.tap(find.text('Done'));
    await tester.tap(find.text('See weak spots'));
    await tester.tap(find.text('Play again'));
    await tester.pumpAndSettle();

    expect(done, 1);
    expect(stats, 1);
    expect(replay, 1);
  });

  testWidgets('tapping a card in the grid opens it', (tester) async {
    final session = played(from: library());
    await pumpResults(tester, session);

    await tester.tap(find.text('な').last);
    await tester.pumpAndSettle();

    expect(find.text('RECENT ANSWERS'), findsOneWidget);
  });

  testWidgets('names the mode when it is not the default', (tester) async {
    final session = Session(
      library: library(),
      config: const SessionConfig(
        length: 2,
        mode: DirectionMode.forward,
        game: GameMode.random,
      ),
      random: Random(3),
    );
    var guard = 0;
    while (!session.isComplete && guard++ < 40) {
      answerWith(session, session.current.answer);
      session.advance();
    }
    await pumpResults(tester, session);

    expect(find.text('Kana · random · character to sound'), findsOneWidget);
  });

  testWidgets('fits a small phone without overflowing', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpResults(tester, played(from: library()));
    expect(tester.takeException(), isNull);
  });
}
