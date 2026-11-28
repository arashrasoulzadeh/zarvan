import 'package:zarvan_core/zarvan_core.dart';
import 'package:test/test.dart';

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

void main() {
  test('custom energy component steps, serializes and validates patches', () {
    final world = makeEnergyWorld();
    final id = world.spawnWith([Energy(5)]);
    world.step(0.5);
    expect(world.getComponent<Energy>(id)!.amount, 4.5);
    expect(world.components.serializeEntity(id)['energy'], {'amount': 4.5});

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
    expect(world.checkPatch(patch), isEmpty);
    world.applyPatch(patch, strict: true);
    expect(world.getComponent<Energy>(id)!.amount, 2);

    final invalid = <String, dynamic>{
      'entities': [
        {
          'id': id,
          'components': {
            'energy': {'amount': -1},
          },
        },
      ],
    };
    expect(world.checkPatch(invalid), isNotEmpty);
    expect(world.getComponent<Energy>(id)!.amount, 2);
    expect(energySchema.validate({'amount': -1}), isNotEmpty);
  });
}
