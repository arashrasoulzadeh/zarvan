import 'dart:math' as math;

import 'package:zarvan_core/zarvan_core.dart' show EntityId, Position, UiRect;
import 'package:zarvan_flutter/zarvan_flutter.dart'
    show Shape, ShapeKind, ShaderEffect, Sprite, UiButton, UiNode;

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
  /// done (it carries a tick). A step to come or the current one shows [number]
  /// (0..99) in Persian digits, or Western when [western].
  EntityId sealAt(
    double x,
    double y,
    double size,
    int state, {
    int? number,
    bool western = false,
    int z = 6,
  }) {
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
        // The number is drawn by the shader itself, in Persian or Western
        // digits, so the seal needs no text on top.
        params: [state.toDouble(), (number ?? -1).toDouble(), western ? 1 : 0],
      ),
    );
    return id;
  }

  /// The emblem of [authorId] ([size] wide, centred at ([x], [y])), drawn by the
  /// `emblem` shader, or null when the game gave them none.
  EntityId? emblemAt(
    String authorId,
    double x,
    double y,
    double size, {
    int? color,
    int z = 8,
  }) {
    final emblem = kit.portraits?.styles[authorId]?.emblem;
    if (emblem == null) return null;
    final id = world.spawn();
    world.componentsOf<Position>().set(id, Position(x, y + yShift));
    world.componentsOf<ShaderEffect>().set(
      id,
      ShaderEffect(
        kind: ShaderEffect.emblem,
        width: size,
        height: size,
        zIndex: z,
        rimArgb: color ?? theme.accent,
        armArgb: theme.accent,
        params: [emblem.index.toDouble()],
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

  /// The finished card picture of [authorId] over [r], from the kit's card art:
  /// drawn at [r]'s width and the picture's own proportions (never stretched),
  /// centred on [r]. Null when the kit has none for them.
  EntityId? cardPictureAt(String authorId, UiRect r, {int z = 5}) {
    final art = kit.cardArt;
    if (art == null || !art.has(authorId)) return null;
    final id = world.spawn();
    world.componentsOf<Position>().set(
      id,
      Position(r.centerX, r.centerY + yShift),
    );
    final scale = r.width / art.width;
    world.componentsOf<Sprite>().set(
      id,
      Sprite(art.atlasId, authorId, scaleX: scale, scaleY: scale, zIndex: z),
    );
    return id;
  }

  /// A gilded cartouche over [r], drawn by the engine's `cartouche` shader: a
  /// banner drawn out to points (green velvet, or parchment when [paper]) or,
  /// with [arch], a tall card with a flowered border around a window of
  /// [window] colour and, when [plaque] is above 0, a name plaque taking that
  /// share of its height; a banner shows sprays of blossoms at its ends, clipped
  /// to it and swaying, in proportion to [flowers] (0..1). [gleam] (0..1) brightens the gold for a card that
  /// is chosen. With [card] it is instead a wide panel for text (parchment in a
  /// blue vine band, medallions on its peaks and, in proportion to [flowers],
  /// sprays of blossom in its corners). With [dialog] it is a tall panel of deep
  /// blue paper with a parchment header taking [header] of its height. A banner
  /// with negative [flowers] has blue lozenges at its ends instead. The shape
  /// fills [r] exactly; the effect's `blur` (0..1) fades it out.
  EntityId cartoucheAt(
    UiRect r, {
    bool arch = false,
    bool card = false,
    bool dialog = false,
    double header = 0,
    bool paper = false,
    double plaque = 0,
    double flowers = 0,
    double gleam = 0,
    int? window,
    int z = 5,
  }) {
    final id = world.spawn();
    world.componentsOf<Position>().set(
      id,
      Position(r.centerX, r.centerY + yShift),
    );
    world.componentsOf<ShaderEffect>().set(
      id,
      ShaderEffect(
        kind: ShaderEffect.cartouche,
        width: r.width,
        height: r.height,
        zIndex: z,
        rimArgb: 0xFFE8B23A,
        armArgb: 0xFF1F4E9C,
        coreArgb: window ?? 0xFF1B6B3A,
        params: [
          dialog ? 3 : (card ? 2 : (arch ? 1 : 0)),
          gleam,
          paper ? 1 : 0,
          dialog ? header : (arch ? plaque : flowers),
        ],
      ),
    );
    return id;
  }

  /// A swirling Persian cloud in [r] (head at the left, or at the right when
  /// [mirror]), drawn by the `cloud` shader; [variant] 0..3 changes its curls.
  EntityId cloudAt(
    UiRect r, {
    int variant = 0,
    bool mirror = false,
    double opacity = 1,
    int z = 1,
  }) {
    final id = world.spawn();
    world.componentsOf<Position>().set(
      id,
      Position(r.centerX, r.centerY + yShift),
    );
    world.componentsOf<ShaderEffect>().set(
      id,
      ShaderEffect(
        kind: ShaderEffect.cloud,
        width: r.width,
        height: r.height,
        zIndex: z,
        rimArgb: 0xFFE8B23A,
        armArgb: 0xFF8FB4E8,
        coreArgb: 0xFFFFF1D6,
        params: [variant.toDouble(), mirror ? 1 : 0, opacity, 0],
      ),
    );
    return id;
  }

  /// A flowering branch in [r] (leaning right, or left when [mirror]), drawn
  /// by the `blossom` shader.
  EntityId blossomAt(UiRect r, {bool mirror = false, int z = 2}) {
    final id = world.spawn();
    world.componentsOf<Position>().set(
      id,
      Position(r.centerX, r.centerY + yShift),
    );
    world.componentsOf<ShaderEffect>().set(
      id,
      ShaderEffect(
        kind: ShaderEffect.blossom,
        width: r.width,
        height: r.height,
        zIndex: z,
        rimArgb: 0xFFF0746A,
        armArgb: 0xFF7A4A24,
        coreArgb: 0xFF5E7A2C,
        params: [mirror ? 1 : 0, 1],
      ),
    );
    return id;
  }

  /// The two blossoming branches on their rocks at the bottom corners of the
  /// screen; call after [QuizScreen.spread] with 1 so they sit on the bottom.
  void footBlossoms({double width = 96, double height = 165}) {
    final y = QuizScreen.worldHeight - height;
    blossomAt(UiRect(0, y, width, height));
    blossomAt(
      UiRect(QuizScreen.worldWidth - width, y, width, height),
      mirror: true,
    );
  }

  /// The look every screen shares: blue paper, [clouds] drifting across it and,
  /// when [blossoms], the blossoming branches on rocks at the bottom corners.
  void styledBackdrop({int clouds = 2, bool blossoms = true, int seed = 1}) {
    lapisSky();
    final rng = math.Random(seed);
    // Away from the title bar at the top: a band in the middle and one low.
    final bands = [(330.0, 380.0), (470.0, 520.0), (120.0, 160.0)];
    for (var i = 0; i < clouds && i < bands.length; i++) {
      spread(0.5);
      final cloud = DriftingCloud(
        this,
        (i * 2 + seed) % 4,
        bands[i].$1,
        bands[i].$2,
      );
      tickers.add((dt) => cloud.step(dt, rng));
    }
    if (blossoms) {
      spread(1);
      footBlossoms(width: 84, height: 135);
    }
    spread(0);
  }

  /// A button over [r] drawn as a gilded banner (green velvet with blossoms, or
  /// parchment when [paper], or [color] velvet), with [text] on it.
  UiButton bannerButton(
    UiRect r,
    String text,
    void Function() onTap, {
    double size = 18,
    bool paper = false,
    int? color,
    double flowers = 1,
    double gleam = 0.15,
    double fade = 0,
    int z = 5,
    QuizGroup? group,
  }) {
    final fx = cartoucheAt(
      r,
      flowers: flowers,
      paper: paper,
      gleam: gleam,
      window: color,
      z: z,
    );
    // A dimmed banner (a button that cannot be pressed yet) is partly faded.
    if (fade > 0) world.componentsOf<ShaderEffect>().get(fx)!.blur = fade;
    group?.addId(fx);
    final b = button(
      r,
      text,
      onTap,
      style: QuizButtonStyle.option,
      size: size,
      group: group,
    );
    b.bg.shape!.alpha = 0;
    b.label.text!.colorArgb = paper ? 0xFF14284B : 0xFFFFF1D6;
    return b;
  }

  /// Mottled blue handmade paper with flecks of gold leaf behind the whole
  /// screen, drawn by the `lapis` shader.
  void lapisSky({int? base, int? light, int? gold}) {
    final id = world.spawn();
    world.componentsOf<Position>().set(
      id,
      Position(QuizScreen.worldWidth / 2, world.height / 2),
    );
    world.componentsOf<ShaderEffect>().set(
      id,
      ShaderEffect(
        kind: ShaderEffect.lapis,
        width: QuizScreen.worldWidth,
        height: world.height,
        zIndex: -9,
        rimArgb: base ?? 0xFF3C74C2,
        armArgb: light ?? 0xFF6E9FDD,
        coreArgb: gold ?? 0xFFF3CB6B,
      ),
    );
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

/// A cloud that crosses the page: it comes in from a random side, drifts to the
/// other and, once it has left the screen, comes in again from a random side
/// at a new height, speed and shape.
class DriftingCloud {
  DriftingCloud(this._screen, int variant, this._top, this._bottom)
    : _shift = _screen.yShift {
    final rng = math.Random(variant * 31 + 5);
    _variant = variant;
    _id = _screen.cloudAt(
      UiRect(0, 0, _w, _h),
      variant: variant,
      opacity: 0.95,
    );
    _launch(rng, onScreen: true);
  }

  /// The screen it drifts on.
  final QuizScreen _screen;
  final double _top;
  final double _bottom;
  final double _shift;
  static const _w = 190.0;
  static const _h = 90.0;
  late final EntityId _id;
  double _speed = 10;
  int _variant = 0;

  /// How far past the screen edge a cloud's centre is when it is fully out of
  /// sight, with a margin so it never pops in or out.
  double _offscreen(double width) => width / 2 + 24;

  void _launch(math.Random rng, {bool onScreen = false}) {
    final right = rng.nextBool();
    final world = _screen.world;
    final fx = world.componentsOf<ShaderEffect>().get(_id)!;
    if (!onScreen) _variant = rng.nextInt(4);
    // A new shape, size and motion each time it comes in.
    // Depth: a far cloud is small, slow and pale, a near one large, quicker
    // and stronger, so the sky reads as having distance (parallax).
    final depth = rng.nextDouble();
    final scale = 0.65 + 0.7 * depth;
    fx.width = _w * scale;
    fx.height = _h * scale;
    // The head leads, so it is mirrored when the cloud drifts to the right.
    fx.params = [
      _variant.toDouble(),
      right ? 1 : 0,
      0.7 + 0.25 * depth,
      rng.nextDouble() * 6,
    ];
    final y = _top + rng.nextDouble() * (_bottom - _top) + fx.height / 2;
    final x = onScreen
        ? rng.nextDouble() * QuizScreen.worldWidth
        : (right
              ? -_offscreen(fx.width)
              : QuizScreen.worldWidth + _offscreen(fx.width));
    _speed = (right ? 1 : -1) * (4 + 11 * depth);
    world.componentsOf<Position>().set(_id, Position(x, y + _shift));
  }

  void step(double dt, math.Random rng) {
    final pos = _screen.world.componentsOf<Position>().get(_id);
    final fx = _screen.world.componentsOf<ShaderEffect>().get(_id);
    if (pos == null || fx == null) return;
    pos.x += _speed * dt;
    final out = _offscreen(fx.width);
    final gone = _speed > 0
        ? pos.x > QuizScreen.worldWidth + out
        : pos.x < -out;
    if (gone) _launch(rng);
  }
}
