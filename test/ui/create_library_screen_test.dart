import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weakspot/core/settings.dart';
import 'package:weakspot/core/store.dart';
import 'package:weakspot/ui/create_library_screen.dart';
import 'package:weakspot/ui/theme.dart';

import '../core/settings_test.dart' show testSettings;
import '../core/store_test.dart' show FakeStore, fakeAssets;

/// Captures what the app puts on the clipboard.
class ClipboardSpy {
  String? text;

  void install(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          text = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
  }
}

Future<void> pumpCreate(
  WidgetTester tester, {
  Settings settings = const Settings(),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: CreateLibraryScreen(
        repository:
            LibraryRepository(store: FakeStore(), assetLoader: fakeAssets),
        settings: testSettings(settings),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the prompt before anything is typed', (tester) async {
    await pumpCreate(tester);

    expect(find.text('New library'), findsOneWidget);
    expect(find.text('What do you want to learn?'), findsOneWidget);
    expect(find.text('WHAT GETS COPIED'), findsOneWidget);
    expect(find.textContaining('[what you want to learn]'), findsOneWidget);
  });

  testWidgets('the prompt follows what you type', (tester) async {
    await pumpCreate(tester);

    await tester.enterText(
        find.byType(TextField), 'I would like to learn the Thai alphabet');
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Topic: I would like to learn the Thai alphabet'),
      findsOneWidget,
    );
  });

  testWidgets('copying puts the whole prompt on the clipboard',
      (tester) async {
    final clipboard = ClipboardSpy();
    clipboard.install(tester);
    await pumpCreate(tester);

    await tester.enterText(find.byType(TextField), 'hiragana');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy prompt'));
    await tester.pump();

    expect(clipboard.text, isNotNull);
    expect(clipboard.text, contains('Topic: hiragana'));
    expect(clipboard.text, contains('"cards"'));
    expect(clipboard.text, contains('"distractors"'));
  });

  testWidgets('says it copied, then goes back to normal', (tester) async {
    ClipboardSpy().install(tester);
    await pumpCreate(tester);

    await tester.tap(find.text('Copy prompt'));
    await tester.pump();
    expect(find.text('Copied to clipboard'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Copy prompt'), findsOneWidget);
  });

  testWidgets('explains the three steps', (tester) async {
    await pumpCreate(tester);

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.textContaining('nothing is sent from this app'),
        findsOneWidget);
  });

  testWidgets('leads on to the import screen', (tester) async {
    await pumpCreate(tester);

    await tester.tap(find.text('I have the reply — bring it in'));
    await tester.pumpAndSettle();

    expect(find.text('Bring in the reply'), findsOneWidget);
  });

  testWidgets('fits a small phone without overflowing', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpCreate(tester);
    expect(tester.takeException(), isNull);
  });
}
