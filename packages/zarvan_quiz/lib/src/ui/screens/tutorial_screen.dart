import 'package:zarvan_core/zarvan_core.dart' show UiRect;
import 'package:zarvan_core/zarvan_core_quiz.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' show measureText;

import '../quiz_screen.dart';
import 'home_screen.dart';

/// The first run: one famous couplet with its blank, to show what the game
/// is. Finishing it sets `flags.tutorialDone`, so it never shows again.
class QuizTutorialScreen extends QuizScreen {
  QuizTutorialScreen(super.kit);

  Question? _q;
  int? _picked;
  late final QuizGroup _view = group();

  @override
  void build() {
    final s = kit.strings;
    titleBar(s.tutorialTitle);
    label(
      s.tutorialBody,
      QuizScreen.worldWidth / 2,
      110,
      size: 16,
      maxWidth: QuizScreen.worldWidth - 60,
      color: theme.soft,
    );
    final item = kit.bank.items(tier: QuizTier.easy).first;
    _q = kit.factory.create(item.id, QuizTier.easy, 1);
    _redraw();
  }

  void _redraw() {
    _view.clear();
    final q = _q;
    if (q == null) return;
    final s = kit.strings;
    final answered = _picked != null;
    final answer = q.options[q.answerIndex];
    final lines = [
      for (final l in q.render())
        answered
            ? l.replaceFirst(defaultBlankMarker, answer)
            : keepBlankTogether(l),
    ];
    const w = QuizScreen.worldWidth - 72;
    final sizes = [
      for (final l in lines)
        measureText(
          l,
          fontSize: 20,
          fontFamily: theme.fontFamily,
          rtl: rtl,
          maxWidth: w,
        ),
    ];
    final inner =
        sizes.fold<double>(0, (a, z) => a + z.height) + 8 * (lines.length - 1);
    const top = 170.0;
    _view.addNode(
      box(
        UiRect(
          QuizScreen.margin,
          top,
          QuizScreen.worldWidth - 2 * QuizScreen.margin,
          inner + 32,
        ),
        theme.surface,
        radius: 16,
      ),
    );
    var y = top + 16;
    for (var i = 0; i < lines.length; i++) {
      _view.addNode(
        label(
          lines[i],
          QuizScreen.worldWidth / 2,
          y + sizes[i].height / 2,
          size: 20,
          maxWidth: w,
          color: answered ? theme.correct : theme.ink,
        ),
      );
      y += sizes[i].height + 8;
    }
    var oy = top + inner + 46;
    for (var i = 0; i < q.options.length; i++) {
      final b = button(
        row(oy),
        q.options[i],
        () {
          _picked = i;
          _redraw();
        },
        style: QuizButtonStyle.option,
        size: 20,
        group: _view,
      );
      b.enabled = !answered;
      oy += 56;
    }
    spread(1);
    final start = button(
      row(QuizScreen.worldHeight - 68),
      s.tutorialDone,
      _finish,
      group: _view,
    );
    start.enabled = answered;
    if (!answered) {
      start.bg.shape!.alpha = 0.4;
      start.label.text!.alpha = 0.4;
    }
  }

  Future<void> _finish() async {
    kit.session.progress.flags['tutorialDone'] = true;
    await QuizProgressStore(kit.session.store).save(kit.session.progress);
    goTo(QuizHomeScreen(kit));
  }
}
