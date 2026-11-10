---
title: Performance and benchmarks
description: Reproducible performance notes for ZARVAN's rendering and simulation paths.
---

# Performance and benchmarks

ZARVAN keeps performance notes close to the feature they measure. The checked-
in post-processing benchmark below is a representative profile, not a promise
for every device or scene.

## Post-processing cost

The benchmark uses 400 seeded procedural sprites and measures `FrameTiming`
after warm-up. Lower is better. Values are milliseconds per frame.

| Preset | Web avg · capped 1.6 MP | Android avg |
|---|---:|---:|
| Off | 3.14 ms | 4.55 ms |
| Bloom | 13.83 ms | 25.38 ms |
| CRT | 13.84 ms | 11.36 ms |
| Everything | 14.53 ms | 24.22 ms |

![Post-processing presets](img/postfx-presets.jpg)

The pixel cap reduces the web `everything` preset from **36.03 ms** at 5.2 MP
to **14.53 ms** at 1.6 MP in this run. The full dataset is versioned at
[`docs/data/postfx-benchmark.json`](https://github.com/arashrasoulzadeh/zarvan/blob/main/docs/data/postfx-benchmark.json).

![Frame time by preset](img/postfx-frame-time.svg)

![Snapshot cost by megapixels](img/postfx-cost-vs-pixels.svg)

## Reproduce locally

Run the benchmark suite from the package that owns the hot path, then compare
the output with the checked-in dataset. For rendering work, use a profile build
and record device, resolution, Flutter version, warm-up, sample count, and
whether the run is web/CanvasKit or native/Impeller.

```bash
cd packages/zarvan_flutter
flutter pub get
flutter test
flutter test benchmark --reporter expanded
```

!!! warning "Interpret results in context"
    Frame time depends on resolution, refresh rate, backend, thermal state,
    and scene composition. Report p95 as well as average when a change is
    user-visible.

## More measurements

- [Rendering pipeline](concepts/rendering.md)
- [Performance concepts](concepts/performance.md)
- [Post-processing and screen effects](concepts/post-processing.md)
