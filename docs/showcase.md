---
title: Showcase
description: Real ZARVAN game and simulation outputs with focused code samples.
---

# Showcase

Ten concrete outputs from the engine's documented paths. The first group is
player-facing games; the second is the simulation and tooling underneath them.
Each item has one job: show what you get, the smallest code that creates it,
and where to follow the complete implementation.

## Play the runtime

This is a live Flutter Web build using `zarvan_core` and `zarvan_flutter`, not
a screenshot. Pick a mode, then open it in the runtime below. The same build
loads every mode through a `?demo=` query parameter.

<div class="zv-live-demo" markdown>
<iframe src="app/?demo=platformer" title="Live ZARVAN platformer demo" loading="eager"></iframe>
<div class="zv-live-links" markdown>
[Platformer](app/?demo=platformer) · [Strategy](app/?demo=strategy) · [Agent](app/?demo=agent) · [Multiplayer](app/?demo=multiplayer) · [Idle](app/?demo=idle) · [ECS](app/?demo=ecs) · [JSON](app/?demo=json) · [Fog](app/?demo=fog) · [Benchmark](app/?demo=benchmark) · [Replay](app/?demo=replay)
</div>
</div>

## Games

<div class="zv-showcase-grid" markdown>

<article class="zv-showcase-card" markdown>
<div class="zv-output zv-output--platformer"><span class="zv-output-player">●</span><span class="zv-output-ground"></span><span class="zv-output-enemy"></span></div>

### Tiny platformer

Player movement, gravity, a patrol enemy, coins, and a health bar in one small
world. The tutorial uses only public package APIs and its snippets are checked
against current signatures.

```dart
final player = spawnPlayer(world, at: const Vec2(48, 80));
spawnEnemy(world, at: const Vec2(180, 80), behavior: PatrolBehavior());
installPlatformerSystems(world);
```

[Verified in Tutorial 1 · Build the platformer](tutorials/01-hello-world.md){ .md-button }
</article>

<article class="zv-showcase-card" markdown>
<img src="img/strategy-skirmish.png" alt="Turn-based strategy output">

### Turn-based skirmish

An 8×8 battlefield with terrain costs, fog of war, two armies, and a computer
controlled opponent. This is the repository's clearest end-to-end game output.

```dart
final battle = StrategyGame.create(map: map, seed: 7);
battle.issue(MoveOrder(unit: scout, target: tile(4, 2)));
battle.endTurn();
```

[Verified in Tutorial 2 · Build the strategy game](tutorials/02-turn-based-strategy.md){ .md-button }
</article>

<article class="zv-showcase-card" markdown>
<div class="zv-output zv-output--agent"><span class="zv-agent-node">WorldView</span><span class="zv-agent-arrow">→</span><span class="zv-agent-node">Action</span><span class="zv-agent-arrow">→</span><span class="zv-agent-node">World</span></div>

### Agent-driven game

The agent sees JSON, chooses orders, and gets rejected when it proposes an
illegal move. The engine remains the referee.

```dart
final view = world.viewFor(agentId);
final action = policy.choose(view);
world.apply(action);
```

[Verified in Tutorial 3 · Build the agent game](tutorials/03-agent-driven-game.md){ .md-button }
</article>

<article class="zv-showcase-card" markdown>
<div class="zv-output zv-output--network"><span>HOST</span><i></i><span>CLIENT A</span><i></i><span>CLIENT B</span></div>

### Multiplayer world

One host owns the simulation; two clients receive snapshots and submit orders.
The mirror worlds never simulate or mutate authority locally.

```dart
final host = GameServer(world: world, transport: WebSocketTransport());
host.listen();
```

[Verified in Tutorial 4 · Build multiplayer](tutorials/04-multiplayer.md){ .md-button }
</article>

<article class="zv-showcase-card" markdown>
<img src="img/idle-game.png" alt="Idle game output">

### Idle economy

An economy generated from one JSON file: offline earnings, generators, upgrades,
prestige, challenges, and validation without launching Flutter.

```dart
final session = IdleSession.load(store);
final reward = session.applyOffline(elapsed: elapsed);
session.save();
```

[Verified in Tutorial 5 · Build the idle game](tutorials/05-idle-game.md){ .md-button }
</article>

</div>

## Simulations

<div class="zv-showcase-grid" markdown>

<article class="zv-showcase-card" markdown>
<div class="zv-output zv-output--ecs"><b>Entity</b><span>Position</span><span>Velocity</span><span>Health</span></div>

### ECS world step

The engine's smallest runtime unit: registered components, ordered systems, and
a fixed step that can be asserted in a pure Dart test.

```dart
world.addSystem(MovementSystem());
world.step(const Duration(milliseconds: 16));
expect(world.get<Position>(player).x, 11);
```

[Core concept · Read the ECS model](concepts/ecs.md){ .md-button }
</article>

<article class="zv-showcase-card" markdown>
<div class="zv-output zv-output--json"><span>{</span><span>"entity": "player",</span><span>"position": [10, 12],</span><span>"velocity": [60, 0]</span><span>}</span></div>

### JSON world snapshot

The same representation can cross a process boundary, become a save file, or
be reduced into an observation for an agent.

```dart
final snapshot = world.toJson();
final restored = World.fromJson(snapshot);
```

[Core concept · Read content as data](concepts/content-as-data.md){ .md-button }
</article>

<article class="zv-showcase-card" markdown>
<div class="zv-output zv-output--fog"><span class="visible"></span><span class="visible"></span><span class="hidden"></span><span class="visible"></span><span class="hidden"></span><span class="visible"></span></div>

### Fog of war

Visibility is not a renderer trick: walls block sight, explored cells persist,
and illegal attacks fail when the target is outside the team's view.

```dart
final visible = fog.canSee(observer, target);
final view = fog.filter(world.viewFor(observer));
```

[Verified example · Add fog of war](examples/fog-of-war.md){ .md-button }
</article>

<article class="zv-showcase-card" markdown>
<div class="zv-output zv-output--bars"><span style="--value:82%"></span><span style="--value:46%"></span><span style="--value:64%"></span></div>

### Rendering benchmark

Measure simulation and rendering separately. The checked-in post-processing
dataset records the device, resolution, preset, and frame-time conditions.

```dart
benchmark('world step', () {
  for (var i = 0; i < 1000; i++) world.step(dt);
});
```

[Checked-in data · See benchmarks](benchmarks.md){ .md-button }
</article>

<article class="zv-showcase-card" markdown>
<div class="zv-output zv-output--timeline"><span>input</span><i></i><span>systems</span><i></i><span>snapshot</span><i></i><span>replay</span></div>

### Replayable simulation

Commands and snapshots make a run reproducible for tests, multiplayer debugging,
and agent evaluation. The important output is a comparable state, not a replay video.

```dart
final replay = Replay.from(commands);
replay.run(seed: 42);
expect(replay.snapshot, expected);
```

[Concept + profiler · Read the performance model](concepts/performance.md){ .md-button }
</article>

</div>

!!! note
    The showcase deliberately separates player-facing output from simulation
    output. Follow the linked page for the complete runnable or tested path;
    the snippets here are intentionally short.
