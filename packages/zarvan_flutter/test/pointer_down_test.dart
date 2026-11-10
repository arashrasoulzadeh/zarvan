
import 'package:flutter/material.dart' hide Velocity;
import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' hide Text;

void main() {
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
