import 'package:zarvan_core/zarvan_core.dart' show UiRect;

import 'package:zarvan_flutter/zarvan_flutter.dart' show measureText;

import '../ornaments.dart';
import '../quiz_screen.dart';
import 'home_screen.dart';

/// Where the content comes from: attribution lines, a link shown as text, and
/// the version, on a parchment card under the title.
class QuizAboutScreen extends QuizScreen {
  QuizAboutScreen(super.kit);

  static const _ink = 0xFF3A2312;

  @override
  void build() {
    final s = kit.strings;
    final about = kit.about;
    styledBackdrop(seed: 3);
    titleBar(s.about, onBack: () => goTo(QuizHomeScreen(kit)));
    const cx = QuizScreen.worldWidth / 2;
    final face = theme.poemFontFamily ?? theme.fontFamily;
    label(
      s.appName,
      cx + 1.5,
      111.5,
      size: 38,
      color: 0x99102040,
      fontFamily: face,
    );
    label(s.appName, cx, 110, size: 38, color: 0xFFFFF1D6, fontFamily: face);
    const textW = QuizScreen.worldWidth - 2 * QuizScreen.margin - 80;
    // Each line is as tall as it wraps to, so a long one never runs into the
    // next or out of the card.
    final heights = [
      for (final line in about.lines)
        measureText(
          line,
          fontSize: 16,
          fontFamily: theme.fontFamily,
          rtl: rtl,
          maxWidth: textW,
        ).height,
    ];
    final extraRows =
        (about.link != null ? 1 : 0) + (about.version.isNotEmpty ? 1 : 0);
    final height =
        96.0 + heights.fold<double>(0, (a, h) => a + h + 14) + extraRows * 36;
    spread(0.1);
    cartoucheAt(
      UiRect(
        QuizScreen.margin,
        160,
        QuizScreen.worldWidth - 2 * QuizScreen.margin,
        height,
      ),
      card: true,
      flowers: 1,
    );
    var y = 160 + 48.0;
    for (var i = 0; i < about.lines.length; i++) {
      label(
        about.lines[i],
        cx,
        y + heights[i] / 2,
        size: 16,
        color: _ink,
        maxWidth: textW,
      );
      y += heights[i] + 14;
    }
    y += 10;
    if (about.link != null) {
      final l = label(about.link!, cx, y, size: 16, color: 0xFF1F4E86);
      l.text!.rtl = false;
      y += 36;
    }
    if (about.version.isNotEmpty) {
      label(
        '${s.aboutVersion}: ${about.version}',
        cx,
        y,
        size: 14,
        color: 0xFF6B4A2B,
      );
    }
  }
}
