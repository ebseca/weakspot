import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weakspot/core/model.dart';
import 'package:weakspot/core/store.dart';

/// In-memory [LibraryStore] that keeps insertion order.
class FakeStore implements LibraryStore {
  final List<Library> saved = [];

  @override
  Future<List<Library>> loadAll() async => List.of(saved);

  @override
  Future<void> save(Library library) async {
    final index = saved.indexWhere((l) => l.id == library.id);
    if (index == -1) {
      saved.add(library);
    } else {
      saved[index] = library;
    }
  }

  @override
  Future<void> remove(String id) async =>
      saved.removeWhere((l) => l.id == id);
}

const String _hiragana =
    '{"deck":"Hiragana","cards":[{"front":"あ","back":"a"}]}';
const String _katakana =
    '{"deck":"Katakana","cards":[{"front":"ア","back":"a"}]}';

Future<String> fakeAssets(String key) async => switch (key) {
      'assets/decks/hiragana.json' => _hiragana,
      'assets/decks/katakana.json' => _katakana,
      _ => throw Exception('missing asset $key'),
    };

void main() {
  group('PrefsLibraryStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<PrefsLibraryStore> store() async =>
        PrefsLibraryStore(preferences: await SharedPreferences.getInstance());

    test('starts empty', () async {
      expect(await (await store()).loadAll(), isEmpty);
    });

    test('saves and reloads a library with its progress', () async {
      final subject = await store();
      const library = Library(
        id: 'kana',
        name: 'Kana',
        notes: [Note(id: 'a', front: 'あ', back: 'a')],
        unlockedIds: {'a'},
      );
      await subject.save(library.recording('a', Direction.forward, true));

      final loaded = await subject.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.single.name, 'Kana');
      expect(loaded.single.stateOf('a', Direction.forward).history, [true]);
    });

    test('keeps insertion order and does not duplicate on re-save', () async {
      final subject = await store();
      const a = Library(id: 'a', name: 'A', notes: []);
      const b = Library(id: 'b', name: 'B', notes: []);

      await subject.save(a);
      await subject.save(b);
      await subject.save(a.copyWith(name: 'A2'));

      final loaded = await subject.loadAll();
      expect(loaded.map((l) => l.id), ['a', 'b']);
      expect(loaded.first.name, 'A2');
    });

    test('removing drops it from the order too', () async {
      final subject = await store();
      await subject.save(const Library(id: 'a', name: 'A', notes: []));
      await subject.remove('a');
      expect(await subject.loadAll(), isEmpty);
    });

    test('a corrupt entry is skipped rather than fatal', () async {
      SharedPreferences.setMockInitialValues({
        'weakspot.order': ['broken', 'fine'],
        'weakspot.library.broken': 'not json at all',
        'weakspot.library.fine': '{"id":"fine","name":"Fine","notes":[]}',
      });
      final subject = await store();
      final loaded = await subject.loadAll();
      expect(loaded.map((l) => l.id), ['fine']);
    });
  });

  group('libraryIdFor', () {
    test('slugifies the name', () {
      expect(libraryIdFor('Thai Alphabet', []), 'thai-alphabet');
      expect(libraryIdFor('Kitchen verbs (basic)', []), 'kitchen-verbs-basic');
    });

    test('trims punctuation off the ends', () {
      expect(libraryIdFor('  ¡Español!  ', []), 'espa-ol');
    });

    test('falls back when nothing usable is left', () {
      expect(libraryIdFor('日本語', []), 'library');
      expect(libraryIdFor('', []), 'library');
    });

    test('suffixes a name that is already taken', () {
      expect(libraryIdFor('Hiragana', ['hiragana']), 'hiragana-2');
      expect(
        libraryIdFor('Hiragana', ['hiragana', 'hiragana-2']),
        'hiragana-3',
      );
    });

    test('never collides with a bundled deck', () {
      final id = libraryIdFor('hiragana', bundledDecks.map((d) => d.id));
      expect(id, isNot('hiragana'));
    });
  });

  group('LibraryRepository', () {
    test('seeds the bundled decks on first run', () async {
      final store = FakeStore();
      final repo = LibraryRepository(store: store, assetLoader: fakeAssets);

      final loaded = await repo.loadAll();
      expect(loaded.map((l) => l.id), ['hiragana', 'katakana']);
      expect(loaded.first.name, 'Hiragana');
      expect(loaded.every((l) => l.bundled), isTrue);
      expect(store.saved, hasLength(2), reason: 'seeding persists');
    });

    test('refreshes bundled content but keeps progress', () async {
      final store = FakeStore();
      // A deck stored by an older version, before hints existed.
      store.saved.add(const Library(
        id: 'hiragana',
        name: 'Hiragana',
        bundled: true,
        unlockedIds: {'a'},
        notes: [Note(id: 'a', front: 'あ', back: 'a')],
      ).recording('あ', Direction.forward, true));

      final repo = LibraryRepository(
        store: store,
        assetLoader: (key) async => key.contains('hiragana')
            ? '{"deck":"Hiragana","cards":[{"id":"a","front":"あ","back":"a",'
                '"hint":"new hint"}]}'
            : await fakeAssets(key),
      );

      final loaded = await repo.loadAll();
      final hiragana = loaded.firstWhere((l) => l.id == 'hiragana');

      expect(hiragana.notes.single.hint, 'new hint');
      expect(hiragana.unlockedCount, 1, reason: 'progress survives');
      expect(hiragana.stateOf('あ', Direction.forward).history, [true]);
    });

    test('a shrunken bundled deck cannot leave the pool out of range',
        () async {
      final store = FakeStore()
        ..saved.add(const Library(
          id: 'hiragana',
          name: 'Hiragana',
          bundled: true,
          unlockedIds: {'gone', 'あ'},
          notes: [],
        ));
      final repo = LibraryRepository(store: store, assetLoader: fakeAssets);

      final loaded = await repo.loadAll();
      final hiragana = loaded.firstWhere((l) => l.id == 'hiragana');
      expect(hiragana.unlockedCount, lessThanOrEqualTo(hiragana.notes.length));
    });

    test('does not re-seed over existing progress', () async {
      final store = FakeStore();
      final repo = LibraryRepository(store: store, assetLoader: fakeAssets);

      var loaded = await repo.loadAll();
      final played =
          loaded.first.copyWith(unlockedIds: {'あ'}).recording('あ', Direction.forward, true);
      await repo.save(played);

      loaded = await repo.loadAll();
      expect(loaded.first.unlockedCount, 1);
      expect(loaded.first.stateOf('あ', Direction.forward).history, [true]);
    });

    test('restores a bundled deck that went missing', () async {
      final store = FakeStore();
      final repo = LibraryRepository(store: store, assetLoader: fakeAssets);
      await repo.loadAll();

      await repo.remove('hiragana');
      final loaded = await repo.loadAll();
      expect(loaded.map((l) => l.id), contains('hiragana'));
    });

    test('lists bundled decks first, then the player\'s own', () async {
      final store = FakeStore()
        ..saved.add(const Library(id: 'thai', name: 'Thai', notes: []));
      final repo = LibraryRepository(store: store, assetLoader: fakeAssets);

      final loaded = await repo.loadAll();
      expect(loaded.map((l) => l.id), ['hiragana', 'katakana', 'thai']);
    });

    test('a broken asset is skipped, not fatal', () async {
      final store = FakeStore();
      final repo = LibraryRepository(
        store: store,
        assetLoader: (key) async => key.contains('hiragana')
            ? 'garbage, not json'
            : await fakeAssets(key),
      );

      final loaded = await repo.loadAll();
      expect(loaded.map((l) => l.id), ['katakana']);
    });
  });
}
