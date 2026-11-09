import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' as eng;

Future<ui.Image> _solid(int w, int h, int r, int g, int b, int a) {
  final bytes = Uint8List(w * h * 4);
  for (var i = 0; i < w * h; i++) {
    bytes[i * 4] = r;
    bytes[i * 4 + 1] = g;
    bytes[i * 4 + 2] = b;
    bytes[i * 4 + 3] = a;
  }
  final c = Completer<ui.Image>();
  ui.decodeImageFromPixels(bytes, w, h, ui.PixelFormat.rgba8888, c.complete);
  return c.future;
}

World _world() {
  final w = World(width: 180, height: 320);
  registerCoreComponents(w);
  eng.registerFlutterComponents(w);
  return w;
}

void main() {
  testWidgets('a sprite comes apart into coloured dust that then vanishes', (
    tester,
  ) async {
    final world = _world();
    final system = eng.DisintegrationSystem(
      style: const eng.DisintegrationStyle(maxDust: 50, sweepSeconds: 0.5),
    );
    final particles = ParticleSystem();
    final move = MovementSystem();
    final atlas = await tester.runAsync(() async {
      final image = await _solid(8, 8, 200, 30, 20, 255);
      return eng.SpriteAtlas(image, {'0': const ui.Rect.fromLTWH(0, 0, 8, 8)});
    });
    final e = world.spawn();
    world.componentsOf<Position>().set(e, Position(50, 60));
    world.componentsOf<eng.Sprite>().set(
      e,
      eng.Sprite('a', '0', scaleX: 2, scaleY: 2, zIndex: 20),
    );

    expect(system.start(world, e, atlas!), isFalse, reason: 'not prepared');
    await tester.runAsync(() => eng.DisintegrationSystem.prepare(atlas));
    expect(eng.DisintegrationSystem.isPrepared(atlas), isTrue);
    world.componentsOf<eng.HitFlash>().set(e, eng.HitFlash(remaining: 1));
    expect(system.start(world, e, atlas), isTrue);
    expect(
      world.componentsOf<eng.HitFlash>().get(e),
      isNull,
      reason: 'a hit flash would keep resetting the fade',
    );
    expect(system.activeCount, 1);

    void step(double dt) {
      system.update(world, dt);
      move.update(world, dt);
      particles.update(world, dt);
    }

    for (var i = 0; i < 10; i++) {
      step(0.05);
    }
    final dust = world.componentsOf<Particle>();
    expect(dust.length, greaterThan(0), reason: 'grains are released');
    expect(dust.length, lessThanOrEqualTo(50));
    expect(dust.denseAt(0).colorArgb, 0xFFC81E14, reason: 'pixel colour');
    expect(dust.denseAt(0).zIndex, 21, reason: 'just above the body');
    final sprite = world.componentsOf<eng.Sprite>().get(e)!;
    expect(sprite.tintArgb! >>> 24, lessThan(255), reason: 'body fades');

    for (var i = 0; i < 80; i++) {
      step(0.05);
    }
    expect(system.activeCount, 0);
    expect(world.componentsOf<Particle>().length, 0, reason: 'all gone');
    expect(sprite.tintArgb! >>> 24, 0, reason: 'body fully gone');
  });

  testWidgets('a fully transparent frame is not disintegrated', (tester) async {
    final world = _world();
    final system = eng.DisintegrationSystem();
    final atlas = await tester.runAsync(() async {
      final image = await _solid(4, 4, 0, 0, 0, 0);
      final a = eng.SpriteAtlas(image, {
        '0': const ui.Rect.fromLTWH(0, 0, 4, 4),
      });
      await eng.DisintegrationSystem.prepare(a);
      return a;
    });
    final e = world.spawn();
    world.componentsOf<Position>().set(e, Position(0, 0));
    world.componentsOf<eng.Sprite>().set(e, eng.Sprite('a', '0'));
    expect(system.start(world, e, atlas!), isFalse);
  });

  testWidgets('grains travel with the body when it is moved', (tester) async {
    final world = _world();
    final system = eng.DisintegrationSystem(
      style: const eng.DisintegrationStyle(
        maxDust: 20,
        sweepSeconds: 0.4,
        rise: 0,
        wind: 0,
        spread: 0,
      ),
    );
    final atlas = await tester.runAsync(() async {
      final image = await _solid(4, 4, 9, 9, 9, 255);
      final a = eng.SpriteAtlas(image, {
        '0': const ui.Rect.fromLTWH(0, 0, 4, 4),
      });
      await eng.DisintegrationSystem.prepare(a);
      return a;
    });
    final e = world.spawn();
    world.componentsOf<Position>().set(e, Position(50, 60));
    world.componentsOf<eng.Sprite>().set(e, eng.Sprite('a', '0'));
    expect(system.start(world, e, atlas!), isTrue);
    system.update(world, 0.2);
    final grain = world.componentsOf<Particle>().entityAt(0);
    final before = world.componentsOf<Position>().get(grain)!.x;
    world.componentsOf<Position>().get(e)!.x -= 30; // the ground scrolls
    system.update(world, 0.01);
    expect(
      world.componentsOf<Position>().get(grain)!.x,
      closeTo(before - 30, 1e-9),
    );
  });
}
