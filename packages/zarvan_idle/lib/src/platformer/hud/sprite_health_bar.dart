import 'dart:ui' show Rect;

import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' hide Text;
import 'package:zarvan_platformer/zarvan_platformer.dart';

/// Regions of the generated `ui_bars` sheet (ornate frame + coloured fills),
/// in the sheet's own pixels.
///
/// The frame is trimmed to its drawn pixels; [innerLeft]/[innerTop]/
/// [innerWidth]/[innerHeight] are the dark opening the fill sits in, relative
/// to the frame's top-left. A different bar sheet needs its own numbers.
class BarsArt {
  const BarsArt._();

  static const frame = Rect.fromLTWH(6, 11, 107, 23);
  static const fillSize = (w: 87.0, h: 10.0);
  static const innerLeft = 19.0;
  static const innerTop = 6.0;
  static const innerWidth = 69.0;
  static const innerHeight = 11.0;

  /// Fill regions by colour (red `hp`, cyan `xp`, orange `boss`).
  static const fills = ['hp', 'xp', 'boss'];

  /// The atlas for `<stem>.png`: regions `frame` and `fill_hp` / `fill_xp` /
  /// `fill_boss`.
  static Future<SpriteAtlas> load(String stem) async {
    final sheet = await SpriteAtlas.loadFullImageFromAssets('$stem.png');
    return SpriteAtlas(sheet.image, {
      'frame': frame,
      // End caps keep their aspect; the plain channel between them stretches.
      'frame_l': Rect.fromLTWH(frame.left, frame.top, innerLeft, frame.height),
      'frame_m': Rect.fromLTWH(
        frame.left + innerLeft,
        frame.top,
        innerWidth,
        frame.height,
      ),
      'frame_r': Rect.fromLTWH(
        frame.left + innerLeft + innerWidth,
        frame.top,
        frame.width - innerLeft - innerWidth,
        frame.height,
      ),
      for (var row = 0; row < fills.length; row++)
        'fill_${fills[row]}': Rect.fromLTWH(
          132,
          row * 34.0 + 24,
          fillSize.w,
          fillSize.h,
        ),
    });
  }
}

/// A bar drawn with the generated ornate frame and a fill sprite that shrinks
/// with the source's `Health` (or any 0..1 value via `fractionOf`). World
/// units; [left]/[top] is the frame's top-left.
///
/// The frame is three slices: the two ornate end caps keep the sheet's aspect
/// ratio at the scale [spawn]'s `height` gives (or, without it, the scale that
/// makes the bar `width` wide), and only the plain channel between them
/// stretches, so a wide, thin bar never smears the ornaments.
class SpriteHealthBar {
  SpriteHealthBar._(
    this._world,
    this._source,
    this._parts,
    this._fill,
    this._s,
    this._channel,
    this._fractionOf,
  );

  final World _world;
  final EntityId _source;
  final List<EntityId> _parts;
  final EntityId _fill;
  final double _s;

  /// Width of the stretched channel in world units.
  final double _channel;
  final double Function()? _fractionOf;
  double _left = 0;
  double _top = 0;

  factory SpriteHealthBar.spawn(
    World world, {
    required String atlasId,
    required EntityId source,
    required double left,
    required double top,
    required double width,
    String fill = 'hp',
    int zIndex = 100,
    double? height,
    double Function()? fractionOf,
  }) {
    final s = height == null
        ? width / BarsArt.frame.width
        : height / BarsArt.frame.height;
    final cap = BarsArt.innerLeft * s;
    final capR =
        (BarsArt.frame.width - BarsArt.innerLeft - BarsArt.innerWidth) * s;
    final channel = width - cap - capR;
    final h = BarsArt.frame.height * s;

    EntityId piece(String region, double x, double w, int z, double sx) {
      final e = world.spawn();
      world.componentsOf<Position>().set(e, Position(x + w / 2, top + h / 2));
      world.componentsOf<Sprite>().set(
        e,
        Sprite(atlasId, region, scaleX: sx, scaleY: s, zIndex: z),
      );
      return e;
    }

    final mid = piece(
      'frame_m',
      left + cap,
      channel,
      zIndex,
      channel / BarsArt.innerWidth,
    );
    final fillEntity = world.spawn();
    world.componentsOf<Position>().set(fillEntity, Position(left, top));
    world.componentsOf<Sprite>().set(
      fillEntity,
      Sprite(atlasId, 'fill_$fill', scaleX: 0, scaleY: s, zIndex: zIndex + 1),
    );
    final capL = piece('frame_l', left, cap, zIndex + 2, s);
    final capRight = piece('frame_r', left + width - capR, capR, zIndex + 2, s);
    return SpriteHealthBar._(
        world,
        source,
        [mid, fillEntity, capL, capRight],
        fillEntity,
        s,
        channel,
        fractionOf,
      )
      .._left = left
      .._top = top
      ..sync();
  }

  /// Recolours the fill (e.g. `boss` for the boss encounter).
  void setFill(String fill) {
    _world.componentsOf<Sprite>().get(_fill)?.region = 'fill_$fill';
  }

  /// Resizes the fill to the source's current health.
  void sync() {
    final hp = _world.componentsOf<Health>().get(_source);
    final fraction = _fractionOf != null
        ? _fractionOf().clamp(0.0, 1.0)
        : hp == null || hp.max <= 0
        ? 0.0
        : (hp.current / hp.max).clamp(0.0, 1.0);
    final fillW = _channel * fraction;
    _world.componentsOf<Position>().get(_fill)
      ?..x = _left + BarsArt.innerLeft * _s + fillW / 2
      ..y = _top + (BarsArt.innerTop + BarsArt.innerHeight / 2) * _s;
    _world.componentsOf<Sprite>().get(_fill)
      ?..scaleX = fillW / BarsArt.fillSize.w
      ..scaleY = BarsArt.innerHeight * _s / BarsArt.fillSize.h;
  }

  void destroy() {
    for (final e in _parts) {
      _world.destroy(e);
    }
  }
}
