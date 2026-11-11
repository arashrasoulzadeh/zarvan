import 'game_flow.dart';

/// One small, replaceable rule in a [GameFlow].
abstract class GameFlowLogic {
  String get id;

  GameFlowSettings apply(GameFlowSettings settings);
}
