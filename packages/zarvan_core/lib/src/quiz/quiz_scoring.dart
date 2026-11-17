import 'dart:math' show Random;

import '../ecs/deterministic_random.dart';
import 'quiz_question.dart';

/// Score parameters; data so each game tunes its own economy.
class ScoreRules {
  /// Base points per tier; tiers not listed use [defaultBase].
  final Map<int, int> baseByTier;
  final int defaultBase;

  /// Each consecutive correct answer adds this to the multiplier.
  final double streakStep;
  final double maxMultiplier;

  /// Fraction of the score kept when a hint was used.
  final double hintFactor;

  /// Points per whole second left on a countdown, added to a correct answer.
  final int timeBonusPerSecond;

  /// Points removed from the score for a wrong answer; never goes below zero.
  final int wrongPenalty;

  const ScoreRules({
    this.baseByTier = const {},
    this.defaultBase = 10,
    this.streakStep = 0.1,
    this.maxMultiplier = 3.0,
    this.hintFactor = 0.5,
    this.timeBonusPerSecond = 0,
    this.wrongPenalty = 0,
  });

  factory ScoreRules.fromJson(Map<String, dynamic> json) => ScoreRules(
    baseByTier: ((json['baseByTier'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(int.parse(k as String), (v as num).toInt()),
    ),
    defaultBase: (json['defaultBase'] as num?)?.toInt() ?? 10,
    streakStep: (json['streakStep'] as num?)?.toDouble() ?? 0.1,
    maxMultiplier: (json['maxMultiplier'] as num?)?.toDouble() ?? 3.0,
    hintFactor: (json['hintFactor'] as num?)?.toDouble() ?? 0.5,
    timeBonusPerSecond: (json['timeBonusPerSecond'] as num?)?.toInt() ?? 0,
    wrongPenalty: (json['wrongPenalty'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'baseByTier': baseByTier.map((k, v) => MapEntry('$k', v)),
    'defaultBase': defaultBase,
    'streakStep': streakStep,
    'maxMultiplier': maxMultiplier,
    'hintFactor': hintFactor,
    'timeBonusPerSecond': timeBonusPerSecond,
    'wrongPenalty': wrongPenalty,
  };
}

/// What one answer did.
class AnswerResult {
  final bool correct;
  final int pointsDelta;
  final int streak;
  final int livesLeft;

  const AnswerResult({
    required this.correct,
    required this.pointsDelta,
    required this.streak,
    required this.livesLeft,
  });
}

/// Mutable state of one play-through: score, streak, lives and hint use.
/// Pure data plus rules, so a CLI or agent can drive it without Flutter.
class QuizRun {
  final ScoreRules rules;
  int score;
  int streak;
  int lives;
  int answered;
  int correctCount;
  bool _hintUsed = false;

  QuizRun({
    required this.rules,
    this.lives = 3,
    this.score = 0,
    this.streak = 0,
    this.answered = 0,
    this.correctCount = 0,
  });

  bool get isOver => lives <= 0;

  /// Current streak multiplier, capped at [ScoreRules.maxMultiplier].
  double get multiplier =>
      (1 + streak * rules.streakStep).clamp(1.0, rules.maxMultiplier);

  /// Indexes of two wrong options to hide, or empty when a hint was already
  /// used on this question or fewer than two wrong options exist. Using it
  /// halves (by [ScoreRules.hintFactor]) the points of this question.
  List<int> useHint(QuizQuestion q, DeterministicRandom random) {
    final wrong = [
      for (var i = 0; i < q.options.length; i++)
        if (i != q.correctIndex) i,
    ];
    if (_hintUsed || wrong.length < 2) return const [];
    _hintUsed = true;
    wrong.shuffle(_Rng(random));
    return wrong.take(2).toList()..sort();
  }

  /// Applies an answer. [secondsLeft] is only used for the time bonus.
  AnswerResult answer(QuizQuestion q, int optionIndex, {int secondsLeft = 0}) {
    answered++;
    final correct = q.isCorrect(optionIndex);
    var delta = 0;
    if (correct) {
      correctCount++;
      streak++;
      final base = rules.baseByTier[q.tier] ?? rules.defaultBase;
      var points = base * multiplier;
      if (_hintUsed) points *= rules.hintFactor;
      delta = points.round() + secondsLeft * rules.timeBonusPerSecond;
    } else {
      streak = 0;
      lives--;
      delta = -(score < rules.wrongPenalty ? score : rules.wrongPenalty);
    }
    score += delta;
    _hintUsed = false;
    return AnswerResult(
      correct: correct,
      pointsDelta: delta,
      streak: streak,
      livesLeft: lives,
    );
  }

  factory QuizRun.fromJson(Map<String, dynamic> json) => QuizRun(
    rules: ScoreRules.fromJson(json['rules'] as Map<String, dynamic>),
    lives: (json['lives'] as num).toInt(),
    score: (json['score'] as num).toInt(),
    streak: (json['streak'] as num).toInt(),
    answered: (json['answered'] as num).toInt(),
    correctCount: (json['correctCount'] as num).toInt(),
  );

  Map<String, dynamic> toJson() => {
    'rules': rules.toJson(),
    'lives': lives,
    'score': score,
    'streak': streak,
    'answered': answered,
    'correctCount': correctCount,
  };
}

class _Rng implements Random {
  final DeterministicRandom _r;
  _Rng(this._r);
  @override
  int nextInt(int max) => _r.nextInt(max);
  @override
  double nextDouble() => _r.nextDouble();
  @override
  bool nextBool() => _r.nextBool();
}
