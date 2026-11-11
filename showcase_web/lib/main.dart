import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text;
import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' hide Text;
import 'package:zarvan_flutter/src/rendering/text.dart' as ztext;
import 'package:zarvan_platformer/zarvan_platformer.dart';
import 'package:zarvan_strategy/zarvan_strategy.dart';

void main() => runGame(ShowcaseGame(Uri.base.queryParameters['demo'] ?? 'platformer'));

class ShowcaseGame extends Game {
  ShowcaseGame(this.demo);
  final String demo;
  final InputController input = InputController();

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
  Scene createInitialScene() => ShowcaseScene(demo, input);

  @override
  InputController createInputController() => input;
}

class ShowcaseScene extends Scene {
  ShowcaseScene(this.demo, this.input);
  final String demo;
  final InputController input;

  @override
  Future<void> populate(World world, SceneController scenes, GameState state) async {
    registerCoreComponents(world);
    registerFlutterComponents(world);
    if (!{'platformer', 'strategy', 'agent', 'idle'}.contains(demo)) {
      world.addSystem(_MotionSystem());
      world.addSystem(_OrbitSystem());
    }
    _buildDemo(world, demo);
    _hud(world, demo);
  }

  void _hud(World world, String mode) {
    const titles = {
      'platformer': ('PLATFORMER PLAYTEST', 'Arrow keys / Space · gravity · patrol AI · collision'),
      'strategy': ('TURN-BASED STRATEGY', 'Red vs Blue · fog of war · action points · AI turn'),
      'agent': ('AGENT AUTHORITY LOOP', 'Observe → propose → validate → apply'),
      'multiplayer': ('NETWORK TOPOLOGY', 'Host owns state · clients submit commands'),
      'idle': ('IDLE ECONOMY', 'Generators · growth curves · offline progression'),
      'ecs': ('ECS WORLD STEP', 'Entities + components + ordered systems'),
      'json': ('WORLD SNAPSHOT', 'Serializable state for save, replay, and agents'),
      'fog': ('FOG OF WAR', 'Visibility is simulation state, not renderer state'),
      'benchmark': ('PROFILER VIEW', 'Measure the simulation before optimizing'),
      'replay': ('DETERMINISTIC REPLAY', 'Same commands + seed → comparable world'),
    };
    final copy = titles[mode] ?? titles['platformer']!;
    final id = world.spawn();
    world.setComponent(id, Position(24, 24));
    world.setComponent(id, ztext.Text(copy.$1, fontSize: 20, colorArgb: 0xFFFFFFFF, screenSpace: true, align: ztext.TextAlignment.left, zIndex: 100));
    final detail = world.spawn();
    world.setComponent(detail, Position(24, 52));
    world.setComponent(detail, ztext.Text(copy.$2, fontSize: 11, colorArgb: 0xFFC8A66A, screenSpace: true, align: ztext.TextAlignment.left, zIndex: 100));
  }

  void _buildDemo(World world, String demo) {
    switch (demo) {
      case 'strategy':
        _strategy(world);
        break;
      case 'agent':
        _agentLoop(world);
        break;
      case 'idle':
        _idle(world);
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
    final player = spawnPlayer(w, x: 120, y: 280, input: input.state, jumpSpeed: 420, maxHealth: 100);
    w.componentsOf<Shape>().set(player, Shape(width: 30, height: 30, colorArgb: 0xFFE6B86A, cornerRadius: 8, kind: ShapeKind.roundedRect));
    final behaviors = BehaviorRegistry();
    behaviors.register('patrol', PatrolBehavior(minX: 300, maxX: 520, speed: 45));
    final enemy = spawnEnemy(w, x: 410, y: 340, behaviorId: 'patrol', affectedByGravity: true, maxHealth: 30);
    w.componentsOf<Shape>().set(enemy, Shape(width: 26, height: 26, colorArgb: 0xFFDE6C65, cornerRadius: 8, kind: ShapeKind.roundedRect));
    final map = TileMap(tileWidth: 40, tileHeight: 40, cols: 20, rows: 12, tiles: List.generate(240, (i) => i >= 220 ? 1 : 0), solidTileIds: {1});
    final ground = w.spawn();
    w.setComponent(ground, map);
    installPlatformerSystems(w, player: player, behaviors: behaviors, includeAnimation: false);
    for (var i = 0; i < 4; i++) _shape(w, 220 + i * 42, 250 - i * 28, 0xFFC8A66A, size: 12);
  }

  void _grid(World w, int cols, int rows) {
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final color = (x + y).isEven ? 0xFF283548 : 0xFF202B3A;
        _shape(w, 180 + x * 56, 90 + y * 56, color, size: 48, kind: ShapeKind.roundedRect);
      }
    }
  }

  void _strategy(World w) {
    const cell = 56.0;
    final nav = GridNavigator(cols: 10, rows: 7, terrainCost: (col, row) => (col == 4 && row > 1 && row < 6) ? null : 1);
    installStrategySystems(w, navigator: nav, cellSize: cell, fog: true, aiTeams: {'blue': AggressiveAI()});
    final redA = spawnStrategyUnit(w, team: 'red', col: 1, row: 5, cellSize: cell, maxHp: 12, attack: 5, actionPoints: 4, visionRange: 4);
    final redB = spawnStrategyUnit(w, team: 'red', col: 2, row: 5, cellSize: cell, maxHp: 10, attack: 3, actionPoints: 3, visionRange: 4);
    final blueA = spawnStrategyUnit(w, team: 'blue', col: 8, row: 1, cellSize: cell, maxHp: 10, attack: 4, actionPoints: 3, visionRange: 4);
    final blueB = spawnStrategyUnit(w, team: 'blue', col: 7, row: 1, cellSize: cell, maxHp: 10, attack: 3, actionPoints: 3, visionRange: 4);
    w.componentsOf<Shape>().set(redA, Shape(width: 28, colorArgb: 0xFFE6B86A));
    w.componentsOf<Shape>().set(redB, Shape(width: 24, colorArgb: 0xFFE6B86A));
    w.componentsOf<Shape>().set(blueA, Shape(width: 28, colorArgb: 0xFFDE6C65));
    w.componentsOf<Shape>().set(blueB, Shape(width: 24, colorArgb: 0xFFDE6C65));
    startTurnBasedGame(w, ['red', 'blue']);
  }

  void _agentLoop(World w) {
    final agent = _shape(w, 120, 240, 0xFFE6B86A, size: 44, kind: ShapeKind.roundedRect);
    w.componentsOf<Velocity>().set(agent, Velocity());
    final target = _shape(w, 650, 240, 0xFFDE6C65, size: 64, kind: ShapeKind.ring);
    final behaviors = BehaviorRegistry()..register('seek_target', _SeekBehavior(target));
    w.componentsOf<AIState>().set(agent, AIState('seek_target'));
    w.addSystem(AISystem(behaviors));
    w.addSystem(MovementSystem());
    for (var i = 0; i < 5; i++) _shape(w, 220 + i * 78, 240, 0xFFC8A66A, size: 8);
  }

  void _network(World w) {
    _shape(w, 400, 240, 0xFFE6B86A, size: 100, kind: ShapeKind.ring);
    _shape(w, 150, 160, 0xFF526B91, size: 70);
    _shape(w, 650, 160, 0xFF526B91, size: 70);
    _shape(w, 150, 320, 0xFFDE6C65, size: 70);
    _shape(w, 650, 320, 0xFFDE6C65, size: 70);
  }

  void _idle(World w) {
    final bars = <EntityId>[];
    for (var i = 0; i < 4; i++) {
      final id = _shape(w, 150 + i * 150, 340, 0xFFC8A66A, size: 64, kind: ShapeKind.roundedRect);
      bars.add(id);
    }
    w.addSystem(_IdleEconomySystem(bars));
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
      if (world.getComponent<ztext.Text>(id) != null) continue;
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
      if (world.getComponent<ztext.Text>(id) != null) continue;
      final p = world.getComponent<Position>(id);
      if (p == null) continue;
      if (i++ % 3 == 0) {
        p.x += math.sin(time + i) * dt * 20;
        p.y += math.cos(time + i) * dt * 20;
      }
    }
  }
}

class _SeekBehavior implements Behavior {
  _SeekBehavior(this.target);
  final EntityId target;

  @override
  Action decide(WorldView view, EntityId self) {
    final from = view.component<Position>(self);
    final to = view.component<Position>(target);
    if (from == null || to == null) return NoOpAction();
    final direction = to.x >= from.x ? 1.0 : -1.0;
    return SetVelocityAction(self, direction * 55, 0);
  }
}

class _IdleEconomySystem implements System {
  _IdleEconomySystem(this.generators);
  final List<EntityId> generators;
  double elapsed = 0;

  @override
  String get name => 'showcase_idle_economy';

  @override
  void update(World world, double dt) {
    elapsed += dt;
    for (var i = 0; i < generators.length; i++) {
      final shape = world.getComponent<Shape>(generators[i]);
      final position = world.getComponent<Position>(generators[i]);
      if (shape == null || position == null) continue;
      final output = 30 + math.sin(elapsed * (i + 1) * .8) * 20 + i * 18;
      shape.height = output;
      position.y = 410 - output / 2;
    }
  }
}
