import 'dart:math' as math;

import 'package:zarvan_core/zarvan_core.dart' show EntityId, UiRect;
import 'package:zarvan_core/zarvan_core_quiz.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart'
    show BackdropBlur, Shape, ShapeKind, UiButton, UiNode;

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
    _piece(
      theme.accent,
      0.22,
      0.8,
      0.5,
      ShapeKind.diamond,
      stroke: 1.5,
      z: _z + 3,
    );

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
    _content.clear();
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

  /// Moves the animation along by [dt] seconds.
  void update(double dt) {
    if (_dir == 0) return;
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
    final cx = _from.centerX + (centerX - _from.centerX) * e;
    final cy = _from.centerY + (centerY - _from.centerY) * e;
    final w = _from.width + (medalW - _from.width) * e;
    final h = _from.height + (medalH - _from.height) * e;
    final spin = math.cos(e * 2 * math.pi).abs().clamp(0.03, 1.0);
    for (final p in _pieces) {
      p.node.pos
        ..x = cx
        ..y = cy;
      p.node.shape!
        ..width = w * p.wFrac * spin
        ..height = h * p.hFrac;
    }
    _veil?.alpha = 0.6 * e;
    _blur?.sigma = 4 * e;
  }

  void _showContent() {
    final author = _author!;
    final s = screen.kit.strings;
    final theme = screen.theme;
    final p = screen.kit.session.progress;
    _contentShown = true;
    const left = centerX - medalW / 2 + 20;
    const width = medalW - 40;

    _content.addNode(
      screen.label(
        author.name,
        centerX,
        centerY - medalH / 2 + 38,
        size: 24,
        color: theme.accent,
        z: _z + 6,
      ),
    );
    var y = centerY - medalH / 2 + 74;
    for (final tier in QuizTier.values) {
      final unlocked = p.isUnlocked(author.id, tier);
      final entry = p.stages[author.id]?[tier.name];
      final b = screen.button(
        UiRect(left, y, width, 54),
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
      b.bg.shape!.zIndex = _z + 5;
      b.bg.shape!
        ..colorArgb = theme.accent
        ..alpha = 0.16;
      b.label.text!.zIndex = _z + 6;
      b.label.pos.y -= 9;
      b.enabled = unlocked;
      final info = unlocked
          ? List.generate(3, (i) => i < (entry?.stars ?? 0) ? '★' : '☆').join()
          : s.stageLockedHint;
      _content.addNode(
        screen.label(
          info,
          centerX,
          y + 38,
          size: 13,
          color: unlocked ? theme.accent : theme.soft,
          z: _z + 6,
        ),
      );
      if (!unlocked) {
        b.bg.shape!.alpha = 0.06;
        b.label.text!.alpha = 0.5;
      }
      y += 62;
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
    _pieces.clear();
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
