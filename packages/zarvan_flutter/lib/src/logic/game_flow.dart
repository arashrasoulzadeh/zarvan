/// Identifies the active gameplay flow independently from the visual Scene.
///
/// A mini-game may reuse the main game's renderer and input presentation while
/// keeping its rules, tutorial, scoring and restart policy in a separate flow.
class GameFlow {
  const GameFlow._(this.id, this.kind);

  const GameFlow.main() : this._('main', GameFlowKind.main);

  const GameFlow.arcade(String mode)
    : this._('arcade:$mode', GameFlowKind.arcade);

  final String id;
  final GameFlowKind kind;

  bool get isMain => kind == GameFlowKind.main;
  bool get isArcade => kind == GameFlowKind.arcade;
}

enum GameFlowKind { main, arcade }
