import 'dart:io';
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
      detail: 96,
      rimGlow: 0.4,
      saturation: 0,
      border: 0.04,
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
    expect(back.detail, 96);
    expect(back.rimGlow, 0.4);
    expect(back.saturation, 0);
    expect(back.border, 0.04);
    expect(
      ShaderEffect(width: 1, height: 1).border,
      0,
      reason: 'no frame unless asked for',
    );
    expect(
      ShaderEffect(width: 1, height: 1).detail,
      30,
      reason: 'chunky by default',
    );
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

  testWidgets('an EngineView with an orb paints without error', (tester) async {
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

  testWidgets('an EngineView with an aurora sky paints without error', (
    tester,
  ) async {
    final w = World(width: 180, height: 320);
    registerCoreComponents(w);
    registerFlutterComponents(w);
    final e = w.spawn();
    w.componentsOf<Position>().set(e, Position(90, 160));
    w.componentsOf<ShaderEffect>().set(
      e,
      ShaderEffect(kind: ShaderEffect.aurora, width: 180, height: 320),
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

  testWidgets('an EngineView with an ornate frame paints without error', (
    tester,
  ) async {
    final w = World(width: 180, height: 320);
    registerCoreComponents(w);
    registerFlutterComponents(w);
    final e = w.spawn();
    w.componentsOf<Position>().set(e, Position(90, 160));
    w.componentsOf<ShaderEffect>().set(
      e,
      ShaderEffect(
        kind: ShaderEffect.ornate,
        width: 160,
        height: 90,
        border: 14,
        detail: 9,
        rimGlow: 14,
        intensity: 1,
        saturation: 0.4,
        coreArgb: 0xFFD9B97B,
      ),
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

  testWidgets('an EngineView with a portrait paints without error', (
    tester,
  ) async {
    final w = World(width: 180, height: 320);
    registerCoreComponents(w);
    registerFlutterComponents(w);
    final e = w.spawn();
    w.componentsOf<Position>().set(e, Position(90, 160));
    w.componentsOf<ShaderEffect>().set(
      e,
      ShaderEffect(
        kind: ShaderEffect.portrait,
        width: 80,
        height: 100,
        params: const [22, 1, 0, 0],
      ),
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

  testWidgets('an EngineView with a veil paints without error', (tester) async {
    final w = World(width: 180, height: 320);
    registerCoreComponents(w);
    registerFlutterComponents(w);
    final e = w.spawn();
    w.componentsOf<Position>().set(e, Position(90, 160));
    w.componentsOf<ShaderEffect>().set(
      e,
      ShaderEffect(
        kind: ShaderEffect.veil,
        width: 80,
        height: 100,
        params: const [0.5, 0.5, 0.5],
      ),
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

  testWidgets('an EngineView with a ink paints without error', (tester) async {
    final w = World(width: 180, height: 320);
    registerCoreComponents(w);
    registerFlutterComponents(w);
    final e = w.spawn();
    w.componentsOf<Position>().set(e, Position(90, 160));
    w.componentsOf<ShaderEffect>().set(
      e,
      ShaderEffect(
        kind: ShaderEffect.ink,
        width: 80,
        height: 100,
        params: const [0.5, 0.5, 0.5],
      ),
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

  testWidgets('an EngineView with a kashi paints without error', (
    tester,
  ) async {
    final w = World(width: 180, height: 320);
    registerCoreComponents(w);
    registerFlutterComponents(w);
    final e = w.spawn();
    w.componentsOf<Position>().set(e, Position(90, 160));
    w.componentsOf<ShaderEffect>().set(
      e,
      ShaderEffect(
        kind: ShaderEffect.kashi,
        width: 80,
        height: 100,
        params: const [0.5, 0.5, 0.5],
      ),
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

  testWidgets('an EngineView with a curtain paints without error', (
    tester,
  ) async {
    final w = World(width: 180, height: 320);
    registerCoreComponents(w);
    registerFlutterComponents(w);
    final e = w.spawn();
    w.componentsOf<Position>().set(e, Position(90, 160));
    w.componentsOf<ShaderEffect>().set(
      e,
      ShaderEffect(
        kind: ShaderEffect.curtain,
        width: 80,
        height: 100,
        params: const [0.5, 0.5, 0.5],
      ),
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

  testWidgets('an EngineView with a seal paints without error', (tester) async {
    final w = World(width: 180, height: 320);
    registerCoreComponents(w);
    registerFlutterComponents(w);
    final e = w.spawn();
    w.componentsOf<Position>().set(e, Position(90, 160));
    w.componentsOf<ShaderEffect>().set(
      e,
      ShaderEffect(
        kind: ShaderEffect.seal,
        width: 80,
        height: 100,
        params: const [1],
      ),
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

  testWidgets('an EngineView with a dust paints without error', (tester) async {
    final w = World(width: 180, height: 320);
    registerCoreComponents(w);
    registerFlutterComponents(w);
    final e = w.spawn();
    w.componentsOf<Position>().set(e, Position(90, 160));
    w.componentsOf<ShaderEffect>().set(
      e,
      ShaderEffect(
        kind: ShaderEffect.dust,
        width: 80,
        height: 100,
        params: const [1],
      ),
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

  testWidgets('an EngineView with a mark paints without error', (tester) async {
    final w = World(width: 180, height: 320);
    registerCoreComponents(w);
    registerFlutterComponents(w);
    final e = w.spawn();
    w.componentsOf<Position>().set(e, Position(90, 160));
    w.componentsOf<ShaderEffect>().set(
      e,
      ShaderEffect(
        kind: ShaderEffect.mark,
        width: 80,
        height: 100,
        params: const [1],
      ),
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

  test('params survive a JSON round trip', () {
    final fx = ShaderEffect(
      kind: ShaderEffect.portrait,
      width: 1,
      height: 1,
      params: const [30, 0.8, 2, 4],
    );
    expect(ShaderEffect.fromJson(fx.toJson()).params, [30, 0.8, 2, 4]);
    expect(ShaderEffect(width: 1, height: 1).params, isEmpty);
  });

  test('the portrait and veil shaders are bundled and listed', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final f in [
      'portrait',
      'veil',
      'ink',
      'kashi',
      'seal',
      'curtain',
      'dust',
      'mark',
    ]) {
      expect(File('shaders/$f.frag').existsSync(), isTrue);
      expect(pubspec, contains('shaders/$f.frag'));
    }
  });

  test('the ornate shader is bundled and listed in the pubspec', () {
    expect(File('shaders/ornate.frag').existsSync(), isTrue);
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('shaders/ornate.frag'),
    );
  });

  test('the aurora shader is bundled and listed in the pubspec', () {
    expect(File('shaders/aurora.frag').existsSync(), isTrue);
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('shaders/aurora.frag'),
    );
  });
}
