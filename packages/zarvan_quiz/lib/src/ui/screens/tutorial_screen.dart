import 'package:zarvan_core/zarvan_core.dart' show UiRect;
import 'package:zarvan_core/zarvan_core_quiz.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' show measureText;

import '../ornaments.dart';
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
    styledBackdrop(seed: 2, clouds: 1);
    titleBar(s.tutorialTitle);
    label(
      s.tutorialBody,
      QuizScreen.worldWidth / 2,
      110,
      size: 16,
      maxWidth: QuizScreen.worldWidth - 60,
      color: 0xFFE9D7A6,
    );
    if (s.tutorialTip != null) {
      label(
        s.tutorialTip!,
        QuizScreen.worldWidth / 2,
        138,
        size: 13,
        maxWidth: QuizScreen.worldWidth - 40,
        color: 0xFFFFD98A,
      );
    }
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
    final top = s.tutorialTip != null ? 164.0 : 150.0;
    // The couplet on a parchment card, as in the game.
    _view.addId(
      cartoucheAt(
        UiRect(
          QuizScreen.margin,
          top - 14,
          QuizScreen.worldWidth - 2 * QuizScreen.margin,
          inner + 84 + 28,
        ),
        card: true,
        flowers: 1,
      ),
    );
    var y = top + 34;
    for (var i = 0; i < lines.length; i++) {
      _view.addNode(
        label(
          lines[i],
          QuizScreen.worldWidth / 2,
          y + sizes[i].height / 2,
          size: 20,
          maxWidth: w,
          color: answered ? 0xFF1F6B3A : 0xFF2A1A0E,
        ),
      );
      y += sizes[i].height + 8;
    }
    var oy = top + inner + 84 + 14 + 18;
    for (var i = 0; i < q.options.length; i++) {
      final b = bannerButton(
        row(oy),
        q.options[i],
        () {
          _picked = i;
          _redraw();
        },
        size: 20,
        group: _view,
      );
      b.enabled = !answered;
      oy += 54;
    }
    spread(1);
    final start = bannerButton(
      row(QuizScreen.worldHeight - 76, height: 56),
      s.tutorialDone,
      _finish,
      gleam: answered ? 0.6 : 0,
      fade: answered ? 0 : 0.6,
      group: _view,
    );
    start.enabled = answered;
    if (!answered) start.label.text!.alpha = 0.4;
  }

  Future<void> _finish() async {
    kit.session.progress.flags['tutorialDone'] = true;
    await QuizProgressStore(kit.session.store).save(kit.session.progress);
    goTo(QuizHomeScreen(kit));
  }
}
