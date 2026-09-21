/// The app's one palette and type scale.
///
/// Deliberately single-theme. The contrast between the warm paper card and
/// the ink ground around it is the app's identity, and a light mode would
/// flatten it — a flashcard should read as paper lying on a dark desk.
library;

import 'package:flutter/material.dart';

import '../core/rules.dart';

/// Named colours. Use these rather than literals so a palette change is
/// one edit.
abstract final class Palette {
  /// Page ground.
  static const Color ground = Color(0xFF15171C);

  /// Raised surfaces: cards, list rows, inputs.
  static const Color panel = Color(0xFF1E212A);

  /// A panel that should sit back rather than forward.
  static const Color sunken = Color(0xFF12141A);

  /// Hairlines and inactive borders.
  static const Color line = Color(0xFF2D323E);

  /// Track behind a progress bar.
  static const Color track = Color(0xFF262A35);

  /// Primary text.
  static const Color text = Color(0xFFE7EAF1);

  /// Secondary text. Contrast against [ground] is about 6:1.
  static const Color dim = Color(0xFF8D95A6);

  /// Text that is present but deliberately receded.
  static const Color faint = Color(0xFF565D6C);

  /// The flashcard face.
  static const Color paper = Color(0xFFF5F2E9);

  /// Text on [paper].
  static const Color paperText = Color(0xFF1A1C22);

  /// Secondary text on [paper].
  static const Color paperDim = Color(0xFF5C5850);

  /// Hairline on [paper].
  static const Color paperLine = Color(0xFFDCD7C8);

  /// Interactive accent. White on this passes AA.
  static const Color accent = Color(0xFF5468C4);

  /// Accent surface behind selected rows.
  static const Color accentPanel = Color(0xFF232842);
}

/// Colours carrying meaning, kept separate from the accent.
abstract final class BandColor {
  static const Color fresh = Color(0xFF39404F);
  static const Color struggling = Color(0xFFC9633C);
  static const Color learning = Color(0xFFD7A13F);
  static const Color mastered = Color(0xFF5FA37F);

  /// The fill for a tile or bar segment in [band].
  static Color of(Band band) => switch (band) {
        Band.fresh => fresh,
        Band.struggling => struggling,
        Band.learning => learning,
        Band.mastered => mastered,
      };

  /// Text sitting on [of] for the same band.
  static Color textOn(Band band) =>
      band == Band.fresh ? const Color(0xFF454C5C) : Palette.ground;

  /// A muted version for a tile that has not been unlocked yet.
  static const Color locked = Color(0xFF1B1E26);
  static const Color lockedBorder = Color(0xFF272B35);
  static const Color lockedText = Color(0xFF454C5C);

  static String label(Band band) => switch (band) {
        Band.fresh => 'New',
        Band.struggling => 'Struggling',
        Band.learning => 'Learning',
        Band.mastered => 'Mastered',
      };
}

/// Monospace for anything read as an instrument: win rates, counts, tallies.
const String monoFamily = 'monospace';

/// Text styles used across screens.
abstract final class Type {
  static const TextStyle screenTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Palette.text,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    color: Palette.text,
  );

  static const TextStyle body = TextStyle(fontSize: 14, color: Palette.text);

  static const TextStyle secondary = TextStyle(fontSize: 13, color: Palette.dim);

  /// Small all-caps section markers.
  static const TextStyle sectionLabel = TextStyle(
    fontSize: 11,
    letterSpacing: 1.2,
    fontWeight: FontWeight.w500,
    color: Palette.dim,
    fontFamily: monoFamily,
  );

  static const TextStyle mono = TextStyle(
    fontSize: 12,
    color: Palette.dim,
    fontFamily: monoFamily,
  );

  /// The glyph on a flashcard. Sized per screen.
  static TextStyle glyph(double size) => TextStyle(
        fontSize: size,
        height: 1.05,
        color: Palette.paperText,
      );

  /// Smallest a card's text is allowed to get.
  ///
  /// Past this the card scrolls rather than shrinking further — scaling a
  /// long answer to fit made it unreadable, which defeats the point of
  /// showing it.
  static const double minCardSize = 18;

  /// Size for a card's prompt, from how much there is to show.
  ///
  /// A lone kana should fill the card; a sentence has to stay legible.
  /// Stepped rather than smoothly scaled so the same card is always the
  /// same size, whatever else is on screen.
  static double cardSizeFor(String text) {
    final length = text.runes.length;
    if (length <= 2) return 104;
    if (length <= 5) return 76;
    if (length <= 12) return 48;
    if (length <= 28) return 32;
    if (length <= 60) return 24;
    return minCardSize;
  }

  /// Size for the answer shown under the prompt, always a step quieter.
  static double answerSizeFor(String text) {
    final length = text.runes.length;
    if (length <= 6) return 28;
    if (length <= 20) return 22;
    return minCardSize;
  }
}

ThemeData buildTheme() {
  const scheme = ColorScheme.dark(
    primary: Palette.accent,
    onPrimary: Colors.white,
    surface: Palette.panel,
    onSurface: Palette.text,
    error: BandColor.struggling,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Palette.ground,
    canvasColor: Palette.ground,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.ground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: Type.screenTitle,
      iconTheme: IconThemeData(color: Palette.dim),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.accent,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    ),
    textTheme: const TextTheme(
      bodyMedium: Type.body,
      bodySmall: Type.secondary,
    ),
  );
}
