import 'package:zarvan_core/zarvan_core.dart' show UiRect;

import '../quiz_screen.dart';
import '../quiz_theme.dart';
import 'home_screen.dart';

/// Theme, sound and haptics. They apply at once (the screen redraws in the new
/// theme) and are saved on change.
class QuizSettingsScreen extends QuizScreen {
  QuizSettingsScreen(super.kit);

  @override
  void build() {
    final s = kit.strings;
    final st = kit.settings;
    titleBar(s.settings, onBack: () => goTo(QuizHomeScreen(kit)));
    label(s.theme, QuizScreen.worldWidth / 2, 100, size: 18);
    final modes = [
      (QuizThemeMode.system, s.themeSystem),
      (QuizThemeMode.light, s.themeLight),
      (QuizThemeMode.dark, s.themeDark),
    ];
    final w = (QuizScreen.worldWidth - 2 * QuizScreen.margin - 16) / 3;
    for (var i = 0; i < 3; i++) {
      final (mode, text) = modes[i];
      button(
        UiRect(QuizScreen.margin + i * (w + 8), 124, w, 44),
        text,
        () {
          st.setThemeMode(mode);
          goTo(QuizSettingsScreen(kit));
        },
        style: st.themeMode == mode
            ? QuizButtonStyle.primary
            : QuizButtonStyle.option,
        size: 14,
      );
    }
    _toggle(200, s.sound, st.sound, st.setSound);
    _toggle(264, s.haptics, st.haptics, st.setHaptics);
  }

  void _toggle(double y, String name, bool on, void Function(bool) set) {
    button(
      row(y, height: 48),
      '$name · ${on ? '✓' : '—'}',
      () {
        set(!on);
        goTo(QuizSettingsScreen(kit));
      },
      style: on ? QuizButtonStyle.primary : QuizButtonStyle.option,
    );
  }
}
