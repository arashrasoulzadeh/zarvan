import 'package:zarvan_core/zarvan_core.dart' show UiRect;

import '../ornaments.dart';
import '../quiz_screen.dart';
import '../quiz_theme.dart';
import 'home_screen.dart';

/// Theme, sound and haptics. They apply at once (the screen redraws in the new
/// theme) and are saved on change. The choices are gilded banners: green velvet
/// for the one that is on, blue for the rest.
class QuizSettingsScreen extends QuizScreen {
  QuizSettingsScreen(super.kit);

  static const _blue = 0xFF1F4E86;

  @override
  void build() {
    final s = kit.strings;
    final st = kit.settings;
    styledBackdrop(seed: 2);
    titleBar(s.settings, onBack: () => goTo(QuizHomeScreen(kit)));
    label(s.theme, QuizScreen.worldWidth / 2, 110, size: 18, color: 0xFFFFF1D6);
    final modes = [
      (QuizThemeMode.system, s.themeSystem),
      (QuizThemeMode.light, s.themeLight),
      (QuizThemeMode.dark, s.themeDark),
    ];
    final w = (QuizScreen.worldWidth - 2 * QuizScreen.margin - 16) / 3;
    for (var i = 0; i < 3; i++) {
      final (mode, text) = modes[i];
      final on = st.themeMode == mode;
      bannerButton(
        UiRect(QuizScreen.margin + i * (w + 8), 134, w, 52),
        text,
        () {
          st.setThemeMode(mode);
          goTo(QuizSettingsScreen(kit));
        },
        size: 14,
        flowers: 0,
        color: on ? null : _blue,
        gleam: on ? 0.5 : 0,
      );
    }
    _toggle(220, s.sound, st.sound, st.setSound);
    _toggle(294, s.haptics, st.haptics, st.setHaptics);
  }

  void _toggle(double y, String name, bool on, void Function(bool) set) {
    // A seal beside the name says whether it is on: ticked, or plain.
    sealAt(
      QuizScreen.worldWidth / 2 + (rtl ? 1 : -1) * 92,
      y + 28,
      28,
      on ? 2 : 0,
      z: 8,
    );
    bannerButton(
      row(y, height: 56),
      name,
      () {
        set(!on);
        goTo(QuizSettingsScreen(kit));
      },
      color: on ? null : _blue,
      gleam: on ? 0.5 : 0,
    );
  }
}
