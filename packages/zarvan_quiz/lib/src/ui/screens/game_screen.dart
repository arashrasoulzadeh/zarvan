import 'dart:math' as math;

import 'package:zarvan_core/zarvan_core.dart' show Position, UiRect, World;
import 'package:zarvan_core/zarvan_core_quiz.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart'
    show ShaderEffect, UiButton, UiNode, measureText;

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

  static const _basePoemSize = 20.0;

  /// The verses' size: the base size times the theme's poem scale.
  double get _poemSize => _basePoemSize * theme.poemScale;

  /// The verses' typeface: the theme's poem face, else its interface one.
  String? get _poemFont => theme.poemFontFamily ?? theme.fontFamily;
  static const _hudSize = 13.0;

  /// How far the poem card's peaks stand above and below the text's area.
  static const _peak = 14.0;

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
  Position? _penPos;

  /// The answer marks on screen and when their pen started, so the strokes
  /// are drawn in over [_markSeconds] rather than appearing at once.
  final List<ShaderEffect> _marks = [];
  double _markStart = -10;
  static const _markSeconds = 0.55;

  double get _markProgress =>
      ((_time - _markStart) / _markSeconds).clamp(0.0, 1.0);

  final List<_Ring> _rings = [];
  UiButton? _shaking;
  double _shakeAge = 0;
  double _shakeBgX = 0;
  double _shakeLabelX = 0;
  double _time = 0;
  final List<DriftingCloud> _clouds = [];
  final List<_Particle> _bursts = [];
  final List<UiRect> _optionRects = [];
  final math.Random _rng = math.Random(3);

  QuizSession get session => kit.session;

  // The poem card is parchment with dark ink, on the blue paper around it.
  static const _parchmentInk = 0xFF2A1A0E;
  static const _parchmentAccent = 0xFF8A5A1E;
  static const _parchmentCorrect = 0xFF1F6B3A;
  static const _optionInk = 0xFFF5E9C8;

  @override
  void build() {
    // The same blue paper as the menu, with clouds drifting across it and
    // blossoming branches on rocks in the bottom corners.
    lapisSky();
    spread(0);
    _clouds.add(DriftingCloud(this, 0, -44, -24));
    _clouds.add(DriftingCloud(this, 1, -30, -6));
    spread(0.85);
    _clouds.add(DriftingCloud(this, 2, 540, 590));
    spread(1);
    footBlossoms(width: 84, height: 135);
    spread(0.08);
    titleBar(
      kit.strings.appName,
      onBack: () => navigate(QuizHomeScreen(kit), returning: true),
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
    // Each number in its own colour: score gold, streak ember, the clock or
    // lives cool, coins cream.
    const hudColors = [0xFFFFD98A, 0xFFFFA45C, 0xFF9FE3D6, 0xFFF3E6C4];
    for (var i = 0; i < 4; i++) {
      _hud[i].text!.colorArgb = hudColors[i];
    }
    _redraw();
    _refreshHud();
    openVeil();
  }

  @override
  void update(double dt, World world) {
    super.update(dt, world);
    _time += dt;
    for (final c in _clouds) {
      c.step(dt, _rng);
    }
    _stepBursts(dt);
    _stepWords();
    _stepMarks();
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

  // The questions of a round with a known length (a stage, the daily), as a
  // row of seals: done ones ticked, the current one lit, the rest to come. Only
  // five show at a time, scrolling with the current one.
  int? get _questionTotal {
    final mode = session.round?.mode;
    return switch (mode) {
      StageMode() => mode.questionCount,
      DailyMode() => mode.tiers.length,
      _ => null,
    };
  }

  bool get _hasStepper => _questionTotal != null;

  void _stepper() {
    final total = _questionTotal;
    final run = session.round?.run;
    if (total == null || run == null) return;
    spread(0.08);
    const shown = 5;
    const pitch = 52.0;
    const size = 38.0;
    final cx = QuizScreen.worldWidth / 2;
    final count = math.min(shown, total);
    final current = run.index.clamp(0, total - 1);
    final first = (current - 2).clamp(0, total - count);
    final y = 126.0;
    for (var k = 0; k < count; k++) {
      final n = first + k;
      final x = cx + (rtl ? -1 : 1) * (k - (count - 1) / 2) * pitch;
      final state = n < current ? 2 : (n == current ? 1 : 0);
      _view.addId(sealAt(x, y, size, state, number: n + 1, western: !rtl));
    }
    final reach = (count - 1) * pitch / 2 + size / 2 + 10;
    _view.addNode(line(24, cx - reach, y, theme.accent));
    _view.addNode(
      line(cx + reach, QuizScreen.worldWidth - 24, y, theme.accent),
    );
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
    _marks.clear();
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
    final textWidth =
        QuizScreen.worldWidth -
        2 * QuizScreen.margin -
        56 -
        2 * theme.poemInset;

    // The poem, with the blank or, after an answer, the right word.
    final answer = q.options[q.answerIndex];
    final lines = [
      for (final l in q.render())
        answered
            ? l.replaceFirst(defaultBlankMarker, answer)
            : keepBlankTogether(l),
    ];
    const gap = 8.0;
    final cardTop = _hasStepper ? 150.0 : 104.0;
    // The tallest the card may be and still leave room for four options of the
    // least height: a long poem is set smaller until it fits.
    final room = 362 + extra * 0.45 - cardTop - _peak - 18;
    var poemSize = _poemSize;
    late List<dynamic> sizes;
    late List<double> lineHeights;
    late double inner;
    for (var attempt = 0; attempt < 8; attempt++) {
      sizes = [
        for (final l in lines)
          measureText(
            l,
            fontSize: poemSize,
            fontFamily: _poemFont,
            rtl: rtl,
            maxWidth: textWidth,
          ),
      ];
      // Rows are as tall as the face measures them, times the theme's factor
      // (a calligraphic face has tall line metrics that leave big gaps).
      lineHeights = [
        for (final z in sizes) (z.height as double) * theme.poemLineScale,
      ];
      inner =
          lineHeights.fold<double>(0, (a, h) => a + h) +
          gap * (lines.length - 1);
      if (inner + 56 <= room || poemSize <= 14) break;
      poemSize = math.max(14, poemSize * 0.9);
    }
    _stepper();
    spread(0.2);
    final cardHeight = inner + 56;
    final cardRect = UiRect(
      QuizScreen.margin,
      cardTop,
      QuizScreen.worldWidth - 2 * QuizScreen.margin,
      cardHeight,
    );
    _view.addId(
      lightAt(
        cardRect,
        answered ? theme.correct : 0xFFE9B04F,
        intensity: answered ? 0.6 : 0.5,
        z: 3,
      ),
    );
    // Gold dust drifting around the card, and a pen of light for the writing.
    _view.addId(dustAround(cardRect, margin: 46, density: 1.1));
    final pen = lightAt(
      UiRect(-200, -200, 26, 26),
      0xFFFFE08A,
      intensity: 1.0,
      z: 10,
    );
    _view.addId(pen);
    _penPos = world.componentsOf<Position>().get(pen);
    // The card is parchment in a blue vine band with sprays of blossom in its
    // corners, all drawn by one shader.
    // The shape's peaks stand outside the rectangle the text fills.
    _view.addId(
      cartoucheAt(
        UiRect(
          cardRect.x,
          cardRect.y - _peak,
          cardRect.width,
          cardRect.height + 2 * _peak,
        ),
        card: true,
        flowers: 1,
        z: 5,
      ),
    );
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
      fontSize: poemSize,
      fontFamily: _poemFont,
      rtl: rtl,
    ).width;
    final finalColor = answered ? _parchmentCorrect : _parchmentInk;
    var y = cardTop + 28;
    var wordNo = 0;
    for (var i = 0; i < lines.length; i++) {
      final words = lines[i].split(' ').where((w) => w.isNotEmpty).toList();
      if (words.isEmpty) {
        y += lineHeights[i] + gap;
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
      final rowHeight = lineHeights[i] / rows.length;
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
            size: poemSize,
            color: _parchmentAccent,
            fontFamily: _poemFont,
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
      y += lineHeights[i] + gap;
    }

    // The four options.
    spread(0.4);
    final optionShift = yShift;
    var oy = cardTop + cardHeight + 18 + _peak;
    _optionRects.clear();
    // A long poem leaves less room: squeeze the gaps, then the banners, so the
    // last option never runs into the button below.
    final free = QuizScreen.worldHeight - 68 + extra * 0.45 - oy - 14;
    var optH = QuizScreen.buttonHeight;
    var optGap = 14.0;
    final optCount = q.options.length;
    if (free < optCount * optH + (optCount - 1) * optGap) {
      optGap = ((free - optCount * optH) / (optCount - 1)).clamp(4.0, 14.0);
      if (free < optCount * optH + (optCount - 1) * optGap) {
        optH = ((free - (optCount - 1) * optGap) / optCount).clamp(38.0, optH);
      }
    }
    for (var i = 0; i < q.options.length; i++) {
      final removed = q.removedByHint.contains(i);
      final optRect = UiRect(
        QuizScreen.margin,
        oy,
        QuizScreen.worldWidth - 2 * QuizScreen.margin,
        optH,
      );
      _optionRects.add(optRect);
      if (!removed) {
        _view.addId(cartoucheAt(optRect, flowers: 1, z: 5));
      }
      final b = button(
        optRect,
        q.options[i],
        () => session.answer(i),
        style: QuizButtonStyle.option,
        size: 20,
        group: _view,
      );
      if (!removed) {
        b.bg.shape!.alpha = 0;
        b.label.text!.colorArgb = _optionInk;
      }
      b.enabled = !answered && !removed && !session.offeringContinue;
      if (removed) {
        // No cartouche is drawn for it, and the button's own plate would show
        // as a pale rounded box, so only the lettering is left, faint.
        b.bg.shape!.alpha = 0;
        b.label.text!.alpha = 0.3;
      }
      if (answered) _color(b, i, q, theme, optRect);
      oy += optH + optGap;
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
        final nr = _narrow(row(bottom));
        _view.addId(cartoucheAt(nr, flowers: 1, gleam: 0.5, z: 5));
        final n = button(
          nr,
          s.next,
          session.next,
          style: QuizButtonStyle.option,
          size: 18,
          group: _view,
        );
        n.bg.shape!.alpha = 0;
        n.label.text!.colorArgb = _optionInk;
        n.enabled = !session.offeringContinue;
      }
    } else if (session.round?.mode is! RaceMode) {
      final hr = _narrow(row(bottom));
      _view.addId(cartoucheAt(hr, flowers: 1, window: 0xFF1F4E86, z: 5));
      final hint = button(
        hr,
        '${s.hint} · ${s.number(QuizProgress.hintCost)}',
        session.useHint,
        style: QuizButtonStyle.option,
        size: 16,
        group: _view,
      );
      hint.bg.shape!.alpha = 0;
      hint.label.text!.colorArgb = _optionInk;
      hint.enabled = session.canHint && !session.offeringContinue;
      if (!hint.enabled) hint.label.text!.alpha = 0.4;
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

  /// The bottom button's rect, narrowed so the branches in the corners show.
  UiRect _narrow(UiRect r) => UiRect(r.centerX - 105, r.y, 210, r.height);

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

  void _color(UiButton b, int i, Question q, theme, UiRect rect) {
    // The options are pointed velvet cartouches, so no rounded box is drawn
    // over them (it showed as a pale rectangle round the banner): the verdict
    // is a glow and a seal, the lettering stays cream for contrast on green.
    if (i == q.answerIndex) {
      _view.addId(lightAt(rect, theme.correct, intensity: 0.65));
      _badge(rect, '✓', theme.correct);
    } else if (i == session.picked) {
      _view.addId(lightAt(rect, theme.wrong, intensity: 0.4));
      _badge(rect, '✕', theme.wrong);
      _shaking = b;
      _shakeAge = 0;
      _shakeBgX = b.bg.pos.x;
      _shakeLabelX = b.label.pos.x;
    } else {
      b.label.text!.alpha = 0.45;
    }
  }

  /// A round glowing seal with a mark in it at the reading-start end of an
  /// answered option, so right and wrong read at a glance.
  void _badge(UiRect rect, String mark, int color) {
    final x = rtl ? rect.right - 30 : rect.x + 30;
    // The first time this answer is drawn the pen starts from nothing; a
    // redraw (a hint, say) finds it already done or part-way.
    if (!_wasAnswered) _markStart = _time;
    final (id, fx) = markAt(
      x,
      rect.centerY,
      64,
      color,
      cross: mark != '✓',
      drawn: _markProgress,
    );
    _view.addId(id);
    _marks.add(fx);
  }

  /// Brings each word of the poem in, in turn: it rises a little, fades in and
  /// turns from the accent gold to the ink colour, with a few sparks as it lands.
  void _stepMarks() {
    for (final m in _marks) {
      m.params = [m.params[0], _markProgress];
    }
  }

  void _stepWords() {
    final t = _time - _revealStart;
    _Word? writing;
    for (final w in _words) {
      final k = ((t - w.delay) / _wordFade).clamp(0.0, 1.0);
      if (k > 0 && !w.started) {
        w.started = true;
        _burst(w.node.pos.x, w.y, 0xFFFFD98A, 4);
      }
      final ease = 1 - math.pow(1 - k, 3).toDouble();
      w.node.text!
        ..alpha = ease
        ..colorArgb = _mix(theme.accent, w.color, ease);
      w.node.pos.y = w.y + (1 - ease) * 7;
      if (k > 0 && k < 1 && (writing == null || w.delay > writing.delay)) {
        writing = w;
      }
    }
    // The pen of light rides on the word being written, then goes out.
    final pen = _penPos;
    if (pen != null) {
      if (writing != null) {
        pen.x = writing.node.pos.x;
        pen.y = writing.node.pos.y;
      } else {
        pen.x = -500;
      }
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
    _dialog.addId(
      cartoucheAt(
        UiRect(24, 196, QuizScreen.worldWidth - 48, 262),
        card: true,
        flowers: 1,
        z: 31,
      ),
    );
    _dialog.addNode(
      label(
        s.continueQuestion,
        QuizScreen.worldWidth / 2,
        262,
        size: 18,
        maxWidth: QuizScreen.worldWidth - 120,
        color: _parchmentInk,
        z: 33,
      ),
    );
    final yes = bannerButton(
      UiRect(50, 318, QuizScreen.worldWidth - 100, 52),
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
      gleam: 0.5,
      z: 32,
      group: _dialog,
    );
    final no = bannerButton(
      UiRect(50, 380, QuizScreen.worldWidth - 100, 52),
      s.noThanks,
      () {
        _asked = false;
        _dialog.clear();
        session.declineContinue();
      },
      color: 0xFF1F4E86,
      flowers: 0,
      z: 32,
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
