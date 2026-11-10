import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' hide Text;
import 'package:flutter/material.dart' hide Velocity;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EngineView renders and steps the world without error', (
    tester,
  ) async {
    final world = World(width: 400, height: 300);
    registerCoreComponents(world);
    registerFlutterComponents(world);
    world.addSystem(MovementSystem());

    final id = world.spawn();
    world.componentsOf<Position>().set(id, Position(50, 50));
    world.componentsOf<Velocity>().set(id, Velocity(10, 0));

    await tester.pumpWidget(
      MaterialApp(
        home: EngineView(
          world: world,
          atlasRegistry: AtlasRegistry(),
          camera: Camera(),
        ),
      ),
    );

    expect(world.tick, 0);
    // The ticker's first callback only establishes a baseline elapsed time
    // (dt can't be computed with no prior tick), so a second pump is
    // needed before world.step actually runs.
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(find.byType(EngineView), findsOneWidget);
    expect(world.tick, greaterThan(0));
  });

  testWidgets(
    'showFpsOverlay renders an fps readout and recomputes over many ticks',
    (tester) async {
      final world = World(width: 400, height: 300);
      registerCoreComponents(world);
      registerFlutterComponents(world);

      await tester.pumpWidget(
        MaterialApp(
          home: EngineView(
            world: world,
            atlasRegistry: AtlasRegistry(),
            camera: Camera(),
            showFpsOverlay: true,
          ),
        ),
      );

      // >30 ticks so the rolling _recentDts window actually evicts its
      // oldest entry (the branch that keeps it capped at 30).
      for (var i = 0; i < 35; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      final text = tester.widget<Text>(find.textContaining('fps:')).data!;
      expect(text, contains('fps:'));
      expect(text, contains('tick:'));
      expect(text, contains('entities:'));
      expect(text, contains('sprites:'));
      expect(text, contains('particles:'));
    },
  );

  testWidgets(
    'showPerformanceOverlay renders Flutter\'s own raster/UI-thread bar graphs',
    (tester) async {
      final world = World(width: 400, height: 300);
      registerCoreComponents(world);
      registerFlutterComponents(world);

      await tester.pumpWidget(
        MaterialApp(
          home: EngineView(
            world: world,
            atlasRegistry: AtlasRegistry(),
            camera: Camera(),
            showPerformanceOverlay: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.byType(PerformanceOverlay), findsOneWidget);
      expect(
        find.byType(EngineView),
        findsOneWidget,
        reason:
            'the gameplay content underneath must still render, not get replaced',
      );
    },
  );

  testWidgets(
    'showPerformanceOverlay off by default -- no extra widget, no extra cost',
    (tester) async {
      final world = World(width: 400, height: 300);
      registerCoreComponents(world);
      registerFlutterComponents(world);

      await tester.pumpWidget(
        MaterialApp(
          home: EngineView(
            world: world,
            atlasRegistry: AtlasRegistry(),
            camera: Camera(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.byType(PerformanceOverlay), findsNothing);
    },
  );

  testWidgets(
    'cameraFollowEntity moves the camera toward that entity\'s Position',
    (tester) async {
      final world = World(width: 2000, height: 2000);
      registerCoreComponents(world);
      registerFlutterComponents(world);

      final player = world.spawn();
      world.componentsOf<Position>().set(player, Position(1000, 1000));
      final camera = Camera(x: 0, y: 0);

      await tester.pumpWidget(
        MaterialApp(
          home: EngineView(
            world: world,
            atlasRegistry: AtlasRegistry(),
            camera: camera,
            cameraFollowEntity: player,
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      expect(camera.x, greaterThan(0));
    },
  );

  testWidgets(
    'a keyboard-bound InputController receives key events through EngineView',
    (tester) async {
      final world = World(width: 400, height: 300);
      registerCoreComponents(world);
      registerFlutterComponents(world);
      final controller = InputController();

      await tester.pumpWidget(
        MaterialApp(
          home: EngineView(
            world: world,
            atlasRegistry: AtlasRegistry(),
            camera: Camera(),
            inputController: controller,
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      expect(controller.state.isPressed('left'), isTrue);

      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      expect(controller.state.isPressed('left'), isFalse);
    },
  );

  testWidgets(
    'onWorldTap receives the tap position converted to world coordinates',
    (tester) async {
      final world = World(width: 400, height: 300);
      registerCoreComponents(world);
      registerFlutterComponents(world);
      final camera = Camera(x: 0, y: 0, zoom: 1);
      Offset? tapped;

      await tester.pumpWidget(
        MaterialApp(
          home: EngineView(
            world: world,
            atlasRegistry: AtlasRegistry(),
            camera: camera,
            onWorldTap: (worldPosition) => tapped = worldPosition,
          ),
        ),
      );
      await tester.pump();

      // The test surface is 800x600 by default, so its center (400,300)
      // sits over world origin (0,0) when the camera is centered there.
      await tester.tapAt(const Offset(400, 300));
      await tester.pump();

      expect(tapped, isNotNull);
      expect(tapped!.dx, closeTo(0, 0.01));
      expect(tapped!.dy, closeTo(0, 0.01));
    },
  );

  testWidgets('with no onWorldTap, a tap is a no-op rather than throwing', (
    tester,
  ) async {
    final world = World(width: 400, height: 300);
    registerCoreComponents(world);
    registerFlutterComponents(world);

    await tester.pumpWidget(
      MaterialApp(
        home: EngineView(
          world: world,
          atlasRegistry: AtlasRegistry(),
          camera: Camera(),
        ),
      ),
    );
    await tester.pump();

    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
  });

  group('onWorldDrag', () {
    testWidgets('follows a drag live, then reports the lift', (tester) async {
      final world = World(width: 400, height: 300);
      registerCoreComponents(world);
      registerFlutterComponents(world);
      final events = <(Offset, bool)>[];
      await tester.pumpWidget(
        MaterialApp(
          home: EngineView(
            world: world,
            atlasRegistry: AtlasRegistry(),
            camera: Camera(x: 0, y: 0, zoom: 1),
            onWorldDrag: (start, delta, ended) => events.add((delta, ended)),
          ),
        ),
      );
      await tester.pump();
      await tester.dragFrom(const Offset(400, 300), const Offset(-120, 0));
      await tester.pump();

      expect(events.length, greaterThan(1), reason: 'moves, then the lift');
      expect(events.where((e) => e.$2), hasLength(1));
      expect(events.last.$2, isTrue);
      expect(events.last.$1.dx, closeTo(-120, 0.5));
      expect(events.first.$1.dx.abs(), lessThan(events.last.$1.dx.abs()));
    });

    testWidgets('keeps following when the view rebuilds mid-drag', (
      tester,
    ) async {
      final world = World(width: 400, height: 300);
      registerCoreComponents(world);
      registerFlutterComponents(world);
      final events = <(Offset, bool)>[];
      Widget view() => MaterialApp(
        home: EngineView(
          world: world,
          atlasRegistry: AtlasRegistry(),
          camera: Camera(x: 0, y: 0, zoom: 1),
          onWorldDrag: (start, delta, ended) => events.add((delta, ended)),
        ),
      );
      await tester.pumpWidget(view());
      final g = await tester.startGesture(const Offset(400, 300));
      await g.moveBy(const Offset(-40, 0));
      // The game rebuilds the view every frame, with fresh callbacks.
      await tester.pumpWidget(view());
      await g.moveBy(const Offset(-40, 0));
      await tester.pumpWidget(view());
      await g.up();
      await tester.pump();

      expect(events.last.$2, isTrue);
      expect(events.last.$1.dx, closeTo(-80, 1));
    });
  });
}
