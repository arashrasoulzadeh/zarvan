import 'dart:math' as math;
import 'dart:ui' as ui;

/// Whether a sprite centred at [center] (screen pixels) can show anywhere on
/// a view of size [view].
///
/// The sprite is a [width] x [height] region scaled by [scale]; it is treated
/// as a circle around its centre so any rotation is covered without trig, and
/// [padding] widens the view so a sprite just past an edge (or a fast-moving
/// one) is still built rather than popping in. Conservative by design: it may
/// keep a sprite that is just off-screen, never drop one that is visible.
bool spriteOnScreen(
  ui.Offset center,
  double width,
  double height,
  double scale,
  ui.Size view,
  double padding,
) {
  final radius = math.sqrt(width * width + height * height) / 2 * scale;
  final reach = radius + padding;
  return center.dx + reach > 0 &&
      center.dy + reach > 0 &&
      center.dx - reach < view.width &&
      center.dy - reach < view.height;
}
