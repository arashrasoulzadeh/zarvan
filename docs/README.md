---
template: home.html
hide:
  - toc
---

# ZARVAN

## Build worlds that agents can understand.

ZARVAN is a pure-Dart 2D game engine with a deterministic simulation, plain
JSON state, and a Flutter shell for Android, iOS, and the web.

<div class="zv-home-actions" markdown>

[:material-rocket-launch: **Start building**](getting-started.md){ .md-button .md-button--primary }
[:material-robot-outline: **Build with agents**](agents.md){ .md-button }
[:material-github: **View source**](https://github.com/arashrasoulzadeh/zarvan){ .md-button }

</div>

## The short version

The simulation is the product. Flutter draws it. Agents observe and propose;
the engine validates and applies.

<div class="zv-home-grid" markdown>

<div markdown>

### Simulation first

Fixed timesteps, seeded randomness, ECS, and headless tests. Run the same
world on a phone, a server, or in CI.

</div>

<div markdown>

### Agent-native

Worlds serialize to JSON. `WorldView` is read-only. `Behavior`, `Action`, and
`Order` keep authority inside the engine.

</div>

<div markdown>

### Data-driven

Author levels and content as data, validate them with the CLI, and keep genre
logic in focused packages instead of one giant framework.

</div>

</div>

## Choose your first step

| You want to… | Start here |
|---|---|
| Run a game in five minutes | [Getting started](getting-started.md) |
| Make a platformer | [Platformer tutorial](tutorials/01-hello-world.md) |
| Make a strategy game | [Strategy tutorial](tutorials/02-turn-based-strategy.md) |
| Let an agent play or edit | [Agent hub](agents.md) |
| Look up an API or JSON shape | [Reference](reference/cheatsheet.md) |
| Read in Persian | [مستندات فارسی](fa/index.md) |

## A game starts this small

```dart
final game = GameBuilder.create(width: 320, height: 240);
final player = game.spawn([Position(10, 10), Velocity(60, 0)]);

game.update(1 / 60);
final snapshot = game.world.toJson();
```

The rest of the engine is modular: `zarvan_core` for simulation, `zarvan_flutter`
for rendering and input, and optional packages for platformers, strategy, idle
games, CLI tooling, schemas, and agent APIs.

[:octicons-arrow-right-24: Explore the package map](packages.md) ·
[:octicons-arrow-right-24: Read the architecture](concepts/architecture.md) ·
[:octicons-arrow-right-24: See benchmarks](benchmarks.md)

!!! note "Documentation quality"
    Tutorials and examples are exercised by the repository's tests. If a
    snippet drifts from the API, treat it as a bug and open an issue.
