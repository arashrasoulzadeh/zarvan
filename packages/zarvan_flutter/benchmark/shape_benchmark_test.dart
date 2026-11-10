import 'package:flutter/material.dart' hide Velocity;
import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' hide Text;

/// 200 flat shapes (a mix of kinds, some dashed) painted every frame --
/// roughly a busy Adad Bazi playfield. Run with:
///   flutter test benchmark/shape_benchmark_test.dart --no-pub
///
/// Recorded (debug VM, M-series Mac): see the printed line; the assertion
/// is a loose 8 ms/frame ceiling so only a real regression trips it.
void main() {
  testWidgets('200 shapes per frame', (tester) async {
    final world = World(width: 400, height: 800);
    registerCoreComponents(world);
    registerFlutterComponents(world);
    for (var i = 0; i < 200; i++) {
      final e = world.spawn();
      world.componentsOf<Position>().set(
        e,
        Position((i % 20) * 18.0 - 180, (i ~/ 20) * 36.0 - 180),
      );
      world.componentsOf<Shape>().set(
        e,
        Shape(
          kind: ShapeKind.values[i % 3],
          width: 28,
          height: 20,
          cornerRadius: 6,
          strokeWidth: i % 2 == 0 ? 0 : 3,
          dashLength: i % 5 == 0 ? 4 : 0,
          gapLength: i % 5 == 0 ? 3 : 0,
          colorArgb: 0xFFFF8800,
        ),
      );
    }

    final stats = FrameStats();
    await tester.pumpWidget(
      MaterialApp(
        home: EngineView(
          world: world,
          atlasRegistry: AtlasRegistry(),
          camera: Camera(),
          frameStats: stats,
        ),
      ),
    );
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    // ignore: avoid_print
    print(
      'BENCH shapes=200 stepMs=${stats.stepMs.toStringAsFixed(3)} '
      'paintMs=${stats.paintMs.toStringAsFixed(3)}',
    );
    expect(stats.paintMs, lessThan(8));
  });
}
