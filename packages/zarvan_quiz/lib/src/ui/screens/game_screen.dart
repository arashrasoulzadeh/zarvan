import 'dart:math' as math;

import 'package:zarvan_core/zarvan_core.dart' show UiRect, World;
import 'package:zarvan_core/zarvan_core_quiz.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart'
    show UiButton, UiNode, measureText;

import '../../quiz_session.dart';
import '../ornaments.dart';
import '../quiz_screen.dart';
import 'home_screen.dart';
import 'result_screen.dart';

/// The round in play, drawn entirely with engine shapes and text: the HUD, the
/// poem with its blank, the four options, and after an answer the full text,
/// the author and a Next button. Opens the result when the round ends, and
/// offers the endless "continue" when the lives run out.
class QuizGameScreen extends QuizScreen {
  QuizGameScreen(super.kit);

  static const _poemSize = 20.0;
  static const _hudSize = 13.0;

  late final List<UiNode> _hud;
  late final QuizGroup _view = group();
  late final QuizGroup _dialog = group();
  Object? _stamp;
  bool _left = false;
  bool _asked = false;
  bool _wasAnswered = false;
  double _time = 0;
  final List<Twinkle> _twinkles = [];
  final List<_Particle> _bursts = [];
  final List<UiRect> _optionRects = [];
  final math.Random _rng = math.Random(3);

  QuizSession get session => kit.session;

  @override
  void build() {
    nightSky();
    _twinkles.addAll(sparkles(14));
    titleBar(kit.strings.appName, onBack: () => goTo(QuizHomeScreen(kit)));
    _hud = [
      for (var i = 0; i < 4; i++)
        label(
          '',
          QuizScreen.worldWidth * (0.14 + 0.24 * i),
          82,
          size: _hudSize,
        ),
    ];
    _redraw();
    _refreshHud();
  }

  @override
  void update(double dt, World world) {
    _time += dt;
    for (final t in _twinkles) {
      t.apply(_time);
    }
    _stepBursts(dt);
    session.tick(Duration(microseconds: (dt * 1e6).round()));
    if (session.finished && !_left) {
      _left = true;
      goTo(QuizResultScreen(kit));
      return;
    }
    _refreshHud();
    final stamp = (
      session.question,
      session.picked,
      session.question?.removedByHint.length,
      session.offeringContinue,
      session.canHint,
    );
    if (stamp != _stamp) _redraw();
  }

  void _refreshHud() {
    final round = session.round;
    if (round == null) return;
    final s = kit.strings;
    final run = round.run;
    final clock = run.clockMs;
    final items = <String>[
      '${s.score} ${s.number(run.score)}',
      '${s.streak} ${s.number(run.streak)}',
      // A stage has neither lives nor a clock, so that slot stays empty.
      if (run.lives != null)
        '${s.lives} ${s.number(run.lives!)}'
      else if (clock != null)
        '${s.clock} ${s.number(clock ~/ 1000 + (clock % 1000 > 0 ? 1 : 0))}'
      else
        '',
      '${s.coins} ${s.number(session.progress.coins)}',
    ];
    for (var i = 0; i < 4; i++) {
      _hud[i].text!.text = items[i];
    }
  }

  void _redraw() {
    _view.clear();
    final q = session.question;
    _stamp = (
      q,
      session.picked,
      q?.removedByHint.length,
      session.offeringContinue,
      session.canHint,
    );
    if (q == null) return;
    final s = kit.strings;
    final theme = this.theme;
    final answered = session.answered;
    final textWidth = QuizScreen.worldWidth - 2 * QuizScreen.margin - 32;

    // The poem, with the blank or, after an answer, the right word.
    final answer = q.options[q.answerIndex];
    final lines = [
      for (final l in q.render())
        answered
            ? l.replaceFirst(defaultBlankMarker, answer)
            : keepBlankTogether(l),
    ];
    final sizes = [
      for (final l in lines)
        measureText(
          l,
          fontSize: _poemSize,
          fontFamily: theme.fontFamily,
          rtl: rtl,
          maxWidth: textWidth,
        ),
    ];
    const gap = 8.0;
    final inner =
        sizes.fold<double>(0, (a, z) => a + z.height) +
        gap * (lines.length - 1);
    final cardTop = 104.0;
    final cardHeight = inner + 32;
    _view.addNode(
      box(
        UiRect(
          QuizScreen.margin,
          cardTop,
          QuizScreen.worldWidth - 2 * QuizScreen.margin,
          cardHeight,
        ),
        theme.surface,
        radius: 16,
      ),
    );
    final cardRect = UiRect(
      QuizScreen.margin,
      cardTop,
      QuizScreen.worldWidth - 2 * QuizScreen.margin,
      cardHeight,
    );
    _view.addId(
      lightAt(
        cardRect,
        answered ? theme.correct : theme.accent,
        intensity: answered ? 0.5 : 0.3,
        z: 3,
      ),
    );
    _view.addNode(
      frame(
        cardRect,
        answered ? theme.correct : theme.accent,
        alpha: 0.85,
        radius: 16,
      ),
    );
    _view.addNode(
      frame(
        UiRect(
          cardRect.x + 6,
          cardRect.y + 6,
          cardRect.width - 12,
          cardRect.height - 12,
        ),
        theme.accent,
        alpha: 0.25,
        radius: 12,
        dash: 3,
      ),
    );
    for (final dx in [cardRect.x + 14, cardRect.right - 14]) {
      for (final dy in [cardRect.y, cardRect.bottom]) {
        _view.addNode(diamondAt(dx, dy, 9, theme.accent, z: 8));
      }
    }
    var y = cardTop + 16;
    for (var i = 0; i < lines.length; i++) {
      _view.addNode(
        label(
          lines[i],
          QuizScreen.worldWidth / 2,
          y + sizes[i].height / 2,
          size: _poemSize,
          maxWidth: textWidth,
          color: answered ? theme.correct : theme.ink,
        ),
      );
      y += sizes[i].height + gap;
    }

    // The four options.
    var oy = cardTop + cardHeight + 18;
    _optionRects.clear();
    for (var i = 0; i < q.options.length; i++) {
      final removed = q.removedByHint.contains(i);
      final optRect = UiRect(
        QuizScreen.margin,
        oy,
        QuizScreen.worldWidth - 2 * QuizScreen.margin,
        QuizScreen.buttonHeight,
      );
      _optionRects.add(optRect);
      if (!removed && !answered) {
        _view.addNode(frame(optRect, theme.accent, alpha: 0.4, radius: 14));
      }
      final b = button(
        optRect,
        q.options[i],
        () => session.answer(i),
        style: QuizButtonStyle.option,
        size: 20,
        group: _view,
      );
      b.enabled = !answered && !removed && !session.offeringContinue;
      if (removed) _fade(b, 0.3);
      if (answered) _color(b, i, q, theme);
      oy += QuizScreen.buttonHeight + 8;
    }

    // After an answer: the author and Next. Before: the hint.
    final bottom = QuizScreen.worldHeight - 68;
    if (answered) {
      final item = kit.bank.byId(q.itemId);
      final author = item?.author == null
          ? null
          : [
              for (final a in kit.bank.authors)
                if (a.id == item!.author) a.name,
            ].firstOrNull;
      if (author != null) {
        _view.addNode(
          label(
            author,
            QuizScreen.worldWidth / 2,
            oy + 12,
            size: 15,
            color: theme.soft,
          ),
        );
      }
      if (session.round?.mode is! RaceMode) {
        final n = button(row(bottom), s.next, session.next, group: _view);
        n.enabled = !session.offeringContinue;
      }
    } else if (session.round?.mode is! RaceMode) {
      final hint = button(
        row(bottom),
        '${s.hint} · ${s.number(QuizProgress.hintCost)}',
        session.useHint,
        style: QuizButtonStyle.outline,
        size: 16,
        group: _view,
      );
      hint.enabled = session.canHint && !session.offeringContinue;
      if (!hint.enabled) _fade(hint, 0.4);
    }

    if (answered && !_wasAnswered) {
      final right = _optionRects[q.answerIndex];
      _burst(right.centerX, right.centerY, theme.correct, 26);
      _burst(right.centerX, right.centerY, theme.accent, 10);
      final picked = session.picked;
      if (picked != null && picked != q.answerIndex) {
        final r = _optionRects[picked];
        _burst(r.centerX, r.centerY, theme.wrong, 8);
      }
    }
    _wasAnswered = answered;

    if (session.offeringContinue && !_asked) _askContinue();
    if (!session.offeringContinue) _dialog.clear();
  }

  /// A burst of light at ([x], [y]): sparks fly out, fall a little and fade.
  void _burst(double x, double y, int color, int count) {
    for (var i = 0; i < count; i++) {
      final a = _rng.nextDouble() * 2 * math.pi;
      final speed = 50 + _rng.nextDouble() * 130;
      final size = 3 + _rng.nextDouble() * 5;
      final node = i % 3 == 0
          ? diamondAt(x, y, size * 1.6, color, z: 20)
          : dot(x, y, size, color, z: 20);
      _bursts.add(
        _Particle(
          node,
          math.cos(a) * speed,
          math.sin(a) * speed - 40,
          0.8 + _rng.nextDouble() * 0.6,
        ),
      );
    }
  }

  void _stepBursts(double dt) {
    for (var i = _bursts.length - 1; i >= 0; i--) {
      final p = _bursts[i];
      p.age += dt;
      if (p.age >= p.life) {
        world.destroy(p.node.id);
        _bursts.removeAt(i);
        continue;
      }
      p.vy += 140 * dt;
      p.node.pos
        ..x += p.vx * dt
        ..y += p.vy * dt;
      p.vx *= 0.985;
      p.node.shape!.alpha = 1 - p.age / p.life;
    }
  }

  void _fade(UiButton b, double alpha) {
    b.bg.shape!.alpha = alpha;
    b.label.text!.alpha = alpha;
  }

  void _color(UiButton b, int i, Question q, theme) {
    if (i == q.answerIndex) {
      b.bg.shape!.colorArgb = theme.correct;
      b.label.text!.colorArgb = theme.background;
    } else if (i == session.picked) {
      b.bg.shape!.colorArgb = theme.wrong;
      b.label.text!.colorArgb = theme.background;
    } else {
      _fade(b, 0.45);
    }
  }

  /// Endless ran out of lives: offers one more for a rewarded ad. With no ad
  /// ready there is nothing to offer and the round simply ends.
  void _askContinue() {
    final ads = kit.ads;
    if (ads == null || !ads.isRewardedReady) {
      session.declineContinue();
      return;
    }
    _asked = true;
    final s = kit.strings;
    final theme = this.theme;
    final veil = box(
      UiRect(0, 0, QuizScreen.worldWidth, QuizScreen.worldHeight),
      theme.background,
      radius: 0,
      z: 30,
    );
    veil.shape!.alpha = 0.82;
    veil.pos.x = QuizScreen.worldWidth / 2;
    veil.pos.y = QuizScreen.worldHeight / 2;
    _dialog.addNode(veil);
    _dialog.addNode(
      box(
        UiRect(30, 210, QuizScreen.worldWidth - 60, 230),
        theme.surface,
        radius: 18,
        z: 31,
      ),
    );
    _dialog.addNode(
      label(
        s.continueQuestion,
        QuizScreen.worldWidth / 2,
        262,
        size: 18,
        maxWidth: QuizScreen.worldWidth - 100,
        z: 33,
      ),
    );
    final yes = button(
      UiRect(50, 322, QuizScreen.worldWidth - 100, QuizScreen.buttonHeight),
      s.continueWithAd,
      () async {
        final earned = await ads.showRewarded('continue');
        _asked = false;
        _dialog.clear();
        if (earned) {
          session.continueRound();
        } else {
          session.declineContinue();
        }
      },
      group: _dialog,
    );
    final no = button(
      UiRect(50, 380, QuizScreen.worldWidth - 100, QuizScreen.buttonHeight),
      s.noThanks,
      () {
        _asked = false;
        _dialog.clear();
        session.declineContinue();
      },
      style: QuizButtonStyle.outline,
      group: _dialog,
    );
    for (final b in [yes, no]) {
      b.bg.shape!.zIndex = 32;
      b.label.text!.zIndex = 34;
    }
    // Nothing behind the dialog can be pressed while it is open.
    for (final b in ui.buttons) {
      if (b != yes && b != no) b.enabled = false;
    }
  }
}

class _Particle {
  _Particle(this.node, this.vx, this.vy, this.life);

  final UiNode node;
  double vx;
  double vy;
  final double life;
  double age = 0;
}
