import 'action.dart';
import 'entity.dart';
import 'world_view.dart';

/// The runtime-agent/NPC hook: implement [decide] to control an entity.
/// Receives a live [WorldView] and should propose an [Action] rather
/// than mutate the world directly. Trusted Dart code can access mutable
/// state through the view, so this is not an isolation boundary.
abstract class Behavior {
  Action decide(WorldView view, EntityId self);
}

/// A [Behavior] from a plain function, for trivial cases that don't earn a
/// class: `FunctionBehavior((view, self) => NoOpAction())`. Same convention as any
/// behavior: it only sees a [WorldView] and proposes an [Action].
class FunctionBehavior implements Behavior {
  final Action Function(WorldView view, EntityId self) _decide;

  /// Wraps [decide].
  FunctionBehavior(Action Function(WorldView view, EntityId self) decide)
    : _decide = decide;

  @override
  Action decide(WorldView view, EntityId self) => _decide(view, self);
}

/// Behaviors carry logic (closures/state machines), so — like
/// `AtlasRegistry` for sprites — they're registered under an id rather
/// than embedded in JSON. `AIState.behaviorId` references entries here.
class BehaviorRegistry {
  final Map<String, Behavior> _behaviors = {};

  void register(String id, Behavior behavior) => _behaviors[id] = behavior;

  /// Registers a function as the behavior [id]; see [FunctionBehavior].
  void registerFn(
    String id,
    Action Function(WorldView view, EntityId self) decide,
  ) => register(id, FunctionBehavior(decide));

  Behavior resolve(String id) {
    final behavior = _behaviors[id];
    if (behavior == null) {
      throw ArgumentError(
        'No Behavior registered for id "$id". Call registry.register() first.',
      );
    }
    return behavior;
  }

  bool has(String id) => _behaviors.containsKey(id);
}
