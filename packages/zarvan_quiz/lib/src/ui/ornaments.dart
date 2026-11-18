import 'dart:math' as math;

import 'package:zarvan_core/zarvan_core.dart' show EntityId, Position, UiRect;
import 'package:zarvan_flutter/zarvan_flutter.dart'
    show Shape, ShapeKind, ShaderEffect, Sprite, UiNode;

import 'quiz_kit.dart';
import 'quiz_screen.dart';

/// Something that pulses or twinkles: [shape]'s alpha moves between [low] and
/// [high], offset by [phase] and sped by [speed].
class Twinkle {
  Twinkle(
    this.shape, {
    this.low = 0.1,
    this.high = 0.5,
    this.phase = 0,
    this.speed = 1,
  });

  final Shape shape;
  final double low;
  final double high;
  final double phase;
  final double speed;

  void apply(double time) {
    final k = (math.sin(time * speed * 2 * math.pi / 3 + phase) + 1) / 2;
    shape.alpha = low + (high - low) * k;
  }
}

/// The decorative pieces of the menu (frames, glows, dividers, sparkles),
/// all made of the engine's four flat shapes and a changing opacity: no
/// gradients, blur or images, which the engine does not draw.
extension QuizOrnaments on QuizScreen {
  /// The line portrait of [authorId] centred at ([x], [y]), [width] wide and
  /// tinted [color], or null when the game gave no portrait for them.
  EntityId? portraitAt(
    String authorId,
    double x,
    double y,
    double width,
    int color, {
    int z = 7,
  }) {
    final portraits = kit.portraits;
    if (portraits == null || !portraits.has(authorId)) return null;
    final id = world.spawn();
    world.componentsOf<Position>().set(id, Position(x, y));
    final scale = width / QuizPortraits.regionWidth;
    world.componentsOf<Sprite>().set(
      id,
      Sprite(
        portraits.atlasId,
        authorId,
        scaleX: scale,
        scaleY: scale,
        zIndex: z,
        tintArgb: color,
      ),
    );
    return id;
  }

  /// A GPU night sky (nebula, aurora, stars, rising dust) behind the whole
  /// screen, in the theme's colours. Drawn by the engine's `aurora` shader.
  void nightSky({double speed = 1}) {
    final id = world.spawn();
    world.componentsOf<Position>().set(
      id,
      Position(QuizScreen.worldWidth / 2, QuizScreen.worldHeight / 2),
    );
    world.componentsOf<ShaderEffect>().set(
      id,
      ShaderEffect(
        kind: ShaderEffect.aurora,
        width: QuizScreen.worldWidth,
        height: QuizScreen.worldHeight,
        zIndex: -9,
        speed: speed,
        rimArgb: theme.background,
        armArgb: theme.accent,
        coreArgb: theme.ink,
      ),
    );
  }

  /// A soft additive light of [color] centred in [rect] (bleeding past it),
  /// breathing by itself, drawn by the engine's `glow` shader.
  EntityId lightAt(
    UiRect rect,
    int color, {
    double intensity = 0.6,
    int z = 4,
  }) {
    final id = world.spawn();
    world.componentsOf<Position>().set(
      id,
      Position(rect.x + rect.width / 2, rect.y + rect.height / 2),
    );
    world.componentsOf<ShaderEffect>().set(
      id,
      ShaderEffect(
        kind: ShaderEffect.glow,
        width: rect.width * 1.9,
        height: rect.height * 1.9,
        zIndex: z,
        intensity: intensity,
        coreArgb: color,
      ),
    );
    return id;
  }

  /// A [size] diamond at ([x], [y]).
  UiNode diamondAt(
    double x,
    double y,
    double size,
    int color, {
    double stroke = 0,
    double alpha = 1,
    int z = 6,
  }) {
    final n = UiNode.shapeNode(
      world,
      Shape(
        kind: ShapeKind.diamond,
        width: size,
        height: size * 1.25,
        colorArgb: color,
        strokeWidth: stroke,
        alpha: alpha,
        zIndex: z,
      ),
      x: x,
      y: y,
    );
    return n;
  }

  /// A circle of diameter [d] at ([x], [y]).
  UiNode dot(
    double x,
    double y,
    double d,
    int color, {
    double alpha = 1,
    int z = 6,
  }) => UiNode.shapeNode(
    world,
    Shape(
      kind: ShapeKind.circle,
      width: d,
      colorArgb: color,
      alpha: alpha,
      zIndex: z,
    ),
    x: x,
    y: y,
  );

  /// A circle outline.
  UiNode ringAt(
    double x,
    double y,
    double d,
    int color, {
    double stroke = 1.5,
    double alpha = 1,
    int z = 6,
  }) => UiNode.shapeNode(
    world,
    Shape(
      kind: ShapeKind.ring,
      width: d,
      colorArgb: color,
      strokeWidth: stroke,
      alpha: alpha,
      zIndex: z,
    ),
    x: x,
    y: y,
  );

  /// An outlined rounded frame.
  UiNode frame(
    UiRect b,
    int color, {
    double stroke = 1.5,
    double radius = 14,
    double alpha = 1,
    int z = 6,
    double dash = 0,
  }) {
    final n = box(b, color, stroke: stroke, radius: radius, z: z);
    n.shape!
      ..alpha = alpha
      ..dashLength = dash
      ..gapLength = dash;
    return n;
  }

  /// A thin horizontal line from [x1] to [x2] at [y].
  UiNode line(double x1, double x2, double y, int color, {double alpha = 0.5}) {
    final n = box(UiRect(x1, y - 1, x2 - x1, 2), color, radius: 1, z: 4);
    n.shape!.alpha = alpha;
    return n;
  }

  /// A plaque: an outlined frame with a diamond at each end and [text] inside.
  /// Returns its glow so the caller may animate it.
  Shape plaque(UiRect b, String text, {double size = 18, int? color}) {
    final theme = this.theme;
    final glow = box(
      UiRect(b.x - 4, b.y - 4, b.width + 8, b.height + 8),
      theme.accent,
      radius: b.height / 2 + 4,
      z: 3,
    );
    glow.shape!.alpha = 0.12;
    frame(b, theme.accent, radius: b.height / 2, alpha: 0.85);
    diamondAt(b.x - 8, b.centerY, 9, theme.accent, alpha: 0.9);
    diamondAt(b.right + 8, b.centerY, 9, theme.accent, alpha: 0.9);
    label(text, b.centerX, b.centerY, size: size, color: color ?? theme.ink);
    return glow.shape!;
  }

  /// Scattered tiny sparkles behind everything, seeded so the same screen
  /// always twinkles the same way. Returns the animations to drive.
  List<Twinkle> sparkles(int count, {int seed = 7}) {
    final rng = math.Random(seed);
    final out = <Twinkle>[];
    for (var i = 0; i < count; i++) {
      final x = 12 + rng.nextDouble() * (QuizScreen.worldWidth - 24);
      final y = 8 + rng.nextDouble() * (QuizScreen.worldHeight - 16);
      final size = 2.0 + rng.nextDouble() * 3.5;
      final n = i.isEven
          ? diamondAt(x, y, size, theme.accent, z: 1)
          : dot(x, y, size, theme.accent, z: 1);
      out.add(
        Twinkle(
          n.shape!,
          low: 0.05,
          high: 0.55,
          phase: rng.nextDouble() * 6.28,
          speed: 0.6 + rng.nextDouble(),
        ),
      );
    }
    return out;
  }
}
