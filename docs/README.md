---
template: home.html
hide:
  - toc
---

<section class="zv-landing" markdown>

<div class="zv-landing__hero" markdown>
<div class="zv-landing__copy" markdown>
<p class="zv-kicker">ZARVAN / DART / 2D</p>

# A game engine for worlds that stay understandable.

Build deterministic 2D games with a pure-Dart simulation, a Flutter renderer,
and an API that both developers and agents can inspect.

<div class="zv-landing__actions" markdown>
[:material-arrow-right: **Get started**](getting-started.md){ .md-button .md-button--primary }
[:material-book-open-variant: **Read the docs**](packages.md){ .md-button }
</div>
</div>
<div class="zv-landing__showcase" markdown>
<img src="img/strategy-skirmish.png" alt="A ZARVAN strategy game scene" loading="eager">
<div class="zv-showcase__caption"><strong>Simulation first.</strong><span>Rendering is a shell around the world.</span></div>
</div>
</div>

<div class="zv-landing__proof" markdown>
<span>Pure Dart core</span><span>Deterministic simulation</span><span>JSON world state</span><span>Flutter on Android · iOS · Web</span>
</div>

<div class="zv-landing__section-head" markdown>
<p class="zv-kicker">Why ZARVAN</p>
## Small surface. Serious control.
</div>

<div class="zv-landing__principles" markdown>
<div markdown><span class="zv-number">01</span>
### Reproducible by default
Fixed timesteps, seeded randomness, ECS, and headless tests make a world
repeatable on a phone, a server, or in CI.
</div>
<div markdown><span class="zv-number">02</span>
### Open to agents
Agents see read-only world views and submit validated actions. State is plain
JSON: easy to inspect, replay, evaluate, and patch.
</div>
<div markdown><span class="zv-number">03</span>
### Modular at the edges
Keep simulation in `zarvan_core`; add rendering, genres, schemas, CLI tooling,
or agent APIs as focused packages.
</div>
</div>

<div class="zv-landing__split" markdown>
<div markdown>
<p class="zv-kicker">The first five minutes</p>
## From world to frame.
Create entities, advance the simulation, and serialize the result. The same
core can run without Flutter, while the shell handles rendering, input, audio,
and platform services.

[:octicons-arrow-right-24: See the architecture](concepts/architecture.md)
</div>
<div class="zv-code-card" markdown>
```dart
final game = GameBuilder.create(width: 320, height: 240);
game.spawn([Position(10, 10), Velocity(60, 0)]);
game.update(1 / 60);

final state = game.world.toJson();
```
<span>One tick. One inspectable snapshot.</span>
</div>
</div>

<div class="zv-landing__cta" markdown>
<div markdown><p class="zv-kicker">Keep exploring</p>## The documentation is the product tour.</div>
<div class="zv-landing__links" markdown>
[:material-rocket-launch: **Start building**](getting-started.md){ .md-button .md-button--primary }
[:material-robot-outline: **For agents**](agents.md){ .md-button }
[:material-code-tags: **Examples**](examples/README.md){ .md-button }
[:material-translate: **فارسی**](fa/index.md){ .md-button }
</div>
</div>
</section>
