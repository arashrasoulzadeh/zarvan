# The agent-facing API: `Behavior` + `WorldView` + `AISystem`

This is the engine's other AI-agent-friendly pillar (alongside
[content-as-data.md](content-as-data.md)): an interface for a runtime
agent/NPC to *drive an entity during simulation* — whether that agent
is a hand-written state machine, a rule-based patrol AI, or an
LLM-backed decision-maker — using a cooperative separation between observation and action. This is not a security boundary for untrusted Dart.

## Why separate observation from action

A behavior that could freely mutate `World` could, by a bug or a bad
LLM tool call, break invariants another system depends on (move an
entity outside the map, delete a component another system reads
unconditionally, etc.). The intended pattern is to inspect a `WorldView`, then return an `Action` for `AISystem` to apply. A custom Dart behavior is trusted code: `WorldView.world` exposes the underlying `World`, and component queries can return mutable objects. Do not treat this interface as process isolation or execute arbitrary untrusted code.

```
Behavior.decide(WorldView, EntityId self) -> Action
                                                 |
                                                 v
                                    AISystem: action.apply(world)
```

## `WorldView`: observation queries

`packages/zarvan_core/lib/src/ecs/world_view.dart`. Wraps a `World` and
provides query helpers. The returned components are not necessarily immutable:

```dart
class MyBehavior implements Behavior {
  @override
  Action decide(WorldView view, EntityId self) {
    final myPos = view.component<Position>(self);
    if (myPos == null) return const NoOpAction();

    for (final other in view.entitiesWith<Position>()) {
      if (other == self) continue;
      // Inspect other entities; do not mutate their components here.
    }

    return const NoOpAction();
  }
}
```

Useful queries: `component<T>(id)`, `hasComponent<T>(id)`,
`entitiesWith<T>()`, `entitiesWithAll<A, B>()`, and a closest-entity
helper — see the full list in `world_view.dart` or
`packages/zarvan_core/README.md`'s agent-API section.

## `Action`: the intended way to cause a change

```dart
abstract class Action {
  void apply(World world);
}
```

The engine ships generic actions (e.g. `NoOpAction`,
`SetVelocityAction` in `packages/zarvan_core/lib/src/ai/set_velocity_action.dart`)
plus whatever your game defines itself — a game-specific `Action`
subclass is how you extend this without the engine needing to know
about your domain logic:

```dart
class TakeDamageAction implements Action {
  TakeDamageAction(this.target, this.amount);
  final EntityId target;
  final double amount;

  @override
  void apply(World world) {
    // Apply domain-specific validation before mutating World.
    final health = world.componentsOf<Health>().get(target);
    // ...
  }
}
```

## `Behavior` + `BehaviorRegistry`

```dart
abstract class Behavior {
  Action decide(WorldView view, EntityId self);
}
```

Behaviors carry logic (closures, state machines) so — unlike plain-data
components — they're registered under a string id rather than embedded
in JSON, and `AIState.behaviorId` references that id:

```dart
final behaviors = BehaviorRegistry();
behaviors.register('patrol', PatrolBehavior(waypoints: [...]));
world.addSystem(AISystem(behaviors));

final enemy = world.spawn();
world.componentsOf<AIState>().set(enemy, AIState('patrol'));
```

`AIState.memory` is a free-form JSON-serializable blackboard (a
waypoint index, a cooldown timer) a behavior can carry state in between
ticks without needing its own component type — mutate it directly on
the `AIState` you read via `view.component<AIState>(self)` inside
`decide`, as a documented convention for trusted behaviors. Other component mutation should be expressed through actions.

## `AISystem`

Runs every `AIState`-tagged entity once per tick: resolves its
`behaviorId` via the registry, calls `decide`, applies the returned
`Action`. Builds one `WorldView` per tick, then calls and applies each behavior in sequence. It is a live view, not an immutable snapshot: earlier actions can affect later observations. `AISystem` does not independently validate arbitrary custom `Action.apply` implementations.

## `zarvan_platformer`'s ready-made behaviors

`PatrolBehavior`, `FollowBehavior`, `AvoidanceBehavior`,
`PathFollowBehavior` (`packages/zarvan_platformer/lib/src/ai/`) are
concrete `Behavior` implementations for common enemy AI — read one of
these as a worked example of writing your own.

## See also

- [ecs.md](ecs.md) — `World`/`ComponentStore`/`System` underneath all of this.
- [content-as-data.md](content-as-data.md) — the other read/write path (patching from outside simulation, vs. deciding during it).
- [examples/custom-behavior.md](../examples/custom-behavior.md) — a focused, minimal worked example.
- [`packages/zarvan_core/README.md`](../../packages/zarvan_core/README.md)'s "The agent-facing API" section.

## Two doors, one idea: real-time and turn-based

The cooperative principle — *an agent proposes, the engine applies* — has two
shapes in this engine:

| | Real-time (platformer) | Turn-based (strategy) |
|---|---|---|
| Agent type | `Behavior` | `TurnAI` (or any external program) |
| Reads | `WorldView` (live observation) | `World.toJson()` snapshot, or the typed stores |
| Proposes | an `Action` returned from `decide` | `Order`s passed to `submitOrder` |
| Applied by | `AISystem` | `OrderSystem` |
| Refused when | the action implementation rejects it | not that team's turn, game over, or the order is illegal |
| Cadence | every tick | once per team turn |

For untrusted external agents, expose a validated protocol with filtered observations, not the mutable Dart world. `TurnAI.playTurn` receives `World` and is also trusted code; built-in strategies follow order and fog rules by convention.

For a complete turn-based agent that sees only JSON, see
[Tutorial 3](../tutorials/03-agent-driven-game.md); for a hand-written
opponent, the [custom TurnAI recipe](../examples/custom-turn-ai.md).
