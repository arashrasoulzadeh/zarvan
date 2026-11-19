import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Velocity;
import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' hide Text;

/// 5,000 sprites painted every frame, in three mixes, to show where the
/// sprite path spends its time: all batchable, a third mirrored (every
/// `FacingSystem` flip), and a third with non-uniform scale (the
/// one-`drawImageRect`-per-sprite fallback). A fourth run keeps 4,500 of
/// them far off-screen to show what camera culling saves. Run with:
///   flutter test benchmark/sprite_benchmark_test.dart --no-pub
///
/// The assertion is a loose ceiling so only a real regression trips it; read
/// the printed `BENCH` lines for the numbers.
Future<double> _paintMs(
  WidgetTester tester, {
  required double Function(int i) scaleXFor,
  required double Function(int i) scaleYFor,
  required double Function(int i) xFor,
}) async {
  final world = World(width: 400, height: 800);
  registerCoreComponents(world);
  registerFlutterComponents(world);
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 8, 8),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  final image = await tester.runAsync(
    () => recorder.endRecording().toImage(8, 8),
  );
  final registry = AtlasRegistry()
    ..register(
      'a',
      SpriteAtlas(image!, {'px': const Rect.fromLTWH(0, 0, 8, 8)}),
    );
  for (var i = 0; i < 5000; i++) {
    final e = world.spawn();
    world.componentsOf<Position>().set(
      e,
      Position(xFor(i), (i ~/ 50) * 6.0 - 300),
    );
    world.componentsOf<Sprite>().set(
      e,
      Sprite('a', 'px', scaleX: scaleXFor(i), scaleY: scaleYFor(i)),
    );
  }
  final stats = FrameStats();
  await tester.pumpWidget(
    MaterialApp(
      home: EngineView(
        world: world,
        atlasRegistry: registry,
        camera: Camera(),
        frameStats: stats,
      ),
    ),
  );
  for (var i = 0; i < 120; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  return stats.paintMs;
}

void main() {
  double col(int i) => (i % 50) * 7.0 - 175;

  testWidgets('5k sprites: all batchable', (tester) async {
    final ms = await _paintMs(
      tester,
      scaleXFor: (_) => 1,
      scaleYFor: (_) => 1,
      xFor: col,
    );
    // ignore: avoid_print
    print('BENCH sprites=5000 mix=batched paintMs=${ms.toStringAsFixed(3)}');
    expect(ms, lessThan(40));
  });

  testWidgets('5k sprites: a third mirrored', (tester) async {
    final ms = await _paintMs(
      tester,
      scaleXFor: (i) => i % 3 == 0 ? -1 : 1,
      scaleYFor: (_) => 1,
      xFor: col,
    );
    // ignore: avoid_print
    print('BENCH sprites=5000 mix=mirrored paintMs=${ms.toStringAsFixed(3)}');
    expect(ms, lessThan(40));
  });

  testWidgets('5k sprites: a third non-uniform (fallback path)', (
    tester,
  ) async {
    final ms = await _paintMs(
      tester,
      scaleXFor: (i) => i % 3 == 0 ? 2 : 1,
      scaleYFor: (_) => 1,
      xFor: col,
    );
    // ignore: avoid_print
    print('BENCH sprites=5000 mix=fallback paintMs=${ms.toStringAsFixed(3)}');
    expect(ms, lessThan(60));
  });

  testWidgets('5k sprites: 90% off-screen (culled)', (tester) async {
    final ms = await _paintMs(
      tester,
      scaleXFor: (_) => 1,
      scaleYFor: (_) => 1,
      xFor: (i) => i % 10 == 0 ? col(i) : 50000.0,
    );
    // ignore: avoid_print
    print('BENCH sprites=5000 mix=culled paintMs=${ms.toStringAsFixed(3)}');
    expect(ms, lessThan(40));
  });
}
