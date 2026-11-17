import 'quiz_item.dart';

/// The one place the points formula lives, so modes, the simulator and the
/// UI cannot drift apart.
///
/// Points are `floor(base x multiplier x (hint ? 0.5 : 1))`. The hint halving
/// comes last, so a halved 7.5 floors to 7, not a rounded 8.
class QuizScoring {
  const QuizScoring({
    this.base = const {
      QuizTier.easy: 10,
      QuizTier.medium: 20,
      QuizTier.hard: 30,
      QuizTier.literary: 40,
    },
  });

  /// Base points per tier; a mode definition may override them.
  final Map<QuizTier, int> base;

  /// The streak multiplier: x2 from ten in a row, x1.5 from five.
  double multiplier(int streak) => streak >= 10
      ? 2.0
      : streak >= 5
      ? 1.5
      : 1.0;

  /// Points for a right answer. [streak] counts the answer being scored
  /// (the first right answer has streak 1), so it must be at least 1.
  int points({
    required QuizTier tier,
    required int streak,
    required bool hint,
  }) {
    if (streak < 1) {
      throw ArgumentError.value(
        streak,
        'streak',
        'must include the current answer (>= 1)',
      );
    }
    return ((base[tier] ?? 0) * multiplier(streak) * (hint ? 0.5 : 1)).floor();
  }
}
