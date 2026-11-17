import 'quiz_item.dart';

int _int(Map<String, dynamic> json, String key, int fallback, {int min = 0}) {
  final v = json[key];
  if (v == null) return fallback;
  if (v is! num || v != v.toInt()) {
    throw FormatException('Mode field "$key" must be a whole number, got $v.');
  }
  if (v < min)
    throw FormatException('Mode field "$key" must be at least $min, got $v.');
  return v.toInt();
}

/// How a round is played, as data: the numbers that balance a game are fields
/// here with the PRD's values as defaults, so they change without touching
/// engine code. Read one from JSON with [GameMode.fromJson].
sealed class GameMode {
  const GameMode();

  /// The mode's name as written in `type` and in a saved run.
  String get type;

  Map<String, dynamic> toJson();

  /// Reads a mode from `{"type": "stage" | "endless" | "race" | "daily", ...}`.
  /// Missing fields take their defaults; a wrong type, an unknown `type` or an
  /// out-of-range value is a [FormatException] that names the field.
  factory GameMode.fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    return switch (type) {
      'stage' => StageMode.fromJson(json),
      'endless' => EndlessMode.fromJson(json),
      'race' => RaceMode.fromJson(json),
      'daily' => DailyMode.fromJson(json),
      _ => throw FormatException(
        'Unknown mode type "$type" (expected stage, endless, race or daily).',
      ),
    };
  }
}

/// One stage of a chapter: a fixed list of questions, a pass mark and stars.
class StageMode extends GameMode {
  const StageMode({
    this.questionCount = 25,
    this.passAt = 18,
    this.starAt = const [18, 22, 25],
  });

  /// Questions in a stage (the most famous items of the author and tier).
  final int questionCount;

  /// Right answers needed to pass.
  final int passAt;

  /// Right answers that earn one, two, three... stars.
  final List<int> starAt;

  @override
  String get type => 'stage';

  bool passed(int correct) => correct >= passAt;

  /// Stars for [correct] right answers: none below [passAt].
  int starsFor(int correct) =>
      correct < passAt ? 0 : starAt.where((t) => correct >= t).length;

  factory StageMode.fromJson(Map<String, dynamic> json) {
    final count = _int(json, 'questionCount', 25, min: 1);
    final pass = _int(json, 'passAt', 18, min: 1);
    if (pass > count) {
      throw FormatException(
        'Mode field "passAt" ($pass) cannot exceed "questionCount" ($count).',
      );
    }
    final raw = json['starAt'];
    final stars = raw == null
        ? const [18, 22, 25]
        : [
            for (final s in (raw as List))
              s is num && s == s.toInt()
                  ? s.toInt()
                  : throw FormatException(
                      'Mode field "starAt" must hold whole numbers.',
                    ),
          ];
    return StageMode(questionCount: count, passAt: pass, starAt: stars);
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'questionCount': questionCount,
    'passAt': passAt,
    'starAt': starAt,
  };
}

/// Play until the lives run out, with the tier rising every [tierStep]
/// questions and one optional continue.
class EndlessMode extends GameMode {
  const EndlessMode({this.lives = 3, this.tierStep = 10, this.continues = 1});

  final int lives;

  /// Questions per tier: 1..tierStep easy, then medium, hard, literary.
  final int tierStep;

  /// Continues allowed in a round (0 or 1: the run records one use).
  final int continues;

  @override
  String get type => 'endless';

  /// The tier of the [n]th question (counting from 1).
  QuizTier tierFor(int n) {
    final step = (n - 1) ~/ tierStep;
    return QuizTier.values[step.clamp(0, QuizTier.values.length - 1)];
  }

  factory EndlessMode.fromJson(Map<String, dynamic> json) => EndlessMode(
    lives: _int(json, 'lives', 3, min: 1),
    tierStep: _int(json, 'tierStep', 10, min: 1),
    continues: _int(json, 'continues', 1).clamp(0, 1),
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'lives': lives,
    'tierStep': tierStep,
    'continues': continues,
  };
}

/// Answer against a clock: a right answer adds time, a wrong one takes it.
class RaceMode extends GameMode {
  const RaceMode({
    this.durationMs = 60000,
    this.bonusMs = 2000,
    this.penaltyMs = 5000,
    this.tierStep = 10,
  });

  final int durationMs;
  final int bonusMs;
  final int penaltyMs;

  /// Questions per tier, as in [EndlessMode.tierStep].
  final int tierStep;

  @override
  String get type => 'race';

  QuizTier tierFor(int n) => EndlessMode(tierStep: tierStep).tierFor(n);

  factory RaceMode.fromJson(Map<String, dynamic> json) => RaceMode(
    durationMs: _int(json, 'durationMs', 60000, min: 1),
    bonusMs: _int(json, 'bonusMs', 2000),
    penaltyMs: _int(json, 'penaltyMs', 5000),
    tierStep: _int(json, 'tierStep', 10, min: 1),
  );

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'durationMs': durationMs,
    'bonusMs': bonusMs,
    'penaltyMs': penaltyMs,
    'tierStep': tierStep,
  };
}

/// The same short set of questions for everyone on a given date.
class DailyMode extends GameMode {
  const DailyMode({
    this.tiers = const [
      QuizTier.easy,
      QuizTier.easy,
      QuizTier.medium,
      QuizTier.medium,
      QuizTier.hard,
    ],
  });

  /// One entry per question, giving its tier.
  final List<QuizTier> tiers;

  @override
  String get type => 'daily';

  factory DailyMode.fromJson(Map<String, dynamic> json) {
    final raw = json['tiers'];
    if (raw == null) return const DailyMode();
    return DailyMode(
      tiers: [
        for (final t in (raw as List))
          QuizTier.byName('$t') ??
              (throw FormatException(
                'Mode field "tiers" has an unknown tier "$t".',
              )),
      ],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'type': type,
    'tiers': [for (final t in tiers) t.name],
  };
}
