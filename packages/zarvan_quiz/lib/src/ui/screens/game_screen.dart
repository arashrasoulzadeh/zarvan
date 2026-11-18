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

  /// The whole poem is written within this many seconds, and one word takes
  /// [_wordFade] seconds to come in.
  static const _writeSeconds = 1.5;
  static const _wordFade = 0.3;

  late final List<UiNode> _hud;
  late final QuizGroup _view = group();
  late final QuizGroup _dialog = group();
  Object? _stamp;
  bool _left = false;
  bool _asked = false;
  bool _wasAnswered = false;
  String? _revealFor;
  double _revealStart = 0;
  final List<_Word> _words = [];
  final List<_Ring> _rings = [];
  UiButton? _shaking;
  double _shakeAge = 0;
  double _shakeBgX = 0;
  double _shakeLabelX = 0;
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
    spread(0.08);
    titleBar(
      kit.strings.appName,
      onBack: () => goTo(QuizHomeScreen(kit)),
      showTitle: false,
    );
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
    _stepWords();
    _stepRings(dt);
    _stepShake(dt);
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
    _words.clear();
    _shaking = null;
    final q = session.question;
    _stamp = (
      q,
      session.picked,
      q?.removedByHint.length,
      session.offeringContinue,
      session.canHint,
    );
    if (q == null) return;
    // A hint makes a new Question for the same item: the writing carries on.
    if (q.itemId != _revealFor) {
      _revealFor = q.itemId;
      _revealStart = _time;
    }
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
    spread(0.2);
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
    // Writing the whole poem takes at most 1.5 s, however many verses it has.
    final count = lines.fold<int>(
      0,
      (n, l) => n + l.split(' ').where((w) => w.isNotEmpty).length,
    );
    final step = count > 1
        ? math.min(0.11, (_writeSeconds - _wordFade) / (count - 1))
        : 0.0;
    double wordsWidth(List<String> ws) => measureText(
      ws.join(' '),
      fontSize: _poemSize,
      fontFamily: theme.fontFamily,
      rtl: rtl,
    ).width;
    final finalColor = answered ? theme.correct : theme.ink;
    var y = cardTop + 16;
    var wordNo = 0;
    for (var i = 0; i < lines.length; i++) {
      final words = lines[i].split(' ').where((w) => w.isNotEmpty).toList();
      if (words.isEmpty) {
        y += sizes[i].height + gap;
        continue;
      }
      // A verse too long for one row is broken into rows here, the same way
      // the engine would, so that every row is written word by word.
      final rows = <List<String>>[[]];
      for (final w in words) {
        final next = [...rows.last, w];
        if (rows.last.isNotEmpty && wordsWidth(next) > textWidth) {
          rows.add([w]);
        } else {
          rows.last.add(w);
        }
      }
      final rowHeight = sizes[i].height / rows.length;
      for (var r = 0; r < rows.length; r++) {
        final rowY = y + rowHeight * (r + 0.5);
        final row = rows[r];
        // Each word is placed where it sits in the finished row.
        final total = wordsWidth(row);
        final start = rtl
            ? QuizScreen.worldWidth / 2 + total / 2
            : QuizScreen.worldWidth / 2 - total / 2;
        for (var k = 0; k < row.length; k++) {
          final upTo = wordsWidth(row.sublist(0, k + 1));
          final own = wordsWidth([row[k]]);
          final cx = rtl ? start - upTo + own / 2 : start + upTo - own / 2;
          final node = label(
            row[k],
            cx,
            rowY,
            size: _poemSize,
            color: theme.accent,
          );
          node.text!.alpha = 0;
          _view.addNode(node);
          final word = _Word(node, wordNo++ * step, rowY + yShift, finalColor);
          // A word that has already been written (a redraw after a hint or
          // an answer) must not throw its sparks again.
          word.started = _time - _revealStart - word.delay > _wordFade;
          _words.add(word);
        }
      }
      y += sizes[i].height + gap;
    }

    // The four options.
    spread(0.4);
    final optionShift = yShift;
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
      if (answered) _color(b, i, q, theme, optRect);
      oy += QuizScreen.buttonHeight + 8;
    }

    // After an answer: the author and Next. Before: the hint.
    final bottom = QuizScreen.worldHeight - 68;
    spread(0.85);
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

    yShift = optionShift;
    if (answered && !_wasAnswered) {
      final right = _optionRects[q.answerIndex];
      _burst(right.centerX, right.centerY, theme.correct, 26);
      _burst(right.centerX, right.centerY, theme.accent, 10);
      _ring(right.centerX, right.centerY, theme.correct);
      final picked = session.picked;
      if (picked != null && picked != q.answerIndex) {
        final r = _optionRects[picked];
        _burst(r.centerX, r.centerY, theme.wrong, 8);
      }
    }
    _wasAnswered = answered;
    yShift = 0;

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

  void _color(UiButton b, int i, Question q, theme, UiRect rect) {
    if (i == q.answerIndex) {
      b.bg.shape!
        ..colorArgb = theme.correct
        ..alpha = 0.42;
      b.label.text!.colorArgb = theme.ink;
      _view.addNode(frame(rect, theme.correct, stroke: 2.5, radius: 14, z: 7));
      _view.addId(lightAt(rect, theme.correct, intensity: 0.65));
      _badge(rect, '✓', theme.correct);
    } else if (i == session.picked) {
      b.bg.shape!
        ..colorArgb = theme.wrong
        ..alpha = 0.38;
      b.label.text!.colorArgb = theme.ink;
      _view.addNode(
        frame(
          rect,
          theme.wrong,
          stroke: 2,
          radius: 14,
          alpha: 0.9,
          z: 7,
          dash: 4,
        ),
      );
      _view.addId(lightAt(rect, theme.wrong, intensity: 0.4));
      _badge(rect, '✕', theme.wrong);
      _shaking = b;
      _shakeAge = 0;
      _shakeBgX = b.bg.pos.x;
      _shakeLabelX = b.label.pos.x;
    } else {
      _fade(b, 0.45);
    }
  }

  /// A round glowing seal with a mark in it at the reading-start end of an
  /// answered option, so right and wrong read at a glance.
  void _badge(UiRect rect, String mark, int color) {
    final x = rtl ? rect.right - 24 : rect.x + 24;
    _view.addNode(dot(x, rect.centerY, 32, color, alpha: 0.35, z: 8));
    _view.addNode(dot(x, rect.centerY, 24, color, z: 9));
    // Drawn from dots, not a glyph: a tick or cross may be missing from the font.
    final segments = mark == '✓'
        ? const [((-6.0, 0.5), (-2.0, 5.0)), ((-2.0, 5.0), (7.0, -5.5))]
        : const [((-5.5, -5.5), (5.5, 5.5)), ((5.5, -5.5), (-5.5, 5.5))];
    for (final ((ax, ay), (bx, by)) in segments) {
      for (var t = 0.0; t <= 1.0; t += 0.12) {
        _view.addNode(
          dot(
            x + ax + (bx - ax) * t,
            rect.centerY + ay + (by - ay) * t,
            3.4,
            theme.background,
            z: 10,
          ),
        );
      }
    }
  }

  /// Brings each word of the poem in, in turn: it rises a little, fades in and
  /// turns from the accent gold to the ink colour, with a few sparks as it lands.
  void _stepWords() {
    final t = _time - _revealStart;
    for (final w in _words) {
      final k = ((t - w.delay) / _wordFade).clamp(0.0, 1.0);
      if (k > 0 && !w.started) {
        w.started = true;
        _burst(w.node.pos.x, w.y, theme.accent, 3);
      }
      final ease = 1 - math.pow(1 - k, 3).toDouble();
      w.node.text!
        ..alpha = ease
        ..colorArgb = _mix(theme.accent, w.color, ease);
      w.node.pos.y = w.y + (1 - ease) * 7;
    }
  }

  static int _mix(int a, int b, double t) {
    int ch(int shift) =>
        (((a >> shift) & 0xFF) * (1 - t) + ((b >> shift) & 0xFF) * t).round();
    return 0xFF000000 | ch(16) << 16 | ch(8) << 8 | ch(0);
  }

  /// A ring of light that spreads from ([x], [y]) and fades.
  void _ring(double x, double y, int color) {
    _rings.add(_Ring(ringAt(x, y, 20, color, stroke: 2.5, z: 20)));
  }

  void _stepRings(double dt) {
    for (var i = _rings.length - 1; i >= 0; i--) {
      final r = _rings[i];
      r.age += dt;
      final k = r.age / 0.8;
      if (k >= 1) {
        world.destroy(r.node.id);
        _rings.removeAt(i);
        continue;
      }
      r.node.shape!
        ..width = 20 + 300 * (1 - math.pow(1 - k, 3).toDouble())
        ..height = 20 + 300 * (1 - math.pow(1 - k, 3).toDouble())
        ..alpha = 0.9 * (1 - k);
    }
  }

  /// The wrong pick shudders for a moment.
  void _stepShake(double dt) {
    final b = _shaking;
    if (b == null) return;
    _shakeAge += dt;
    final k = (_shakeAge / 0.5).clamp(0.0, 1.0);
    final off = math.sin(_shakeAge * 60) * 6 * (1 - k);
    b.bg.pos.x = _shakeBgX + off;
    b.label.pos.x = _shakeLabelX + off;
    if (k >= 1) _shaking = null;
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
    yShift = extra / 2;
    final veil = box(
      UiRect(0, 0, QuizScreen.worldWidth, world.height),
      theme.background,
      radius: 0,
      z: 30,
    );
    veil.shape!.alpha = 0.82;
    veil.pos.x = QuizScreen.worldWidth / 2;
    veil.pos.y = world.height / 2;
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
    yShift = 0;
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

class _Word {
  _Word(this.node, this.delay, this.y, this.color);

  final UiNode node;
  final double delay;
  final double y;
  final int color;
  bool started = false;
}

class _Ring {
  _Ring(this.node);

  final UiNode node;
  double age = 0;
}
