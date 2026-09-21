/// Persistence for libraries.
///
/// Libraries are stored one JSON string per key rather than as a single
/// blob, so saving progress on one deck never rewrites the others. The
/// [LibraryStore] interface exists so the backing store can change later
/// without anything above it noticing.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'deck_import.dart';
import 'model.dart';

/// Where libraries live between runs.
abstract class LibraryStore {
  /// Every stored library, in the order they were added.
  Future<List<Library>> loadAll();

  /// Write one library, adding it to the order if it is new.
  Future<void> save(Library library);

  /// Forget one library entirely.
  Future<void> remove(String id);
}

/// A deck that ships with the app.
class BundledDeck {
  const BundledDeck({required this.id, required this.asset});

  final String id;
  final String asset;
}

/// Decks seeded on first run, in the order they should appear.
const List<BundledDeck> bundledDecks = [
  BundledDeck(id: 'hiragana', asset: 'assets/decks/hiragana.json'),
  BundledDeck(id: 'katakana', asset: 'assets/decks/katakana.json'),
];

/// [LibraryStore] backed by shared_preferences.
///
/// Works unchanged on Android and on web, where it lands in localStorage.
class PrefsLibraryStore implements LibraryStore {
  PrefsLibraryStore({SharedPreferences? preferences}) : _injected = preferences;

  static const String _orderKey = 'weakspot.order';
  static const String _libraryPrefix = 'weakspot.library.';

  final SharedPreferences? _injected;
  SharedPreferences? _cached;

  Future<SharedPreferences> get _prefs async =>
      _injected ?? (_cached ??= await SharedPreferences.getInstance());

  @override
  Future<List<Library>> loadAll() async {
    final prefs = await _prefs;
    final order = prefs.getStringList(_orderKey) ?? const <String>[];
    final libraries = <Library>[];

    for (final id in order) {
      final raw = prefs.getString('$_libraryPrefix$id');
      if (raw == null) continue;
      final library = _decode(raw);
      if (library != null) libraries.add(library);
    }
    return libraries;
  }

  @override
  Future<void> save(Library library) async {
    final prefs = await _prefs;
    await prefs.setString(
      '$_libraryPrefix${library.id}',
      jsonEncode(library.toJson()),
    );

    final order = prefs.getStringList(_orderKey) ?? <String>[];
    if (!order.contains(library.id)) {
      await prefs.setStringList(_orderKey, [...order, library.id]);
    }
  }

  @override
  Future<void> remove(String id) async {
    final prefs = await _prefs;
    await prefs.remove('$_libraryPrefix$id');
    final order = prefs.getStringList(_orderKey) ?? <String>[];
    await prefs.setStringList(_orderKey, order.where((e) => e != id).toList());
  }

  /// A corrupt entry is skipped rather than crashing the library list —
  /// losing one deck beats refusing to open the app.
  Library? _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return Library.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }
}

/// Libraries plus the bundled decks, which are restored if they go missing.
class LibraryRepository {
  LibraryRepository({LibraryStore? store, AssetLoader? assetLoader})
      : _store = store ?? PrefsLibraryStore(),
        _loadAsset = assetLoader ?? rootBundle.loadString;

  final LibraryStore _store;
  final AssetLoader _loadAsset;

  /// Everything the player has, bundled decks first.
  Future<List<Library>> loadAll() async {
    final stored = await _store.loadAll();
    final byId = {for (final library in stored) library.id: library};

    for (final deck in bundledDecks) {
      final shipped = await _seed(deck);
      if (shipped == null) continue;

      final stored = byId[deck.id];
      if (stored == null) {
        await _store.save(shipped);
        byId[deck.id] = shipped;
        continue;
      }

      // A bundled deck's content belongs to the app version, so an update
      // that adds hints or categories reaches decks already in use. Card
      // ids are stable, so everything answered survives.
      final refreshed = stored.copyWith(
        name: shipped.name,
        notes: shipped.notes,
        reversible: shipped.reversible,
      );
      await _store.save(refreshed);
      byId[deck.id] = refreshed;
    }

    final bundledIds = bundledDecks.map((d) => d.id).toList();
    final ordered = <Library>[
      for (final id in bundledIds)
        if (byId.containsKey(id)) byId[id]!,
      for (final library in stored)
        if (!bundledIds.contains(library.id)) library,
    ];
    return ordered;
  }

  Future<void> save(Library library) => _store.save(library);

  Future<void> remove(String id) => _store.remove(id);

  /// Read a bundled deck asset in the same shape the AI prompt asks for.
  Future<Library?> _seed(BundledDeck deck) async {
    try {
      final raw = await _loadAsset(deck.asset);
      final parsed = parseDeck(raw, fallbackName: deck.id);
      if (!parsed.isUsable) return null;
      return parsed.toLibrary(id: deck.id, bundled: true);
    } catch (_) {
      return null;
    }
  }
}

/// Reads an asset as a string. Swapped out in tests.
typedef AssetLoader = Future<String> Function(String key);

/// A storage id for a new library, derived from its name.
///
/// Readable rather than a random uuid, so the stored keys are legible if
/// anyone ever goes looking. A name that collides — or one with no usable
/// characters at all, like a deck named only in emoji — gets a numeric
/// suffix instead of silently overwriting an existing deck.
String libraryIdFor(String name, Iterable<String> taken) {
  final slug = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  final base = slug.isEmpty ? 'library' : slug;
  final used = taken.toSet();
  if (!used.contains(base)) return base;

  for (var i = 2;; i++) {
    final candidate = '$base-$i';
    if (!used.contains(candidate)) return candidate;
  }
}
