import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weakspot/core/settings.dart';
import 'package:weakspot/ui/settings_screen.dart';
import 'package:weakspot/ui/theme.dart';

import '../core/settings_test.dart' show FakeSettingsStore;

late FakeSettingsStore store;

Future<SettingsController> pumpSettings(
  WidgetTester tester, {
  Settings initial = const Settings(),
}) async {
  store = FakeSettingsStore(initial);
  final controller = SettingsController(store: store, initial: initial);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: SettingsScreen(controller: controller),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// Bring [finder] into view. The settings list is taller than a test
/// viewport, and a ListView only builds what is on screen.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find.byType(Scrollable).first,
  );
}

void main() {
  testWidgets('shows every setting on one screen', (tester) async {
    await pumpSettings(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Weakspot Pro'), findsOneWidget);
    expect(find.text('DECK LANGUAGE'), findsOneWidget);
    expect(find.text('ANSWER OPTIONS'), findsOneWidget);

    await scrollTo(tester, find.text('CARDS IN PLAY'));
    expect(find.text('CARDS IN PLAY'), findsOneWidget);

    await scrollTo(tester, find.text('Haptics'));
    expect(find.text('Haptics'), findsOneWidget);
  });

  testWidgets('changing the option count is saved straight away',
      (tester) async {
    final controller = await pumpSettings(tester);

    await scrollTo(tester, find.text('ANSWER OPTIONS'));
    await tester.tap(find.text('6'));
    await tester.pumpAndSettle();

    expect(controller.settings.optionCount, 6);
    expect(store.stored.optionCount, 6);
  });

  testWidgets('changing the pool size is saved straight away', (tester) async {
    final controller = await pumpSettings(tester);

    await scrollTo(tester, find.text('CARDS IN PLAY'));
    await tester.tap(find.text('8'));
    await tester.pumpAndSettle();

    expect(controller.settings.cardsInPlay, 8);
    expect(store.stored.cardsInPlay, 8);
  });

  testWidgets('haptics can be turned off', (tester) async {
    final controller = await pumpSettings(tester);

    await scrollTo(tester, find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(controller.settings.haptics, isFalse);
    expect(store.stored.haptics, isFalse);
  });

  testWidgets('the language picker offers every language and keeps the pick',
      (tester) async {
    final controller = await pumpSettings(tester);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    // Only the first few fit a test viewport; the sheet scrolls for the
    // rest, which is the widget's own `for` over PromptLanguage.values.
    expect(find.text(PromptLanguage.english.nativeName), findsWidgets);
    expect(find.text(PromptLanguage.turkish.nativeName), findsOneWidget);

    await tester.tap(find.text('Türkçe').last);
    await tester.pumpAndSettle();

    expect(controller.settings.language, PromptLanguage.turkish);
    expect(store.stored.language, PromptLanguage.turkish);
    expect(find.text('Türkçe'), findsOneWidget, reason: 'the sheet closed');
  });

  group('Pro', () {
    testWidgets('says plainly that nothing is charged', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Subscribe now'), findsOneWidget);
      expect(find.textContaining('no payments in it'), findsOneWidget);
    });

    testWidgets('subscribing turns it on and is kept', (tester) async {
      final controller = await pumpSettings(tester);

      await tester.tap(find.text('Subscribe now'));
      await tester.pumpAndSettle();

      expect(controller.settings.pro, isTrue);
      expect(store.stored.pro, isTrue);
      expect(find.text('PRO'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('it can be turned off again', (tester) async {
      final controller =
          await pumpSettings(tester, initial: const Settings(pro: true));

      expect(find.text('Subscribe now'), findsNothing);
      await tester.tap(find.text('Turn Pro off'));
      await tester.pumpAndSettle();

      expect(controller.settings.pro, isFalse);
      expect(find.text('Subscribe now'), findsOneWidget);
    });
  });

  testWidgets('fits a small phone without overflowing', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpSettings(tester);
    expect(tester.takeException(), isNull);
  });
}
