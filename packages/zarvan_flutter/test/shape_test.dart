import 'dart:math' show cos, sin;
import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Velocity;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' hide Text;

World _world() {
  final world = World(width: 400, height: 300);
  registerCoreComponents(world);
  registerFlutterComponents(world);
  return world;
}

void _spawn(World world, double x, double y, Shape shape) {
  final e = world.spawn();
  world.componentsOf<Position>().set(e, Position(x, y));
  world.componentsOf<Shape>().set(e, shape);
}

/// Renders [world] at 400x300 and returns a pixel reader (screen coords).
Future<Color Function(int, int)> _render(
  WidgetTester tester,
  World world, {
  Camera? camera,
}) async {
  final key = UniqueKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: 400,
          height: 300,
          child: RepaintBoundary(
            key: key,
            child: EngineView(
              world: world,
              atlasRegistry: AtlasRegistry(),
              camera: camera ?? Camera(),
              backgroundColor: const Color(0xFF000000),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 16));
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final data = (await tester.runAsync(() async {
    final image = await boundary.toImage();
    return image.toByteData(format: ui.ImageByteFormat.rawRgba);
  }))!;
  return (x, y) {
    final o = (y * 400 + x) * 4;
    return Color.fromARGB(
      data.getUint8(o + 3),
      data.getUint8(o),
      data.getUint8(o + 1),
      data.getUint8(o + 2),
    );
  };
}

const _red = 0xFFFF0000;
bool _isRed(Color c) => c.r > 0.9 && c.g < 0.1 && c.b < 0.1;
bool _isBlack(Color c) => c.r < 0.1 && c.g < 0.1 && c.b < 0.1;

void main() {
  group('Shape data', () {
    test('toJson/fromJson round-trips every field and kind', () {
      for (final kind in ShapeKind.values) {
        final s = Shape(
          kind: kind,
          width: 31,
          height: 17,
          cornerRadius: 5,
          strokeWidth: 3,
          colorArgb: 0xFF123456,
          dashLength: 6,
          gapLength: 2,
          screenSpace: true,
          alpha: 0.5,
          zIndex: 9,
        );
        final r = Shape.fromJson(s.toJson());
        expect(r.toJson(), s.toJson());
        expect(r.kind, kind);
      }
    });

    test('fromJson falls back to defaults and to circle for unknown kind', () {
      final r = Shape.fromJson({'kind': 'blob'});
      expect(r.kind, ShapeKind.circle);
      expect(r.width, 40);
      expect(r.alpha, 1);
      expect(r.screenSpace, isFalse);
    });

    test('a world with a Shape survives toJson -> applyPatch unchanged', () {
      final world = _world();
      _spawn(
        world,
        10,
        20,
        Shape(
          kind: ShapeKind.ring,
          strokeWidth: 4,
          dashLength: 5,
          gapLength: 3,
        ),
      );
      final json = world.toJson();

      final fresh = _world()..spawn();
      fresh.applyPatch(json);
      expect(fresh.toJson(), json);
      final shapes = fresh.componentsOf<Shape>();
      expect(shapes.length, 1);
      expect(shapes.denseAt(0).kind, ShapeKind.ring);
      expect(shapes.denseAt(0).dashLength, 5);
    });
  });

  group('Shape rendering', () {
    testWidgets('filled circle colours its pixels and nothing outside', (
      tester,
    ) async {
      final world = _world();
      _spawn(world, 0, 0, Shape(width: 60, colorArgb: _red));
      final px = await _render(tester, world);
      expect(_isRed(px(200, 150)), isTrue);
      expect(_isRed(px(225, 150)), isTrue);
      expect(_isBlack(px(240, 150)), isTrue);
      // Corner of the bounding box is outside the circle.
      expect(_isBlack(px(228, 122)), isTrue);
    });

    testWidgets('alpha scales the colour', (tester) async {
      final world = _world();
      _spawn(world, 0, 0, Shape(width: 60, colorArgb: _red, alpha: 0.5));
      final px = await _render(tester, world);
      final c = px(200, 150);
      expect(c.r, closeTo(0.5, 0.05));
    });

    testWidgets('rounded rect: filled, outlined and transparent corner', (
      tester,
    ) async {
      final filled = _world();
      _spawn(
        filled,
        0,
        0,
        Shape(
          kind: ShapeKind.roundedRect,
          width: 100,
          height: 60,
          cornerRadius: 20,
          colorArgb: _red,
        ),
      );
      final f = await _render(tester, filled);
      expect(_isRed(f(200, 150)), isTrue);
      expect(_isRed(f(160, 150)), isTrue);
      // Extreme corner pixel lies outside the 20px radius.
      expect(_isBlack(f(151, 121)), isTrue);

      final outlined = _world();
      _spawn(
        outlined,
        0,
        0,
        Shape(
          kind: ShapeKind.roundedRect,
          width: 100,
          height: 60,
          cornerRadius: 20,
          strokeWidth: 6,
          colorArgb: _red,
        ),
      );
      final o = await _render(tester, outlined);
      expect(_isRed(o(201, 122)), isTrue); // top edge
      expect(_isBlack(o(200, 150)), isTrue); // hollow centre
    });

    testWidgets('ring keeps a transparent centre; dashes leave gaps', (
      tester,
    ) async {
      final solid = _world();
      _spawn(
        solid,
        0,
        0,
        Shape(
          kind: ShapeKind.ring,
          width: 100,
          strokeWidth: 8,
          colorArgb: _red,
        ),
      );
      final s = await _render(tester, solid);
      expect(_isBlack(s(200, 150)), isTrue);
      expect(_isRed(s(200 + 46, 150)), isTrue);

      final dashed = _world();
      _spawn(
        dashed,
        0,
        0,
        Shape(
          kind: ShapeKind.ring,
          width: 100,
          strokeWidth: 8,
          colorArgb: _red,
          dashLength: 10,
          gapLength: 10,
        ),
      );
      final d = await _render(tester, dashed);
      // Walk the ring's circumference: some samples red, some black.
      var red = 0, black = 0;
      for (var a = 0; a < 360; a += 3) {
        final rad = a * 3.14159265 / 180;
        final x = (200 + 46 * cos(rad)).round();
        final y = (150 + 46 * sin(rad)).round();
        _isRed(d(x, y)) ? red++ : black++;
      }
      expect(red, greaterThan(20));
      expect(black, greaterThan(20));
    });

    testWidgets('moving the camera does not move a screen-space shape', (
      tester,
    ) async {
      Future<Color Function(int, int)> at(double camX) {
        final world = _world();
        _spawn(
          world,
          100,
          80,
          Shape(width: 30, colorArgb: _red, screenSpace: true),
        );
        return _render(tester, world, camera: Camera(x: camX));
      }

      final a = await at(0);
      expect(_isRed(a(100, 80)), isTrue);
      final b = await at(300);
      expect(_isRed(b(100, 80)), isTrue);

      // Contrast: the same shape in world space does move.
      final world = _world();
      _spawn(world, 0, 0, Shape(width: 30, colorArgb: _red));
      final w = await _render(tester, world, camera: Camera(x: 300));
      expect(_isBlack(w(200, 150)), isTrue);
    });

    testWidgets('z-index orders shapes', (tester) async {
      final world = _world();
      _spawn(world, 0, 0, Shape(width: 60, colorArgb: _red, zIndex: 1));
      _spawn(world, 0, 0, Shape(width: 60, colorArgb: 0xFF0000FF, zIndex: 0));
      final px = await _render(tester, world);
      expect(_isRed(px(200, 150)), isTrue);
    });
  });
}
