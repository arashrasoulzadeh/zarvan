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
    this.intensity = 0.5,
    this.period = 5,
    this.rimArgb = 0xFFB5400C,
    this.armArgb = 0xFFFFC53D,
    this.coreArgb = 0xFFFFF1B8,
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
    'intensity': intensity,
    'period': period,
    'rimArgb': rimArgb,
    'armArgb': armArgb,
    'coreArgb': coreArgb,
  };

  factory ShaderEffect.fromJson(Map<String, dynamic> json) => ShaderEffect(
    kind: json['kind'] as String? ?? portal,
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
    zIndex: (json['zIndex'] as num?)?.toInt() ?? 0,
    speed: (json['speed'] as num?)?.toDouble() ?? 1,
    images: ((json['images'] as List?) ?? const []).cast<String>(),
    blur: (json['blur'] as num?)?.toDouble() ?? 0.03,
    intensity: (json['intensity'] as num?)?.toDouble() ?? 0.5,
    period: (json['period'] as num?)?.toDouble() ?? 5,
    rimArgb: (json['rimArgb'] as num?)?.toInt() ?? 0xFFB5400C,
    armArgb: (json['armArgb'] as num?)?.toInt() ?? 0xFFFFC53D,
    coreArgb: (json['coreArgb'] as num?)?.toInt() ?? 0xFFFFF1B8,
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
