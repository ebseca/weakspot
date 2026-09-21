/// What the player has chosen about how the app behaves.
///
/// Separate from [Library] on purpose: these apply to every deck, and
/// wiping a deck should not reset them. Stored under their own
/// shared_preferences keys, one per setting, so a value added later
/// simply falls back to its default on an install that predates it.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The language new decks are generated in.
///
/// This is about the *content* the AI writes, not the app's own text: a
/// Turkish speaker learning Thai wants Thai on the front and Turkish on
/// the back. It is carried into the generated prompt and nowhere else.
enum PromptLanguage {
  english('English', 'English'),
  turkish('Türkçe', 'Turkish'),
  spanish('Español', 'Spanish'),
  german('Deutsch', 'German'),
  french('Français', 'French'),
  portuguese('Português', 'Portuguese'),
  russian('Русский', 'Russian'),
  japanese('日本語', 'Japanese');

  const PromptLanguage(this.nativeName, this.englishName);

  /// Shown in the picker, in the language itself.
  final String nativeName;

  /// Written into the prompt, which is in English.
  final String englishName;

  /// The default. English asks for no special instruction, so a deck made
  /// on a fresh install reads exactly as it always has.
  bool get isDefault => this == PromptLanguage.english;

  static PromptLanguage byName(String? name) => PromptLanguage.values
      .firstWhere((l) => l.name == name, orElse: () => PromptLanguage.english);
}

/// How many options a question may show.
///
/// Fewer is easier; more is a harder recall test. Four is the default the
/// whole app was tuned against.
const List<int> optionCountChoices = [3, 4, 6];

/// How many unmastered cards to hold in play.
///
/// The pacing knob. Three is a trickle, eight is closer to cramming.
const List<int> cardsInPlayChoices = [3, 5, 8];

/// Minutes offered for a timed run once Pro is on.
///
/// The free lengths plus one longer one. Pro adds a choice rather than
/// taking anything away.
const int proTimedMinutes = 10;

/// Every setting, as one immutable value.
@immutable
class Settings {
  const Settings({
    this.language = PromptLanguage.english,
    this.optionCount = 4,
    this.cardsInPlay = 5,
    this.haptics = true,
    this.pro = false,
  });

  final PromptLanguage language;
  final int optionCount;
  final int cardsInPlay;

  /// A short buzz on answering, so a right answer is felt as well as seen.
  final bool haptics;

  /// Whether Weakspot Pro is on.
  ///
  /// Nothing is charged and nothing is checked — the button flips this
  /// flag locally. It exists so the surfaces a subscription would gate
  /// are built and working; binding it to a real purchase later means
  /// changing where this value comes from, not what reads it.
  final bool pro;

  Settings copyWith({
    PromptLanguage? language,
    int? optionCount,
    int? cardsInPlay,
    bool? haptics,
    bool? pro,
  }) =>
      Settings(
        language: language ?? this.language,
        optionCount: optionCount ?? this.optionCount,
        cardsInPlay: cardsInPlay ?? this.cardsInPlay,
        haptics: haptics ?? this.haptics,
        pro: pro ?? this.pro,
      );

  @override
  bool operator ==(Object other) =>
      other is Settings &&
      other.language == language &&
      other.optionCount == optionCount &&
      other.cardsInPlay == cardsInPlay &&
      other.haptics == haptics &&
      other.pro == pro;

  @override
  int get hashCode =>
      Object.hash(language, optionCount, cardsInPlay, haptics, pro);
}

/// Where settings live between runs.
abstract class SettingsStore {
  Future<Settings> load();

  Future<void> save(Settings settings);
}

/// [SettingsStore] backed by shared_preferences.
class PrefsSettingsStore implements SettingsStore {
  PrefsSettingsStore({SharedPreferences? preferences})
      : _injected = preferences;

  static const String _language = 'weakspot.settings.language';
  static const String _optionCount = 'weakspot.settings.optionCount';
  static const String _cardsInPlay = 'weakspot.settings.cardsInPlay';
  static const String _haptics = 'weakspot.settings.haptics';
  static const String _pro = 'weakspot.settings.pro';

  final SharedPreferences? _injected;
  SharedPreferences? _cached;

  Future<SharedPreferences> get _prefs async =>
      _injected ?? (_cached ??= await SharedPreferences.getInstance());

  @override
  Future<Settings> load() async {
    final prefs = await _prefs;
    const fallback = Settings();

    // Each value is validated against what the app currently offers: a
    // stored option count of 5 from some future build should land back on
    // the default rather than asking an impossible question.
    final options = prefs.getInt(_optionCount);
    final pool = prefs.getInt(_cardsInPlay);

    return Settings(
      language: PromptLanguage.byName(prefs.getString(_language)),
      optionCount: optionCountChoices.contains(options)
          ? options!
          : fallback.optionCount,
      cardsInPlay:
          cardsInPlayChoices.contains(pool) ? pool! : fallback.cardsInPlay,
      haptics: prefs.getBool(_haptics) ?? fallback.haptics,
      pro: prefs.getBool(_pro) ?? fallback.pro,
    );
  }

  @override
  Future<void> save(Settings settings) async {
    final prefs = await _prefs;
    await prefs.setString(_language, settings.language.name);
    await prefs.setInt(_optionCount, settings.optionCount);
    await prefs.setInt(_cardsInPlay, settings.cardsInPlay);
    await prefs.setBool(_haptics, settings.haptics);
    await prefs.setBool(_pro, settings.pro);
  }
}

/// Holds the current settings and tells the screens when they change.
///
/// A [ChangeNotifier] rather than a state-management package, matching the
/// rest of the app: one object, passed down explicitly.
class SettingsController extends ChangeNotifier {
  SettingsController({SettingsStore? store, Settings? initial})
      : _store = store ?? PrefsSettingsStore(),
        _settings = initial ?? const Settings(),
        _loaded = initial != null;

  final SettingsStore _store;
  Settings _settings;
  bool _loaded;

  Settings get settings => _settings;

  /// False until [load] has finished. The app holds its first frame on
  /// this so a Pro install never flashes the free logo on the way in.
  bool get isLoaded => _loaded;

  Future<void> load() async {
    try {
      _settings = await _store.load();
    } catch (_) {
      // Unreadable settings are not worth failing the app over; the
      // defaults are all perfectly usable.
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> update(Settings settings) async {
    if (settings == _settings) return;
    _settings = settings;
    notifyListeners();
    await _store.save(settings);
  }
}
