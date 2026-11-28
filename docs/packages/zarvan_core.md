# zarvan_core

**Runtime:** pure Dart, no Flutter · **Audience:** developers, agents · **Depends on:** `zarvan_schema`

The engine itself. Everything that is not drawing, input or audio lives here,
so a simulation can run headless in CI, in the CLI, or under an agent.

## What's inside

| Area (`lib/src/`) | What it gives you |
|---|---|
| `ecs` | `World`, entities, `ComponentStore`, systems, the component registry, deterministic random, replay recording, `WorldView` and `Behavior`. |
| `physics` | `Position`, `Collider`, `TileMap`, autotiling, tile animation, spatial hash. |
| `ai` | Behavior trees, state machines, steering, flee, hearing, pathfinding helpers. |
| `content` | The content DSL (`Level`), dialogue, cinematics, inventory, animation clips, key-value stores, localized `StringTable`. |
| `turn` | Turn-based strategy rules: turn clock, orders, grid navigation, combat, fog of war. |
| `idle` | Idle/incremental rules: economy, prestige, offline progress, `BigNumber`, balance simulator. |
| `quiz` | Quiz rules: bank, question factory, modes, scoring, progress, simulation. |
| `rendering` | Renderer-independent particles, day/night cycle. |
| `ui` | Renderer-independent button and hit-test data. |
| `graph` | Node-graph model, validator, and compilers to behavior trees and dialogue. |
| `command` | The undoable edit-command model Studio and the API share ([ADR 0002](../adr/0002-command-model-in-engine-core.md)). |
| `ops` | The operation registry: every operation as CLI command, MCP tool, REST route and JSON-RPC method. |
| `net` | Networking and lockstep primitives. |
| `distribution` | Release manifests. |
| `validation`, `testing`, `io` | Content validation, test helpers, file-backed IO. |

## Entry points

Genre and platform code is split into separate libraries so a game only imports what it uses:

| Import | Gives you |
|---|---|
| `package:zarvan_core/zarvan_core.dart` | The general engine. |
| `zarvan_core_essentials.dart` | A smaller surface for tools. |
| `zarvan_core_idle.dart` | Idle rules (also re-exported by `zarvan_idle`). |
| `zarvan_core_quiz.dart` | Quiz rules (also re-exported by `zarvan_quiz`). |
| `zarvan_core_ops.dart` | The operation registry. |
| `zarvan_core_io.dart`, `zarvan_core_web.dart` | Platform-specific IO. |
| `zarvan_core_testing.dart` | Test helpers. |

## Quick example

```dart
final world = World(width: 800, height: 480);
registerCoreComponents(world); // Position, Velocity, Collider, AIState, TileMap
world.addSystem(MovementSystem());
world.step(1 / 60);

final snapshot = world.toJson();   // full state as JSON
world.applyPatch(patch);           // an agent edits state through a patch
```

## The agent-facing API

Three pieces support agent integration: content as data (`Level`), JSON state (`World.toJson()` / `applyPatch()`), and the cooperative `WorldView` + `Behavior` interface. Trusted Dart behaviors are not security-isolated. See [the agent API](../concepts/agent-api.md) and [the ECS](../concepts/ecs.md).

## Install

Not on pub.dev yet (pre-1.0). Depend on it through git, the same way `zarvan create` wires generated projects:

```yaml
dependencies:
  zarvan_core:
    git:
      url: https://github.com/arashrasoulzadeh/zarvan.git
      path: packages/zarvan_core
      ref: main
```

## Links

- [Source and README](https://github.com/arashrasoulzadeh/zarvan/tree/main/packages/zarvan_core)
- [Changelog](https://github.com/arashrasoulzadeh/zarvan/blob/main/packages/zarvan_core/CHANGELOG.md)
- [Generated API reference](https://meetarash.ir/zarvan/api/zarvan_core/)
- [All packages](../packages.md)
