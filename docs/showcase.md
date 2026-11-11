---
title: Showcase
description: Real ZARVAN game and simulation outputs with focused code samples.
---

# Showcase

Ten small outputs that show what ZARVAN is built to do. Every card links to a
corresponding tutorial, example, benchmark, or package test; snippets are the
interesting part of the output, not a copy of the engine.

## Games

<div class="zv-showcase-grid" markdown>

<article class="zv-showcase-card" markdown>
<div class="zv-output zv-output--platformer"><span class="zv-output-player">●</span><span class="zv-output-ground"></span><span class="zv-output-enemy"></span></div>

### Tiny platformer

Player movement, gravity, a patrol enemy, coins, and a health bar in one small world.

```dart
final player = spawnPlayer(world, at: const Vec2(48, 80));
spawnEnemy(world, at: const Vec2(180, 80), behavior: PatrolBehavior());
installPlatformerSystems(world);
```

[Build the platformer](tutorials/01-hello-world.md){ .md-button }
</article>

<article class="zv-showcase-card" markdown>
<img src="img/strategy-skirmish.png" alt="Turn-based strategy output">

### Turn-based skirmish

Grid movement, terrain, fog of war, and an AI opponent with explicit turns.

```dart
final battle = StrategyGame.create(map: map, seed: 7);
battle.issue(MoveOrder(unit: scout, target: tile(4, 2)));
battle.endTurn();
```

[Build the strategy game](tutorials/02-turn-based-strategy.md){ .md-button }
</article>

<article class="zv-showcase-card" markdown>
<div class="zv-output zv-output--agent"><span class="zv-agent-node">WorldView</span><span class="zv-agent-arrow">→</span><span class="zv-agent-node">Action</span><span class="zv-agent-arrow">→</span><span class="zv-agent-node">World</span></div>

### Agent-driven game

An agent observes a read-only world view, chooses an action, and plays through the same authority boundary as a human.

```dart
final view = world.viewFor(agentId);
final action = policy.choose(view);
world.apply(action);
```

[Build the agent game](tutorials/03-agent-driven-game.md){ .md-button }
</article>

<article class="zv-showcase-card" markdown>
<div class="zv-output zv-output--network"><span>HOST</span><i></i><span>CLIENT A</span><i></i><span>CLIENT B</span></div>

### Multiplayer world

One host simulation, multiple clients, and explicit commands moving through a transport.

```dart
final host = GameServer(world: world, transport: WebSocketTransport());
host.listen();
```

[Build multiplayer](tutorials/04-multiplayer.md){ .md-button }
</article>

<article class="zv-showcase-card" markdown>
<img src="img/idle-game.png" alt="Idle game output">

### Idle economy

Offline progress, upgrades, waves, loot, and a saveable economy driven by data.

```dart
final session = IdleSession.load(store);
final reward = session.applyOffline(elapsed: elapsed);
session.save();
```

[Build the idle game](tutorials/05-idle-game.md){ .md-button }
</article>

</div>

## Simulations

<div class="zv-showcase-grid" markdown>

<article class="zv-showcase-card" markdown>
<div class="zv-output zv-output--ecs"><b>Entity</b><span>Position</span><span>Velocity</span><span>Health</span></div>

### ECS world step

Systems query components, update the world, and run without a Flutter binding.

```dart
world.addSystem(MovementSystem());
world.step(const Duration(milliseconds: 16));
expect(world.get<Position>(player).x, 11);
```

[Read the ECS concept](concepts/ecs.md){ .md-button }
</article>

<article class="zv-showcase-card" markdown>
<div class="zv-output zv-output--json"><span>{</span><span>"entity": "player",</span><span>"position": [10, 12],</span><span>"velocity": [60, 0]</span><span>}</span></div>

### JSON world snapshot

State stays inspectable for tools, agents, save files, replay, and debugging.

```dart
final snapshot = world.toJson();
final restored = World.fromJson(snapshot);
```

[Read content as data](concepts/content-as-data.md){ .md-button }
</article>

<article class="zv-showcase-card" markdown>
<div class="zv-output zv-output--fog"><span class="visible"></span><span class="visible"></span><span class="hidden"></span><span class="visible"></span><span class="hidden"></span><span class="visible"></span></div>

### Fog of war

Visibility is a simulation result: walls block sight, units reveal tiles, and the agent only receives allowed information.

```dart
final visible = fog.canSee(observer, target);
final view = fog.filter(world.viewFor(observer));
```

[Add fog of war](examples/fog-of-war.md){ .md-button }
</article>

<article class="zv-showcase-card" markdown>
<div class="zv-output zv-output--bars"><span style="--value:82%"></span><span style="--value:46%"></span><span style="--value:64%"></span></div>

### Rendering benchmark

Measure world step, collision, post-processing, and frame time before changing the renderer.

```dart
benchmark('world step', () {
  for (var i = 0; i < 1000; i++) world.step(dt);
});
```

[See benchmarks](benchmarks.md){ .md-button }
</article>

<article class="zv-showcase-card" markdown>
<div class="zv-output zv-output--timeline"><span>input</span><i></i><span>systems</span><i></i><span>snapshot</span><i></i><span>replay</span></div>

### Replayable simulation

Commands and snapshots make a run reproducible for tests, debugging, and agent evaluation.

```dart
final replay = Replay.from(commands);
replay.run(seed: 42);
expect(replay.snapshot, expected);
```

[Read the performance model](concepts/performance.md){ .md-button }
</article>

</div>

!!! note
    The showcase uses the repository's real tutorials, examples, tests, and benchmark concepts. Each snippet is intentionally the smallest useful code that produces the output.
