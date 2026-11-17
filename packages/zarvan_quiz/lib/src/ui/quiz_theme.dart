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
