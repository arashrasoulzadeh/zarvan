import '../quiz_screen.dart';
import 'home_screen.dart';

/// Where the content comes from: attribution lines, a link shown as text, and
/// the version.
class QuizAboutScreen extends QuizScreen {
  QuizAboutScreen(super.kit);

  @override
  void build() {
    final s = kit.strings;
    final about = kit.about;
    titleBar(s.about, onBack: () => goTo(QuizHomeScreen(kit)));
    final cx = QuizScreen.worldWidth / 2;
    label(s.appName, cx, 120, size: 30);
    var y = 180.0;
    for (final line in about.lines) {
      label(
        line,
        cx,
        y,
        size: 16,
        maxWidth: QuizScreen.worldWidth - 2 * QuizScreen.margin,
      );
      y += 44;
    }
    if (about.link != null) {
      final l = label(about.link!, cx, y, size: 16, color: theme.accent);
      l.text!.rtl = false;
      y += 44;
    }
    if (about.version.isNotEmpty) {
      label(
        '${s.aboutVersion}: ${about.version}',
        cx,
        y,
        size: 14,
        color: theme.soft,
      );
    }
  }
}
