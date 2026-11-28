import '../ecs/behavior.dart';
import 'ai_state.dart';
import '../ecs/system.dart';
import '../ecs/world.dart';
import '../ecs/world_view.dart';

/// Drives every `AIState`-tagged entity by resolving its behavior and
/// applying the `Action` it returns. One live `WorldView` is reused for
/// the update; each action applies immediately, so earlier actions can
/// affect subsequent behavior decisions.
class AISystem implements System {
  final BehaviorRegistry registry;

  AISystem(this.registry);

  @override
  String get name => 'ai';

  @override
  void update(World world, double dt) {
    final states = world.componentsOf<AIState>();
    if (states.length == 0) return;

    final view = WorldView(world);
    for (var i = 0; i < states.length; i++) {
      final entity = states.entityAt(i);
      final state = states.denseAt(i);
      final behavior = registry.resolve(state.behaviorId);
      final action = behavior.decide(view, entity);
      action.apply(world);
    }
  }
}
