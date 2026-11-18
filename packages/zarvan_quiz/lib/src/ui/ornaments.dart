import 'dart:math' as math;

import 'package:zarvan_core/zarvan_core.dart' show EntityId, Position, UiRect;
import 'package:zarvan_flutter/zarvan_flutter.dart'
    show Shape, ShapeKind, ShaderEffect, UiNode;

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
  /// drawn in [color] by the `portrait` shader, or null when the game gave no
  /// style for them.
  EntityId? portraitAt(
    String authorId,
    double x,
    double y,
    double width,
    int color, {
    int z = 7,
  }) {
    final style = kit.portraits?.styles[authorId];
    if (style == null) return null;
    final id = world.spawn();
    world.componentsOf<Position>().set(id, Position(x, y + yShift));
    world.componentsOf<ShaderEffect>().set(
      id,
      ShaderEffect(
        kind: ShaderEffect.portrait,
        width: width,
        height: width * 1.25,
        zIndex: z,
        rimArgb: color,
        params: style.params,
      ),
    );
    return id;
  }

  /// A progress seal of [size] centred at ([x], [y]), drawn by the `seal`
  /// shader: [state] 0 for a step to come, 1 for the current one, 2 for one
  /// done (it carries a tick).
  EntityId sealAt(double x, double y, double size, int state, {int z = 6}) {
    final id = world.spawn();
    world.componentsOf<Position>().set(id, Position(x, y + yShift));
    world.componentsOf<ShaderEffect>().set(
      id,
      ShaderEffect(
        // The rect is larger than the star so the glow and rays have room and
        // are not cut off at its edge.
        kind: ShaderEffect.seal,
        width: size * 1.9,
        height: size * 1.9,
        zIndex: z,
        rimArgb: 0xFFE3C477,
        armArgb: theme.accent,
        coreArgb: 0xFF0B2420,
        params: [state.toDouble()],
      ),
    );
    return id;
  }

  /// An answer mark of [size] centred at ([x], [y]): a star medallion edged in
  /// gold with a calligraphic tick or, when [cross], a cross, drawn in by a pen
  /// of light as [ShaderEffect.params] y goes from 0 to 1 (the caller animates
  /// it; the entity and its effect are returned for that). Drawn by the engine's `mark` shader; the rect is larger than the
  /// medallion so its glow is not cut off.
  (EntityId, ShaderEffect) markAt(
    double x,
    double y,
    double size,
    int color, {
    bool cross = false,
    double drawn = 1,
    int z = 9,
  }) {
    final id = world.spawn();
    world.componentsOf<Position>().set(id, Position(x, y + yShift));
    final fx = ShaderEffect(
      kind: ShaderEffect.mark,
      width: size,
      height: size,
      zIndex: z,
      rimArgb: 0xFFE3C477,
      armArgb: color,
      coreArgb: 0xFF0B2420,
      params: [cross ? 1 : 0, drawn],
    );
    world.componentsOf<ShaderEffect>().set(id, fx);
    return (id, fx);
  }

  /// An ornate Persian frame around [r], drawn by the engine's `ornate`
  /// shader: a band [band] thick of a lattice with cells [cell] wide, gold
  /// lines and corner rosettes, with the corners rounded by [radius]. Inside
  /// it lays [fill] (parchment when [paper] is up, with [cusp] scallops on
  /// the band's inner edge), or leaves the middle clear when [fill] is null.
  EntityId ornateFrame(
    UiRect r, {
    double band = 14,
    double cell = 9,
    double radius = 14,
    int? fill,
    double paper = 0,
    double cusp = 0,
    int? gold,
    int? teal,
    int z = 6,
  }) {
    final id = world.spawn();
    world.componentsOf<Position>().set(
      id,
      Position(r.centerX, r.centerY + yShift),
    );
    world.componentsOf<ShaderEffect>().set(
      id,
      ShaderEffect(
        kind: ShaderEffect.ornate,
        width: r.width,
        height: r.height,
        zIndex: z,
        border: band,
        detail: cell,
        rimGlow: radius,
        intensity: paper,
        saturation: cusp,
        rimArgb: gold ?? 0xFFE3C477,
        armArgb: teal ?? 0xFF1F7A6E,
        coreArgb: fill ?? 0x00000000,
      ),
    );
    return id;
  }

  /// A GPU night sky (nebula, aurora, stars, rising dust) behind the whole
  /// screen, in the theme's colours. Drawn by the engine's `aurora` shader.
  void nightSky({double speed = 1, int? sky, int? nebula, int? star}) {
    final id = world.spawn();
    world.componentsOf<Position>().set(
      id,
      Position(QuizScreen.worldWidth / 2, world.height / 2),
    );
    world.componentsOf<ShaderEffect>().set(
      id,
      ShaderEffect(
        kind: ShaderEffect.aurora,
        width: QuizScreen.worldWidth * 1.6,
        height: world.height * 1.6,
        zIndex: -9,
        speed: speed,
        rimArgb: sky ?? theme.background,
        armArgb: nebula ?? theme.accent,
        coreArgb: star ?? theme.ink,
      ),
    );
  }

  /// Sparse drifting motes of light around [r] (and a little beyond, by
  /// [margin]), drawn by the engine's `dust` shader.
  EntityId dustAround(
    UiRect r, {
    double margin = 40,
    double density = 1,
    int? color,
    int? accent,
    int z = 9,
  }) {
    final id = world.spawn();
    world.componentsOf<Position>().set(
      id,
      Position(r.centerX, r.centerY + yShift),
    );
    world.componentsOf<ShaderEffect>().set(
      id,
      ShaderEffect(
        kind: ShaderEffect.dust,
        width: r.width + 2 * margin,
        height: r.height + 2 * margin,
        zIndex: z,
        rimArgb: color ?? 0xFFFFD98A,
        armArgb: accent ?? 0xFFFFF4DC,
        params: [density],
      ),
    );
    return id;
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
      Position(rect.x + rect.width / 2, rect.y + rect.height / 2 + yShift),
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
      y: y + yShift,
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
    y: y + yShift,
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
    y: y + yShift,
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
      final y = 8 + rng.nextDouble() * (world.height - 16 - yShift);
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
