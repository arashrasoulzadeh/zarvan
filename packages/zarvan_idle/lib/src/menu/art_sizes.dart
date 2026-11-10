import 'dart:ui' show Size;

import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' as eng show Sprite;

/// Pixel sizes of the full-image art the menu scenes loaded, by asset path.
///
/// Kept outside the scenes because a game may build a scene twice (once to
/// load its assets, once to run it): what the first instance measured must
/// still be known to the second, so higher-resolution art draws at the same
/// world size as the art the layout was authored for.
final artSizes = <String, Size>{};

/// Scale that draws the image at [path] [width] world units wide; [nominal] is
/// the pixel width the layout assumed, used until the real size is known.
double artFit(String path, double size, double nominal, {bool tall = false}) {
  final s = artSizes[path];
  return size / (tall ? (s?.height ?? nominal) : (s?.width ?? nominal));
}

/// Re-scales sprites to their art's real pixel size once it is known.
///
/// A scene may spawn its sprites before its images finish loading (or have
/// been loaded by another instance), so a sprite starts at the scale for the
/// layout's nominal art size and [apply] corrects it on the first update after
/// the size is measured.
class ArtFitter {
  final _items = <_Fit>[];
  bool _done = true;

  /// Tracks [entity], to be drawn [width] world units wide with the art's own
  /// aspect. [onScale] hears every applied scale (for effects that animate it).
  void add(
    EntityId entity,
    String path,
    double width,
    double nominal, {
    void Function(double scale)? onScale,
  }) {
    _items.add(_Fit(entity, path, width, null, nominal, 0, onScale));
    _done = false;
  }

  /// Tracks [entity], to be stretched to [width] x [height] world units.
  void addStretch(
    EntityId entity,
    String path,
    double width,
    double height,
    double nominalW,
    double nominalH,
  ) {
    _items.add(_Fit(entity, path, width, height, nominalW, nominalH, null));
    _done = false;
  }

  /// Applies every scale whose art size is known; cheap once all are done.
  void apply(World world) {
    if (_done) return;
    final sprites = world.componentsOf<eng.Sprite>();
    var all = true;
    for (final f in _items) {
      final art = artSizes[f.path];
      if (art == null) {
        all = false;
        continue;
      }
      final kx = f.width / art.width;
      final ky = f.height == null ? kx : f.height! / art.height;
      final s = sprites.get(f.entity);
      if (s != null) {
        s.scaleX = kx;
        s.scaleY = ky;
      }
      f.onScale?.call(kx);
    }
    _done = all;
  }
}

class _Fit {
  _Fit(
    this.entity,
    this.path,
    this.width,
    this.height,
    this.nominalW,
    this.nominalH,
    this.onScale,
  );

  final EntityId entity;
  final String path;
  final double width;
  final double? height;
  final double nominalW;
  final double nominalH;
  final void Function(double scale)? onScale;
}
