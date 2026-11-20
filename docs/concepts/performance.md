# Performance

Measure before you optimise. The engine gives you a per-system profiler, a set of benchmarks,
and a fixed-timestep loop that keeps the simulation cost predictable.

The profiler samples are executed by
`packages/zarvan_core/test/doc_examples_performance_test.dart`.

## Find the slow system: `WorldProfiler`

```dart
world.profiler = WorldProfiler();     // off by default: a world without one pays nothing
// ... run some frames ...
print(world.profiler!.format());
```

```text
# example output - your numbers will differ
step 0.412ms  events 0.020ms  entities 1840
collision  avg 0.188ms  max 0.390ms
movement   avg 0.075ms  max 0.120ms
...
```

- `report()` lists systems slowest first, each with `lastMs`, a smoothed `averageMs` and the worst
  `maxMs` since the last `reset()`.
- `stepMs`, `eventsMs` and `entityCount` describe the latest step; `stepHistory` keeps the last
  120 step times (a ring buffer) for a graph.
- `toJson()` gives the same data for tooling and agents.
- In the [studio](../studio/user-guide.md#play-test), the preview has a **Profiler** switch that
  shows these numbers live.

The profiler measures *simulation*. Rendering cost (drawing thousands of sprites, shaders,
lighting) is separate: a world can step in 0.3 ms and still render slowly. On a device, use Flutter's
own tools (DevTools performance overlay) for that side.

## Benchmarks

`zarvan_core/benchmark/` has micro-benchmarks for the pieces that scale with entity count:

```bash
cd packages/zarvan_core
dart run benchmark/world_step_benchmark.dart
dart run benchmark/collision_system_benchmark.dart
dart run benchmark/entity_churn_benchmark.dart
dart run benchmark/particle_system_benchmark.dart
dart run benchmark/world_view_benchmark.dart
```

Each prints a time per run for several entity counts (for example `WorldStep(movement only,
n=1000)`), so you can see whether a change is linear or worse. Numbers depend on the machine; compare
before and after on the *same* one, and run twice. The CLAUDE.md rule for this repo is to re-run the
relevant benchmark for any change to a hot path.

Benchmark classes report per run of `run()`, not per batch: the harness's `exercise()` calls `run()` ten
times, so every benchmark here overrides `exercise()` to call it once. Do not compare numbers taken before
that fix. `collision_system_benchmark.dart` sizes the world to its entity count (a fixed-width world made
large counts pile into one row and look quadratic), so read its growth as the system's real scaling.
`zarvan_flutter/benchmark/sprite_benchmark_test.dart` covers the sprite draw path
(`flutter test benchmark --reporter expanded`).

## Rendering cost and battery

- **Cap the frame rate** a game does not need. `GameConfig.maxFps` (also `"maxFps"` in `game_config.json`)
  throttles the ticker; a quiz or turn-based strategy game looks the same at 30 fps and does about half the
  work. New strategy projects from `zarvan create` start at 30.
- **A paused `EngineView` costs nothing.** `paused: true` mutes its ticker, so the app is not woken per
  frame while a menu or dialog covers the game.
- **Off-screen things are not drawn.** Sprites, shapes and particle dots wholly outside the view (plus
  `EngineView.cullBufferPx`, 96 by default, so a sprite is never popped at the edge) are skipped. The check is
  `spriteOnScreen` and is conservative: it uses the sprite's bounding circle, so it never hides a visible one.
- **Shaders compile before the first frame.** `EngineWarmup` primes lighting, GPU-shadow, normal-map and the
  shader effects a world uses (`effect:<kind>`), so the first use does not hitch. The loading screen
  also loads the post-processing shader when `Game.postFx` is already on; if you switch it on later, call
  `ShaderPostProcessed.warmUp()` first.
- **Rank shaders before tuning them.** `dart run tool/shader_cost.dart` (in `packages/zarvan_flutter`) lists
  every fragment shader by the transcendental calls and texture reads a pixel pays, weighted by loops. It is a
  static estimate (a GPU cannot be timed from Dart), so use it to pick what to profile on a device, and
  profile there before changing how a shader looks.
- **A `maxFps` cap really sleeps.** When the cap leaves room between frames (30 fps on a 60 or 120 Hz
  display), `EngineView` stops its ticker until the next frame is due instead of waking at the display rate
  to skip frames. A cap close to the display rate (60 on 60 Hz) keeps the vsync ticker, since sleeping would
  save nothing.
- **Trace a slow start.** With `logFrameTimings` on, one `[zarvan:startup]` line lists each phase of the first
  load (`init`, `font`, `populate`, `assets`, `warm-up`, `scene-ready`, `splash-held`, `first-frame`) as
  `label=total(+own)ms`.
- **Measure frames on a device** with `GameConfig.logFrameTimings` (a game can wire it to a
  `--dart-define`), which logs `FrameTimingMonitor` percentiles every 3 s, including `fps=`, the frames actually rendered per second. A
  game capped at 30 that reports 120 is still waking the display every frame.

## Keep the step cost predictable

- **Fixed timestep.** Set `GameConfig.fixedTimestepSeconds` (for example `1 / 60`, or `1 / 20` for
  strategy games). The simulation then always advances by the same `dt`, so results are identical across devices -
  which replays and multiplayer need - and one slow frame cannot produce one huge step.
- **Iterate by entity id** in systems that must be deterministic; a component store's dense order
  depends on add/remove history (see the real-time strategy guide's determinism section).
- **Cap what grows**: particle `rate × lifetime`, projectiles, and anything spawned per frame all
  count as entities and show up in `entityCount`.
- **Avoid per-step allocation** in systems you write (build lists once, reuse them); `Archetype`
  gives dense iteration over entities that share a component set when a hot loop needs it.

## Background work: `JobSystem`

For CPU-heavy work that does not need the live world, `JobSystem` runs a `Job` on a pool of worker
isolates (default 3):

```dart
class SumJob implements Job<List<int>, int> {
  @override
  int run(List<int> input) => input.fold(0, (a, b) => a + b);
}

final jobs = JobSystem(workerCount: 2);
final total = await jobs.dispatch(SumJob(), [1, 2, 3]);                 // 6
final squares = await jobs.dispatchBatch(SquareJob(), [1, 2, 3]);       // results in input order
jobs.shutdown();
```

- A job is a **class** (a closure cannot cross isolates) and its input and output must be sendable:
  numbers, strings, lists, maps and plain objects, not entities of a live `World` or anything holding
  native resources. Copy the data you need into the input.
- An error thrown in a job is rethrown to the caller of `dispatch`; the system keeps working.
- Workers start on the first dispatch (or `start()`); concurrent callers share that start.
- `shutdown()` fails any jobs still in flight with a `StateError`, and the system can be started
  again afterwards.
- It costs a copy of the input and output per job, so it pays off for work that takes noticeably
  longer than that (broadphase over thousands of entities, large searches), not for small tasks.
- Isolates are unavailable on the web: do not use it in a game that ships there.
- Two ready-made jobs: `CollisionBroadphaseJob` and `PathfindingJob` (four-way A* over a tile grid,
  returning tile centres; it knows nothing about gravity, so it is for top-down or flying movement).

These behaviours are tested in `packages/zarvan_core/test/job_system_test.dart`.
