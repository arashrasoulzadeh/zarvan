/// Which flat geometric form a [Shape] draws.
enum ShapeKind {
  /// A circle whose diameter is [Shape.width].
  circle,

  /// A [Shape.width] x [Shape.height] rectangle with [Shape.cornerRadius].
  roundedRect,

  /// A circle outline of diameter [Shape.width], always stroked with
  /// [Shape.strokeWidth] (its centre stays transparent).
  ring,

  /// A four-point diamond whose width and height are the supplied bounds.
  diamond,
}

/// A flat, code-drawn geometric primitive (circle, rounded rectangle, ring)
/// centred on this entity's `Position` -- the "no art assets" counterpart to
/// `Sprite`, for games whose whole look is flat shapes and `Text`.
///
/// [strokeWidth] `0` fills a circle or rounded rect; `> 0` outlines it
/// instead. A ring is always stroked (a `0` stroke falls back to a hairline
/// rather than vanishing). [dashLength]/[gapLength] break an outline into
/// dashes; either `<= 0` means solid. [alpha] multiplies the colour's own
/// alpha so a fade tween only has to animate one number.
///
/// [screenSpace] mirrors `Text.screenSpace`: `true` reads `Position` as
/// viewport pixels and ignores the camera; `false` (default) draws in world
/// space, scaled by `camera.zoom`.
class Shape {
  ShapeKind kind;
  double width;
  double height;
  double cornerRadius;
  double strokeWidth;
  int colorArgb;
  double dashLength;
  double gapLength;
  bool screenSpace;
  double alpha;

  /// Draw order relative to every other renderable -- see `Sprite.zIndex`.
  int zIndex;

  Shape({
    this.kind = ShapeKind.circle,
    this.width = 40,
    this.height = 40,
    this.cornerRadius = 0,
    this.strokeWidth = 0,
    this.colorArgb = 0xFFFFFFFF,
    this.dashLength = 0,
    this.gapLength = 0,
    this.screenSpace = false,
    this.alpha = 1,
    this.zIndex = 0,
  });

  /// Whether the outline is drawn as dashes rather than a solid line.
  bool get isDashed => dashLength > 0 && gapLength > 0;

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'width': width,
    'height': height,
    'cornerRadius': cornerRadius,
    'strokeWidth': strokeWidth,
    'colorArgb': colorArgb,
    'dashLength': dashLength,
    'gapLength': gapLength,
    'screenSpace': screenSpace,
    'alpha': alpha,
    'zIndex': zIndex,
  };

  factory Shape.fromJson(Map<String, dynamic> json) => Shape(
    kind: ShapeKind.values.firstWhere(
      (k) => k.name == json['kind'],
      orElse: () => ShapeKind.circle,
    ),
    width: (json['width'] as num?)?.toDouble() ?? 40,
    height: (json['height'] as num?)?.toDouble() ?? 40,
    cornerRadius: (json['cornerRadius'] as num?)?.toDouble() ?? 0,
    strokeWidth: (json['strokeWidth'] as num?)?.toDouble() ?? 0,
    colorArgb: (json['colorArgb'] as num?)?.toInt() ?? 0xFFFFFFFF,
    dashLength: (json['dashLength'] as num?)?.toDouble() ?? 0,
    gapLength: (json['gapLength'] as num?)?.toDouble() ?? 0,
    screenSpace: json['screenSpace'] as bool? ?? false,
    alpha: (json['alpha'] as num?)?.toDouble() ?? 1,
    zIndex: (json['zIndex'] as num?)?.toInt() ?? 0,
  );
}
