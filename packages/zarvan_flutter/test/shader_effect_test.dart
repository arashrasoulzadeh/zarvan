import 'package:flutter/material.dart' hide Velocity, Text;
import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart';

void main() {
  test('a ShaderEffect survives a JSON round trip', () {
    final fx = ShaderEffect(
      width: 30,
      height: 70,
      zIndex: 3,
      speed: 2,
      images: const ['sky', 'far'],
      blur: 0.05,
      intensity: 0.8,
      period: 7,
      rimArgb: 0xFF112233,
    );
    final back = ShaderEffect.fromJson(fx.toJson());
    expect(back.kind, ShaderEffect.portal);
    expect(back.width, 30);
    expect(back.height, 70);
    expect(back.zIndex, 3);
    expect(back.speed, 2);
    expect(back.images, ['sky', 'far']);
    expect(back.blur, 0.05);
    expect(back.intensity, 0.8);
    expect(back.period, 7);
    expect(back.rimArgb, 0xFF112233);
    expect(back.armArgb, fx.armArgb);
  });

  test('is registered so worlds serialise it', () {
    final w = World(width: 100, height: 100);
    registerCoreComponents(w);
    registerFlutterComponents(w);
    final e = w.spawn();
    w.componentsOf<Position>().set(e, Position(10, 10));
    w.componentsOf<ShaderEffect>().set(e, ShaderEffect(width: 5, height: 9));
    final json = w.toJson().toString();
    expect(json, contains('shaderEffect'));
  });

  testWidgets('an EngineView with a shine paints without error', (
    tester,
  ) async {
    final w = World(width: 180, height: 320);
    registerCoreComponents(w);
    registerFlutterComponents(w);
    final e = w.spawn();
    w.componentsOf<Position>().set(e, Position(90, 200));
    w.componentsOf<ShaderEffect>().set(
      e,
      ShaderEffect(kind: ShaderEffect.shine, width: 100, height: 30),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EngineView(
          world: w,
          atlasRegistry: AtlasRegistry(),
          camera: Camera(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an EngineView with a glow paints without error', (tester) async {
    final w = World(width: 180, height: 320);
    registerCoreComponents(w);
    registerFlutterComponents(w);
    final e = w.spawn();
    w.componentsOf<Position>().set(e, Position(90, 200));
    w.componentsOf<ShaderEffect>().set(
      e,
      ShaderEffect(kind: ShaderEffect.glow, width: 100, height: 40),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EngineView(
          world: w,
          atlasRegistry: AtlasRegistry(),
          camera: Camera(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an EngineView with a portal paints without error', (
    tester,
  ) async {
    final w = World(width: 180, height: 320);
    registerCoreComponents(w);
    registerFlutterComponents(w);
    final e = w.spawn();
    w.componentsOf<Position>().set(e, Position(90, 160));
    w.componentsOf<ShaderEffect>().set(e, ShaderEffect(width: 40, height: 80));
    await tester.pumpWidget(
      MaterialApp(
        home: EngineView(
          world: w,
          atlasRegistry: AtlasRegistry(),
          camera: Camera(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an EngineView with an orb paints without error', (
    tester,
  ) async {
    final w = World(width: 180, height: 320);
    registerCoreComponents(w);
    registerFlutterComponents(w);
    final e = w.spawn();
    w.componentsOf<Position>().set(e, Position(90, 160));
    w.componentsOf<ShaderEffect>().set(
      e,
      ShaderEffect(kind: ShaderEffect.orb, width: 50, height: 50),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: EngineView(
          world: w,
          atlasRegistry: AtlasRegistry(),
          camera: Camera(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });
}
