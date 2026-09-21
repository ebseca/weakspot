import 'package:flutter_test/flutter_test.dart';
import 'package:weakspot/core/launcher_icon.dart';
import 'package:weakspot/core/settings.dart';

/// A settings store held in memory, so a test never touches the platform.
class FakeSettingsStore implements SettingsStore {
  FakeSettingsStore([this.stored = const Settings()]);

  Settings stored;
  int saves = 0;

  /// Set to make [load] fail, standing in for unreadable storage.
  bool failOnLoad = false;

  @override
  Future<Settings> load() async {
    if (failOnLoad) throw StateError('unreadable');
    return stored;
  }

  @override
  Future<void> save(Settings settings) async {
    stored = settings;
    saves += 1;
  }
}

/// Records which launcher icon it was asked for.
class FakeLauncherIcon implements LauncherIcon {
  final List<bool> asked = [];

  @override
  Future<void> use({required bool pro}) async => asked.add(pro);
}

/// A controller a widget test can pump straight away.
SettingsController testSettings([Settings initial = const Settings()]) =>
    SettingsController(
      store: FakeSettingsStore(initial),
      launcherIcon: FakeLauncherIcon(),
      initial: initial,
    );

void main() {
  group('Settings', () {
    test('defaults match what the app was tuned against', () {
      const settings = Settings();
      expect(settings.language, PromptLanguage.english);
      expect(settings.optionCount, 4);
      expect(settings.cardsInPlay, 5);
      expect(settings.haptics, isTrue);
      expect(settings.pro, isFalse);
    });

    test('every default is one of the offered choices', () {
      const settings = Settings();
      expect(optionCountChoices, contains(settings.optionCount));
      expect(cardsInPlayChoices, contains(settings.cardsInPlay));
    });

    test('copyWith changes one thing and leaves the rest', () {
      const settings = Settings(pro: true, cardsInPlay: 8);
      final changed = settings.copyWith(optionCount: 6);

      expect(changed.optionCount, 6);
      expect(changed.pro, isTrue);
      expect(changed.cardsInPlay, 8);
    });

    test('values compare by content, so a no-op update is detectable', () {
      expect(const Settings(), const Settings());
      expect(const Settings(pro: true), isNot(const Settings()));
    });

    test('an unknown stored language falls back to English', () {
      expect(PromptLanguage.byName('klingon'), PromptLanguage.english);
      expect(PromptLanguage.byName(null), PromptLanguage.english);
      expect(PromptLanguage.byName('turkish'), PromptLanguage.turkish);
    });

    test('only English counts as the default', () {
      expect(PromptLanguage.english.isDefault, isTrue);
      expect(PromptLanguage.turkish.isDefault, isFalse);
    });

    test('the Pro timed length is longer than any free one', () {
      expect(proTimedMinutes, greaterThan(5));
    });
  });

  group('SettingsController', () {
    test('a controller given no initial value is not loaded yet', () {
      final controller = SettingsController(store: FakeSettingsStore());
      expect(controller.isLoaded, isFalse);
    });

    test('loading publishes what was stored', () async {
      final store = FakeSettingsStore(const Settings(pro: true));
      final controller =
          SettingsController(store: store, launcherIcon: FakeLauncherIcon());

      var notified = 0;
      controller.addListener(() => notified += 1);
      await controller.load();

      expect(controller.isLoaded, isTrue);
      expect(controller.settings.pro, isTrue);
      expect(notified, 1);
    });

    test('unreadable storage falls back to defaults rather than failing',
        () async {
      final controller = SettingsController(
        store: FakeSettingsStore()..failOnLoad = true,
        launcherIcon: FakeLauncherIcon(),
      );

      await controller.load();

      expect(controller.isLoaded, isTrue);
      expect(controller.settings, const Settings());
    });

    test('an update is published and written', () async {
      final store = FakeSettingsStore();
      final controller =
          SettingsController(store: store, launcherIcon: FakeLauncherIcon());
      await controller.load();

      var notified = 0;
      controller.addListener(() => notified += 1);
      await controller.update(const Settings(pro: true));

      expect(controller.settings.pro, isTrue);
      expect(store.stored.pro, isTrue);
      expect(notified, 1);
    });

    test('setting the same value again writes nothing', () async {
      final store = FakeSettingsStore();
      final controller =
          SettingsController(store: store, launcherIcon: FakeLauncherIcon());
      await controller.load();

      await controller.update(const Settings());

      expect(store.saves, 0);
    });
  });

  group('the launcher icon follows Pro', () {
    test('loading reconciles the icon with what was stored', () async {
      final icon = FakeLauncherIcon();
      final controller = SettingsController(
        store: FakeSettingsStore(const Settings(pro: true)),
        launcherIcon: icon,
      );

      await controller.load();

      expect(icon.asked, [true],
          reason: 'a Pro install gets the Pro icon back on every launch');
    });

    test('subscribing swaps it, and turning Pro off swaps it back',
        () async {
      final icon = FakeLauncherIcon();
      final controller = SettingsController(
        store: FakeSettingsStore(),
        launcherIcon: icon,
      );
      await controller.load();
      icon.asked.clear();

      await controller.update(const Settings(pro: true));
      await controller.update(const Settings());

      expect(icon.asked, [true, false]);
    });

    test('a change that leaves Pro alone does not touch the icon', () async {
      final icon = FakeLauncherIcon();
      final controller = SettingsController(
        store: FakeSettingsStore(),
        launcherIcon: icon,
      );
      await controller.load();
      icon.asked.clear();

      await controller.update(const Settings(optionCount: 6));
      await controller.update(const Settings(optionCount: 6, cardsInPlay: 8));

      expect(icon.asked, isEmpty);
    });
  });
}
