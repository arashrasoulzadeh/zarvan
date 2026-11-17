import 'package:test/test.dart';
import 'package:zarvan_core/zarvan_core_quiz.dart';

void main() {
  // Written out by hand from R-SCORE-1..3, not computed by the same formula
  // as the code. Columns: streak 1, 4, 5, 9, 10, 20; first row without a
  // hint, second with.
  const table = {
    QuizTier.easy: ([10, 10, 15, 15, 20, 20], [5, 5, 7, 7, 10, 10]),
    QuizTier.medium: ([20, 20, 30, 30, 40, 40], [10, 10, 15, 15, 20, 20]),
    QuizTier.hard: ([30, 30, 45, 45, 60, 60], [15, 15, 22, 22, 30, 30]),
    QuizTier.literary: ([40, 40, 60, 60, 80, 80], [20, 20, 30, 30, 40, 40]),
  };
  const streaks = [1, 4, 5, 9, 10, 20];

  table.forEach((tier, rows) {
    for (var i = 0; i < streaks.length; i++) {
      test('R-SCORE-1..3: ${tier.name} streak ${streaks[i]}', () {
        const s = QuizScoring();
        expect(
          s.points(tier: tier, streak: streaks[i], hint: false),
          rows.$1[i],
        );
        expect(
          s.points(tier: tier, streak: streaks[i], hint: true),
          rows.$2[i],
        );
      });
    }
  });

  test('R-SCORE-3: the hint halves after the multiplier, then floors', () {
    // easy 10 x 1.5 = 15, halved = 7.5, floored = 7 (not 5 x 1.5 = 7.5 -> 8)
    expect(
      const QuizScoring().points(tier: QuizTier.easy, streak: 5, hint: true),
      7,
    );
  });

  test('the base points can be set by a mode definition', () {
    const s = QuizScoring(
      base: {
        QuizTier.easy: 1,
        QuizTier.medium: 2,
        QuizTier.hard: 3,
        QuizTier.literary: 4,
      },
    );
    expect(s.points(tier: QuizTier.literary, streak: 10, hint: false), 8);
  });

  test('the multiplier steps are the rule values', () {
    const s = QuizScoring();
    expect(
      [
        for (final n in [1, 4, 5, 9, 10, 99]) s.multiplier(n),
      ],
      [1.0, 1.0, 1.5, 1.5, 2.0, 2.0],
    );
  });

  test(
    'a streak below 1 is an error: the streak includes the current answer',
    () {
      expect(
        () => const QuizScoring().points(
          tier: QuizTier.easy,
          streak: 0,
          hint: false,
        ),
        throwsArgumentError,
      );
    },
  );
}
