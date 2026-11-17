import 'question.dart';
import 'quiz_item.dart';
import 'scoring.dart';

/// One answered question, as saved in a run and shown in a result list.
class AnswerRecord {
  const AnswerRecord({
    required this.itemId,
    required this.tier,
    required this.chosen,
    required this.correct,
    required this.hint,
    required this.points,
  });

  final String itemId;
  final QuizTier tier;
  final int chosen;
  final bool correct;
  final bool hint;
  final int points;

  factory AnswerRecord.fromJson(Map<String, dynamic> json) => AnswerRecord(
    itemId: json['itemId'] as String,
    tier: QuizTier.byName(json['tier'] as String)!,
    chosen: (json['chosen'] as num).toInt(),
    correct: json['correct'] as bool,
    hint: json['hint'] as bool,
    points: (json['points'] as num).toInt(),
  );

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'tier': tier.name,
    'chosen': chosen,
    'correct': correct,
    'hint': hint,
    'points': points,
  };
}

/// What one answer did.
class AnswerResult {
  const AnswerResult({
    required this.correct,
    required this.points,
    required this.streak,
    required this.livesLeft,
    required this.over,
    required this.record,
  });

  final bool correct;

  /// Points this answer earned (0 when wrong).
  final int points;

  /// The streak after this answer.
  final int streak;

  /// Lives left, or null in a mode without lives.
  final int? livesLeft;

  /// True when this answer used the last life.
  final bool over;
  final AnswerRecord record;
}

/// A game round in progress: score, streak, lives, the clock, what has been
/// asked and the question on screen. Immutable, so a saved game, an agent and
/// a replay can each hold one safely; every step returns a new run.
class QuizRun {
  const QuizRun({
    required this.mode,
    required this.seedBase,
    this.index = 0,
    this.score = 0,
    this.streak = 0,
    this.lives,
    this.continueUsed = false,
    this.clockMs,
    this.usedItemIds = const [],
    this.answers = const [],
    this.current,
    this.scoring = const QuizScoring(),
  });

  /// The only saved-run format this reader understands.
  static const version = 1;

  /// A new run. [lives] is null for a mode without lives; [clockMs] is only
  /// set in the timed race.
  factory QuizRun.start({
    required String mode,
    required String seedBase,
    int? lives,
    int? clockMs,
    QuizScoring scoring = const QuizScoring(),
  }) => QuizRun(
    mode: mode,
    seedBase: seedBase,
    lives: lives,
    clockMs: clockMs,
    scoring: scoring,
  );

  /// The mode's name (`stage`, `endless`, `race`, `daily`).
  final String mode;

  /// Text the question seeds are built from, so the run can be replayed.
  final String seedBase;

  /// How many questions have been answered.
  final int index;
  final int score;
  final int streak;
  final int? lives;
  final bool continueUsed;
  final int? clockMs;
  final List<String> usedItemIds;
  final List<AnswerRecord> answers;

  /// The question waiting for an answer, or null between questions.
  final Question? current;
  final QuizScoring scoring;

  /// A copy with the given fields changed. A field left out keeps its value,
  /// so a field cannot be set back to null here: use [withQuestion] and the
  /// dedicated methods for that.
  QuizRun copyWith({
    int? index,
    int? score,
    int? streak,
    int? lives,
    bool? continueUsed,
    int? clockMs,
    List<String>? usedItemIds,
    List<AnswerRecord>? answers,
  }) => QuizRun(
    mode: mode,
    seedBase: seedBase,
    index: index ?? this.index,
    score: score ?? this.score,
    streak: streak ?? this.streak,
    lives: lives ?? this.lives,
    continueUsed: continueUsed ?? this.continueUsed,
    clockMs: clockMs ?? this.clockMs,
    usedItemIds: usedItemIds ?? this.usedItemIds,
    answers: answers ?? this.answers,
    current: current,
    scoring: scoring,
  );

  /// The run with [question] on screen and its item marked as used.
  QuizRun withQuestion(Question question) => QuizRun(
    mode: mode,
    seedBase: seedBase,
    index: index,
    score: score,
    streak: streak,
    lives: lives,
    continueUsed: continueUsed,
    clockMs: clockMs,
    usedItemIds: usedItemIds.contains(question.itemId)
        ? usedItemIds
        : [...usedItemIds, question.itemId],
    answers: answers,
    current: question,
    scoring: scoring,
  );

  /// Takes the hint on the current question (R-SCORE-5: once per question).
  QuizRun useHint() {
    final q = _requireCurrent();
    return withQuestion(q.applyHint());
  }

  /// Answers the current question with option [choice]. Returns the next run
  /// (no current question until [withQuestion]) and what happened. Throws
  /// [StateError] when there is no question waiting (so a question cannot be
  /// answered twice) and [ArgumentError] for an option that does not exist or
  /// that the hint removed.
  (QuizRun, AnswerResult) answer(int choice) {
    final q = _requireCurrent();
    if (choice < 0 || choice >= q.options.length) {
      throw ArgumentError.value(choice, 'choice', 'no such option');
    }
    if (q.removedByHint.contains(choice)) {
      throw ArgumentError.value(choice, 'choice', 'removed by the hint');
    }
    final correct = q.isCorrect(choice);
    final hint = q.removedByHint.isNotEmpty;
    final newStreak = correct ? streak + 1 : 0;
    final points = correct
        ? scoring.points(tier: q.tier, streak: newStreak, hint: hint)
        : 0;
    final newLives = (!correct && lives != null) ? lives! - 1 : lives;
    final record = AnswerRecord(
      itemId: q.itemId,
      tier: q.tier,
      chosen: choice,
      correct: correct,
      hint: hint,
      points: points,
    );
    final next = QuizRun(
      mode: mode,
      seedBase: seedBase,
      index: index + 1,
      score: score + points,
      streak: newStreak,
      lives: newLives,
      continueUsed: continueUsed,
      clockMs: clockMs,
      usedItemIds: usedItemIds,
      answers: [...answers, record],
      scoring: scoring,
    );
    return (
      next,
      AnswerResult(
        correct: correct,
        points: points,
        streak: newStreak,
        livesLeft: newLives,
        over: newLives != null && newLives <= 0,
        record: record,
      ),
    );
  }

  Question _requireCurrent() {
    final q = current;
    if (q == null)
      throw StateError('There is no question waiting for an answer.');
    return q;
  }

  factory QuizRun.fromJson(Map<String, dynamic> json) {
    final v = json['version'];
    if (v != version) {
      throw FormatException(
        'Unsupported quiz run version $v (this reader supports version $version).',
      );
    }
    return QuizRun(
      mode: json['mode'] as String,
      seedBase: json['seedBase'] as String,
      index: (json['index'] as num).toInt(),
      score: (json['score'] as num).toInt(),
      streak: (json['streak'] as num).toInt(),
      lives: (json['lives'] as num?)?.toInt(),
      continueUsed: json['continueUsed'] as bool? ?? false,
      clockMs: (json['clockMs'] as num?)?.toInt(),
      usedItemIds: ((json['usedItemIds'] as List?) ?? const []).cast<String>(),
      answers: [
        for (final a in (json['answers'] as List? ?? const []))
          AnswerRecord.fromJson((a as Map).cast<String, dynamic>()),
      ],
      current: json['current'] == null
          ? null
          : Question.fromJson((json['current'] as Map).cast<String, dynamic>()),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'mode': mode,
    'seedBase': seedBase,
    'index': index,
    'score': score,
    'streak': streak,
    'lives': lives,
    'continueUsed': continueUsed,
    'clockMs': clockMs,
    'usedItemIds': usedItemIds,
    'answers': [for (final a in answers) a.toJson()],
    'current': current?.toJson(),
  };
}
