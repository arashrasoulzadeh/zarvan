import 'dart:math' as math;

import 'package:zarvan_core/zarvan_core.dart' show EntityId, Position, UiRect;
import 'package:zarvan_core/zarvan_core_quiz.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart'
    show BackdropBlur, ShaderEffect, Shape, UiButton, UiNode;

import 'ornaments.dart';
import 'quiz_screen.dart';
import 'screens/game_screen.dart';

/// A poet's panel over a blurred screen, with the four levels to choose from:
/// deep blue paper edged in gold with sprays of blossom in its corners, a
/// parchment header with their emblem, name and title, and a banner for each
/// level (green velvet when it can be played, parchment with a hint when it is
/// still locked). It comes and goes quietly: the screen blurs and the panel
/// fades in while growing the last few percent, and the same backwards.
///
/// Drawn by the engine's `cartouche` shader and text; the blur is the engine's
/// [BackdropBlur].
class MedalOverlay {
  MedalOverlay(this.screen, {this.onClosed});

  final QuizScreen screen;

  /// Called once the panel has gone.
  final void Function()? onClosed;

  /// Where the panel is, centred, and how big it is.
  static const centerX = QuizScreen.worldWidth / 2;

  /// The panel is in the middle of the screen, whatever its height.
  double get centerY => screen.world.height / 2;
  static const medalW = 300.0;
  static const medalH = 428.0;

  /// Draw order: the blur covers everything below [_z]; the veil and the panel
  /// stay sharp above it.
  static const _z = 50;

  /// Seconds to fade in (or out).
  static const seconds = 0.22;

  /// How small the panel starts, as a share of its full size.
  static const _startScale = 0.92;

  static const _cream = 0xFFFFF1D6;
  static const _navy = 0xFF14284B;
  static const _ink = 0xFF3A2312;

  double _t = 0;
  int _dir = 0;
  bool _contentShown = false;
  QuizAuthor? _author;

  final List<EntityId> _ids = [];
  final List<_Item> _items = [];
  final List<_Fx> _effects = [];
  final List<(UiButton, bool)> _buttons = [];

  /// Where each playable level's stars go: the row's middle y and how many it has.
  final List<(double, int)> _starRows = [];
  final List<EntityId> _seals = [];
  final List<UiButton> _suspended = [];
  UiButton? _veilButton;
  late QuizGroup _content;
  Shape? _veil;
  BackdropBlur? _blur;
  EntityId? _emblem;

  /// Whether the panel is up (or opening or closing).
  bool get isOpen => _dir != 0 || _t > 0;

  /// Whether the panel has finished opening and shows its levels.
  bool get isShown => _contentShown;

  /// The author on the panel, if any.
  QuizAuthor? get author => _author;

  /// Opens the panel for [author]. [card] is where their card is on the shelf;
  /// the panel does not fly from it, it only fades in in the middle.
  void open(QuizAuthor author, UiRect card) {
    if (isOpen) return;
    _author = author;
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

    _buildContent();
    _t = 0;
    _dir = 1;
    _apply();
  }

  /// Fades the panel out. Ignored while it opens.
  void close() {
    if (_dir != 0 && !_contentShown) return;
    if (_t <= 0) return;
    for (final (b, _) in _buttons) {
      b.enabled = false;
    }
    _destroy(_veilButton);
    _veilButton = null;
    _dropEmblem();
    for (final id in _seals) {
      screen.world.destroy(id);
      _ids.remove(id);
    }
    _seals.clear();
    _contentShown = false;
    _dir = -1;
  }

  void _dropEmblem() {
    final id = _emblem;
    if (id == null) return;
    screen.world.destroy(id);
    _ids.remove(id);
    _emblem = null;
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
    final scale = _startScale + (1 - _startScale) * e;
    final cx = centerX;
    final cy = centerY;
    for (final it in _items) {
      it.place(cx, cy, scale, e);
    }
    for (final fx in _effects) {
      fx.place(cx, cy, scale, e);
    }
    _veil?.alpha = 0.55 * e;
    _blur?.sigma = 4 * e;
  }

  /// Lays the header and the level banners out in their final place, and
  /// registers them as items so every frame fades and scales them together.
  void _buildContent() {
    final author = _author!;
    final s = screen.kit.strings;
    final p = screen.kit.session.progress;
    final top = centerY - medalH / 2;
    const rowW = medalW - 48;
    const left = centerX - rowW / 2;

    final panel = screen.cartoucheAt(
      UiRect(centerX - medalW / 2, top, medalW, medalH),
      dialog: true,
      header: 0.295,
      gleam: 0.4,
      window: 0xFF1B4C9A,
      z: _z + 1,
    );
    _addEffect(panel, centerX, centerY);

    final title = screen.label(
      author.name,
      centerX,
      top + 82,
      size: 26,
      color: _navy,
      z: _z + 6,
    );
    _content.addNode(title);
    _items.add(_Item.text(title, centerX, centerY));
    final epithet = screen.kit.portraits?.styles[author.id]?.epithet;
    if (epithet != null) {
      final sub = screen.label(
        epithet,
        centerX,
        top + 106,
        size: 13,
        color: _ink,
        z: _z + 6,
      );
      _content.addNode(sub);
      _items.add(_Item.text(sub, centerX, centerY));
    }

    var y = top + 140;
    for (final tier in QuizTier.values) {
      final unlocked = p.isUnlocked(author.id, tier);
      final entry = p.stages[author.id]?[tier.name];
      final rect = UiRect(left, y, rowW, 60);
      final row = screen.cartoucheAt(
        rect,
        flowers: unlocked ? 1 : -1,
        paper: !unlocked,
        gleam: unlocked ? 0.3 : 0,
        z: _z + 2,
      );
      _addEffect(row, centerX, centerY);
      final b = screen.button(
        rect,
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
        ..alpha = 0;
      b.label.text!
        ..zIndex = _z + 6
        ..colorArgb = unlocked ? _cream : _navy;
      b.label.pos.y -= unlocked ? 8 : 9;
      b.enabled = false;
      _buttons.add((b, unlocked));
      _items
        ..add(_Item.box(b.bg, centerX, centerY))
        ..add(_Item.text(b.label, centerX, centerY));
      if (unlocked) {
        // Its stars are small seals, drawn once the panel has settled.
        _starRows.add((y + 43, entry?.stars ?? 0));
      } else {
        final info = screen.label(
          s.stageLockedHint,
          centerX,
          y + 44,
          size: 12,
          color: _ink,
          z: _z + 6,
        );
        _content.addNode(info);
        _items.add(_Item.text(info, centerX, centerY));
      }
      y += 68;
    }
  }

  void _addEffect(EntityId id, double cx, double cy) {
    _ids.add(id);
    final fx = screen.world.componentsOf<ShaderEffect>().get(id)!;
    final pos = screen.world.componentsOf<Position>().get(id)!;
    _effects.add(_Fx(fx, pos, cx, cy));
  }

  /// The panel is up: the levels can be pressed, and a tap outside closes.
  void _showContent() {
    _contentShown = true;
    // The author's emblem appears once the panel has settled (a shader icon
    // does not fade with the text).
    final emblem = screen.emblemAt(
      _author!.id,
      centerX,
      centerY - medalH / 2 + 42,
      44,
      color: 0xFF14284B,
      z: _z + 7,
    );
    if (emblem != null) {
      _emblem = emblem;
      _ids.add(emblem);
    }
    for (final (row, stars) in _starRows) {
      for (var i = 0; i < 3; i++) {
        final id = screen.sealAt(
          centerX + (i - 1) * 26,
          row,
          17,
          i < stars ? 2 : 0,
          z: _z + 7,
        );
        _seals.add(id);
        _ids.add(id);
      }
    }
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
    _emblem = null;
    for (final id in _ids) {
      screen.world.destroy(id);
    }
    _ids.clear();
    _content.clear();
    _items.clear();
    _effects.clear();
    _buttons.clear();
    _starRows.clear();
    _seals.clear();
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

/// A shader effect of the panel: it keeps its place and size relative to the
/// panel's centre, scales with it and fades with the effect's `blur`.
class _Fx {
  _Fx(this.fx, this.pos, double cx, double cy)
    : dx = pos.x - cx,
      dy = pos.y - cy,
      w = fx.width,
      h = fx.height;

  final ShaderEffect fx;
  final Position pos;
  final double dx;
  final double dy;
  final double w;
  final double h;

  void place(double cx, double cy, double scale, double shown) {
    pos
      ..x = cx + dx * scale
      ..y = cy + dy * scale;
    fx
      ..width = w * scale
      ..height = h * scale
      ..blur = 1 - shown;
  }
}

/// A text or an invisible button box of the panel: it keeps its place relative
/// to the panel's centre, scales with it and, for text, fades in.
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

  void place(double cx, double cy, double scale, double shown) {
    node.pos
      ..x = cx + dx * scale
      ..y = cy + dy * scale;
    final shape = node.shape;
    if (shape != null) {
      shape
        ..width = w * scale
        ..height = h * scale;
      return;
    }
    node.text!
      ..textScale = scale
      ..alpha = alpha * shown;
  }
}
