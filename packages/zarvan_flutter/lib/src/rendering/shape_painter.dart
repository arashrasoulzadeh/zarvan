import 'dart:math' show max;
import 'dart:ui';

import 'shape.dart';

/// Paints [shape] centred on [center] at [scale] (the camera zoom for a
/// world-space shape, `1` for a screen-space one).
///
/// Kept apart from `EngineView` so the geometry is testable on a bare
/// `Canvas` and shared by anything else that needs to draw a `Shape`
/// (e.g. an image capture) without a widget tree.
void paintShape(Canvas canvas, Shape shape, Offset center, double scale) {
  final alpha = shape.alpha.clamp(0.0, 1.0);
  if (alpha <= 0) return;
  final base = Color(shape.colorArgb);
  final color = base.withValues(alpha: base.a * alpha);

  final w = shape.width * scale;
  final h = shape.height * scale;
  final stroke = shape.strokeWidth * scale;
  final isRing = shape.kind == ShapeKind.ring;
  final outlined = isRing || stroke > 0;
  final lineWidth = isRing ? max(stroke, 1.0) : stroke;

  final paint = Paint()
    ..color = color
    ..isAntiAlias = true
    ..style = outlined ? PaintingStyle.stroke : PaintingStyle.fill
    ..strokeWidth = lineWidth;

  // An outline is centred on the path edge; pull it inwards by half its
  // width so the shape's stated size is its outer bound.
  final inset = outlined ? lineWidth / 2 : 0.0;
  final Path path;
  switch (shape.kind) {
    case ShapeKind.circle:
    case ShapeKind.ring:
      path = Path()
        ..addOval(Rect.fromCircle(center: center, radius: w / 2 - inset));
    case ShapeKind.roundedRect:
      final rect = Rect.fromCenter(
        center: center,
        width: w - 2 * inset,
        height: h - 2 * inset,
      );
      final r = max(0.0, shape.cornerRadius * scale - inset);
      path = Path()
        ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(r)));
  }

  if (outlined && shape.isDashed) {
    final dash = shape.dashLength * scale;
    final gap = shape.gapLength * scale;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  } else {
    canvas.drawPath(path, paint);
  }
}
