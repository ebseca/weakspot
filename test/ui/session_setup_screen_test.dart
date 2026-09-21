import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weakspot/core/model.dart';
import 'package:weakspot/core/settings.dart';
import 'package:weakspot/core/store.dart';
import 'package:weakspot/ui/session_setup_screen.dart';
import 'package:weakspot/ui/theme.dart';

import '../core/settings_test.dart' show testSettings;
import '../core/store_test.dart' show FakeStore;

const Library _kana = Library(
  id: 'kana',
  name: 'Kana',
  notes: [
    Note(id: 'na', front: 'な', back: 'na'),
    Note(id: 'ni', front: 'に', back: 'ni'),
    Note(id: 'nu', front: 'ぬ', back: 'nu'),
    Note(id: 'ne', front: 'ね', back: 'ne'),
    Note(id: 'no', front: 'の', back: 'no'),
    Note(id: 're', front: 'れ', back: 're'),
    Note(id: 'ro', front: 'ろ', back: 'ro'),
    Note(id: 'ra', front: 'ら', back: 'ra'),
  ],
);

Future<void> pumpSetup(
  WidgetTester tester, {
  Settings settings = const Settings(),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: SessionSetupScreen(
        library: _kana,
        repository: LibraryRepository(
          store: FakeStore(),
          assetLoader: (_) async => throw UnimplementedError(),
        ),
        settings: testSettings(settings),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Switch to the timed mode, where the lengths are minutes.
Future<void> chooseTimed(WidgetTester tester) async {
  await tester.tap(find.text('Timed'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the pool preview follows the cards-in-play setting',
      (tester) async {
    // The count sits in a span inside the "Opens with ..." note.
    await pumpSetup(tester, settings: const Settings(cardsInPlay: 3));
    expect(find.textContaining('3 cards', findRichText: true), findsOneWidget);

    await pumpSetup(tester, settings: const Settings(cardsInPlay: 8));
    expect(find.textContaining('8 cards', findRichText: true), findsOneWidget);
  });

  group('the Pro timed length', () {
    testWidgets('is on screen but locked without Pro', (tester) async {
      await pumpSetup(tester);
      await chooseTimed(tester);

      expect(find.text('$proTimedMinutes'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('does not become the choice when it is tapped',
        (tester) async {
      await pumpSetup(tester);
      await chooseTimed(tester);

      await tester.tap(find.text('$proTimedMinutes'));
      await tester.pumpAndSettle();

      // Tapping it opens settings rather than selecting it, so the
      // padlock is still what is drawn on that choice.
      expect(find.text('Weakspot Pro'), findsOneWidget);
    });

    testWidgets('unlocks once Pro is on', (tester) async {
      await pumpSetup(tester, settings: const Settings(pro: true));
      await chooseTimed(tester);

      expect(find.text('$proTimedMinutes'), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsNothing);

      await tester.tap(find.text('$proTimedMinutes'));
      await tester.pumpAndSettle();

      expect(find.text('Weakspot Pro'), findsNothing,
          reason: 'it was chosen, not gated');
    });
  });

  testWidgets('fits a small phone without overflowing', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpSetup(tester);
    await chooseTimed(tester);
    expect(tester.takeException(), isNull);
  });
}
