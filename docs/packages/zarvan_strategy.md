# zarvan_strategy

**Runtime:** Flutter · **Audience:** developers · **Depends on:** `zarvan_core`, `zarvan_flutter`

Turn-based strategy assembly. The rules (turn clock, orders, grid navigation,
combat, fog of war, selection) live in `zarvan_core` under `lib/src/turn/`
because they are genre-general. This package wires them together in the correct
order, the way `zarvan_platformer` does for platformers.

## What's inside

| Piece | What it does |
|---|---|
| `installStrategySystems` | Registers vision, orders, AI turn, turn, win condition, grid-to-world, selection markers and move-range highlight in the right order. |
| `spawnStrategyUnit` | Spawns a unit with grid position, team and action points. |
| `startTurnBasedGame` | Starts the turn clock once units exist. |
| `GridTapController` | Turns a tap into a select or order. |
| `MoveRangeHighlightSystem`, `FogShadeSystem` | Draw reachable cells and fog. |
| `smooth_motion`, `online_view` | Smoothed unit movement and an online-match view. |

## Quick example

```dart
installStrategySystems(
  world,
  navigator: GridNavigator(cols: 8, rows: 8, terrainCost: (c, r) => 1),
  cellSize: 48,
  fog: true,
  aiTeams: {'blue': AggressiveAI()},
);
spawnStrategyUnit(world, team: 'red', col: 1, row: 6, cellSize: 48);
spawnStrategyUnit(world, team: 'blue', col: 5, row: 1, cellSize: 48);
startTurnBasedGame(world, ['red', 'blue']);
```

## Agents

All turn state is world state and serializes with `World.toJson()`. An agent
acts through `submitOrder(world, unit, MoveOrder(c, r) | AttackOrder(id))`, the
same path a tap uses. Scaffold a starter with
`zarvan create my_game --template strategy_game`. See
[Turn-based strategy](../concepts/turn-based-strategy.md).

## Install

Not on pub.dev yet (pre-1.0). Depend on it through git, the same way `zarvan create` wires generated projects:

```yaml
dependencies:
  zarvan_strategy:
    git:
      url: https://github.com/arashrasoulzadeh/zarvan.git
      path: packages/zarvan_strategy
      ref: main
```

## Links

- [Source and README](https://github.com/arashrasoulzadeh/zarvan/tree/main/packages/zarvan_strategy)
- [Changelog](https://github.com/arashrasoulzadeh/zarvan/blob/main/packages/zarvan_strategy/CHANGELOG.md)
- [Generated API reference](https://meetarash.ir/zarvan/api/zarvan_strategy/)
- [All packages](../packages.md)
