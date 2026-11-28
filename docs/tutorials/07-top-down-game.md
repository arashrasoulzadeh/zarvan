# 7 · A top-down collection game

**You will build:** a top-down game with four-direction movement and collectible coins. The starter uses `zarvan_core` and `zarvan_flutter`, not platformer gravity or jump systems.

## 1. Create and run

Follow [Getting started](../getting-started.md) to install the CLI.

```bash
zarvan create my_topdown --template topdown_game
cd my_topdown
flutter run
```

Move the player with the arrow keys or the on-screen joystick. Touch the coins to remove them. The generated game draws its own simple sprite atlas.

## 2. Understand the starter

Open `lib/main.dart`. The scene spawns a player with position, velocity, collider and sprite components, then five tagged coins. The input system runs in `SystemPhase.prePhysics` and the movement system advances the position. The coin pickup system uses a proximity query and deferred destruction.

The following extract is from the starter (inside `MainScene.populate`, where `world`, `input` and `_player` already exist):

```dart
SystemPresets.core(world);
world.addSystemFn('topdown-input', (world, dt) {
  final s = input.state;
  final v = world.getComponent<Velocity>(_player)!;
  v.x = ((s.isPressed('right') ? 1 : 0) -
      (s.isPressed('left') ? 1 : 0)) * 160.0 + s.axis('moveX') * 160;
  v.y = ((s.isPressed('down') ? 1 : 0) -
      (s.isPressed('up') ? 1 : 0)) * 160.0 + s.axis('moveY') * 160;
}, phase: SystemPhase.prePhysics);

world.addSystemFn('coin-pickup', (world, dt) {
  final p = world.getComponent<Position>(_player)!;
  for (final id in world.findNear(p.x, p.y, 22, exclude: _player)) {
    if (world.hasTag(id, 'coin')) world.commands.destroy(id);
  }
});
```

See the [canonical template source](../../packages/zarvan_cli/templates/topdown_game/lib/main.dart.tmpl). This is an extract, not a standalone program.

## 3. Make a change

Change the movement speed from 160 to 100 in both axes; rerun and confirm movement is slower. Add another coin with a unique position. Use deferred `world.commands.destroy` when removing entities during queries.

The starter creates its world in Dart, so there is no authored level file for an agent to edit yet. To make the layout data-driven, move entity definitions into level JSON and load them through `Level.loadInto`; see [Content as data](../concepts/content-as-data.md).

## 4. Validate

```bash
flutter analyze
flutter test
```

Manually check movement in every direction and collection of each coin. For more complex games, add headless tests using [GameTester](../concepts/authoring.md).

Next: [pickups and waves](../examples/pickups-doors-waves.md), [ECS](../concepts/ecs.md), [rendering](../concepts/rendering.md).
