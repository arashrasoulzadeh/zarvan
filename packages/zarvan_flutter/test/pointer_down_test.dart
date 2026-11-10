import 'package:flutter/material.dart' hide Velocity;
import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' hide Text;

void main() {
  sceneTests();
  testWidgets(
    'onWorldPointerDown fires on touch-down, before lift, in world coordinates',
    (tester) async {
      final world = World(width: 400, height: 300);
      registerCoreComponents(world);
      registerFlutterComponents(world);
      final downs = <Offset>[];
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 400,
              height: 300,
              child: EngineView(
                world: world,
                atlasRegistry: AtlasRegistry(),
                camera: Camera(),
                onWorldPointerDown: downs.add,
                onWorldTap: (_) => taps++,
              ),
            ),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(EngineView));
      final gesture = await tester.startGesture(center);
      expect(downs, hasLength(1));
      expect(taps, 0);
      expect(downs.single.dx, closeTo(0, 1));
      expect(downs.single.dy, closeTo(0, 1));
      await gesture.up();
      await tester.pump();
      expect(taps, 1);
      expect(downs, hasLength(1));
    },
  );

  testWidgets('no pointer-down callback adds no behaviour', (tester) async {
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
    await tester.tap(find.byType(EngineView));
  });
}

class _ProbeScene extends Scene {
  final downs = <(double, double)>[];
  @override
  Future<void> populate(
    World world,
    SceneController scenes,
    GameState state,
  ) async {}
  @override
  void handlePointerDown(
    World world,
    SceneController scenes,
    double worldX,
    double worldY,
  ) => downs.add((worldX, worldY));
}

void sceneTests() {
  test(
    'Scene.handlePointerDown takes plain doubles and defaults to a no-op',
    () {
      final s = _ProbeScene();
      s.handlePointerDown(World(width: 1, height: 1), SceneController(), 3, 4);
      expect(s.downs, [(3.0, 4.0)]);
    },
  );
}
