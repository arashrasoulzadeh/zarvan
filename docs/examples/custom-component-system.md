# Recipe: a custom component and system

**Audience:** Dart game developers and coding agents. **Runtime:** pure Dart. Use this pattern for gameplay data that must serialize, validate and step without Flutter.

## Define the data, schema and system

The example stores energy, consumes one unit per second, and clamps at zero. Put it in a Dart file in a project that depends on `zarvan_core`.

```dart
import 'package:zarvan_core/zarvan_core.dart';

class Energy {
  Energy(this.amount);
  double amount;

  Map<String, dynamic> toJson() => {'amount': amount};

  factory Energy.fromJson(Map<String, dynamic> json) {
    final amount = (json['amount'] as num).toDouble();
    if (!amount.isFinite || amount < 0) {
      throw FormatException('Energy must be finite and non-negative.');
    }
    return Energy(amount);
  }
}

const energySchema = ComponentSchema('energy', [
  FieldSchema('amount', FieldType.double, min: 0, required: true),
]);

void registerEnergy(World world) {
  world.components.register<Energy>(
    'energy',
    (energy) => energy.toJson(),
    Energy.fromJson,
    schema: energySchema,
  );
}

World makeEnergyWorld() {
  final world = World(width: 320, height: 240);
  registerEnergy(world);
  world.addSystemFn('energy-drain', (world, dt) {
    final store = world.componentsOf<Energy>();
    for (var i = 0; i < store.length; i++) {
      final energy = store.denseAt(i);
      final next = energy.amount - dt;
      energy.amount = next < 0 ? 0 : next;
    }
  });
  return world;
}
```

Registration binds the stable JSON name to the Dart type and serializers. Register once per world, before spawning the component or loading a level. The schema describes the JSON contract; constructor/deserializer checks still matter because callers can enter through different APIs.

## Exercise it

```dart
final world = makeEnergyWorld();
final id = world.spawnWith([Energy(5)]);
world.step(0.5);
assert(world.getComponent<Energy>(id)!.amount == 4.5);

final patch = <String, dynamic>{
  'entities': [
    {
      'id': id,
      'components': {
        'energy': {'amount': 2},
      },
    },
  ],
};
final problems = world.checkPatch(patch);
if (problems.isEmpty) world.applyPatch(patch, strict: true);
```

This updates an existing entity. It does not create missing entities or merge individual fields into the old component automatically.

## Agent and Studio integration

A game-local registration makes the component available in that world. It does **not** automatically add the schema to the engine-wide `allComponentSchemas` used by the stock CLI, MCP server and Studio. A reusable engine component requires an exported schema in `zarvan_schema`, registration in the correct runtime package, and regenerated component documentation. For a game-specific tool, supply the game's schemas explicitly to its validator.

Do not put a game-specific component into core solely to make the stock tools accept it.

## Verification

The example has a regression test in [custom_component_docs_test.dart](../../packages/zarvan_core/test/custom_component_docs_test.dart):

```bash
cd packages/zarvan_core
dart test test/custom_component_docs_test.dart
```

Related: [ECS](../concepts/ecs.md), [component reference](../reference/components.md), [content as data](../concepts/content-as-data.md).
