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

A `null` config swaps immediately. The previews below are looping illustrations
of each motion, not recordings of the engine; shader effects are approximated.

## The gallery

<div class="zv-showcase-grid" markdown>

<article class="zv-showcase-card" markdown>
<div class="zv-output zv-tr zv-tr--fade" aria-hidden="true"><i class="zv-tr-a">A</i><i class="zv-tr-b">B</i><i class="zv-tr-fx"></i></div>

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
<div class="zv-output zv-tr zv-tr--iris" aria-hidden="true"><i class="zv-tr-a">A</i><i class="zv-tr-b">B</i><i class="zv-tr-fx"></i></div>

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
<div class="zv-output zv-tr zv-tr--crossfade" aria-hidden="true"><i class="zv-tr-a">A</i><i class="zv-tr-b">B</i><i class="zv-tr-fx"></i></div>

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
<div class="zv-output zv-tr zv-tr--slide-left" aria-hidden="true"><i class="zv-tr-a">A</i><i class="zv-tr-b">B</i><i class="zv-tr-fx"></i></div>

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
<div class="zv-output zv-tr zv-tr--slide-up" aria-hidden="true"><i class="zv-tr-a">A</i><i class="zv-tr-b">B</i><i class="zv-tr-fx"></i></div>

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
<div class="zv-output zv-tr zv-tr--dissolve" aria-hidden="true"><i class="zv-tr-a">A</i><i class="zv-tr-b">B</i><i class="zv-tr-fx"></i></div>

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
<div class="zv-output zv-tr zv-tr--portal" aria-hidden="true"><i class="zv-tr-a">A</i><i class="zv-tr-b">B</i><i class="zv-tr-fx"></i></div>

### `portal`

A ring grows from a point you choose (`portalX`, `portalY`) in a colour you choose; `portalReverse` collapses it instead.

```dart
SceneTransitionConfig(
  type: SceneTransitionType.portal,
  portalX: 0.3, portalY: 0.6,
  portalColorArgb: 0xFF7FD6FF,
)
```
</article>

<article class="zv-showcase-card" markdown>
<div class="zv-output zv-tr zv-tr--pageturn" aria-hidden="true"><i class="zv-tr-a">A</i><i class="zv-tr-b">B</i><i class="zv-tr-fx"></i></div>

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
<div class="zv-output zv-tr zv-tr--lanterns" aria-hidden="true"><i class="zv-tr-a">A</i><i class="zv-tr-b">B</i><i class="zv-tr-fx"></i></div>

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
<div class="zv-output zv-tr zv-tr--ripple" aria-hidden="true"><i class="zv-tr-a">A</i><i class="zv-tr-b">B</i><i class="zv-tr-fx"></i></div>

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
| `portalX`, `portalY`, `portalColorArgb`, `portalReverse` | Where the portal ring starts, its colour and its direction. |
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
