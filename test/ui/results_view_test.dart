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

  testWidgets('lists what this run asked, not the whole deck',
      (tester) async {
    final session = played(from: library(unlocked: 5), length: 6);
    await pumpResults(tester, session);

    expect(find.text('THIS RUN'), findsOneWidget);

    final asked = session.runCards.map((c) => c.note.id).toSet();
    expect(asked, isNotEmpty);
    for (final note in _notes) {
      final matcher = asked.contains(note.id) ? findsWidgets : findsNothing;
      expect(find.text(note.front), matcher,
          reason: '${note.id} was '
              '${asked.contains(note.id) ? '' : 'not '}asked this run');
    }
  });

  testWidgets('reports each card as it went this run', (tester) async {
    final session = played(from: library(), length: 6, correct: true);
    await pumpResults(tester, session);

    for (final card in session.runCards) {
      expect(find.text('${card.correct}/${card.asked}'), findsWidgets);
    }
    expect(find.textContaining('all clean'), findsOneWidget);
  });

  testWidgets('counts what needs work when answers were dropped',
      (tester) async {
    final session = played(from: library(), length: 6, correct: false);
    await pumpResults(tester, session);

    expect(session.shakyCount, greaterThan(0));
    expect(find.textContaining('${session.shakyCount} to work on'),
        findsOneWidget);
  });

  testWidgets('puts the worst card first', (tester) async {
    final session = played(from: library(), length: 6, correct: false);
    final cards = session.runCards;

    expect(cards.length, greaterThan(1));
    for (var i = 1; i < cards.length; i++) {
      expect(cards[i - 1].winRate, lessThanOrEqualTo(cards[i].winRate));
    }
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

  testWidgets('a run that answered nothing says so rather than showing an '
      'empty list', (tester) async {
    final session = Session(
      library: library(),
      config: const SessionConfig(length: 4, mode: DirectionMode.forward),
      random: Random(3),
    )..stop();

    await pumpResults(tester, session);

    expect(find.text('THIS RUN'), findsOneWidget);
    expect(find.textContaining('Nothing was answered'), findsOneWidget);
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
    await tester.tap(find.text('Play again'));

    // The run list can be longer than the page, so the link under it is
    // only built once it is scrolled to.
    await tester.scrollUntilVisible(
      find.text('See the whole deck'),
      160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('See the whole deck'));
    await tester.pumpAndSettle();

    expect(done, 1);
    expect(stats, 1);
    expect(replay, 1);
  });

  testWidgets('tapping a card in the run list opens it', (tester) async {
    final session = played(from: library());
    await pumpResults(tester, session);

    await tester.tap(find.text(session.runCards.first.prompt).first);
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
