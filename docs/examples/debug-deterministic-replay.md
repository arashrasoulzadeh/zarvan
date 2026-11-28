# Recipe: diagnose a divergent replay

**Audience:** developers and agents investigating reproducibility. **Runtime:** pure Dart.

The goal is to find the first differing tick, not to compare only the final world.

## Capture the inputs

Record the engine Git ref, initial level/content version, world seed, system order, fixed timestep, and all external input or agent orders by tick. Copy mutable input maps before recording them with `ReplayRecorder`. The recorder stores arbitrary input data and timing; it does not automatically capture every simulation decision.

## Reproduce with two worlds

```dart
import 'package:zarvan_core/zarvan_core.dart';

World makeWorld() {
  final world = World(width: 320, height: 240, seed: 42);
  registerCoreComponents(world);
  world.addSystem(MovementSystem());
  world.spawnWith([Position(0, 0), Velocity(10, 0)]);
  return world;
}

void main() {
  final a = makeWorld();
  final b = makeWorld();
  for (var tick = 0; tick < 60; tick++) {
    a.step(1 / 60);
    b.step(1 / 60);
    // Compare canonicalized snapshot JSON at this tick in a test.
  }
}
```

In a regression test, compare `WorldSnapshot.capture(a).toJson()` with the equivalent snapshot from `b` after every step. Dart's test `equals` matcher compares nested maps and lists structurally. If a mismatch appears, report the tick, entity ID, component name, expected value and actual value. Keep the seed and inputs fixed while reducing the reproduction.

## Diagnose the first differing tick

| Symptom | Inspect |
|---|---|
| Different random choice | World seed and `world.random.state`; find unseeded random generators |
| Different position or timer | Exact step duration, number of steps, system phase/order |
| Different entity IDs | Spawn/destruction order, deferred commands and initialization |
| Different agent decision | Observations, behavior memory, order of actions |
| Snapshot missing data | Component registration and serializers |
| Replay diverges after restore | System-owned mutable state, queued callbacks, timers or external side effects |

## Choose the right state API

`World.toJson()` is the inspection format. `applyPatch` updates existing entities. `WorldSnapshot.capture(world)` captures registered entity components, tick and random state; `snapshot.restoreInto(world)` restores that data into a configured world. It does not serialize arbitrary Dart callbacks, installed systems or external resources. Rebuild the same systems and include game-specific state needed by the simulation.

A fixed timestep and seed are necessary for reproducibility, not a guarantee of it. Keep real-time UI, audio and network arrival timing outside deterministic game rules.

See [ECS](../concepts/ecs.md), [networking](../concepts/networking.md) and [save/load](save-load.md).
