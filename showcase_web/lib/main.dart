import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text, Action, Velocity;
import 'package:flutter/services.dart';
import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' hide Text;
import 'package:zarvan_flutter/src/rendering/text.dart' as ztext;

void main() =>
    runGame(ShowcaseGame(Uri.base.queryParameters['demo'] ?? 'pong'));

class ShowcaseGame extends Game {
  ShowcaseGame(this.demo);
  final String demo;
  final InputController input = InputController(
    bindings: InputController.defaultBindings(wasd: true),
  );

  @override
  GameConfig get config => const GameConfig(
    title: 'ZARVAN · Playable games',
    worldWidth: 800,
    worldHeight: 480,
    backgroundColor: Color(0xFF101216),
    fixedTimestepSeconds: 1 / 60,
    onScreenControls: OnScreenControlsMode.off,
  );

  @override
  InputController createInputController() => input;

  @override
  SplashConfig get splash => const SplashConfig(
    title: 'ZARVAN playable games',
    backgroundColor: Color(0xFF101216),
    minDuration: Duration(milliseconds: 650),
  );

  @override
  Scene createInitialScene() => GameScene(demo, input.state);
}

class GameScene extends Scene {
  GameScene(this.demo, this.input);
  final String demo;
  final InputState input;

  @override
  Future<void> populate(
    World world,
    SceneController scenes,
    GameState state,
  ) async {
    registerCoreComponents(world);
    registerFlutterComponents(world);
    switch (demo) {
      case 'snake':
        world.addSystem(SnakeSystem(input));
        break;
      case 'breakout':
        world.addSystem(BreakoutSystem(input));
        break;
      case 'asteroids':
        world.addSystem(AsteroidsSystem(input));
        break;
      default:
        world.addSystem(PongSystem(input));
    }
    _hud(world);
  }

  void _hud(World world) {
    const titles = {
      'pong': ('PONG', 'W/S or ↑/↓ to move · first to 7'),
      'snake': ('SNAKE', 'Arrow keys or WASD · collect the gold'),
      'breakout': ('BREAKOUT', 'A/D or ←/→ to move the paddle'),
      'asteroids': ('ASTEROIDS', 'A/D or ←/→ · survive the field'),
    };
    final copy = titles[demo] ?? titles['pong']!;
    final title = world.spawn();
    world.setComponent(title, Position(24, 24));
    world.setComponent(
      title,
      ztext.Text(
        copy.$1,
        fontSize: 22,
        colorArgb: 0xFFFFFFFF,
        screenSpace: true,
        align: ztext.TextAlignment.left,
        zIndex: 100,
      ),
    );
    final help = world.spawn();
    world.setComponent(help, Position(24, 54));
    world.setComponent(
      help,
      ztext.Text(
        copy.$2,
        fontSize: 11,
        colorArgb: 0xFFC8A66A,
        screenSpace: true,
        align: ztext.TextAlignment.left,
        zIndex: 100,
      ),
    );
  }
}

EntityId box(
  World w,
  double x,
  double y,
  double width,
  double height,
  int color,
) {
  final id = w.spawn();
  w.setComponent(id, Position(x, y));
  w.setComponent(
    id,
    Shape(
      kind: ShapeKind.roundedRect,
      width: width,
      height: height,
      cornerRadius: 6,
      colorArgb: color,
    ),
  );
  return id;
}

EntityId dot(World w, double x, double y, double size, int color) {
  final id = w.spawn();
  w.setComponent(id, Position(x, y));
  w.setComponent(id, Shape(width: size, height: size, colorArgb: color));
  return id;
}

double clamp(double v, double min, double max) => v.clamp(min, max).toDouble();

class PongSystem implements System {
  PongSystem(this.input);
  final InputState input;
  EntityId? player, enemy, ball, scoreText;
  double vx = 220, vy = 130;
  int playerScore = 0, enemyScore = 0;
  bool initialized = false;

  @override
  String get name => 'pong';

  @override
  void update(World w, double dt) {
    if (!initialized) {
      player = box(w, 55, 240, 18, 92, 0xFFE6B86A);
      enemy = box(w, 745, 240, 18, 92, 0xFFDE6C65);
      ball = dot(w, 400, 240, 18, 0xFFFFFFFF);
      scoreText = w.spawn();
      w.setComponent(scoreText!, Position(400, 82));
      w.setComponent(
        scoreText!,
        ztext.Text(
          '0  :  0',
          fontSize: 28,
          colorArgb: 0xFFFFFFFF,
          screenSpace: true,
          align: ztext.TextAlignment.center,
          zIndex: 90,
        ),
      );
      initialized = true;
    }
    final p = w.getComponent<Position>(player!)!;
    final e = w.getComponent<Position>(enemy!)!;
    final b = w.getComponent<Position>(ball!)!;
    p.y += (input.isPressed('up') ? -280 : 0) * dt;
    p.y += (input.isPressed('down') ? 280 : 0) * dt;
    p.y = clamp(p.y, 90, 390);
    e.y += (b.y - e.y) * dt * 2.2;
    b.x += vx * dt;
    b.y += vy * dt;
    if (b.y < 82 || b.y > 398) vy = -vy;
    if ((b.x < 74 && (b.y - p.y).abs() < 58) ||
        (b.x > 726 && (b.y - e.y).abs() < 58))
      vx = -vx;
    if (b.x < 0) {
      enemyScore++;
      _reset(b, false);
    }
    if (b.x > 800) {
      playerScore++;
      _reset(b, true);
    }
    (w.getComponent<ztext.Text>(scoreText!)!).text =
        '$playerScore  :  $enemyScore';
  }

  void _reset(Position b, bool toLeft) {
    b.x = 400;
    b.y = 240;
    vx = (toLeft ? -1 : 1) * 220;
    vy = (playerScore + enemyScore).isEven ? 130 : -130;
  }
}

class SnakeSystem implements System {
  SnakeSystem(this.input);
  final InputState input;
  final segments = <EntityId>[];
  EntityId? food;
  double timer = 0;
  int dx = 1, dy = 0;
  bool initialized = false;

  @override
  String get name => 'snake';

  @override
  void update(World w, double dt) {
    if (!initialized) {
      for (var i = 0; i < 5; i++)
        segments.add(box(w, 400 - i * 22, 240, 18, 18, 0xFFE6B86A));
      food = dot(w, 600, 240, 16, 0xFFDE6C65);
      initialized = true;
    }
    if (input.isPressed('up') && dy == 0) {
      dx = 0;
      dy = -1;
    }
    if (input.isPressed('down') && dy == 0) {
      dx = 0;
      dy = 1;
    }
    if (input.isPressed('left') && dx == 0) {
      dx = -1;
      dy = 0;
    }
    if (input.isPressed('right') && dx == 0) {
      dx = 1;
      dy = 0;
    }
    timer += dt;
    if (timer < .12) return;
    timer = 0;
    final head = w.getComponent<Position>(segments.first)!;
    final next = Position(head.x + dx * 22, head.y + dy * 22);
    final target = w.getComponent<Position>(food!);
    if (next.x < 70 || next.x > 730 || next.y < 90 || next.y > 410) {
      dx = -dx;
      dy = -dy;
      return;
    }
    for (var i = segments.length - 1; i > 0; i--) {
      final from = w.getComponent<Position>(segments[i - 1])!;
      final to = w.getComponent<Position>(segments[i])!;
      to.x = from.x;
      to.y = from.y;
    }
    head.x = next.x;
    head.y = next.y;
    if ((next.x - target!.x).abs() < 20 && (next.y - target.y).abs() < 20) {
      segments.add(box(w, target.x, target.y, 18, 18, 0xFFE6B86A));
      target.x = 90 + ((segments.length * 83) % 620);
      target.y = 110 + ((segments.length * 47) % 280);
    }
  }
}

class BreakoutSystem implements System {
  BreakoutSystem(this.input);
  final InputState input;
  EntityId? paddle, ball;
  final bricks = <EntityId>[];
  double vx = 180, vy = -180;
  bool initialized = false;

  @override
  String get name => 'breakout';

  @override
  void update(World w, double dt) {
    if (!initialized) {
      paddle = box(w, 400, 420, 110, 18, 0xFFE6B86A);
      ball = dot(w, 400, 380, 16, 0xFFFFFFFF);
      for (var y = 0; y < 4; y++)
        for (var x = 0; x < 10; x++)
          bricks.add(
            box(
              w,
              105 + x * 65,
              120 + y * 30,
              54,
              20,
              y.isEven ? 0xFF526B91 : 0xFFDE6C65,
            ),
          );
      initialized = true;
    }
    final p = w.getComponent<Position>(paddle!)!;
    final b = w.getComponent<Position>(ball!)!;
    p.x += (input.isPressed('left') ? -320 : 0) * dt;
    p.x += (input.isPressed('right') ? 320 : 0) * dt;
    p.x = clamp(p.x, 70, 730);
    b.x += vx * dt;
    b.y += vy * dt;
    if (b.x < 60 || b.x > 740) vx = -vx;
    if (b.y < 75) vy = -vy;
    if (b.y > 392 && (b.x - p.x).abs() < 65) vy = -vy;
    for (final id in List<EntityId>.from(bricks)) {
      final brick = w.getComponent<Position>(id);
      if (brick != null &&
          (b.x - brick.x).abs() < 32 &&
          (b.y - brick.y).abs() < 15) {
        w.destroy(id);
        bricks.remove(id);
        vy = -vy;
        break;
      }
    }
    if (b.y > 470) {
      b.x = 400;
      b.y = 380;
    }
  }
}

class AsteroidsSystem implements System {
  AsteroidsSystem(this.input);
  final InputState input;
  EntityId? ship;
  final rocks = <EntityId>[];
  bool initialized = false;
  double time = 0;

  @override
  String get name => 'asteroids';

  @override
  void update(World w, double dt) {
    if (!initialized) {
      ship = dot(w, 400, 350, 26, 0xFFE6B86A);
      for (var i = 0; i < 10; i++)
        rocks.add(
          dot(
            w,
            90 + (i * 67) % 620,
            110 + (i * 43) % 250,
            22 + (i % 3) * 7,
            0xFF526B91,
          ),
        );
      initialized = true;
    }
    final s = w.getComponent<Position>(ship!)!;
    s.x += (input.isPressed('left') ? -260 : 0) * dt;
    s.x += (input.isPressed('right') ? 260 : 0) * dt;
    s.x = clamp(s.x, 60, 740);
    time += dt;
    for (var i = 0; i < rocks.length; i++) {
      final r = w.getComponent<Position>(rocks[i]);
      if (r == null) continue;
      r.y += (30 + i * 3) * dt;
      r.x += math.sin(time + i) * dt * 18;
      if (r.y > 450) r.y = 85;
    }
  }
}
