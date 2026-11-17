import 'package:test/test.dart';
import 'package:zarvan_core/zarvan_core_quiz.dart';
import 'package:zarvan_core/zarvan_core.dart' show DeterministicRandom;

QuizQuestion q({int tier = 1}) => QuizQuestion(
      itemId: 'i',
      tier: tier,
      lines: const ['a ____'],
      blankLine: 0,
      answer: 'x',
      options: const ['w', 'x', 'y', 'z'],
      correctIndex: 1,
    );

void main() {
  test('streak raises the multiplier up to the cap', () {
    final run = SimpleQuizRun(rules: const ScoreRules(streakStep: 0.5, maxMultiplier: 2.0));
    expect(run.answer(q(), 1).pointsDelta, 15); // streak 1 -> x1.5
    expect(run.answer(q(), 1).pointsDelta, 20); // x2.0
    expect(run.answer(q(), 1).pointsDelta, 20); // capped
  });

  test('per-tier base score', () {
    final run = SimpleQuizRun(rules: const ScoreRules(baseByTier: {2: 50}, streakStep: 0));
    expect(run.answer(q(tier: 2), 1).pointsDelta, 50);
    expect(run.answer(q(tier: 1), 1).pointsDelta, 10);
  });

  test('wrong answer resets streak, costs a life, penalty floors at zero', () {
    final run = SimpleQuizRun(rules: const ScoreRules(wrongPenalty: 100), lives: 2);
    run.answer(q(), 1);
    final r = run.answer(q(), 0);
    expect(r.correct, isFalse);
    expect(run.streak, 0);
    expect(run.lives, 1);
    expect(run.score, 0);
    run.answer(q(), 0);
    expect(run.isOver, isTrue);
  });

  test('hint hides two wrong options once and halves that question only', () {
    final run = SimpleQuizRun(rules: const ScoreRules(streakStep: 0));
    final hidden = run.useHint(q(), DeterministicRandom(1));
    expect(hidden.length, 2);
    expect(hidden.contains(1), isFalse);
    expect(run.useHint(q(), DeterministicRandom(1)), isEmpty);
    expect(run.answer(q(), 1).pointsDelta, 5);
    expect(run.answer(q(), 1).pointsDelta, 10);
  });

  test('time bonus adds per second left', () {
    final run = SimpleQuizRun(rules: const ScoreRules(streakStep: 0, timeBonusPerSecond: 2));
    expect(run.answer(q(), 1, secondsLeft: 5).pointsDelta, 20);
  });

  test('run and rules round-trip through JSON', () {
    final run = SimpleQuizRun(rules: const ScoreRules(baseByTier: {3: 7}), lives: 2)..answer(q(), 1);
    expect(SimpleQuizRun.fromJson(run.toJson()).toJson(), run.toJson());
  });

  group('modes', () {
    test('endless tier steps every N questions and caps', () {
      const m = QuizMode(kind: QuizModeKind.endless, tierStepEvery: 2, maxTier: 3);
      expect([for (var i = 0; i < 8; i++) m.tierFor(i)], [1, 1, 2, 2, 3, 3, 3, 3]);
    });

    test('non-endless modes stay on the start tier', () {
      expect(const QuizMode(kind: QuizModeKind.staged, startTier: 2).tierFor(50), 2);
    });

    test('stars and unlock use correct ratio', () {
      const m = QuizMode(kind: QuizModeKind.staged, questionCount: 10);
      expect(m.starsFor(5), 0);
      expect(m.starsFor(6), 1);
      expect(m.starsFor(8), 2);
      expect(m.starsFor(10), 3);
      expect(m.unlocks(5), isFalse);
      expect(m.unlocks(6), isTrue);
    });

    test('daily seed depends only on the date', () {
      expect(QuizMode.dailySeed(DateTime(2026, 11, 17, 3)), 20261117);
      expect(QuizMode.dailySeed(DateTime(2026, 11, 17, 23)), QuizMode.dailySeed(DateTime(2026, 11, 17)));
      expect(QuizMode.dailySeed(DateTime(2026, 11, 18)), isNot(20261117));
    });

    test('mode round-trips through JSON', () {
      const m = QuizMode(kind: QuizModeKind.timedRace, durationSeconds: 30);
      expect(QuizMode.fromJson(m.toJson()).toJson(), m.toJson());
    });
  });
}
