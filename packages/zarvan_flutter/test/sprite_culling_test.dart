import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart';

void main() {
  const view = Size(800, 600);

  test('a sprite inside the view is kept', () {
    expect(spriteOnScreen(const Offset(400, 300), 32, 32, 1, view, 0), isTrue);
  });

  test('a sprite far outside is dropped', () {
    expect(
      spriteOnScreen(const Offset(-500, 300), 32, 32, 1, view, 0),
      isFalse,
    );
    expect(
      spriteOnScreen(const Offset(400, 2000), 32, 32, 1, view, 0),
      isFalse,
    );
    expect(
      spriteOnScreen(const Offset(5000, 300), 32, 32, 1, view, 0),
      isFalse,
    );
  });

  test('a large sprite whose centre is off-screen but body shows is kept', () {
    expect(
      spriteOnScreen(const Offset(-100, 300), 400, 400, 1, view, 0),
      isTrue,
    );
  });

  test('scale grows the reach', () {
    const c = Offset(-100, 300);
    expect(spriteOnScreen(c, 32, 32, 1, view, 0), isFalse);
    expect(spriteOnScreen(c, 32, 32, 10, view, 0), isTrue);
  });

  test('padding keeps a sprite just past the edge', () {
    const c = Offset(-60, 300);
    expect(spriteOnScreen(c, 32, 32, 1, view, 0), isFalse);
    expect(spriteOnScreen(c, 32, 32, 1, view, 96), isTrue);
  });

  test('a rotated sprite is never dropped while a corner could show', () {
    // Half-diagonal of 100x100 is ~70.7: a corner can reach 70 px from the
    // centre at any angle, so centre -60 must be kept.
    expect(
      spriteOnScreen(const Offset(-60, 300), 100, 100, 1, view, 0),
      isTrue,
    );
  });
}
