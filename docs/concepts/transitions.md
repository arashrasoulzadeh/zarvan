---
title: Transitions
description: Every ZARVAN scene transition with a sample of each, how to choose one, and how to write your own.
---

# Transitions

A scene transition hides the swap between two scenes. ZARVAN ships **twelve**
built-in types, from a plain fade to shader effects that bend the real screen.
Every one is a value of `SceneTransitionType`, configured by one JSON-friendly
`SceneTransitionConfig`.

```dart
sceneController.loadSceneWithTransition(
  NextScene(),
  const SceneTransitionConfig(
    type: SceneTransitionType.ripple,
    duration: 0.8,
    easing: EasingType.easeInOutQuad,
  ),
);
```

A `null` config swaps immediately.

## Play every transition

This is the live ZARVAN runtime (`zarvan_core` and `zarvan_flutter`, compiled to the web), swapping between a blue
scene and a red scene with the real engine: nothing here is a mock-up. Pick a type; the scenes switch every couple
of seconds, or tap the screen to switch now.

<div class="zv-live-demo" data-app="../../showcase/app/">
<div class="zv-live-bar">
<button class="is-active" data-query="demo=transitions&type=ripple" data-hint="ripple: tap the screen to switch scenes">ripple</button>
<button data-query="demo=transitions&type=pageTurn" data-hint="pageTurn: tap the screen to switch scenes">pageTurn</button>
<button data-query="demo=transitions&type=lanterns" data-hint="lanterns: tap the screen to switch scenes">lanterns</button>
<button data-query="demo=transitions&type=portal" data-hint="portal: tap the screen to switch scenes">portal</button>
<button data-query="demo=transitions&type=fade" data-hint="fade: tap the screen to switch scenes">fade</button>
<button data-query="demo=transitions&type=iris" data-hint="iris: tap the screen to switch scenes">iris</button>
<button data-query="demo=transitions&type=crossfade" data-hint="crossfade: tap the screen to switch scenes">crossfade</button>
<button data-query="demo=transitions&type=pixelDissolve" data-hint="pixelDissolve: tap the screen to switch scenes">pixelDissolve</button>
<button data-query="demo=transitions&type=slideLeft" data-hint="slideLeft: tap the screen to switch scenes">slideLeft</button>
<button data-query="demo=transitions&type=slideRight" data-hint="slideRight: tap the screen to switch scenes">slideRight</button>
<button data-query="demo=transitions&type=slideUp" data-hint="slideUp: tap the screen to switch scenes">slideUp</button>
<button data-query="demo=transitions&type=slideDown" data-hint="slideDown: tap the screen to switch scenes">slideDown</button>
<a data-open href="../../showcase/app/?demo=transitions&type=ripple">Open full screen ↗</a>
</div>
<div class="zv-live-stage"><div class="zv-live-box"><div class="zv-spin"><i></i>Loading the engine…</div><iframe src="../../showcase/app/?demo=transitions&type=ripple" title="Live ZARVAN transition demo" loading="lazy"></iframe></div></div>
<div class="zv-live-hint">ripple: tap the screen to switch scenes</div>
</div>

## Each type in code

<div class="zv-showcase-grid" markdown>

<article class="zv-showcase-card" markdown>
### `fade`

A solid colour covers the scene, the swap happens behind it, then it clears. Not a snapshot: drawn by a screen-tint component.

```dart
SceneTransitionConfig(
  type: SceneTransitionType.fade,
  duration: 0.5,
  fadeColorArgb: 0xFF000000,
)
```
</article>

<article class="zv-showcase-card" markdown>
### `iris`

A circle closes on the outgoing scene and opens on the next. Drawn by a clip component.

```dart
SceneTransitionConfig(
  type: SceneTransitionType.iris,
  duration: 0.6,
)
```
</article>

<article class="zv-showcase-card" markdown>
### `crossfade`

The outgoing scene fades out over the new one, which is already loaded underneath.

```dart
SceneTransitionConfig(
  type: SceneTransitionType.crossfade,
  duration: 0.4,
)
```
</article>

<article class="zv-showcase-card" markdown>
### `slideLeft`

The outgoing scene slides off to the left. `slideRight`, `slideUp` and `slideDown` are the same with another direction.

```dart
SceneTransitionConfig(
  type: SceneTransitionType.slideLeft,
  duration: 0.35,
)
```
</article>

<article class="zv-showcase-card" markdown>
### `slideUp`

Slide off upward: a good fit for opening a menu or a pause screen.

```dart
SceneTransitionConfig(
  type: SceneTransitionType.slideUp,
  easing: EasingType.easeOutCubic,
)
```
</article>

<article class="zv-showcase-card" markdown>
### `pixelDissolve`

The outgoing scene breaks into blocks that vanish in a scattered order. The same `seed` always gives the same pattern.

```dart
SceneTransitionConfig(
  type: SceneTransitionType.pixelDissolve,
  duration: 0.7,
)
```
</article>

<article class="zv-showcase-card" markdown>
### `portal`

A ring grows from the centre in a colour you choose (`portalColorArgb`); `portalReverse` collapses it instead.

```dart
SceneTransitionConfig(
  type: SceneTransitionType.portal,
  portalColorArgb: 0xFF7FD6FF,
)
```
</article>

<article class="zv-showcase-card" markdown>
### `pageTurn`

The real screen is lifted from its right edge and rolled toward the left over the next scene, with the paper's back showing and a shadow ahead of the curl. Drawn by the `pageturn.frag` shader.

```dart
SceneTransitionConfig(
  type: SceneTransitionType.pageTurn,
  duration: 0.9,
)
```
</article>

<article class="zv-showcase-card" markdown>
### `lanterns`

Three layers of swaying, flickering paper lanterns on strings carry the screen up and away, lighting its underside (`lanterns.frag`).

```dart
SceneTransitionConfig(
  type: SceneTransitionType.lanterns,
  duration: 1.1,
)
```
</article>

<article class="zv-showcase-card" markdown>
### `ripple`

A drop falls where the player touched and rings bend the real screen as they pass; the next scene appears behind the leading ring (`ripple.frag`). Start it at the last touch with `originX` / `originY`.

```dart
SceneTransitionConfig(
  type: SceneTransitionType.ripple,
  originX: touch.dx / size.width,
  originY: touch.dy / size.height,
)
```
</article>

</div>

## Choosing one

| Type | Kind | Feels like | Cost |
|---|---|---|---|
| `fade`, `iris` | Components in the world (cover, swap, reveal) | Classic, neutral | Lowest |
| `crossfade`, `slideLeft/Right/Up/Down`, `pixelDissolve`, `portal` | Snapshot of the outgoing scene | Navigation, menus | Low |
| `pageTurn`, `lanterns`, `ripple` | Snapshot plus a fragment shader | A moment worth noticing | One shader |

- **Two-phase vs. one-phase.** `fade` and `iris` play a cover phase and a reveal phase of `duration` seconds each,
  so a call takes `2 * duration`. Snapshot types (`SceneTransitionType.usesSnapshot`) capture the outgoing frame,
  load the next scene underneath at once, and play once.
- **Shaders are compiled at start-up** and awaited before a transition, so a shader effect never silently falls back to a slide.
- **Keep it short.** Under a second for navigation. Reserve `lanterns` and `pageTurn` for entering or leaving a whole mode.

## Configuration

| Field | Meaning |
|---|---|
| `type` | One of the values above. |
| `duration` | Seconds per phase. |
| `easing` | Any `EasingType`. |
| `fadeColorArgb` | The colour a `fade` goes through (default black). |
| `portalColorArgb`, `portalReverse`, `portalX`, `portalY` | The portal ring's colour, its direction, and its centre in screen pixels. |
| `originX`, `originY` | Where `ripple` starts, as fractions of the screen (0..1). |

The config round-trips as JSON, so a level or scene file can name its own transition:

```json
{ "type": "ripple", "duration": 0.8, "originX": 0.5, "originY": 0.7 }
```

## In a quiz game

`zarvan_quiz` picks a transition by name through `QuizKit`:

| Kind | Look |
|---|---|
| `ripple` (default, both ways) | Water rings from the player's last touch. |
| `page` | The screen curls away from the right. |
| `lanterns` | Paper lanterns lift the screen off the top. |
| `curtain`, `kashi`, `ink`, `veil` | Overlay effects drawn over the next screen. |
| `verse` | Poem words swirl in over an ink wash. |

```dart
QuizKit(
  transitionKind: quizPageTurnTransition,      // entering a game
  returnTransitionKind: quizLanternsTransition, // back to the menu
)
```

Set `transitions: false` to turn them all off.

## Related

- [Cinematics and scene transitions](cinematics.md): scripted sequences inside a scene.
- [Post-processing](post-processing.md) and [Rendering](rendering.md): the shader pipeline the snapshot effects use.
- [`zarvan_flutter`](../packages/zarvan_flutter.md), [`zarvan_quiz`](../packages/zarvan_quiz.md).
