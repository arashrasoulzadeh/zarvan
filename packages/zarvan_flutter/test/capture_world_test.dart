import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' hide Text;

World _world() {
  final world = World(width: 200, height: 100);
  registerCoreComponents(world);
  registerFlutterComponents(world);
  final e = world.spawn();
  world.componentsOf<Position>().set(e, Position(0, 0));
  world.componentsOf<Shape>().set(e, Shape(width: 40, colorArgb: 0xFFFF0000));
  return world;
}

void main() {
  testWidgets('capture returns a PNG of the requested size', (tester) async {
    await tester.runAsync(() async {
      final bytes = await captureWorldToPng(_world(), width: 200, height: 100);
      expect(bytes.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      expect(image.width, 200);
      expect(image.height, 100);
    });
  });

  testWidgets('capture matches the background and a shape pixel', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final bytes = await captureWorldToPng(
        _world(),
        width: 200,
        height: 100,
        backgroundColor: const ui.Color(0xFF0000FF),
      );
      final codec = await ui.instantiateImageCodec(bytes);
      final image = (await codec.getNextFrame()).image;
      final data = (await image.toByteData())!;
      int px(int x, int y) => (y * 200 + x) * 4;
      // Background corner is blue.
      expect(data.getUint8(px(2, 2)), 0);
      expect(data.getUint8(px(2, 2) + 2), 255);
      // Shape centre (world 0,0 -> image centre) is red.
      expect(data.getUint8(px(100, 50)), 255);
      expect(data.getUint8(px(100, 50) + 2), 0);
    });
  });

  testWidgets('capture does not mutate or advance the world', (tester) async {
    final world = _world();
    final before = world.toJson();
    await tester.runAsync(
      () => captureWorldToPng(world, width: 200, height: 100),
    );
    expect(world.toJson(), before);
    expect(world.tick, 0);
  });
}
