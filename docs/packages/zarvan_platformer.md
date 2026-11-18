# zarvan_platformer

**Runtime:** Flutter · **Audience:** developers · **Depends on:** `zarvan_core`, `zarvan_flutter`

Platformer-genre gameplay. Genre-general data (like `TileMap`) lives in
`zarvan_core`; this package holds only platformer **logic** that operates on it.

## What's inside

| Area | What it gives you |
|---|---|
| `installPlatformerSystems` | One call that registers every system in the correct order. |
| Physics | Gravity, jump, tile and platform collision, slopes, one-way tiles, pushables. |
| `PlatformerController` | Movement feel: coyote time, jump buffering, variable jump. |
| Combat | Damage and health, guard, poise and parry, melee combos, ranged weapons. |
| AI | Patrol and follow behaviors, telegraphed enemy combat AI, platformer-aware pathfinding. |
| Animation | Movement-driven animation. |
| Collectibles | Inventory and pickups. |
| Spawn helpers | `spawnPlayer`, `spawnEnemy` and friends. |

## Quick example

```dart
final world = World(width: 800, height: 480);
registerCoreComponents(world);
registerFlutterComponents(world);
registerPlatformerComponents(world);

installPlatformerSystems(world);   // gravity, jump, collision, combat, animation
```

System order matters (a jump ordering bug was caught by a regression test), so
use `installPlatformerSystems` rather than adding systems by hand. See
[Platformer gameplay](../concepts/platformer.md) and
[tutorial 1](../tutorials/01-hello-world.md).

## Install

Not on pub.dev yet (pre-1.0). Depend on it through git, the same way `zarvan create` wires generated projects:

```yaml
dependencies:
  zarvan_platformer:
    git:
      url: https://github.com/arashrasoulzadeh/zarvan.git
      path: packages/zarvan_platformer
      ref: main
```

## Links

- [Source and README](https://github.com/arashrasoulzadeh/zarvan/tree/main/packages/zarvan_platformer)
- [Changelog](https://github.com/arashrasoulzadeh/zarvan/blob/main/packages/zarvan_platformer/CHANGELOG.md)
- [Generated API reference](https://meetarash.ir/zarvan/api/zarvan_platformer/)
- [All packages](../packages.md)
