import 'dart:ui' as ui;

/// A procedural GPU effect drawn by a fragment shader into a rect, with no
/// texture: add it to an entity with a `Position` (the rect's centre) and the
/// engine paints it each frame at [zIndex], animated by the engine's clock.
///
/// [kind] picks the shader; today `'portal'`, a magical doorway filling the
/// whole rect edge to edge: a glowing rim, a deep void whose clouds spiral in
/// to a bright core, light streaks falling, sparks rising and a pool of light
/// on the floor. Its colours are ARGB ints: the void ([rimArgb]), the clouds
/// and rim glow ([armArgb]) and the core, brightest rim, streaks and sparks
/// ([coreArgb]). [speed] scales time, so `0` freezes it and `2` runs it twice
/// as fast. [images] puts a blurred picture (a level's backdrop) inside it.
/// World space, like a `Sprite`: [width] and [height] are world units and scale
/// with the camera zoom.
class ShaderEffect {
  /// Which shader draws it; unknown kinds draw nothing.
  String kind;

  /// Up to four numbers the kind reads (`portrait`: beard length, beard
  /// spread, headwear, flags; `veil`: progress, origin x, origin y), set
  /// each frame by the game. Missing ones are 0.
  List<double> params;

  /// Size of the rect the effect fills, in world units.
  double width;
  double height;

  /// Draw order relative to every other renderable.
  int zIndex;

  /// Clock multiplier; `0` holds the effect still.
  double speed;

  /// Ids of up to two loaded atlases (their whole image) shown, blurred, as the
  /// backdrop inside the portal, bottom layer first: the picture of where it
  /// leads. Empty draws no picture. Only the middle slice of each image that
  /// matches the rect's aspect is used.
  List<String> images;

  /// How soft the backdrop is, as a fraction of the image (0 sharp; ~0.03 is a
  /// soft haze).
  double blur;

  /// How many pixels the portal is drawn in across its width: ~30 is chunky
  /// pixel art, higher gives a finer, sharper picture (and spiral). Only the
  /// portal uses it.
  double detail;

  /// Strength of the glow along the portal's rim and floor: 1 as designed,
  /// lower is calmer, 0 none. Only the portal uses it.
  double rimGlow;

  /// Colour saturation of the whole portal: 1 full colour, 0 grey. Anything
  /// below 1 also darkens it, so a locked doorway reads as shut. Portal only.
  double saturation;

  /// Width of a gold-and-lapis frame drawn round the portal, as a fraction of
  /// its width (~0.04 is a slim ornate border); 0 draws none. Portal only.
  double border;

  /// How strong an additive `'glow'` or `'shine'` is (the portal ignores it).
  double intensity;

  /// Seconds between the sweeps of a `'shine'`.
  double period;

  /// Base, spiral arm and centre colours (ARGB); a glow uses [coreArgb].
  int rimArgb;
  int armArgb;
  int coreArgb;

  ShaderEffect({
    this.kind = portal,
    required this.width,
    required this.height,
    this.zIndex = 0,
    this.speed = 1,
    this.images = const [],
    this.blur = 0.03,
    this.detail = 30,
    this.rimGlow = 1,
    this.saturation = 1,
    this.border = 0,
    this.intensity = 0.5,
    this.period = 5,
    this.rimArgb = 0xFFB5400C,
    this.armArgb = 0xFFFFC53D,
    this.coreArgb = 0xFFFFF1B8,
    this.params = const [],
  });

  /// The portal doorway.
  static const portal = 'portal';

  /// A glossy sphere, masked to the circle inscribed in the effect's rect,
  /// showing [images] through a slowly-spinning fisheye sample with sphere
  /// shading and a specular highlight — a crystal-ball/orb window, as
  /// opposed to [portal]'s edge-to-edge rectangular doorway.
  static const orb = 'orb';

  /// A soft additive glow that lights what is behind it.
  static const glow = 'glow';

  /// A full-rect night sky: nebula, aurora ribbons, twinkling stars and rising
  /// motes. Colours: [rimArgb] the sky, [armArgb] nebula and aurora, [coreArgb]
  /// stars. Opaque, so draw it behind everything.
  static const aurora = 'aurora';

  /// An ornate Persian panel border drawn by `ornate.frag`: a teal band of
  /// diamonds, stars and gold dots with gold lines and a rosette in each
  /// corner, optionally around a sheet of parchment. Colours: [rimArgb] the
  /// gold, [armArgb] the teal, [coreArgb] the middle (alpha 0 leaves it
  /// clear). Sizes are world units: [border] band thickness, [detail] lattice
  /// cell, [rimGlow] corner radius; [intensity] 0..1 parchment grain and
  /// edge darkening; [saturation] 0..1 depth of the band's inner scallops.
  static const ornate = 'ornate';

  /// A minimal line portrait of a poet, drawn by `portrait.frag` with
  /// distance-field strokes. [rimArgb] is the line colour; [params] pick the
  /// beard, headwear and extras (see the shader).
  static const portrait = 'portrait';

  /// A screen transition drawn by `veil.frag`: a swirling veil with a
  /// gold-rimmed edge that spreads from a point ([params] = progress 0..1,
  /// origin x, origin y, all but progress as fractions of the rect). Colours:
  /// [rimArgb] the edge, [armArgb] the lattice, [coreArgb] the body.
  static const veil = 'veil';

  /// A poetic transition drawn by `ink.frag`: ink bleeds across the screen
  /// from a point with gold-leaf dust at its wet edge, then faint gold script
  /// shows in it while rose petals drift over. Same [params] as [veil].
  /// Colours: [rimArgb] gold, [armArgb] petals, [coreArgb] the ink.
  static const ink = 'ink';

  /// A transition in the game's own style, drawn by `kashi.frag`: Persian
  /// tilework. Tiles turn over outward from a point, each with a gold eight-
  /// pointed star, ring and corner diamonds on teal, until the screen is
  /// tiled. Same [params] as [veil]. Colours: [rimArgb] gold, [armArgb] teal,
  /// [coreArgb] the dark tile body.
  static const kashi = 'kashi';

  /// A theatre curtain transition drawn by `curtain.frag`: two embroidered
  /// velvet panels with gold braided edges slide shut from the sides under a
  /// moonlight beam (and part again). [params] x is progress 0..1. Colours:
  /// [rimArgb] gold braid and embroidery, [armArgb] moonlight, [coreArgb] the
  /// velvet.
  static const curtain = 'curtain';

  /// Drifting motes of light drawn by `dust.frag`: sparse fireflies / gold dust
  /// that rise and sway with a soft halo and a twinkle, over a transparent
  /// rect. [params] x is how many (default 1, up to 2). Colours: [rimArgb] the
  /// motes, [armArgb] an occasional second kind.
  static const dust = 'dust';

  /// A small eight-pointed progress seal drawn by `seal.frag`; [params] x is 0
  /// upcoming (dim), 1 current (bright, breathing light), 2 done (a tick).
  /// Colours: [rimArgb] gold, [armArgb] teal, [coreArgb] the dark.
  static const seal = 'seal';

  /// A band of light that sweeps across `images[0]` every [period] seconds,
  /// lighting only its opaque pixels: lay it over a button or banner, same rect.
  static const shine = 'shine';

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'width': width,
    'height': height,
    'zIndex': zIndex,
    'speed': speed,
    'images': images,
    'blur': blur,
    'detail': detail,
    'rimGlow': rimGlow,
    'saturation': saturation,
    'border': border,
    'intensity': intensity,
    'period': period,
    'rimArgb': rimArgb,
    'armArgb': armArgb,
    'coreArgb': coreArgb,
    'params': params,
  };

  factory ShaderEffect.fromJson(Map<String, dynamic> json) => ShaderEffect(
    kind: json['kind'] as String? ?? portal,
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
    zIndex: (json['zIndex'] as num?)?.toInt() ?? 0,
    speed: (json['speed'] as num?)?.toDouble() ?? 1,
    images: ((json['images'] as List?) ?? const []).cast<String>(),
    blur: (json['blur'] as num?)?.toDouble() ?? 0.03,
    detail: (json['detail'] as num?)?.toDouble() ?? 30,
    rimGlow: (json['rimGlow'] as num?)?.toDouble() ?? 1,
    saturation: (json['saturation'] as num?)?.toDouble() ?? 1,
    border: (json['border'] as num?)?.toDouble() ?? 0,
    intensity: (json['intensity'] as num?)?.toDouble() ?? 0.5,
    period: (json['period'] as num?)?.toDouble() ?? 5,
    rimArgb: (json['rimArgb'] as num?)?.toInt() ?? 0xFFB5400C,
    armArgb: (json['armArgb'] as num?)?.toInt() ?? 0xFFFFC53D,
    coreArgb: (json['coreArgb'] as num?)?.toInt() ?? 0xFFFFF1B8,
    params: ((json['params'] as List?) ?? const [])
        .map((e) => (e as num).toDouble())
        .toList(),
  );
}

/// A compiled fragment program for a [ShaderEffect] kind, loaded once. Same
/// contract as the engine's other shaders: [shader] kicks the async compile off
/// on first use and returns `null` until it is ready (the effect simply isn't
/// drawn for those frames), and also when the shader can't be loaded at all.
class EffectShader {
  EffectShader._(String file)
    : _assetKey = 'packages/zarvan_flutter/shaders/$file';

  /// `portal.frag`.
  static final portal = EffectShader._('portal.frag');

  /// `orb.frag`.
  static final orb = EffectShader._('orb.frag');

  /// `glow.frag`.
  static final glow = EffectShader._('glow.frag');

  /// `shine.frag`.
  static final shine = EffectShader._('shine.frag');

  /// `aurora.frag`.
  static final aurora = EffectShader._('aurora.frag');

  /// `pageturn.frag`, the page curl over a snapshot (see
  /// `SceneTransitionType.pageTurn`).
  static final pageTurn = EffectShader._('pageturn.frag');

  /// `dust.frag`.
  static final dust = EffectShader._('dust.frag');

  /// `ripple.frag`, rings spreading over a snapshot like water (see
  /// `SceneTransitionType.ripple`).
  static final ripple = EffectShader._('ripple.frag');

  /// `lanterns.frag`, the page lifted by paper lanterns (see
  /// `SceneTransitionType.lanterns`).
  static final lanterns = EffectShader._('lanterns.frag');

  /// `ornate.frag`.
  static final ornate = EffectShader._('ornate.frag');

  /// `portrait.frag`.
  static final portrait = EffectShader._('portrait.frag');

  /// `veil.frag`.
  static final veil = EffectShader._('veil.frag');

  /// `ink.frag`.
  static final ink = EffectShader._('ink.frag');

  /// `curtain.frag`.
  static final curtain = EffectShader._('curtain.frag');

  /// `kashi.frag`.
  static final kashi = EffectShader._('kashi.frag');

  /// `seal.frag`.
  static final seal = EffectShader._('seal.frag');

  final String _assetKey;
  ui.FragmentProgram? _program;
  Future<void>? _loading;

  /// A fresh shader to set uniforms on, or null while not ready.
  ui.FragmentShader? shader() {
    final p = _program;
    if (p != null) return p.fragmentShader();
    _loading ??= ui.FragmentProgram.fromAsset(
      _assetKey,
    ).then((v) => _program = v, onError: (Object _, StackTrace __) {});
    return null;
  }

  /// Compiles now and completes when ready (or failed, silently).
  Future<void> warmUp() {
    shader();
    return _loading ?? Future<void>.value();
  }
}

/// The clock the shaders animate with: seconds since the app first painted one.
final Stopwatch shaderClock = Stopwatch()..start();

/// A 1x1 image bound to the shader's picture slots when it has none, so the
/// samplers are always valid.
ui.Image? _blank;
ui.Image blankShaderImage() {
  return _blank ??= () {
    final rec = ui.PictureRecorder();
    ui.Canvas(rec).drawRect(
      const ui.Rect.fromLTWH(0, 0, 1, 1),
      ui.Paint()..color = const ui.Color(0xFF000000),
    );
    return rec.endRecording().toImageSync(1, 1);
  }();
}
