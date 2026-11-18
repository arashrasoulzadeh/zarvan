import 'dart:ui' show Brightness, PlatformDispatcher;

import 'package:zarvan_flutter/zarvan_flutter.dart' show UiColors;

/// The colours and type of the quiz screens. One accent, quiet surfaces;
/// the game gives its own (the engine has no brand). It is the palette the
/// engine's UI builder draws with.
class QuizTheme implements UiColors {
  const QuizTheme({
    required this.background,
    required this.ink,
    required this.soft,
    required this.surface,
    required this.accent,
    required this.onAccent,
    required this.correct,
    required this.wrong,
    this.fontFamily,
    this.poemFontFamily,
    this.poemScale = 1,
    this.poemInset = 0,
    this.poemLineScale = 1,
    this.isDark = false,
  });

  @override
  final int background;

  /// Body text and strokes.
  @override
  final int ink;

  /// Quiet text and disabled controls.
  @override
  final int soft;

  /// Cards and panels.
  final int surface;

  /// Buttons and highlights.
  final int accent;

  /// Text on top of [accent].
  final int onAccent;

  /// Right answer and wrong answer colours.
  final int correct;
  final int wrong;

  /// The typeface for every label; null keeps the engine's default (which
  /// lacks Persian letters), so a Persian game must give one.
  final String? fontFamily;

  /// The typeface of the verses on the poem card, when the game wants one
  /// different from the interface's (a calligraphic face for poetry); null
  /// uses [fontFamily].
  final String? poemFontFamily;

  /// How much bigger or smaller than the default the verses are set in
  /// [poemFontFamily] (a calligraphic face usually needs to be larger).
  final double poemScale;

  /// Extra padding on each side of the verses, in world units, for a face whose
  /// glyphs overhang the width they are measured at.
  final double poemInset;

  /// A factor on how tall each verse row is laid out, for a face whose line
  /// metrics are taller than its glyphs.
  final double poemLineScale;
  final bool isDark;
}

/// Which theme the player wants.
enum QuizThemeMode { system, light, dark }

/// A light and a dark [QuizTheme] and the choice between them.
class QuizThemes {
  const QuizThemes({required this.light, required this.dark});

  final QuizTheme light;
  final QuizTheme dark;

  /// The theme for [mode]; `system` follows the device's brightness.
  QuizTheme resolve(QuizThemeMode mode, {Brightness? deviceBrightness}) {
    final b =
        deviceBrightness ?? PlatformDispatcher.instance.platformBrightness;
    return switch (mode) {
      QuizThemeMode.light => light,
      QuizThemeMode.dark => dark,
      QuizThemeMode.system => b == Brightness.dark ? dark : light,
    };
  }
}
