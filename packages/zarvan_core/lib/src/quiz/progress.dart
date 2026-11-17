import 'dart:convert';

import '../content/key_value_store.dart';
import 'game_mode.dart';
import 'quiz_item.dart';
import 'round.dart';

/// The best result on one stage (a chapter's tier).
class StageProgress {
  StageProgress({this.stars = 0, this.attempts = 0, this.passedOnce = false});

  int stars;
  int attempts;

  /// Whether the stage was ever passed; the first pass pays a coin bonus
  /// and opens the next tier, and a replay must not pay it again.
  bool passedOnce;

  factory StageProgress.fromJson(Map<String, dynamic> json) => StageProgress(
    stars: _int(json, 'stars'),
    attempts: _int(json, 'attempts'),
    passedOnce: json['passedOnce'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'stars': stars,
    'attempts': attempts,
    'passedOnce': passedOnce,
  };
}

/// Best scores of the two score-chasing modes.
class QuizRecords {
  QuizRecords({this.endlessBest = 0, this.raceBest = 0});

  int endlessBest;
  int raceBest;

  factory QuizRecords.fromJson(Map<String, dynamic> json) => QuizRecords(
    endlessBest: _int(json, 'endlessBest'),
    raceBest: _int(json, 'raceBest'),
  );

  Map<String, dynamic> toJson() => {
    'endlessBest': endlessBest,
    'raceBest': raceBest,
  };
}

/// The daily challenge history: which dates were played and the streak.
class DailyProgress {
  DailyProgress({
    this.lastDate,
    this.streakDays = 0,
    Map<String, List<bool>>? results,
  }) : results = results ?? {};

  String? lastDate;

  /// Consecutive days played, ending at [lastDate].
  int streakDays;

  /// Right/wrong per question, by date.
  final Map<String, List<bool>> results;

  factory DailyProgress.fromJson(Map<String, dynamic> json) => DailyProgress(
    lastDate: json['lastDate'] as String?,
    streakDays: _int(json, 'streakDays'),
    results: {
      for (final e in ((json['results'] as Map?) ?? const {}).entries)
        e.key as String: [for (final r in (e.value as List)) r as bool],
    },
  );

  Map<String, dynamic> toJson() => {
    if (lastDate != null) 'lastDate': lastDate,
    'streakDays': streakDays,
    'results': results,
  };
}

/// What [QuizProgress.applyRun] paid out for one finished round.
class RunReward {
  const RunReward({
    this.streakCoins = 0,
    this.firstPassCoins = 0,
    this.dailyCoins = 0,
    this.stars = 0,
    this.newRecord = false,
  });

  final int streakCoins;
  final int firstPassCoins;
  final int dailyCoins;

  /// Stars this play earned in a stage (the saved best may be higher).
  final int stars;

  /// True when an endless or race score beat the saved best.
  final bool newRecord;

  int get coins => streakCoins + firstPassCoins + dailyCoins;
}

int _int(Map<String, dynamic> json, String key) {
  final v = json[key];
  if (v == null) return 0;
  if (v is! num || v != v.toInt() || v < 0) {
    throw FormatException(
      'Progress field "$key" must be a whole number of at least 0, got $v.',
    );
  }
  return v.toInt();
}

/// Everything a player keeps between sessions: coins, stage stars and
/// unlocks, records and the daily history. Kept apart from the round so it
/// saves simply and can be migrated by version. Rules: R-PROG in
/// quiz-rules.md.
class QuizProgress {
  QuizProgress({
    this.coins = startCoins,
    Map<String, Map<String, StageProgress>>? stages,
    QuizRecords? records,
    DailyProgress? daily,
    Map<String, bool>? flags,
  }) : stages = stages ?? {},
       records = records ?? QuizRecords(),
       daily = daily ?? DailyProgress(),
       flags = flags ?? {};

  /// The only saved format this reader understands.
  static const version = 1;

  static const startCoins = 60;
  static const streakBonus = 5;
  static const firstPassBonus = 10;
  static const dailyBonus = 20;
  static const adBonus = 15;
  static const hintCost = 20;

  int coins;

  /// Stage results by chapter (author id) and tier name.
  final Map<String, Map<String, StageProgress>> stages;
  final QuizRecords records;
  final DailyProgress daily;

  /// Small yes/no marks the app keeps (for example `tutorialDone`).
  final Map<String, bool> flags;

  /// R-PROG-1: every chapter is open and starts at easy; a higher tier opens
  /// when the tier below it was passed once.
  bool isUnlocked(String author, QuizTier tier) {
    final below = QuizTier.ofLevel(tier.level - 1);
    if (below == null) return true;
    return stages[author]?[below.name]?.passedOnce ?? false;
  }

  bool hasPlayedDaily(String date) => daily.results.containsKey(date);

  /// Books a finished [round]: stage stars and unlocks, records, the daily
  /// result and every coin the round earned. Throws [StateError] when the
  /// round is not over, or when a daily for that date was already played
  /// (nothing changes then).
  RunReward applyRun(QuizRound round) {
    if (!round.isOver) throw StateError('The round is not over yet.');
    final mode = round.mode;
    final streakCoins = _streakCoins(round);
    var firstPass = 0;
    var dailyCoins = 0;
    var stars = 0;
    var newRecord = false;
    switch (mode) {
      case StageMode():
        final tier = round.tier!;
        final entry = (stages[round.author!] ??= {})[tier.name] ??=
            StageProgress();
        stars = round.stars;
        entry.attempts++;
        if (stars > entry.stars) entry.stars = stars;
        if (round.passed && !entry.passedOnce) {
          entry.passedOnce = true;
          firstPass = firstPassBonus;
        }
      case EndlessMode():
        if (round.run.score > records.endlessBest) {
          records.endlessBest = round.run.score;
          newRecord = true;
        }
      case RaceMode():
        if (round.run.score > records.raceBest) {
          records.raceBest = round.run.score;
          newRecord = true;
        }
      case DailyMode():
        final date = round.date!;
        if (hasPlayedDaily(date)) {
          throw StateError('The daily for $date was already played.');
        }
        daily.results[date] = round.results;
        daily.streakDays = _continues(daily.lastDate, date)
            ? daily.streakDays + 1
            : 1;
        daily.lastDate = date;
        dailyCoins = dailyBonus;
    }
    final reward = RunReward(
      streakCoins: streakCoins,
      firstPassCoins: firstPass,
      dailyCoins: dailyCoins,
      stars: stars,
      newRecord: newRecord,
    );
    coins += reward.coins;
    return reward;
  }

  /// Five coins each time the streak reaches a multiple of five.
  static int _streakCoins(QuizRound round) {
    var streak = 0;
    var coins = 0;
    for (final a in round.run.answers) {
      streak = a.correct ? streak + 1 : 0;
      if (a.correct && streak % 5 == 0) coins += streakBonus;
    }
    return coins;
  }

  /// Whether [date] is the day after [last].
  static bool _continues(String? last, String date) {
    if (last == null) return false;
    final a = DateTime.parse('${last}T00:00:00Z');
    final b = DateTime.parse('${date}T00:00:00Z');
    return b.difference(a).inDays == 1;
  }

  /// A rewarded ad was watched (the app shows it; this pays it).
  void rewardedAd() => coins += adBonus;

  /// Pays [hintCost] for a hint. False, with nothing changed, when the coins
  /// do not cover it, so the balance never goes below zero.
  bool buyHint() {
    if (coins < hintCost) return false;
    coins -= hintCost;
    return true;
  }

  factory QuizProgress.fromJson(Map<String, dynamic> json) {
    final v = json['version'];
    if (v != version) {
      throw FormatException(
        'Unsupported quiz progress version $v (this reader supports version $version).',
      );
    }
    final coins = json['coins'];
    if (coins != null &&
        (coins is! num || coins != coins.toInt() || coins < 0)) {
      throw FormatException(
        'Progress field "coins" must be a whole number of at least 0, got $coins.',
      );
    }
    return QuizProgress(
      coins: (coins as num?)?.toInt() ?? startCoins,
      stages: {
        for (final a in ((json['stages'] as Map?) ?? const {}).entries)
          a.key as String: {
            for (final t in (a.value as Map).entries)
              t.key as String: StageProgress.fromJson(
                (t.value as Map).cast<String, dynamic>(),
              ),
          },
      },
      records: QuizRecords.fromJson(
        ((json['records'] as Map?) ?? const {}).cast<String, dynamic>(),
      ),
      daily: DailyProgress.fromJson(
        ((json['daily'] as Map?) ?? const {}).cast<String, dynamic>(),
      ),
      flags: {
        for (final e in ((json['flags'] as Map?) ?? const {}).entries)
          e.key as String: e.value as bool,
      },
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'coins': coins,
    'stages': {
      for (final a in stages.entries)
        a.key: {for (final t in a.value.entries) t.key: t.value.toJson()},
    },
    'records': records.toJson(),
    'daily': daily.toJson(),
    'flags': flags,
  };
}

/// A load result: the progress to use, and why a saved copy was not used.
class ProgressLoad {
  const ProgressLoad(this.progress, {this.error});

  final QuizProgress progress;

  /// Null when the save was read (or there was none); otherwise what was
  /// wrong with it, for the app to report.
  final String? error;
}

/// Saves a [QuizProgress] through the engine's [KeyValueStore], so no
/// platform code lives in the core.
class QuizProgressStore {
  QuizProgressStore(this.store, {this.key = 'quiz.progress'});

  final KeyValueStore store;
  final String key;

  Future<void> save(QuizProgress progress) =>
      store.setString(key, jsonEncode(progress.toJson()));

  /// Reads the saved progress. No save gives a fresh one. A save that cannot
  /// be read gives a fresh one too, with [ProgressLoad.error] set and the bad
  /// text kept under `$key.corrupt`, so a bug here never destroys a player's
  /// data and never crashes the app.
  Future<ProgressLoad> load() async {
    final raw = await store.getString(key);
    if (raw == null) return ProgressLoad(QuizProgress());
    try {
      return ProgressLoad(
        QuizProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>),
      );
    } on Object catch (e) {
      await store.setString('$key.corrupt', raw);
      return ProgressLoad(QuizProgress(), error: '$e');
    }
  }
}
