import 'dart:ui' show Offset, Rect, Size;

import 'package:zarvan_core/zarvan_core.dart';

import '../rendering/backdrop_blur.dart';
import '../rendering/sprite.dart';
import '../rendering/text.dart';
import 'panel_frame.dart';
import 'world_text.dart';

/// A modal dialog: a framed panel with a title and a close button over a dimmed,
/// blurred game, that pauses the world while it is open.
///
/// This is the one place the engine does "a window is up": opening it blurs
/// everything drawn below [z] ([BackdropBlur]), darkens it with a veil, fades
/// the panel in and sets `World.timeScale` to 0 (restored on close), so every
/// dialog, tab page or popup built on it behaves the same. Put the dialog's own
/// content in with [add]; it is hidden, faded and moved with the panel.
///
/// Drive [update] every frame with real time (it runs while the game is
/// paused). [closesOn] tells a tap on the close button or outside the panel.
/// World units throughout.
class ModalDialog {
  ModalDialog._(this.world, this.rect, this.z, this._opts);

  final World world;

  /// The panel's rectangle.
  final Rect rect;

  /// Draw order of the panel frame; the veil sits 10 below it and the blur
  /// covers everything under the veil. Content belongs at `z + 10` and above.
  final int z;
  final _Opts _opts;

  final _parts = <EntityId>[];
  final _frame = <EntityId>{};
  EntityId? _veil;
  EntityId? _blur;
  EntityId? _title;
  EntityId? _closeBlock;
  Rect? _closeRect;
  bool _open = false;
  bool _shown = true;
  double _fade = 0;
  double _prevScale = 1;

  /// How far (world units, along y) hidden content is parked off screen.
  static const hiddenOffset = 3000.0;

  /// How long the fade takes.
  static const fadeSeconds = 0.2;

  /// Spawns a closed dialog. [frameAtlasId] is a [panelFrameAtlas] atlas (null
  /// draws no panel or veil, only the blur and what you [add]); [frameSource]
  /// is the frame image's size in pixels, [frameInset] its border width in
  /// pixels and [frameCorner] the corner size in world units. With [dark], the
  /// frame is darkened and the title is light. [blurSigma] 0 turns the blur
  /// off; [pause] false leaves the world running.
  factory ModalDialog.spawn(
    World world, {
    required Rect rect,
    required int z,
    String? frameAtlasId,
    Size frameSource = const Size(96, 75),
    double frameInset = 24,
    double frameCorner = 9,
    bool dark = true,
    double blurSigma = 3,
    bool pause = true,
    String title = '',
    double titleSize = 6.4,
    bool closable = true,
    bool rtl = false,
  }) {
    final d = ModalDialog._(
      world,
      rect,
      z,
      _Opts(
        frameAtlasId: frameAtlasId,
        frameSource: frameSource,
        frameInset: frameInset,
        dark: dark,
        blurSigma: blurSigma,
        pause: pause,
        rtl: rtl,
      ),
    );
    final atlas = frameAtlasId;
    if (atlas != null) {
      final mid = Size(
        frameSource.width - 2 * frameInset,
        frameSource.height - 2 * frameInset,
      );
      final w = world.width.toDouble();
      final h = world.height.toDouble();
      final veil = world.spawn();
      world.componentsOf<Position>().set(veil, Position(w / 2, h / 2));
      world.componentsOf<Sprite>().set(
        veil,
        Sprite(
          atlas,
          'f11',
          scaleX: (w + 20) / mid.width,
          scaleY: (h + 20) / mid.height,
          zIndex: z - 10,
          tintArgb: 0x00101828,
        ),
      );
      d._veil = veil;
      d._parts.add(veil);
      for (final e in spawnPanelFrame(
        world,
        atlasId: atlas,
        rect: rect,
        source: frameSource,
        inset: frameInset,
        corner: frameCorner,
        zIndex: z,
      )) {
        d._parts.add(e);
        d._frame.add(e);
      }
    }
    d._blur = world.spawn();
    world.componentsOf<BackdropBlur>().set(
      d._blur!,
      BackdropBlur(belowZIndex: z - 10),
    );
    final ink = dark ? 0xFFFFE7A0 : 0xFF3A2410;
    d._title = d.addText(rect.center.dx, rect.top + 14, title, titleSize, ink);
    if (closable && atlas != null) {
      const cw = 14.0, ch = 10.0;
      final cx = rtl ? rect.left + 16 : rect.right - 16;
      final cy = rect.top + 13;
      final block = world.spawn();
      world.componentsOf<Position>().set(block, Position(cx, cy));
      world.componentsOf<Sprite>().set(
        block,
        Sprite(
          atlas,
          'f11',
          scaleX: cw / mid(frameSource, frameInset).width,
          scaleY: ch / mid(frameSource, frameInset).height,
          zIndex: z + 10,
          tintArgb: 0xFF7A2E16,
        ),
      );
      d._closeBlock = d.add(block);
      d.addText(cx, cy, 'X', 5, 0xFFFFE7A0);
      d._closeRect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: cw + 6,
        height: ch + 6,
      );
    }
    d._setShown(false);
    return d;
  }

  static Size mid(Size source, double inset) =>
      Size(source.width - 2 * inset, source.height - 2 * inset);

  /// Registers [entity] as dialog content: it is parked off screen while the
  /// dialog is closed and fades with it. Returns [entity].
  EntityId add(EntityId entity) {
    _parts.add(entity);
    if (!_shown) _shift(entity, hiddenOffset);
    return entity;
  }

  /// Spawns a centred label as dialog content.
  EntityId addText(
    double x,
    double y,
    String text,
    double size,
    int colorArgb, {
    double? maxWidth,
  }) => add(
    spawnWorldText(
      world,
      x,
      y,
      text,
      fontSize: size,
      colorArgb: colorArgb,
      zIndex: z + 15,
      maxWidth: maxWidth,
      rtl: _opts.rtl ? true : null,
    ),
  );

  /// Rewrites the title.
  void setTitle(String text) {
    final t = _title == null ? null : world.componentsOf<Text>().get(_title!);
    t?.text = text;
  }

  /// Whether the dialog is open (or opening).
  bool get isOpen => _open;

  /// Opens the dialog and pauses the world.
  void open() {
    if (_open) return;
    _open = true;
    if (_opts.pause) {
      _prevScale = world.timeScale == 0 ? 1 : world.timeScale;
      world.timeScale = 0;
    }
    _setShown(true);
  }

  /// Starts closing the dialog and resumes the world.
  void close() {
    if (!_open) return;
    _open = false;
    if (_opts.pause) world.timeScale = _prevScale;
  }

  /// Opens a closed dialog, closes an open one.
  void toggle() => _open ? close() : open();

  /// True when [at] is on the close button or outside the panel, i.e. a tap
  /// there should close the dialog.
  bool closesOn(Offset at) =>
      (_closeRect?.contains(at) ?? false) || !rect.contains(at);

  /// Moves the fade along; call every frame with real time.
  void update(double dt) {
    final target = _open ? 1.0 : 0.0;
    if (_fade == target) return;
    final step = dt / fadeSeconds;
    _fade = target > _fade
        ? (_fade + step).clamp(0.0, target)
        : (_fade - step).clamp(target, 1.0);
    _applyFade();
    if (_fade == 0) _setShown(false);
  }

  void _setShown(bool shown) {
    if (shown == _shown) return;
    _shown = shown;
    for (final e in _parts) {
      _shift(e, shown ? -hiddenOffset : hiddenOffset);
    }
  }

  void _shift(EntityId e, double dy) {
    final p = world.componentsOf<Position>().get(e);
    if (p != null) p.y += dy;
  }

  void _applyFade() {
    final a = (_fade * 255).round();
    final white = (a << 24) | 0xFFFFFF;
    final sprites = world.componentsOf<Sprite>();
    final texts = world.componentsOf<Text>();
    world.componentsOf<BackdropBlur>().get(_blur ?? -1)?.sigma =
        _fade * _opts.blurSigma;
    for (final e in _parts) {
      final s = sprites.get(e);
      if (s != null) {
        s.tintArgb = e == _veil
            ? (_fade * 0.6 * 255).round() << 24 | 0x101828
            : e == _closeBlock
            ? a << 24 | 0x7A2E16
            : _opts.dark && _frame.contains(e)
            ? (a * 0.72).round() << 24 | 0x140A06
            : white;
      }
      final t = texts.get(e);
      if (t != null) t.colorArgb = (a << 24) | (t.colorArgb & 0xFFFFFF);
    }
  }
}

class _Opts {
  const _Opts({
    required this.frameAtlasId,
    required this.frameSource,
    required this.frameInset,
    required this.dark,
    required this.blurSigma,
    required this.pause,
    required this.rtl,
  });

  final String? frameAtlasId;
  final Size frameSource;
  final double frameInset;
  final bool dark;
  final double blurSigma;
  final bool pause;
  final bool rtl;
}
