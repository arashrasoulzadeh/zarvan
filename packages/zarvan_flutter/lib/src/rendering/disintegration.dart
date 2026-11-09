import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:zarvan_core/zarvan_core.dart';

import 'hit_flash.dart';
import 'sprite.dart';
import 'sprite_atlas.dart';

/// How a [DisintegrationSystem] turns a sprite into dust.
class DisintegrationStyle {
  const DisintegrationStyle({
    this.delay = 0.2,
    this.sweepSeconds = 0.9,
    this.dustLifeMin = 0.9,
    this.dustLifeMax = 1.7,
    this.maxDust = 1400,
    this.dustSize = 0.4,
    this.rise = 14,
    this.wind = 10,
    this.spread = 6,
  });

  /// Seconds between the end of the death animation and the first grain leaving
  /// the body; the game that triggers the effect honours it (the system itself
  /// starts at once).
  final double delay;

  /// How long the body takes to come apart. Grains leave in a sweep from one
  /// side to the other (with noise), the way the snap crumbles a body.
  final double sweepSeconds;

  /// Each grain floats for a random time in this range, then is gone.
  final double dustLifeMin;
  final double dustLifeMax;

  /// Upper bound on grains per body; an opaque body is sampled down to this.
  final int maxDust;

  /// Grain radius in world units at birth (they shrink as they float).
  final double dustSize;

  /// World units per second the grains climb, drift sideways with [wind] and
  /// scatter by up to [spread] in any direction.
  final double rise;
  final double wind;
  final double spread;
}

/// The "snap" death: a sprite's body comes apart into tiny coloured grains
/// that float up, scatter on the wind and fade to nothing.
///
/// [prepare] reads an atlas's pixels once (async); [start] then samples the
/// sprite's current frame, hides the sprite progressively over
/// [DisintegrationStyle.sweepSeconds] and releases a [Particle] per sampled
/// pixel, coloured like the pixel, in a left-to-right sweep. Needs
/// `ParticleSystem` and `MovementSystem` in the world (the grains are ordinary
/// particles with a `Velocity`). The sprite entity is left alive but fully
/// transparent, so a game's own clean-up still applies.
class DisintegrationSystem implements System {
  DisintegrationSystem({
    this.style = const DisintegrationStyle(),
    math.Random? random,
  }) : _random = random ?? math.Random(7);

  final DisintegrationStyle style;
  final math.Random _random;

  static final _pixels = Expando<ByteData>();

  final _jobs = <_Job>[];

  @override
  String get name => 'disintegration';

  /// Reads [atlas]'s pixels so sprites of it can be disintegrated. Call once
  /// per atlas after loading; [start] skips atlases that were not prepared.
  static Future<void> prepare(SpriteAtlas atlas) async {
    if (_pixels[atlas.image] != null) return;
    _pixels[atlas.image] = await atlas.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
  }

  /// Whether [atlas] has been [prepare]d.
  static bool isPrepared(SpriteAtlas atlas) => _pixels[atlas.image] != null;

  /// Number of bodies still coming apart.
  int get activeCount => _jobs.where((j) => j.coming).length;

  /// True while a body is coming apart or its last grains are still floating;
  /// a game can hold a pause or a popup back until this is false.
  bool get isBusy => _jobs.isNotEmpty;

  final _opaque = <ui.Image, Map<String, List<_Grain>>>{};

  /// The opaque pixels of [region] in [atlas] (u, v in 0..1 and colour), cached
  /// and thinned to a few hundred so each frame of a death clip is cheap to
  /// draw grains from.
  List<_Grain> _grainsOf(SpriteAtlas atlas, String region) {
    final perImage = _opaque[atlas.image] ??= {};
    final cached = perImage[region];
    if (cached != null) return cached;
    final bytes = _pixels[atlas.image];
    // Not prepared yet: nothing to sample, and nothing worth caching.
    if (bytes == null) return const [];
    final rect = atlas.regions[region];
    final out = <_Grain>[];
    if (rect != null) {
      final imageW = atlas.image.width;
      final x0 = rect.left.floor(), y0 = rect.top.floor();
      final w = rect.width.floor(), h = rect.height.floor();
      for (var py = 0; py < h; py++) {
        for (var px = 0; px < w; px++) {
          final i = ((y0 + py) * imageW + (x0 + px)) * 4;
          final a = bytes.getUint8(i + 3);
          if (a < 60) continue;
          out.add(
            _Grain(
              px / w,
              py / h,
              (a << 24) |
                  (bytes.getUint8(i) << 16) |
                  (bytes.getUint8(i + 1) << 8) |
                  bytes.getUint8(i + 2),
              w.toDouble(),
              h.toDouble(),
            ),
          );
        }
      }
      out.shuffle(_random);
      if (out.length > 2500) out.removeRange(2500, out.length);
    }
    return perImage[region] = out;
  }

  /// Starts disintegrating [entity]'s sprite (drawn from [atlas]). Grains are
  /// taken from whatever frame the sprite shows as the sweep goes on, so a body
  /// that is still falling crumbles in its current pose. Returns false,
  /// changing nothing, when the entity has no sprite and position, the atlas
  /// was not prepared, or the frame has no opaque pixels. Any `HitFlash` on the
  /// entity is removed, since it would keep resetting the fade.
  bool start(World world, EntityId entity, SpriteAtlas atlas) {
    final sprite = world.componentsOf<Sprite>().get(entity);
    if (sprite == null ||
        world.componentsOf<Position>().get(entity) == null ||
        _grainsOf(atlas, sprite.region).isEmpty) {
      return false;
    }
    world.componentsOf<HitFlash>().remove(entity);
    final pos = world.componentsOf<Position>().get(entity)!;
    _jobs.add(_Job(entity, atlas, sprite.zIndex + 1)..last = (pos.x, pos.y));
    return true;
  }

  @override
  void update(World world, double dt) {
    final particles = world.componentsOf<Particle>();
    final positions = world.componentsOf<Position>();
    for (var j = _jobs.length - 1; j >= 0; j--) {
      final job = _jobs[j];
      final sprite = world.componentsOf<Sprite>().get(job.entity);
      final pos = positions.get(job.entity);
      if (sprite == null || pos == null) {
        job.coming = false;
      } else {
        // Grains travel with the body: when the ground scrolls past (or the
        // body is pushed) the dust in the air moves along with it.
        final dx = pos.x - job.last.$1, dy = pos.y - job.last.$2;
        job.last = (pos.x, pos.y);
        if (dx != 0 || dy != 0) {
          for (final g in job.grains) {
            final gp = positions.get(g.id);
            if (gp != null && identical(particles.get(g.id), g.particle)) {
              gp.x += dx;
              gp.y += dy;
            }
          }
        }
        job.age += dt;
        _releaseSome(world, job, sprite, pos);
        final fade =
            1 - (job.age / (style.sweepSeconds + 0.15)).clamp(0.0, 1.0);
        sprite.tintArgb = (fade * 255).round() << 24 | 0xFFFFFF;
        if (fade == 0 && job.released >= style.maxDust) job.coming = false;
      }
      job.grains.removeWhere(
        (g) => !identical(particles.get(g.id), g.particle),
      );
      if (!job.coming && job.grains.isEmpty) _jobs.removeAt(j);
    }
  }

  void _releaseSome(World world, _Job job, Sprite sprite, Position pos) {
    final p = (job.age / style.sweepSeconds).clamp(0.0, 1.0);
    final target = (style.maxDust * p).round();
    final grains = _grainsOf(job.atlas, sprite.region);
    final dir = sprite.scaleX < 0 ? -1.0 : 1.0;
    while (job.released < target && grains.isNotEmpty) {
      job.released++;
      // Prefer pixels inside the sweep window, which moves across the body.
      var g = grains[_random.nextInt(grains.length)];
      for (var t = 0; t < 8; t++) {
        final u = dir > 0 ? g.u : 1 - g.u;
        if (u >= p - 0.3 && u <= p + 0.12) break;
        g = grains[_random.nextInt(grains.length)];
      }
      job.grains.add(
        _release(
          world,
          g,
          pos.x + sprite.offsetX + (g.u - 0.5) * g.w * sprite.scaleX,
          pos.y + sprite.offsetY + (g.v - 0.5) * g.h * sprite.scaleY,
          job.z,
        ),
      );
    }
  }

  _Flying _release(World world, _Grain g, double x, double y, int z) {
    final id = world.spawn();
    world.componentsOf<Position>().set(id, Position(x, y));
    final a = _random.nextDouble() * 2 * math.pi;
    final s = _random.nextDouble() * style.spread;
    world.componentsOf<Velocity>().set(
      id,
      Velocity(
        style.wind * (0.4 + _random.nextDouble()) + math.cos(a) * s,
        -style.rise * (0.3 + _random.nextDouble()) + math.sin(a) * s * 0.5,
      ),
    );
    final life =
        style.dustLifeMin +
        _random.nextDouble() * (style.dustLifeMax - style.dustLifeMin);
    final particle = Particle(
      lifetime: life,
      // The renderer draws a grain 4 * scale pixels wide per zoom unit.
      startScale: style.dustSize / 4,
      endScale: style.dustSize / 16,
      startAlpha: 1,
      endAlpha: 0,
      colorArgb: g.argb,
      zIndex: z,
    );
    world.componentsOf<Particle>().set(id, particle);
    return _Flying(id, particle);
  }
}

class _Grain {
  _Grain(this.u, this.v, this.argb, this.w, this.h);
  final double u, v;
  final int argb;
  final double w, h;
}

class _Flying {
  _Flying(this.id, this.particle);
  final EntityId id;
  final Particle particle;
}

class _Job {
  _Job(this.entity, this.atlas, this.z);
  final EntityId entity;
  final SpriteAtlas atlas;
  final int z;
  final grains = <_Flying>[];
  (double, double) last = (0, 0);
  double age = 0;
  int released = 0;

  /// Still releasing grains (the sprite has not finished fading).
  bool coming = true;
}
