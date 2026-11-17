import 'dart:math' as math;

import 'package:zarvan_core/zarvan_core.dart' show EntityId, Position, UiRect;
import 'package:zarvan_core/zarvan_core_quiz.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart'
    show BackdropBlur, ShaderEffect, Shape, ShapeKind, UiButton, UiNode;

import 'ornaments.dart';
import 'quiz_screen.dart';
import 'screens/game_screen.dart';

/// A poet's card that leaves the shelf, spins and opens in front of a blurred
/// screen like a medal, with the four levels to choose from. Closing it spins
/// it back to its place on the shelf.
///
/// Drawn only with engine shapes; the spin is the medal's width following
/// `cos`, and the blur is the engine's [BackdropBlur].
class MedalOverlay {
  MedalOverlay(this.screen, {this.onClosed});

  final QuizScreen screen;

  /// Called once the medal has gone back to the shelf.
  final void Function()? onClosed;

  /// Where the medal ends up, centred, and how big it is.
  static const centerX = QuizScreen.worldWidth / 2;
  static const centerY = 300.0;
  static const medalW = 272.0;
  static const medalH = 340.0;

  /// Draw order: the blur covers everything below [_z]; the veil and the medal
  /// stay sharp above it.
  static const _z = 50;

  /// Seconds for the card to fly out and spin (or back).
  static const seconds = 0.7;

  double _t = 0;
  int _dir = 0;
  bool _contentShown = false;
  UiRect _from = const UiRect(0, 0, 58, 96);
  QuizAuthor? _author;

  final List<EntityId> _ids = [];
  final List<_Piece> _pieces = [];
  final List<_Spark> _sparks = [];
  final List<_Item> _items = [];
  final List<(UiButton, bool)> _buttons = [];
  ShaderEffect? _glow;
  Position? _glowPos;
  Shape? _ring;
  UiNode? _ringNode;
  double _time = 0;
  final List<UiButton> _suspended = [];
  UiButton? _veilButton;
  late QuizGroup _content;
  Shape? _veil;
  BackdropBlur? _blur;

  /// Whether the medal is up (or opening or closing).
  bool get isOpen => _dir != 0 || _t > 0;

  /// Whether the medal has finished opening and shows its levels.
  bool get isShown => _contentShown;

  /// The author on the medal, if any.
  QuizAuthor? get author => _author;

  /// Opens the medal for [author], starting from their [card] rectangle.
  void open(QuizAuthor author, UiRect card) {
    if (isOpen) return;
    _author = author;
    _from = card;
    final theme = screen.theme;
    _content = screen.group();

    for (final b in screen.ui.buttons) {
      if (b.enabled) {
        _suspended.add(b);
        b.enabled = false;
      }
    }

    final blurId = screen.world.spawn();
    _blur = BackdropBlur(belowZIndex: _z);
    screen.world.componentsOf<BackdropBlur>().set(blurId, _blur!);
    _ids.add(blurId);

    final veil = screen.box(
      UiRect(
        -QuizScreen.worldWidth,
        -QuizScreen.worldHeight,
        QuizScreen.worldWidth * 3,
        QuizScreen.worldHeight * 3,
      ),
      theme.background,
      radius: 0,
      z: _z,
    );
    _veil = veil.shape;
    veil.shape!.alpha = 0;
    _ids.add(veil.id);

    _piece(theme.accent, 0.3, 1.1, 1.06, ShapeKind.roundedRect, z: _z + 1);
    _piece(theme.surface, 1, 1, 1, ShapeKind.roundedRect, z: _z + 2);
    _piece(
      theme.accent,
      0.95,
      1,
      1,
      ShapeKind.roundedRect,
      stroke: 3,
      z: _z + 3,
    );
    _piece(
      theme.accent,
      0.35,
      0.93,
      0.95,
      ShapeKind.roundedRect,
      stroke: 1.2,
      dash: 5,
      z: _z + 3,
    );

    _glow = ShaderEffect(
      kind: ShaderEffect.glow,
      width: 10,
      height: 10,
      zIndex: _z + 1,
      intensity: 0.9,
      coreArgb: theme.accent,
    );
    final glowId = screen.world.spawn();
    _glowPos = Position(_from.centerX, _from.centerY);
    screen.world.componentsOf<Position>().set(glowId, _glowPos!);
    screen.world.componentsOf<ShaderEffect>().set(glowId, _glow!);
    _ids.add(glowId);

    final rng = math.Random(7);
    for (var i = 0; i < 22; i++) {
      final big = i % 3 == 0;
      final size = big ? 11.0 : 4.0 + rng.nextDouble() * 3;
      final color = i.isEven ? theme.accent : theme.ink;
      final node = big
          ? screen.diamondAt(
              _from.centerX,
              _from.centerY,
              size,
              color,
              z: _z + 4,
              alpha: 0,
            )
          : screen.dot(
              _from.centerX,
              _from.centerY,
              size,
              color,
              z: _z + 4,
              alpha: 0,
            );
      _ids.add(node.id);
      _sparks.add(
        _Spark(
          node,
          angle: i / 22 * 2 * math.pi + rng.nextDouble() * 0.3,
          reach: 0.56 + rng.nextDouble() * 0.2,
          phase: rng.nextDouble() * 6,
        ),
      );
    }
    final ring = screen.ringAt(
      _from.centerX,
      _from.centerY,
      10,
      theme.accent,
      stroke: 2,
      z: _z + 4,
      alpha: 0,
    );
    _ring = ring.shape;
    _ringNode = ring;
    _ids.add(ring.id);

    _buildContent();
    _t = 0;
    _dir = 1;
    _apply();
  }

  void _piece(
    int color,
    double alpha,
    double wFrac,
    double hFrac,
    ShapeKind kind, {
    double stroke = 0,
    double dash = 0,
    required int z,
  }) {
    final radius = kind == ShapeKind.roundedRect ? 26.0 : 0.0;
    final n = UiNode.shapeNode(
      screen.world,
      Shape(
          kind: kind,
          width: 10,
          height: 10,
          cornerRadius: radius,
          colorArgb: color,
          strokeWidth: stroke,
          alpha: alpha,
          zIndex: z,
        )
        ..dashLength = dash
        ..gapLength = dash,
      x: _from.centerX,
      y: _from.centerY,
    );
    _ids.add(n.id);
    _pieces.add(_Piece(n, wFrac, hFrac));
  }

  /// Starts spinning the medal back to the shelf. Ignored while it opens.
  void close() {
    if (_dir != 0 && !_contentShown) return;
    if (_t <= 0) return;
    for (final (b, _) in _buttons) {
      b.enabled = false;
    }
    _destroy(_veilButton);
    _veilButton = null;
    _contentShown = false;
    _dir = -1;
  }

  void _destroy(UiButton? b) {
    if (b == null) return;
    screen.world.destroy(b.bg.id);
    screen.world.destroy(b.label.id);
    screen.ui.buttons.remove(b);
  }

  static double _ease(double t) => 1 - math.pow(1 - t, 3).toDouble();

  /// Like [_ease] but overshoots a little before settling, so the medal lands
  /// with a bounce.
  static double _back(double t) {
    const c1 = 1.9, c3 = c1 + 1;
    final u = t - 1;
    return 1 + c3 * u * u * u + c1 * u * u;
  }

  /// Moves the animation along by [dt] seconds.
  void update(double dt) {
    _time += dt;
    if (_dir == 0) {
      if (_pieces.isNotEmpty) _apply();
      return;
    }
    _t = (_t + _dir * dt / seconds).clamp(0.0, 1.0);
    _apply();
    if (_dir == 1 && _t >= 1) {
      _dir = 0;
      _showContent();
    } else if (_dir == -1 && _t <= 0) {
      _dir = 0;
      _finish();
    }
  }

  void _apply() {
    final e = _ease(_t);
    final bounce = _back(_t);
    final cx = _from.centerX + (centerX - _from.centerX) * e;
    final cy = _from.centerY + (centerY - _from.centerY) * e;
    final w = _from.width + (medalW - _from.width) * bounce;
    final h = _from.height + (medalH - _from.height) * bounce;
    final spin = math.cos(e * 4 * math.pi).abs().clamp(0.03, 1.0);
    for (final p in _pieces) {
      p.node.pos
        ..x = cx
        ..y = cy;
      p.node.shape!
        ..width = w * p.wFrac * spin
        ..height = h * p.hFrac;
    }
    final sx = w / medalW * spin;
    final sy = h / medalH;
    for (final it in _items) {
      it.place(cx, cy, sx, sy, spin);
    }
    _veil?.alpha = 0.6 * e;
    _blur?.sigma = 4 * e;

    final breathe = _dir == 0 ? 0.85 + 0.15 * math.sin(_time * 2.2) : 1.0;
    _glowPos
      ?..x = cx
      ..y = cy;
    _glow
      ?..width = w * 1.7
      ..height = h * 1.5
      ..intensity = 0.9 * e * breathe;

    for (final sp in _sparks) {
      final a = sp.angle + _time * 0.35 * (sp.phase > 3 ? 1 : -1);
      sp.node.pos
        ..x = cx + math.cos(a) * medalW * sp.reach * bounce
        ..y = cy + math.sin(a) * medalH * sp.reach * bounce;
      final tw = 0.55 + 0.45 * math.sin(_time * 3 + sp.phase * 3);
      sp.node.shape!.alpha = (e * tw).clamp(0.0, 1.0);
    }

    final ring = _ring;
    if (ring != null) {
      _ringNode!.pos
        ..x = cx
        ..y = cy;
      final k = ((_t - 0.55) / 0.45).clamp(0.0, 1.0);
      ring
        ..width = medalW * (0.8 + 0.9 * k)
        ..height = medalW * (0.8 + 0.9 * k)
        ..alpha = _dir == 1 && k > 0 ? 0.8 * (1 - k) : 0;
    }
  }

  /// Lays the title and the level buttons out in their final place, but
  /// registers them as [_items] so every frame moves and squeezes them with the
  /// medal: they turn with it from the first moment of the spin.
  void _buildContent() {
    final author = _author!;
    final s = screen.kit.strings;
    final theme = screen.theme;
    final p = screen.kit.session.progress;
    const left = centerX - medalW / 2 + 20;
    const width = medalW - 40;

    final title = screen.label(
      author.name,
      centerX,
      centerY - medalH / 2 + 38,
      size: 24,
      color: theme.accent,
      z: _z + 6,
    );
    _content.addNode(title);
    _items.add(_Item.text(title, centerX, centerY));
    var y = centerY - medalH / 2 + 80;
    for (final tier in QuizTier.values) {
      final unlocked = p.isUnlocked(author.id, tier);
      final entry = p.stages[author.id]?[tier.name];
      final b = screen.button(
        UiRect(left, y, width, 52),
        '${s.stage} ${s.tierName(tier.level)}',
        () => screen.play(
          QuizRound.stage(
            screen.kit.factory,
            screen.kit.stageMode,
            author: author.id,
            tier: tier,
            attempt: (entry?.attempts ?? 0) + 1,
          ),
          () => QuizGameScreen(screen.kit),
        ),
        style: QuizButtonStyle.option,
        size: 18,
        group: _content,
      );
      b.bg.shape!
        ..zIndex = _z + 5
        ..colorArgb = theme.accent
        ..alpha = unlocked ? 0.16 : 0.06;
      b.label.text!.zIndex = _z + 6;
      b.label.pos.y -= 8;
      if (!unlocked) b.label.text!.alpha = 0.5;
      b.enabled = false;
      _buttons.add((b, unlocked));
      final info = screen.label(
        unlocked
            ? List.generate(
                3,
                (i) => i < (entry?.stars ?? 0) ? '★' : '☆',
              ).join()
            : s.stageLockedHint,
        centerX,
        y + 37,
        size: 13,
        color: unlocked ? theme.accent : theme.soft,
        z: _z + 6,
      );
      _content.addNode(info);
      _items
        ..add(_Item.box(b.bg, centerX, centerY))
        ..add(_Item.text(b.label, centerX, centerY))
        ..add(_Item.text(info, centerX, centerY));
      y += 60;
    }
  }

  /// The medal has landed: the levels can be pressed, and a tap outside closes.
  void _showContent() {
    _contentShown = true;
    for (final (b, unlocked) in _buttons) {
      b.enabled = unlocked;
    }
    _veilButton = screen.button(
      UiRect(
        -QuizScreen.worldWidth,
        -QuizScreen.worldHeight,
        QuizScreen.worldWidth * 3,
        QuizScreen.worldHeight * 3,
      ),
      '',
      close,
      style: QuizButtonStyle.option,
    );
    _veilButton!.bg.shape!.alpha = 0;
    _veilButton!.bg.shape!.zIndex = _z - 1;
  }

  void _finish() {
    for (final id in _ids) {
      screen.world.destroy(id);
    }
    _ids.clear();
    _content.clear();
    _items.clear();
    _buttons.clear();
    _pieces.clear();
    _sparks.clear();
    _glow = null;
    _glowPos = null;
    _ring = null;
    _ringNode = null;
    for (final b in _suspended) {
      b.enabled = true;
    }
    _suspended.clear();
    _veil = null;
    _blur = null;
    _author = null;
    onClosed?.call();
  }
}

class _Piece {
  _Piece(this.node, this.wFrac, this.hFrac);

  final UiNode node;
  final double wFrac;
  final double hFrac;
}

class _Spark {
  _Spark(
    this.node, {
    required this.angle,
    required this.reach,
    required this.phase,
  });

  final UiNode node;
  final double angle;
  final double reach;
  final double phase;
}

/// A piece of the medal's face (the title, a level button, its stars) that
/// keeps its place relative to the medal's centre and turns with it: its
/// offset is squeezed by the spin, a box narrows, and text shrinks and fades
/// as it goes edge-on (the engine's text cannot be squashed on one axis).
class _Item {
  _Item._(this.node, this.dx, this.dy, this.w, this.h, this.alpha, this.size);

  factory _Item.text(UiNode n, double cx, double cy) => _Item._(
    n,
    n.pos.x - cx,
    n.pos.y - cy,
    0,
    0,
    n.text!.alpha,
    n.text!.fontSize,
  );

  factory _Item.box(UiNode n, double cx, double cy) => _Item._(
    n,
    n.pos.x - cx,
    n.pos.y - cy,
    n.shape!.width,
    n.shape!.height,
    n.shape!.alpha,
    0,
  );

  final UiNode node;
  final double dx;
  final double dy;
  final double w;
  final double h;
  final double alpha;
  final double size;

  void place(double cx, double cy, double sx, double sy, double spin) {
    node.pos
      ..x = cx + dx * sx
      ..y = cy + dy * sy;
    final shape = node.shape;
    if (shape != null) {
      shape
        ..width = w * sx
        ..height = h * sy;
      return;
    }
    final text = node.text!;
    text
      ..textScale = (sy * spin).clamp(0.05, 1.2)
      ..alpha = alpha * ((spin - 0.25) / 0.75).clamp(0.0, 1.0);
  }
}
