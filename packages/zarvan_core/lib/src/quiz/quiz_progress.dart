import 'dart:convert';

import '../content/key_value_store.dart';
import 'quiz_modes.dart';

/// Best result on one staged level.
class StageRecord {
  final int stars;
  final int bestScore;
  final int plays;

  const StageRecord({this.stars = 0, this.bestScore = 0, this.plays = 0});

  factory StageRecord.fromJson(Map<String, dynamic> json) => StageRecord(
    stars: (json['stars'] as num?)?.toInt() ?? 0,
    bestScore: (json['bestScore'] as num?)?.toInt() ?? 0,
    plays: (json['plays'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'stars': stars,
    'bestScore': bestScore,
    'plays': plays,
  };
}

/// Everything a player keeps between sessions: stage stars and unlocks,
/// high scores per mode, and a currency balance. Plain data, saved as one
/// JSON string through a [KeyValueStore].
class QuizProgress {
  final Map<String, StageRecord> stages;
  final Set<String> unlocked;

  /// Best score per mode name (`QuizModeKind.name`).
  final Map<String, int> records;
  int currency;

  QuizProgress({
    Map<String, StageRecord>? stages,
    Set<String>? unlocked,
    Map<String, int>? records,
    this.currency = 0,
  }) : stages = stages ?? {},
       unlocked = unlocked ?? {},
       records = records ?? {};

  bool isUnlocked(String stageId) => unlocked.contains(stageId);

  int starsOf(String stageId) => stages[stageId]?.stars ?? 0;

  int get totalStars => stages.values.fold(0, (a, s) => a + s.stars);

  /// Records a finished staged level. Stars and best score only ever go up,
  /// so a worse replay never costs progress. When [mode] unlocks on
  /// [correct], [nextStageId] becomes playable. Returns the stars this
  /// play earned, regardless of the stored best.
  int completeStage({
    required String stageId,
    required QuizMode mode,
    required int correct,
    required int score,
    String? nextStageId,
  }) {
    final earned = mode.starsFor(correct);
    final old = stages[stageId] ?? const StageRecord();
    stages[stageId] = StageRecord(
      stars: earned > old.stars ? earned : old.stars,
      bestScore: score > old.bestScore ? score : old.bestScore,
      plays: old.plays + 1,
    );
    if (nextStageId != null && mode.unlocks(correct)) unlocked.add(nextStageId);
    return earned;
  }

  /// Stores [score] for [kind] when it beats the record; true if it did.
  bool recordScore(QuizModeKind kind, int score) {
    if (score <= (records[kind.name] ?? 0)) return false;
    records[kind.name] = score;
    return true;
  }

  void earn(int amount) {
    if (amount < 0)
      throw ArgumentError.value(amount, 'amount', 'must not be negative');
    currency += amount;
  }

  /// Takes [amount] if affordable; false (and no change) otherwise.
  bool spend(int amount) {
    if (amount < 0)
      throw ArgumentError.value(amount, 'amount', 'must not be negative');
    if (amount > currency) return false;
    currency -= amount;
    return true;
  }

  factory QuizProgress.fromJson(Map<String, dynamic> json) => QuizProgress(
    stages: ((json['stages'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(
        k as String,
        StageRecord.fromJson(v as Map<String, dynamic>),
      ),
    ),
    unlocked: {...((json['unlocked'] as List?) ?? const []).cast<String>()},
    records: ((json['records'] as Map?) ?? const {}).map(
      (k, v) => MapEntry(k as String, (v as num).toInt()),
    ),
    currency: (json['currency'] as num?)?.toInt() ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'stages': stages.map((k, v) => MapEntry(k, v.toJson())),
    'unlocked': unlocked.toList()..sort(),
    'records': records,
    'currency': currency,
  };

  /// Writes this progress under [key].
  Future<void> save(KeyValueStore store, {String key = 'quiz_progress'}) =>
      store.setString(key, jsonEncode(toJson()));

  /// Reads progress from [key]; a missing entry gives a fresh one. An
  /// unreadable entry is copied to `$key.corrupt` before a fresh one is
  /// returned, so a bad save is never silently destroyed.
  static Future<QuizProgress> load(
    KeyValueStore store, {
    String key = 'quiz_progress',
  }) async {
    final raw = await store.getString(key);
    if (raw == null) return QuizProgress();
    try {
      return QuizProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await store.setString('$key.corrupt', raw);
      return QuizProgress();
    }
  }
}
