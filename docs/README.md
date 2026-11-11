---
template: home.html
hide:
  - toc
---

<section class="zv-landing" markdown>

<div class="zv-landing__hero" markdown>
<div class="zv-landing__copy" markdown>
<p class="zv-kicker">ZARVAN · زروان</p>

# Build worlds that think.

ZARVAN is a simulation-first, agent-native 2D game engine for Dart. Build a
deterministic world once, then let people, tools, and AI agents observe it,
change it, and play inside it.

<div class="zv-landing__actions" markdown>
[:material-arrow-right: **Read the docs**](getting-started.md){ .md-button .md-button--primary }
[:material-github: **View on GitHub**](https://github.com/arashrasoulzadeh/zarvan){ .md-button }
</div>
<p class="zv-landing__note">Pure Dart core · Flutter shell · JSON state · 2D by design</p>
</div>
<div class="zv-landing__mark" aria-hidden="true"><img src="assets/logo.png" alt="" width="128" height="128"><span></span></div>
</div>

<div class="zv-landing__principles" markdown>
<div markdown><span class="zv-number">01</span>
### Simulation first
Fixed timesteps, seeded randomness, ECS, and headless tests keep the same
world reproducible on a phone, a server, or in CI.
</div>
<div markdown><span class="zv-number">02</span>
### Agents are native
Agents receive read-only views and propose validated actions. World state is
plain JSON, so it can be inspected, patched, replayed, and evaluated.
</div>
<div markdown><span class="zv-number">03</span>
### Data stays portable
Levels, components, commands, and content are data. Keep game rules in Dart,
keep authoring flexible, and keep the engine small.
</div>
</div>

<div class="zv-landing__split" markdown>
<div markdown>
<p class="zv-kicker">A small mental model</p>
## The engine is the world.
`zarvan_core` owns simulation and authority. `zarvan_flutter` renders it and
connects input, audio, and platform services. Optional packages add genres,
schemas, CLI tooling, and agent APIs without changing the core.

[:octicons-arrow-right-24: Explore the architecture](concepts/architecture.md)
</div>
<div class="zv-code-card" markdown>
```dart
final game = GameBuilder.create(width: 320, height: 240);
final player = game.spawn([
  Position(10, 10),
  Velocity(60, 0),
]);

game.update(1 / 60);
final snapshot = game.world.toJson();
```
<span>One deterministic tick. One inspectable snapshot.</span>
</div>
</div>

<div class="zv-landing__cta" markdown>
<div markdown>## Start with the path that fits.</div>
<div class="zv-landing__links" markdown>
[:material-rocket-launch: **Getting started**](getting-started.md){ .md-button .md-button--primary }
[:material-robot-outline: **Agent hub**](agents.md){ .md-button }
[:material-book-open-variant: **Tutorials**](tutorials/README.md){ .md-button }
[:material-translate: **فارسی**](fa/index.md){ .md-button }
</div>
</div>
</section>
