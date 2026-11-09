import 'dart:ui' show Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart';

void main() {
  test('items at or above shakeFreeFromZ ignore the shake, the rest jolt', () {
    final camera = Camera(x: 90, y: 160)..zoom = 2;
    const size = Size(360, 640);
    final calm = camera.worldToScreen(10, 10, size);
    camera.shake(magnitude: 20, duration: 1, frequency: 30);
    camera.update(0.05);
    expect(camera.shakeOffset.dx != 0 || camera.shakeOffset.dy != 0, isTrue);

    expect(camera.worldToScreen(10, 10, size) != calm, isTrue, reason: 'game');
    camera.shakeFreeFromZ = 100;
    expect(
      camera.worldToScreen(10, 10, size, zIndex: 99) != calm,
      isTrue,
      reason: 'below the HUD still shakes',
    );
    expect(
      camera.worldToScreen(10, 10, size, zIndex: 100),
      calm,
      reason: 'the HUD stays put',
    );
  });
}
