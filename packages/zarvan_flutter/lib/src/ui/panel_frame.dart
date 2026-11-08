import 'dart:ui' show Rect, Size;

import 'package:zarvan_core/zarvan_core.dart';
import '../rendering/sprite.dart';
import '../rendering/sprite_atlas.dart';

/// Spawns the nine sprites of a framed panel over [rect] (world units) from an
/// atlas made by [panelFrameAtlas] (regions `f<row><col>`): corners of
/// [corner] world units, stretching edges and middle. [source] is the frame
/// image's size in pixels and [inset] the width of its border in pixels.
/// Returns the sprite entities, row by row, so a caller can tint or move them.
List<EntityId> spawnPanelFrame(
  World world, {
  required String atlasId,
  required Rect rect,
  required Size source,
  required double inset,
  required double corner,
  required int zIndex,
}) {
  final srcX = [inset, source.width - 2 * inset, inset];
  final srcY = [inset, source.height - 2 * inset, inset];
  final dstX = [corner, rect.width - 2 * corner, corner];
  final dstY = [corner, rect.height - 2 * corner, corner];
  final pieces = <EntityId>[];
  var y = rect.top;
  for (var row = 0; row < 3; row++) {
    var x = rect.left;
    for (var col = 0; col < 3; col++) {
      final e = world.spawn();
      world.componentsOf<Position>().set(
        e,
        Position(x + dstX[col] / 2, y + dstY[row] / 2),
      );
      world.componentsOf<Sprite>().set(
        e,
        Sprite(
          atlasId,
          'f$row$col',
          scaleX: dstX[col] / srcX[col],
          scaleY: dstY[row] / srcY[row],
          zIndex: zIndex,
        ),
      );
      pieces.add(e);
      x += dstX[col];
    }
    y += dstY[row];
  }
  return pieces;
}

/// The atlas to register for a loaded frame image: nine regions `f<row><col>`
/// cut [inset] pixels in from each edge, as [spawnPanelFrame] expects.
SpriteAtlas panelFrameAtlas(SpriteAtlas full, double inset) {
  final w = full.image.width.toDouble();
  final h = full.image.height.toDouble();
  final xs = [0.0, inset, w - inset, w];
  final ys = [0.0, inset, h - inset, h];
  return SpriteAtlas(full.image, {
    for (var r = 0; r < 3; r++)
      for (var c = 0; c < 3; c++)
        'f$r$c': Rect.fromLTRB(xs[c], ys[r], xs[c + 1], ys[r + 1]),
  });
}
