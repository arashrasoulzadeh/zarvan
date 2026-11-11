import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' hide Text;

void main() => runGame(ShowcaseGame(Uri.base.queryParameters['demo'] ?? 'platformer'));

class ShowcaseGame extends Game {
  ShowcaseGame(this.demo);
  final String demo;

  @override
  GameConfig get config => GameConfig(
        title: 'ZARVAN Showcase · $demo',
        worldWidth: 800,
        worldHeight: 480,
        backgroundColor: const Color(0xFF101216),
        fixedTimestepSeconds: 1 / 60,
        onScreenControls: OnScreenControlsMode.off,
      );

  @override
  SplashConfig get splash => const SplashConfig(
        title: 'ZARVAN live showcase',
        backgroundColor: Color(0xFF101216),
        minDuration: Duration(milliseconds: 900),
      );

  @override
  Scene createInitialScene() => ShowcaseScene(demo);
}

class ShowcaseScene extends Scene {
  ShowcaseScene(this.demo);
  final String demo;

  @override
  Future<void> populate(World world, SceneController scenes, GameState state) async {
    registerCoreComponents(world);
    registerFlutterComponents(world);
    world.addSystem(_MotionSystem());
    world.addSystem(_OrbitSystem());
    _buildDemo(world, demo);
  }

  void _buildDemo(World world, String demo) {
    switch (demo) {
      case 'strategy':
        _grid(world, 8, 6);
        _unit(world, 160, 300, 0xFFE6B86A, 28);
        _unit(world, 560, 150, 0xFFDE6C65, 28);
        break;
      case 'agent':
        _agentLoop(world);
        break;
      case 'multiplayer':
        _network(world);
        break;
      case 'idle':
        _bars(world);
        break;
      case 'ecs':
        _orbiters(world);
        break;
      case 'json':
        _jsonState(world);
        break;
      case 'fog':
        _fog(world);
        break;
      case 'benchmark':
        _benchmark(world);
        break;
      case 'replay':
        _replay(world);
        break;
      default:
        _platformer(world);
    }
  }

  EntityId _shape(World world, double x, double y, int color, {double size = 24, ShapeKind kind = ShapeKind.circle}) {
    final id = world.spawn();
    world.setComponent(id, Position(x, y));
    world.setComponent(id, Shape(kind: kind, width: size, height: size, cornerRadius: 6, colorArgb: color));
    return id;
  }

  void _platformer(World w) {
    _shape(w, 125, 290, 0xFFE6B86A, size: 30);
    _shape(w, 320, 330, 0xFFDE6C65, size: 26);
    for (var i = 0; i < 10; i++) _shape(w, 40 + i * 80, 410, 0xFF526B91, size: 55, kind: ShapeKind.roundedRect);
    for (var i = 0; i < 4; i++) _shape(w, 220 + i * 42, 260 - i * 28, 0xFFC8A66A, size: 12);
  }

  void _grid(World w, int cols, int rows) {
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final color = (x + y).isEven ? 0xFF283548 : 0xFF202B3A;
        _shape(w, 180 + x * 56, 90 + y * 56, color, size: 48, kind: ShapeKind.roundedRect);
      }
    }
  }

  void _agentLoop(World w) {
    _shape(w, 150, 240, 0xFFE6B86A, size: 84, kind: ShapeKind.ring);
    _shape(w, 400, 240, 0xFF526B91, size: 84, kind: ShapeKind.ring);
    _shape(w, 650, 240, 0xFFDE6C65, size: 84, kind: ShapeKind.ring);
    for (var i = 0; i < 6; i++) _shape(w, 210 + i * 78, 240, 0xFFC8A66A, size: 10);
  }

  void _network(World w) {
    _shape(w, 400, 240, 0xFFE6B86A, size: 100, kind: ShapeKind.ring);
    _shape(w, 150, 160, 0xFF526B91, size: 70);
    _shape(w, 650, 160, 0xFF526B91, size: 70);
    _shape(w, 150, 320, 0xFFDE6C65, size: 70);
    _shape(w, 650, 320, 0xFFDE6C65, size: 70);
  }

  void _bars(World w) {
    for (var i = 0; i < 8; i++) _shape(w, 130 + i * 78, 390 - (i % 4) * 48, 0xFFC8A66A, size: 56, kind: ShapeKind.roundedRect);
  }

  void _orbiters(World w) {
    for (var i = 0; i < 18; i++) _shape(w, 400, 240, 0xFF526B91, size: 12 + (i % 3) * 4);
  }

  void _jsonState(World w) {
    _shape(w, 400, 240, 0xFF9CCB9B, size: 260, kind: ShapeKind.roundedRect);
    for (var i = 0; i < 5; i++) _shape(w, 300 + i * 50, 150 + i * 45, 0xFF17191D, size: 12);
  }

  void _fog(World w) {
    for (var y = 0; y < 5; y++) {
      for (var x = 0; x < 8; x++) {
        final clear = (x - 3) * (x - 3) + (y - 2) * (y - 2) < 7;
        _shape(w, 190 + x * 56, 110 + y * 56, clear ? 0xFF526B91 : 0xFF17191D, size: 50, kind: ShapeKind.roundedRect);
      }
    }
    _shape(w, 358, 222, 0xFFE6B86A, size: 24);
  }

  void _benchmark(World w) {
    for (var i = 0; i < 9; i++) _shape(w, 120 + i * 70, 400 - (i + 2) * 28, 0xFFC8A66A, size: 42, kind: ShapeKind.roundedRect);
  }

  void _replay(World w) {
    for (var i = 0; i < 8; i++) _shape(w, 120 + i * 80, 240, i.isEven ? 0xFFE6B86A : 0xFF526B91, size: 28);
  }

  void _unit(World w, double x, double y, int color, double size) => _shape(w, x, y, color, size: size);
}

class _MotionSystem implements System {
  @override
  String get name => 'showcase_motion';

  @override
  void update(World world, double dt) {
    for (final id in world.entities.all) {
      final p = world.getComponent<Position>(id);
      if (p == null) continue;
      if (p.x > 820) p.x = -20;
      p.x += 8 * dt;
    }
  }
}

class _OrbitSystem implements System {
  double time = 0;

  @override
  String get name => 'showcase_orbit';

  @override
  void update(World world, double dt) {
    time += dt;
    var i = 0;
    for (final id in world.entities.all) {
      final p = world.getComponent<Position>(id);
      if (p == null) continue;
      if (i++ % 3 == 0) {
        p.x += math.sin(time + i) * dt * 20;
        p.y += math.cos(time + i) * dt * 20;
      }
    }
  }
}
