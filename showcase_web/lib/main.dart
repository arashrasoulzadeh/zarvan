import 'dart:math' as math;
import 'dart:html' as html;

import 'package:flutter/material.dart' hide Text, Action, Velocity;
import 'package:flutter/services.dart';
import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' hide Text;
import 'package:zarvan_flutter/src/rendering/text.dart' as ztext;

void main() =>
    runGame(ShowcaseGame(Uri.base.queryParameters['demo'] ?? 'pong'));

class ShowcaseGame extends Game {
  ShowcaseGame(this.demo) {
    loadingProgress.addListener(_syncHtmlLoader);
  }
  final String demo;
  final InputController input = InputController(
    bindings: {
      ...InputController.defaultBindings(wasd: true),
      LogicalKeyboardKey.keyR: 'restart',
    },
  );

  @override
  GameConfig get config => const GameConfig(
    title: 'ZARVAN · Playable games',
    orientation: GameOrientation.landscape,
    worldWidth: 800,
    worldHeight: 480,
    backgroundColor: Color(0xFF101216),
    fixedTimestepSeconds: 1 / 60,
    onScreenControls: OnScreenControlsMode.on,
  );

  @override
  List<OnScreenButtonSpec> onScreenButtons() => const [];

  @override
  bool get onScreenJoystickVertical => demo == 'pong' || demo == 'snake';

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

  void _syncHtmlLoader() {
    if (loadingProgress.fraction < 1) return;
    final loader = html.document.getElementById('runtime-loader');
    if (loader == null || loader.classes.contains('done')) return;
    loader.classes.add('done');
    Future<void>.delayed(const Duration(milliseconds: 350), loader.remove);
  }
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
    switch (demo) {
      case 'snake':
        world.addSystem(SnakeSystem(input));
        break;
      case 'breakout':
        world.addSystem(BreakoutSystem(input));
        break;
      default:
        world.addSystem(PongSystem(input));
    }
    _arena(world);
    _hud(world);
  }

  void _arena(World world) {
    const wall = 0xFF252B36;
    box(world, 40, 76, 720, 2, wall);
    box(world, 40, 424, 720, 2, wall);
    box(world, 40, 250, 2, 348, wall);
    box(world, 760, 250, 2, 348, wall);
  }

  void _hud(World world) {
    const titles = {
      'pong': ('PONG', 'W/S or ↑/↓ to move · first to 11 · R to restart'),
      'snake': ('SNAKE', 'Arrow keys or WASD · collect the gold'),
      'breakout': ('BREAKOUT', 'A/D or ←/→ · clear the wall · 3 lives'),
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

EntityId diamond(World w, double x, double y, double size, int color) {
  final id = w.spawn();
  w.setComponent(id, Position(x, y));
  w.setComponent(
    id,
    Shape(kind: ShapeKind.diamond, width: size, height: size, colorArgb: color),
  );
  return id;
}

EntityId ring(World w, double x, double y, double size, int color) {
  final id = w.spawn();
  w.setComponent(id, Position(x, y));
  w.setComponent(
    id,
    Shape(
      kind: ShapeKind.ring,
      width: size,
      height: size,
      strokeWidth: 3,
      colorArgb: color,
    ),
  );
  return id;
}

double clamp(double v, double min, double max) => v.clamp(min, max).toDouble();

void restartIfRequested(InputState input) {
  if (input.isPressed('restart')) html.window.location.reload();
}

class PongSystem implements System {
  PongSystem(this.input);
  final InputState input;
  EntityId? player, enemy, ball, scoreText, resultText;
  double vx = 220, vy = 130;
  int playerScore = 0, enemyScore = 0;
  bool initialized = false, finished = false;

  @override
  String get name => 'pong';

  @override
  void update(World w, double dt) {
    restartIfRequested(input);
    if (!initialized) {
      player = box(w, 70, 250, 18, 92, 0xFFE6B86A);
      enemy = box(w, 730, 250, 18, 92, 0xFFDE6C65);
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
      resultText = w.spawn();
      w.setComponent(resultText!, Position(400, 250));
      w.setComponent(
        resultText!,
        ztext.Text(
          '',
          fontSize: 26,
          colorArgb: 0xFFFFFFFF,
          screenSpace: true,
          align: ztext.TextAlignment.center,
          zIndex: 100,
        ),
      );
      initialized = true;
    }
    if (finished) return;
    final p = w.getComponent<Position>(player!)!;
    final e = w.getComponent<Position>(enemy!)!;
    final b = w.getComponent<Position>(ball!)!;
    p.y += (input.isPressed('up') ? -360 : 0) * dt;
    p.y += (input.isPressed('down') ? 360 : 0) * dt;
    p.y = clamp(p.y, 125, 375);
    e.y += (b.y - e.y) * dt * 1.35;
    e.y = clamp(e.y, 125, 375);
    b.x += vx * dt;
    b.y += vy * dt;
    if (b.y < 82 || b.y > 398) vy = -vy;
    if (b.x < 98 && (b.y - p.y).abs() < 70) {
      b.x = 98;
      vx = vx.abs();
    } else if (b.x > 702 && (b.y - e.y).abs() < 70) {
      b.x = 702;
      vx = -vx.abs();
    }
    if (b.x < 42) {
      enemyScore++;
      _reset(b, false);
    }
    if (b.x > 758) {
      playerScore++;
      _reset(b, true);
    }
    if (playerScore >= 11 || enemyScore >= 11) {
      finished = true;
      (w.getComponent<ztext.Text>(resultText!)!).text = playerScore > enemyScore
          ? 'YOU WIN  ·  press R to restart'
          : 'CPU WINS  ·  press R to restart';
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
  EntityId? food, scoreText, resultText;
  double timer = 0;
  int dx = 0, dy = 0, score = 0;
  bool initialized = false, finished = false;

  @override
  String get name => 'snake';

  @override
  void update(World w, double dt) {
    restartIfRequested(input);
    if (!initialized) {
      for (var i = 0; i < 5; i++)
        segments.add(box(w, 400 - i * 22, 240, 18, 18, 0xFFE6B86A));
      food = dot(w, 600, 240, 16, 0xFFDE6C65);
      scoreText = w.spawn();
      w.setComponent(scoreText!, Position(660, 52));
      w.setComponent(
        scoreText!,
        ztext.Text(
          '0',
          fontSize: 12,
          colorArgb: 0xFFFFFFFF,
          screenSpace: true,
          align: ztext.TextAlignment.right,
          zIndex: 100,
        ),
      );
      resultText = w.spawn();
      w.setComponent(resultText!, Position(400, 250));
      w.setComponent(
        resultText!,
        ztext.Text(
          '',
          fontSize: 26,
          colorArgb: 0xFFFFFFFF,
          screenSpace: true,
          align: ztext.TextAlignment.center,
          zIndex: 100,
        ),
      );
      initialized = true;
    }
    if (finished) return;
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
    if (dx == 0 && dy == 0) return;
    timer += dt;
    if (timer < .12) return;
    timer = 0;
    final head = w.getComponent<Position>(segments.first)!;
    final next = Position(head.x + dx * 22, head.y + dy * 22);
    final target = w.getComponent<Position>(food!);
    if (next.x < 70 || next.x > 730 || next.y < 90 || next.y > 410) {
      finished = true;
      (w.getComponent<ztext.Text>(resultText!)!).text =
          'GAME OVER  ·  press R to restart';
      return;
    }
    for (final segment in segments.skip(1)) {
      final p = w.getComponent<Position>(segment)!;
      if ((next.x - p.x).abs() < 12 && (next.y - p.y).abs() < 12) {
        finished = true;
        (w.getComponent<ztext.Text>(resultText!)!).text =
            'GAME OVER  ·  press R to restart';
        return;
      }
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
      score++;
      _placeFood(w, target);
    }
    (w.getComponent<ztext.Text>(scoreText!)!).text = '$score';
  }

  void _placeFood(World world, Position target) {
    final candidates = <Position>[
      for (var y = 110; y <= 390; y += 22)
        for (var x = 90; x <= 710; x += 22)
          Position(x.toDouble(), y.toDouble()),
    ];
    final start = (score * 37 + segments.length * 11) % candidates.length;
    for (var offset = 0; offset < candidates.length; offset++) {
      final candidate = candidates[(start + offset) % candidates.length];
      final occupied = segments.any((id) {
        final position = world.getComponent<Position>(id);
        return position != null &&
            position.x == candidate.x &&
            position.y == candidate.y;
      });
      if (!occupied) {
        target.x = candidate.x;
        target.y = candidate.y;
        return;
      }
    }
  }
}

class BreakoutSystem implements System {
  BreakoutSystem(this.input);
  final InputState input;
  EntityId? paddle, ball, scoreText, resultText;
  final bricks = <EntityId>[];
  double vx = 180, vy = -180;
  int score = 0, lives = 3;
  bool initialized = false, finished = false;

  @override
  String get name => 'breakout';

  @override
  void update(World w, double dt) {
    restartIfRequested(input);
    if (!initialized) {
      paddle = box(w, 400, 405, 110, 18, 0xFFE6B86A);
      ball = dot(w, 400, 380, 16, 0xFFFFFFFF);
      scoreText = w.spawn();
      w.setComponent(scoreText!, Position(660, 52));
      w.setComponent(
        scoreText!,
        ztext.Text(
          '0  ·  3',
          fontSize: 12,
          colorArgb: 0xFFFFFFFF,
          screenSpace: true,
          align: ztext.TextAlignment.right,
          zIndex: 100,
        ),
      );
      resultText = w.spawn();
      w.setComponent(resultText!, Position(400, 250));
      w.setComponent(
        resultText!,
        ztext.Text(
          '',
          fontSize: 26,
          colorArgb: 0xFFFFFFFF,
          screenSpace: true,
          align: ztext.TextAlignment.center,
          zIndex: 100,
        ),
      );
      for (var y = 0; y < 4; y++)
        for (var x = 0; x < 10; x++)
          bricks.add(
            box(
              w,
              100 + x * 66,
              120 + y * 30,
              54,
              20,
              y.isEven ? 0xFF526B91 : 0xFFDE6C65,
            ),
          );
      initialized = true;
    }
    if (finished) return;
    final p = w.getComponent<Position>(paddle!)!;
    final b = w.getComponent<Position>(ball!)!;
    p.x += (input.isPressed('left') ? -320 : 0) * dt;
    p.x += (input.isPressed('right') ? 320 : 0) * dt;
    p.x = clamp(p.x, 110, 690);
    b.x += vx * dt;
    b.y += vy * dt;
    if (b.x < 58 || b.x > 742) vx = -vx;
    if (b.y < 75) vy = -vy;
    if (b.y > 375 && b.y < 430 && (b.x - p.x).abs() < 68) {
      b.y = 375;
      vx = clamp(vx + (b.x - p.x) * 2.1, -360, 360);
      vy = -vy;
    }
    for (final id in List<EntityId>.from(bricks)) {
      final brick = w.getComponent<Position>(id);
      if (brick != null &&
          (b.x - brick.x).abs() < 32 &&
          (b.y - brick.y).abs() < 15) {
        w.destroy(id);
        bricks.remove(id);
        score += 10;
        vy = -vy;
        break;
      }
    }
    if (bricks.isEmpty) {
      finished = true;
      (w.getComponent<ztext.Text>(resultText!)!).text =
          'YOU WIN  ·  press R to restart';
    } else if (b.y > 438) {
      lives--;
      b.x = 400;
      b.y = 360;
      vx = 180;
      vy = -180;
      if (lives <= 0) {
        finished = true;
        (w.getComponent<ztext.Text>(resultText!)!).text =
            'GAME OVER  ·  press R to restart';
      }
    }
    (w.getComponent<ztext.Text>(scoreText!)!).text = '$score  ·  $lives';
  }
}

class AsteroidsSystem implements System {
  AsteroidsSystem(this.input);
  final InputState input;
  EntityId? ship, scoreText, resultText;
  final rocks = <EntityId>[];
  final bullets = <EntityId>[];
  final rockVx = <double>[];
  final rockVy = <double>[];
  double angle = -math.pi / 2;
  double fireCooldown = 0;
  int score = 0;
  bool initialized = false, finished = false;

  @override
  String get name => 'asteroids';

  @override
  void update(World w, double dt) {
    restartIfRequested(input);
    if (!initialized) {
      ship = diamond(w, 400, 350, 28, 0xFFE6B86A);
      scoreText = w.spawn();
      w.setComponent(scoreText!, Position(660, 52));
      w.setComponent(
        scoreText!,
        ztext.Text(
          '0',
          fontSize: 12,
          colorArgb: 0xFFFFFFFF,
          screenSpace: true,
          align: ztext.TextAlignment.right,
          zIndex: 100,
        ),
      );
      resultText = w.spawn();
      w.setComponent(resultText!, Position(400, 250));
      w.setComponent(
        resultText!,
        ztext.Text(
          '',
          fontSize: 26,
          colorArgb: 0xFFFFFFFF,
          screenSpace: true,
          align: ztext.TextAlignment.center,
          zIndex: 100,
        ),
      );
      for (var i = 0; i < 10; i++) {
        rocks.add(
          ring(w, 100 + (i * 59) % 600, 100 + (i * 41) % 250, 26, 0xFF526B91),
        );
        rockVx.add((i.isEven ? 1 : -1) * (20 + i * 2));
        rockVy.add((i.isEven ? -1 : 1) * (18 + i * 2));
      }
      initialized = true;
    }
    if (finished) return;
    final s = w.getComponent<Position>(ship!)!;
    if (input.isPressed('left')) angle -= 2.8 * dt;
    if (input.isPressed('right')) angle += 2.8 * dt;
    if (input.isPressed('up')) {
      s.x += math.cos(angle) * 150 * dt;
      s.y += math.sin(angle) * 150 * dt;
    }
    if (s.x < 48) s.x = 752;
    if (s.x > 752) s.x = 48;
    if (s.y < 80) s.y = 420;
    if (s.y > 420) s.y = 80;
    fireCooldown -= dt;
    if (input.isPressed('jump') && fireCooldown <= 0) {
      final bullet = dot(w, s.x, s.y, 7, 0xFFFFFFFF);
      bullets.add(bullet);
      w.setComponent(
        bullet,
        Velocity(math.cos(angle) * 360, math.sin(angle) * 360),
      );
      fireCooldown = .22;
    }
    for (final bullet in List<EntityId>.from(bullets)) {
      final bp = w.getComponent<Position>(bullet);
      final bv = w.getComponent<Velocity>(bullet);
      if (bp == null || bv == null) continue;
      bp.x += bv.x * dt;
      bp.y += bv.y * dt;
      if (bp.x < 45 || bp.x > 755 || bp.y < 80 || bp.y > 420) {
        w.destroy(bullet);
        bullets.remove(bullet);
        continue;
      }
      for (final rock in List<EntityId>.from(rocks)) {
        final rp = w.getComponent<Position>(rock);
        if (rp != null &&
            (bp.x - rp.x).abs() < 20 &&
            (bp.y - rp.y).abs() < 20) {
          final rockIndex = rocks.indexOf(rock);
          w.destroy(rock);
          w.destroy(bullet);
          rocks.removeAt(rockIndex);
          rockVx.removeAt(rockIndex);
          rockVy.removeAt(rockIndex);
          bullets.remove(bullet);
          score += 10;
          break;
        }
      }
    }
    for (var i = 0; i < rocks.length; i++) {
      final rp = w.getComponent<Position>(rocks[i]);
      if (rp == null) continue;
      rp.x += rockVx[i] * dt;
      rp.y += rockVy[i] * dt;
      if (rp.x < 48) rp.x = 752;
      if (rp.x > 752) rp.x = 48;
      if (rp.y < 80) rp.y = 420;
      if (rp.y > 420) rp.y = 80;
      if ((rp.x - s.x).abs() < 24 && (rp.y - s.y).abs() < 24) {
        finished = true;
        (w.getComponent<ztext.Text>(resultText!)!).text =
            'SHIP LOST  ·  press R to restart';
      }
    }
    if (rocks.isEmpty) {
      finished = true;
      (w.getComponent<ztext.Text>(resultText!)!).text =
          'SECTOR CLEAR  ·  press R to restart';
    }
    (w.getComponent<ztext.Text>(scoreText!)!).text = '$score';
  }
}
