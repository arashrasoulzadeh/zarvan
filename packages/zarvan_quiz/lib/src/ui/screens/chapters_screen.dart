import 'package:zarvan_core/zarvan_core.dart' show UiRect;
import 'package:zarvan_core/zarvan_core_quiz.dart';

import '../quiz_screen.dart';
import 'home_screen.dart';
import 'stages_screen.dart';

/// One card per author with the stars earned out of twelve. Every chapter is
/// open.
class QuizChaptersScreen extends QuizScreen {
  QuizChaptersScreen(super.kit);

  @override
  void build() {
    final s = kit.strings;
    titleBar(s.chapters, onBack: () => goTo(QuizHomeScreen(kit)));
    var y = 78.0;
    final max = QuizTier.values.length * 3;
    for (final a in kit.bank.authors) {
      final stars = [
        for (final t in QuizTier.values)
          kit.session.progress.stages[a.id]?[t.name]?.stars ?? 0,
      ].fold(0, (x, y) => x + y);
      button(
        UiRect(
          QuizScreen.margin,
          y,
          QuizScreen.worldWidth - 2 * QuizScreen.margin,
          46,
        ),
        a.name,
        () => goTo(QuizStagesScreen(kit, a)),
        style: QuizButtonStyle.option,
        size: 18,
      );
      label(
        '${s.number(stars)} / ${s.number(max)} ${s.stars}',
        rtl
            ? QuizScreen.margin + 52
            : QuizScreen.worldWidth - QuizScreen.margin - 52,
        y + 23,
        size: 12,
        color: theme.soft,
      );
      y += 54;
    }
  }
}
