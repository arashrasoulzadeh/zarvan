import 'dart:ui' as ui;

import 'package:zarvan_core/zarvan_core.dart';

import 'ambient_lighting_shader.dart';
import 'gpu_light_shader.dart';
import 'light2d.dart';
import 'normal_mapping_combined_shader.dart';
import 'normal_mapping_shader.dart';
import 'shader_effect.dart';
import 'shader_post_fx.dart';
import 'sprite.dart';

/// Warms up the GPU-side systems a [World] will actually use, during loading.
///
/// Fragment programs compile lazily on first paint, so without this the first
/// frame that needs lighting or normal mapping draws without it and the
/// pipeline compile lands in a visible frame. Only what the world needs is
/// touched: no lights, no lighting shaders. Never throws: a shader that cannot
/// load degrades exactly as it already does at paint time.
class EngineWarmup {
  /// Shaders [world] needs, by name (`ambient`, `gpuShadow`, `normalMap`, and
  /// `effect:<kind>` for each [ShaderEffect] kind the world holds).
  static Set<String> neededShaders(World world) {
    final needs = <String>{};
    final lights = world.componentsOf<Light2D>();
    for (var i = 0; i < lights.length; i++) {
      final light = lights.denseAt(i);
      needs.add('ambient');
      if (light.useGpuShadows && light.castsShadows) needs.add('gpuShadow');
    }
    final sprites = world.componentsOf<Sprite>();
    for (var i = 0; i < sprites.length; i++) {
      if (sprites.denseAt(i).normalAtlasId != null) {
        needs.add('normalMap');
        break;
      }
    }
    final effects = world.componentsOf<ShaderEffect>();
    for (var i = 0; i < effects.length; i++) {
      final kind = effects.denseAt(i).kind;
      if (EffectShader.forAnyKind(kind) != null) needs.add('effect:$kind');
    }
    return needs;
  }

  /// Compiles [neededShaders] and draws each once into a 1x1 offscreen image
  /// so the GPU pipeline is built before the first visible frame. Reports
  /// `(fraction, label)` as it goes.
  ///
  /// [extraEffects] are effect kinds the world does not use yet but a later
  /// screen will, so their first draw does not stall the frame it opens on.
  ///
  /// With [warmBlur] the blur pipelines a `BackdropBlur` uses are built too:
  /// they are the engine's own, not fragment programs, so [neededShaders]
  /// cannot see them in a world that has not opened its blur yet.
  ///
  /// With [warmPostFx] the post-processing shader is loaded too, so turning
  /// `Game.postFx` on does not stall the frame it first appears on. It is not
  /// in [neededShaders] because post-processing is a setting, not an entity.
  static Future<void> run(
    World world, {
    void Function(double fraction, String label)? report,
    bool warmBlur = false,
    bool warmPostFx = false,
    Set<String> extraEffects = const {},
  }) async {
    final needs = {
      ...neededShaders(world),
      for (final kind in extraEffects)
        if (EffectShader.forAnyKind(kind) != null) 'effect:$kind',
    };
    final steps =
        <(String, Future<void> Function(), ui.FragmentShader? Function())>[
          if (needs.contains('ambient'))
            (
              'lighting',
              AmbientLightingShader.warmUp,
              AmbientLightingShader.shader,
            ),
          if (needs.contains('gpuShadow'))
            ('shadows', GpuLightShader.warmUp, GpuLightShader.shader),
          if (needs.contains('normalMap')) ...[
            (
              'normal maps',
              NormalMappingShader.warmUp,
              NormalMappingShader.shader,
            ),
            (
              'normal maps',
              NormalMappingCombinedShader.warmUp,
              NormalMappingCombinedShader.shader,
            ),
          ],
          for (final need in needs.where((n) => n.startsWith('effect:')))
            (
              'effects',
              EffectShader.forAnyKind(need.substring(7))!.warmUp,
              EffectShader.forAnyKind(need.substring(7))!.shader,
            ),
        ];
    for (var i = 0; i < steps.length; i++) {
      final (label, load, make) = steps[i];
      report?.call(i / steps.length, 'Warming up $label');
      try {
        await load();
        final shader = make();
        if (shader != null) _drawOnce(shader);
      } on Object {
        // Same fallback as paint time: the feature is skipped, not fatal.
      }
    }
    if (warmPostFx) {
      report?.call(steps.length / (steps.length + 1), 'Warming up effects');
      await ShaderPostProcessed.warmUp();
    }
    if (warmBlur) {
      report?.call(steps.length / (steps.length + 1), 'Warming up blur');
      try {
        _blurOnce();
      } on Object {
        // The blur is built at first use instead, as it was before.
      }
    }
    report?.call(1, 'Warming up');
  }

  /// Blurs a small layer into an offscreen image, as `BackdropBlur` does to
  /// the screen, so its pipelines exist before the first visible blur.
  static void _blurOnce() {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    const rect = ui.Rect.fromLTWH(0, 0, 96, 96);
    canvas.saveLayer(
      rect,
      ui.Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: 4,
          sigmaY: 4,
          tileMode: ui.TileMode.clamp,
        ),
    );
    canvas.drawRect(rect, ui.Paint()..color = const ui.Color(0xFF808080));
    canvas.restore();
    final picture = recorder.endRecording();
    picture.toImageSync(96, 96).dispose();
    picture.dispose();
  }

  /// Draws [shader] once so its pipeline is built. Every image sampler it
  /// declares is bound to a 1x1 image first: drawing with a sampler left
  /// unbound dereferences null inside the engine and kills the app, which no
  /// try/catch can stop.
  static void _drawOnce(ui.FragmentShader shader) {
    final images = <ui.Image>[];
    try {
      for (var i = 0; i < 8; i++) {
        final image = _blankImage();
        try {
          shader.setImageSampler(i, image);
          images.add(image);
        } on Object {
          image.dispose();
          break;
        }
      }
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 1, 1),
        ui.Paint()..shader = shader,
      );
      final picture = recorder.endRecording();
      picture.toImageSync(1, 1).dispose();
      picture.dispose();
    } finally {
      for (final image in images) {
        image.dispose();
      }
    }
  }

  static ui.Image _blankImage() {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      const ui.Rect.fromLTWH(0, 0, 1, 1),
      ui.Paint()..color = const ui.Color(0x00000000),
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(1, 1);
    picture.dispose();
    return image;
  }
}
