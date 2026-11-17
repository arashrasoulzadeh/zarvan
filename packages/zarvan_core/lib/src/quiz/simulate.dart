import 'dart:math' as math;

import 'game_mode.dart';
import 'question.dart';
import 'round.dart';
import 'seeded_random.dart';

/// How a simulated player answers.
sealed class AnswerPolicy {
  const AnswerPolicy();

  /// `always_correct`, `random` (uniform over the options) or
  /// `accuracy:<p>` with p in 0..1. Anything else is a [FormatException].
  factory AnswerPolicy.parse(String text) {
    if (text == 'always_correct') return const _Accuracy(1);
    if (text == 'random') return const _Random();
    if (text.startsWith('accuracy:')) {
      final p = double.tryParse(text.substring('accuracy:'.length));
      if (p != null && p >= 0 && p <= 1) return _Accuracy(p);
    }
    throw FormatException(
      'Unknown policy "$text" (expected always_correct, random or accuracy:<0..1>).',
    );
  }

  /// The option to choose for [q].
  int choose(Question q, SeededRandom rng);
}

class _Accuracy extends AnswerPolicy {
  const _Accuracy(this.p);

  final double p;

  @override
  int choose(Question q, SeededRandom rng) {
    if (rng.nextDouble() < p) return q.answerIndex;
    final wrong = [
      for (var i = 0; i < q.options.length; i++)
        if (i != q.answerIndex && !q.removedByHint.contains(i)) i,
    ];
    return rng.pick(wrong);
  }
}

class _Random extends AnswerPolicy {
  const _Random();

  @override
  int choose(Question q, SeededRandom rng) {
    final open = [
      for (var i = 0; i < q.options.length; i++)
        if (!q.removedByHint.contains(i)) i,
    ];
    return rng.pick(open);
  }
}

/// Totals over many simulated rounds.
class SimulationReport {
  const SimulationReport({
    required this.runs,
    required this.questions,
    required this.correct,
    required this.avgScore,
    required this.avgQuestions,
    required this.passRate,
    required this.stars,
  });

  final int runs;
  final int questions;
  final int correct;
  final double avgScore;
  final double avgQuestions;

  /// Share of stage runs that passed (0 outside the stage mode).
  final double passRate;

  /// Stage runs by star count (index 0..3).
  final List<int> stars;

  double get correctRate => questions == 0 ? 0 : correct / questions;

  Map<String, dynamic> toJson() => {
    'runs': runs,
    'questions': questions,
    'correct': correct,
    'correctRate': correctRate,
    'avgScore': avgScore,
    'avgQuestions': avgQuestions,
    'passRate': passRate,
    'stars': stars,
  };
}

/// Plays [runs] rounds with [policy] and totals the results, to tune
/// difficulty and the economy without playing by hand. [newRound] builds the
/// round for run number `r` (0-based); in a race each question advances the
/// clock by [secondsPerQuestion]. Same inputs, same report.
SimulationReport simulateRounds({
  required QuizRound Function(int r) newRound,
  required AnswerPolicy policy,
  required int runs,
  required int seed,
  int secondsPerQuestion = 4,
  int maxQuestions = 1000,
}) {
  var questions = 0;
  var correct = 0;
  var score = 0;
  var passes = 0;
  var stageRuns = 0;
  final stars = [0, 0, 0, 0];
  for (var r = 0; r < runs; r++) {
    final round = newRound(r);
    final rng = SeededRandom(seedOf('sim:$seed:$r'));
    var asked = 0;
    while (!round.isOver && asked < maxQuestions) {
      final q = round.nextQuestion();
      if (q == null) break;
      round.answer(policy.choose(q, rng));
      asked++;
      if (round.mode is RaceMode && !round.isOver) {
        round.tick(Duration(seconds: secondsPerQuestion));
      }
    }
    questions += asked;
    correct += round.correctCount;
    score += round.run.score;
    if (round.mode is StageMode) {
      stageRuns++;
      stars[math.min(round.stars, 3)]++;
      if (round.passed) passes++;
    }
  }
  return SimulationReport(
    runs: runs,
    questions: questions,
    correct: correct,
    avgScore: runs == 0 ? 0 : score / runs,
    avgQuestions: runs == 0 ? 0 : questions / runs,
    passRate: stageRuns == 0 ? 0 : passes / stageRuns,
    stars: stars,
  );
}
