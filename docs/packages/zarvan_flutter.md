# zarvan_flutter

**Runtime:** Flutter · **Audience:** developers · **Depends on:** `zarvan_core`

The Flutter shell: rendering, input, camera, audio and save/load. It contains
**no gameplay logic**. Gameplay, physics and AI belong in `zarvan_core`.

## What's inside

| Area | What it gives you |
|---|---|
| `Game`, `Scene`, `runGame` | You extend `Game` and return the first `Scene`; `runGame` handles orientation, asset loading, lifecycle, scene switching and the render loop. |
| `GameConfig` | Atlases, audio, startup splash hand-off and per-game settings. |
| Rendering | Sprites and atlases, tile renderer, parallax, particles, lighting (`Light2D`), z-index draw order, `ClipShape` masking, flat shapes, post-processing, image capture. |
| Input | Keyboard, pointer, mobile touch controls, joystick, haptics. |
| Camera | Follow, bounds, shake. |
| Audio | `AudioManager` and sound events. |
| Save/load | Persist and restore a `World`. |
| UI | Splash screen and the UI builder. |
| Error reporting | `ErrorReportingManager` and reporters. |
| Testing | Test-support widgets for headless scene tests. |

Call `registerFlutterComponents(world)` next to `registerCoreComponents(world)` so
the Flutter-side components serialize like everything else.

## Quick example

```dart
class MyGame extends Game {
  @override
  GameConfig get config => const GameConfig();

  @override
  Scene createInitialScene() => MyScene();
}

void main() => runGame(MyGame());
```

See [Rendering](../concepts/rendering.md), [Lighting](../concepts/lighting.md),
[Post-processing](../concepts/post-processing.md) and the
[splash screen](../concepts/splash-screen.md).

## Install

Not on pub.dev yet (pre-1.0). Depend on it through git, the same way `zarvan create` wires generated projects:

```yaml
dependencies:
  zarvan_flutter:
    git:
      url: https://github.com/arashrasoulzadeh/zarvan.git
      path: packages/zarvan_flutter
      ref: main
```

## Links

- [Source and README](https://github.com/arashrasoulzadeh/zarvan/tree/main/packages/zarvan_flutter)
- [Changelog](https://github.com/arashrasoulzadeh/zarvan/blob/main/packages/zarvan_flutter/CHANGELOG.md)
- [Generated API reference](https://meetarash.ir/zarvan/api/zarvan_flutter/)
- [All packages](../packages.md)
