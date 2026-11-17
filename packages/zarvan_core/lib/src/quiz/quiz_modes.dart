/// The shapes of play a quiz game offers.
enum QuizModeKind { staged, endless, timedRace, daily }

/// A play mode as data. Only the fields relevant to [kind] are read.
class QuizMode {
  final QuizModeKind kind;
  final int questionCount;

  /// Staged: fraction of correct answers needed to unlock the next stage.
  final double unlockThreshold;

  /// Staged: correct-answer fractions that earn 1, 2, 3... stars.
  final List<double> starThresholds;

  /// Endless: the tier rises by one every this many questions.
  final int tierStepEvery;

  /// Endless: how many times a lost run may be continued.
  final int continues;

  /// Timed race: total seconds on the clock.
  final int durationSeconds;

  /// Tier of the first question.
  final int startTier;

  /// Highest tier an endless run climbs to.
  final int maxTier;

  const QuizMode({
    required this.kind,
    this.questionCount = 10,
    this.unlockThreshold = 0.6,
    this.starThresholds = const [0.6, 0.8, 1.0],
    this.tierStepEvery = 5,
    this.continues = 1,
    this.durationSeconds = 60,
    this.startTier = 1,
    this.maxTier = 3,
  });

  /// Tier for the zero-based [questionIndex]; only endless mode escalates.
  int tierFor(int questionIndex) {
    if (kind != QuizModeKind.endless) return startTier;
    final t = startTier + questionIndex ~/ tierStepEvery;
    return t > maxTier ? maxTier : t;
  }

  /// Stars earned for [correct] out of [questionCount]; 0 below the first threshold.
  int starsFor(int correct) {
    if (questionCount <= 0) return 0;
    final ratio = correct / questionCount;
    var stars = 0;
    for (final t in starThresholds) {
      if (ratio >= t) stars++;
    }
    return stars;
  }

  /// Whether [correct] answers pass the staged unlock threshold.
  bool unlocks(int correct) =>
      questionCount > 0 && correct / questionCount >= unlockThreshold;

  /// Seed for the daily set: the same for everyone on one calendar date, so
  /// the date alone reproduces the questions.
  static int dailySeed(DateTime date) => date.year * 10000 + date.month * 100 + date.day;

  factory QuizMode.fromJson(Map<String, dynamic> json) => QuizMode(
        kind: QuizModeKind.values.byName(json['kind'] as String),
        questionCount: (json['questionCount'] as num?)?.toInt() ?? 10,
        unlockThreshold: (json['unlockThreshold'] as num?)?.toDouble() ?? 0.6,
        starThresholds: ((json['starThresholds'] as List?) ?? const [0.6, 0.8, 1.0])
            .map((e) => (e as num).toDouble())
            .toList(),
        tierStepEvery: (json['tierStepEvery'] as num?)?.toInt() ?? 5,
        continues: (json['continues'] as num?)?.toInt() ?? 1,
        durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 60,
        startTier: (json['startTier'] as num?)?.toInt() ?? 1,
        maxTier: (json['maxTier'] as num?)?.toInt() ?? 3,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'questionCount': questionCount,
        'unlockThreshold': unlockThreshold,
        'starThresholds': starThresholds,
        'tierStepEvery': tierStepEvery,
        'continues': continues,
        'durationSeconds': durationSeconds,
        'startTier': startTier,
        'maxTier': maxTier,
      };
}
