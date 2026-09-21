import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weakspot/core/model.dart';
import 'package:weakspot/core/session.dart';
import 'package:weakspot/core/store.dart';
import 'package:weakspot/ui/session_screen.dart';
import 'package:weakspot/ui/theme.dart';

import '../core/settings_test.dart' show testSettings;
import '../core/store_test.dart' show FakeStore;

const Library _kana = Library(
  id: 'kana',
  name: 'Kana',
  unlockedIds: {'na', 'ni', 'nu', 'ne'},
  notes: [
    Note(id: 'na', front: 'な', back: 'na'),
    Note(id: 'ni', front: 'に', back: 'ni'),
    Note(id: 'nu', front: 'ぬ', back: 'nu'),
    Note(
      id: 'ne',
      front: 'ね',
      back: 'ne',
      hint: 'Vertical spine, then a loop',
      distractors: ['nu'],
    ),
  ],
);

/// Pump a session screen with a deterministic engine.
Future<Session> pumpSession(
  WidgetTester tester, {
  int length = 3,
  DirectionMode mode = DirectionMode.forward,
  int seed = 4,
  FakeStore? store,
}) async {
  final config = SessionConfig(length: length, mode: mode);
  final session =
      Session(library: _kana, config: config, random: Random(seed));

  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: SessionScreen(
        library: _kana,
        repository: LibraryRepository(
          store: store ?? FakeStore(),
          assetLoader: (_) async => throw UnimplementedError(),
        ),
        settings: testSettings(),
        config: config,
        session: session,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return session;
}

/// Clear the introduction screen if a card is being shown for the first
/// time, so the question underneath can be answered.
Future<void> clearIntroduction(WidgetTester tester) async {
  if (find.text('Got it').evaluate().isEmpty) return;
  await tester.tap(find.text('Got it'));
  await tester.pumpAndSettle();
}

/// Tap the option matching [label], introducing the card first if needed.
Future<void> tapOption(WidgetTester tester, String label) async {
  await clearIntroduction(tester);
  await tester.tap(find.widgetWithText(InkWell, label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows a card it has never shown before, unscored first',
      (tester) async {
    final session = await pumpSession(tester);

    expect(find.text('NEW CARD'), findsOneWidget);
    expect(find.text('Got it'), findsOneWidget);
    expect(find.textContaining("haven't seen this one"), findsOneWidget);
    // Both sides are on the card, and nothing is being asked yet.
    expect(find.text(session.current.answer), findsOneWidget);
    expect(session.asked, 0);
    expect(session.isIntroducing, isTrue);
  });

  testWidgets('the introduction is not scored', (tester) async {
    final session = await pumpSession(tester);
    final question = session.current;

    await clearIntroduction(tester);

    expect(session.isIntroducing, isFalse);
    expect(session.asked, 0);
    expect(
      session.library.stateOf(question.note.id, question.direction).attempts,
      0,
      reason: 'being shown a card is not an attempt at it',
    );
    expect(session.introduced, 1);
  });

  testWidgets('a card is only introduced once', (tester) async {
    final session = await pumpSession(tester, length: 6);
    final first = session.current.note.id;

    await tapOption(tester, session.current.answer);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Walk until that card comes round again; it must not re-introduce.
    var guard = 0;
    while (session.current.note.id != first && guard++ < 20) {
      await tapOption(tester, session.current.answer);
      if (session.isComplete) break;
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    }
    if (!session.isComplete && session.current.note.id == first) {
      expect(session.isIntroducing, isFalse);
    }
  });

  testWidgets('shows the prompt, the direction and four options',
      (tester) async {
    final session = await pumpSession(tester);
    await clearIntroduction(tester);

    expect(find.text('READING'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text(session.current.prompt), findsOneWidget);
    for (final option in session.current.options) {
      expect(find.text(option), findsWidgets);
    }
  });

  testWidgets('a right answer says so and offers Next', (tester) async {
    final session = await pumpSession(tester);
    final answer = session.current.answer;

    await tapOption(tester, answer);

    expect(find.text('CORRECT'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(session.correct, 1);
  });

  testWidgets('a wrong answer says so and reveals the hint', (tester) async {
    // Seeded so the first question is ね, the only card with a hint.
    late Session session;
    var seed = 0;
    for (; seed < 60; seed++) {
      session = Session(
        library: _kana,
        config: const SessionConfig(length: 3, mode: DirectionMode.forward),
        random: Random(seed),
      );
      if (session.current.note.id == 'ne') break;
    }
    expect(session.current.note.id, 'ne', reason: 'needed a hinted card');

    await pumpSession(tester, seed: seed);

    final question = session.current;
    final wrong = question.options.firstWhere((o) => o != question.answer);
    await tapOption(tester, wrong);

    expect(find.text('NOT QUITE'), findsOneWidget);
    expect(find.text('Vertical spine, then a loop'), findsOneWidget);
    expect(find.text('ne'), findsWidgets, reason: 'the answer is shown');
  });

  testWidgets('tapping an option again while revealing does nothing',
      (tester) async {
    final session = await pumpSession(tester);
    final answer = session.current.answer;

    await tapOption(tester, answer);
    await tapOption(tester, answer);

    expect(session.asked, 1);
  });

  testWidgets('walks to the end and shows the score', (tester) async {
    final session = await pumpSession(tester, length: 3);

    for (var i = 0; i < 3; i++) {
      await tapOption(tester, session.current.answer);
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
    }

    expect(find.text('SESSION COMPLETE'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('/3'), findsOneWidget);
  });

  testWidgets('the last question offers "See results"', (tester) async {
    final session = await pumpSession(tester, length: 1);
    await tapOption(tester, session.current.answer);
    expect(find.text('See results'), findsOneWidget);
  });

  testWidgets('progress is saved after every answer', (tester) async {
    final store = FakeStore();
    final session = await pumpSession(tester, store: store);

    await tapOption(tester, session.current.answer);
    await tester.pumpAndSettle();

    expect(store.saved, hasLength(1));
    final saved = store.saved.single;
    expect(saved.id, 'kana');
    expect(
      saved.cards.values.where((c) => c.attempts > 0),
      hasLength(1),
    );
  });

  testWidgets('a reverse session asks for the character', (tester) async {
    final session =
        await pumpSession(tester, mode: DirectionMode.reverse, length: 2);
    await clearIntroduction(tester);

    expect(find.text('WRITING'), findsOneWidget);
    expect(session.current.direction, Direction.reverse);
    // The prompt is romaji and the options are characters.
    expect(session.current.answer, isIn(_kana.notes.map((n) => n.front)));
  });

  testWidgets('fits a small phone without overflowing', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final session = await pumpSession(tester);
    await tapOption(tester, session.current.answer);

    expect(tester.takeException(), isNull);
  });

  testWidgets('answering does not resize the card', (tester) async {
    final session = await pumpSession(tester);
    await clearIntroduction(tester);

    Size cardSize() => tester.getSize(
          find.ancestor(
            of: find.text(session.current.prompt),
            matching: find.byType(Container),
          ).first,
        );

    final before = cardSize();
    await tapOption(tester, session.current.answer);
    final after = cardSize();

    expect(after, before,
        reason: 'the Next button reserves its space whether shown or not');
  });

  testWidgets('lays out side by side in landscape', (tester) async {
    tester.view.physicalSize = const Size(800, 380);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final session = await pumpSession(tester);
    await clearIntroduction(tester);

    expect(tester.takeException(), isNull);

    // The card sits to the left of the options rather than above them.
    final card = tester.getTopLeft(find.text(session.current.prompt));
    final firstOption = tester.getTopLeft(
      find.widgetWithText(InkWell, session.current.options.first).last,
    );
    expect(firstOption.dx, greaterThan(card.dx));
  });

  testWidgets('landscape survives answering too', (tester) async {
    tester.view.physicalSize = const Size(800, 380);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final session = await pumpSession(tester);
    await tapOption(tester, session.current.answer);

    expect(tester.takeException(), isNull);
    expect(find.text('Next'), findsOneWidget);
  });
}
