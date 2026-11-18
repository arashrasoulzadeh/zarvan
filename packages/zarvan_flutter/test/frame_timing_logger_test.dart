import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart';

void main() {
  test('percentile picks the nearest rank of a sorted list', () {
    final xs = [for (var i = 1; i <= 100; i++) i.toDouble()];
    expect(percentile(xs, 0.5), closeTo(50, 1));
    expect(percentile(xs, 0.9), closeTo(90, 1));
    expect(percentile(xs, 0.99), closeTo(99, 1));
    expect(percentile(const [], 0.5), 0);
    expect(percentile(const [7], 0.99), 7);
  });

  test('a summary reports each thread and the share over the frame budget', () {
    // 10 frames: the build is always fast; two frames are slow on raster.
    final builds = List<double>.filled(10, 3);
    final rasters = [
      4,
      5,
      4,
      30,
      4,
      5,
      4,
      25,
      4,
      5,
    ].map((e) => e.toDouble()).toList();
    final s = summarizeFrameTimings(builds, rasters);
    expect(s.frames, 10);
    expect(s.buildP50, 3);
    expect(s.rasterP50, closeTo(4.5, 1));
    expect(s.rasterP99, 30);
    expect(s.jankyShare, closeTo(0.2, 1e-9));
    expect(s.toString(), contains('janky=20%'));
  });

  test('no frames summarise to zeros, not an error', () {
    final s = summarizeFrameTimings(const [], const []);
    expect(s.frames, 0);
    expect(s.jankyShare, 0);
  });

  test('the logger flushes a line with what it has gathered', () {
    final lines = <String>[];
    final logger = FrameTimingLogger(sink: lines.add);
    logger.flush();
    expect(lines, isEmpty, reason: 'nothing to say yet');
  });

  test(
    'logFrameTimings round-trips through the config JSON, off by default',
    () {
      expect(
        const GameConfig(worldWidth: 100, worldHeight: 100).logFrameTimings,
        isFalse,
      );
      final on = GameConfig.fromJson(
        const GameConfig(
          worldWidth: 100,
          worldHeight: 100,
          logFrameTimings: true,
        ).toJson(),
      );
      expect(on.logFrameTimings, isTrue);
    },
  );
}
