import 'game_flow_logic.dart';

class GameFlowSettings {
  const GameFlowSettings({
    this.timeLimit = 0,
    this.maxLiveQuestions = 3,
    this.startLives,
    this.guideKey,
    this.guided = false,
    this.showQuestionLessons = true,
    this.countdown = 3,
    this.ensureNumericQuestion = false,
  });

  final double timeLimit;
  final int maxLiveQuestions;
  final int? startLives;
  final String? guideKey;
  final bool guided;
  final bool showQuestionLessons;
  final double countdown;
  final bool ensureNumericQuestion;

  GameFlowSettings copyWith({
    double? timeLimit,
    int? maxLiveQuestions,
    int? startLives,
    String? guideKey,
    bool? guided,
    bool? showQuestionLessons,
    double? countdown,
    bool? ensureNumericQuestion,
  }) => GameFlowSettings(
    timeLimit: timeLimit ?? this.timeLimit,
    maxLiveQuestions: maxLiveQuestions ?? this.maxLiveQuestions,
    startLives: startLives ?? this.startLives,
    guideKey: guideKey ?? this.guideKey,
    guided: guided ?? this.guided,
    showQuestionLessons: showQuestionLessons ?? this.showQuestionLessons,
    countdown: countdown ?? this.countdown,
    ensureNumericQuestion: ensureNumericQuestion ?? this.ensureNumericQuestion,
  );
}

/// A composable ruleset shared by the renderer but independent of the game.
abstract class GameFlow {
  const GameFlow();

  String get id;
  GameFlowKind get kind;
  List<GameFlowLogic> get logic;

  GameFlowSettings get settings {
    var resolved = const GameFlowSettings();
    for (final rule in logic) {
      resolved = rule.apply(resolved);
    }
    return resolved;
  }

  bool get isMain => kind == GameFlowKind.main;
  bool get isArcade => kind == GameFlowKind.arcade;
}

/// Default flow used by engine scenes that do not opt into a custom flow.
class DefaultGameFlow extends GameFlow {
  const DefaultGameFlow();

  @override
  String get id => 'main';

  @override
  GameFlowKind get kind => GameFlowKind.main;

  @override
  List<GameFlowLogic> get logic => const [];
}

enum GameFlowKind { main, arcade }
