import '../../zarvan_core.dart';

/// Rewards as `resource id -> amount`, credited by the caller (to a wallet,
/// or any other store); this file never touches game state.
typedef Rewards = Map<String, BigNumber>;

Rewards _rewardsFromJson(Object? json) => {
  for (final e in ((json as Map?) ?? const {}).entries)
    e.key as String: BigNumber.fromJson(e.value as Object),
};

Map<String, dynamic> _rewardsToJson(Rewards r) => {
  for (final e in r.entries) e.key: e.value.toJson(),
};

/// `2026-11-17`: the calendar day a streak or quest set belongs to. Date
/// only, so the same day gives the same key in every time zone offset the
/// caller already applied to [t].
String dayKey(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

int _dayNumber(DateTime t) =>
    DateTime.utc(t.year, t.month, t.day).millisecondsSinceEpoch ~/ 86400000;

/// What a [LoginStreak.claim] did.
class LoginClaim {
  const LoginClaim({
    required this.claimed,
    required this.streak,
    this.reward = const {},
    this.broken = false,
  });

  /// False when today's reward was already taken.
  final bool claimed;

  /// The streak length after this call.
  final int streak;
  final Rewards reward;

  /// True when days were missed and the streak restarted at 1.
  final bool broken;
}

/// Consecutive-day login streak with a reward per streak day, cycling
/// through [rewards] (day 1 gets `rewards[0]`, the day after the last
/// repeats from the start).
class LoginStreak {
  LoginStreak({
    required this.rewards,
    this.streak = 0,
    this.best = 0,
    this.lastDay,
  });

  final List<Rewards> rewards;
  int streak;
  int best;

  /// `dayKey` of the last claim; null before the first.
  String? lastDay;

  /// Whether [now] is a day not yet claimed.
  bool canClaim(DateTime now) => lastDay != dayKey(now);

  /// Claims today's reward. The same calendar day twice is a no-op; the next
  /// day extends the streak; any longer gap restarts it at 1. A clock that
  /// moved backwards counts as the same day, never as a restart.
  LoginClaim claim(DateTime now) {
    if (!canClaim(now)) return LoginClaim(claimed: false, streak: streak);
    var broken = false;
    final last = lastDay;
    if (last == null) {
      streak = 1;
    } else {
      final gap = _dayNumber(now) - _dayNumber(DateTime.parse(last));
      if (gap < 0) return LoginClaim(claimed: false, streak: streak);
      if (gap == 1) {
        streak++;
      } else {
        broken = streak > 0;
        streak = 1;
      }
    }
    lastDay = dayKey(now);
    if (streak > best) best = streak;
    final reward = rewards.isEmpty ? <String, BigNumber>{} : rewards[(streak - 1) % rewards.length];
    return LoginClaim(claimed: true, streak: streak, reward: reward, broken: broken);
  }

  factory LoginStreak.fromJson(Map<String, dynamic> json) => LoginStreak(
    rewards: [for (final r in (json['rewards'] as List? ?? const [])) _rewardsFromJson(r)],
    streak: (json['streak'] as num?)?.toInt() ?? 0,
    best: (json['best'] as num?)?.toInt() ?? 0,
    lastDay: json['lastDay'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'rewards': [for (final r in rewards) _rewardsToJson(r)],
    'streak': streak,
    'best': best,
    if (lastDay != null) 'lastDay': lastDay,
  };
}

/// One quest the game can offer: do the game event [event] [target] times.
class DailyQuest {
  const DailyQuest({
    required this.id,
    required this.event,
    this.target = 1,
    this.reward = const {},
  });

  final String id;

  /// The event name the game reports through [DailyQuests.record].
  final String event;
  final int target;
  final Rewards reward;

  factory DailyQuest.fromJson(Map<String, dynamic> json) => DailyQuest(
    id: json['id'] as String,
    event: json['event'] as String,
    target: (json['target'] as num?)?.toInt() ?? 1,
    reward: _rewardsFromJson(json['reward']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'event': event,
    'target': target,
    'reward': _rewardsToJson(reward),
  };
}

/// A fresh set of [perDay] quests from a [pool] each calendar day, with
/// progress and claim state. The day's picks depend only on the date and
/// [seed], so every device shows the same quests.
class DailyQuests {
  DailyQuests({
    required this.pool,
    this.perDay = 3,
    this.seed = 0,
    this.day,
    List<String>? active,
    Map<String, int>? progress,
    Set<String>? claimed,
  }) : active = [...?active],
       progress = {...?progress},
       claimed = {...?claimed};

  final List<DailyQuest> pool;
  final int perDay;
  final int seed;

  /// `dayKey` the current set was rolled for.
  String? day;

  /// Ids of today's quests.
  final List<String> active;
  final Map<String, int> progress;
  final Set<String> claimed;

  /// Today's quests, in pick order.
  List<DailyQuest> get today => [
    for (final id in active)
      for (final q in pool)
        if (q.id == id) q,
  ];

  /// Rolls a new set when [now] is a new day; returns whether it did. Call
  /// on app start and resume, before [record].
  bool rollover(DateTime now) {
    final key = dayKey(now);
    if (day == key) return false;
    final rng = DeterministicRandom(seed ^ _dayNumber(now));
    final ids = [for (final q in pool) q.id];
    final picked = <String>[];
    while (picked.length < perDay && ids.isNotEmpty) {
      picked.add(ids.removeAt(rng.nextInt(ids.length)));
    }
    day = key;
    active
      ..clear()
      ..addAll(picked);
    progress.clear();
    claimed.clear();
    return true;
  }

  /// Counts [amount] of the game event [event] towards today's quests that
  /// listen to it (capped at their target).
  void record(String event, [int amount = 1]) {
    for (final q in today) {
      if (q.event != event || claimed.contains(q.id)) continue;
      final next = (progress[q.id] ?? 0) + amount;
      progress[q.id] = next > q.target ? q.target : next;
    }
  }

  int progressOf(DailyQuest q) => progress[q.id] ?? 0;

  bool isComplete(DailyQuest q) => progressOf(q) >= q.target;

  /// Takes the reward of quest [id] if it is today's, complete and not
  /// already taken; null otherwise.
  Rewards? claim(String id) {
    final matches = today.where((q) => q.id == id);
    if (matches.isEmpty) return null;
    final q = matches.first;
    if (!isComplete(q) || !claimed.add(id)) return null;
    return q.reward;
  }

  factory DailyQuests.fromJson(Map<String, dynamic> json) => DailyQuests(
    pool: [for (final q in (json['pool'] as List? ?? const [])) DailyQuest.fromJson((q as Map).cast<String, dynamic>())],
    perDay: (json['perDay'] as num?)?.toInt() ?? 3,
    seed: (json['seed'] as num?)?.toInt() ?? 0,
    day: json['day'] as String?,
    active: ((json['active'] as List?) ?? const []).cast<String>(),
    progress: {
      for (final e in ((json['progress'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toInt(),
    },
    claimed: {...((json['claimed'] as List?) ?? const []).cast<String>()},
  );

  Map<String, dynamic> toJson() => {
    'pool': [for (final q in pool) q.toJson()],
    'perDay': perDay,
    'seed': seed,
    if (day != null) 'day': day,
    'active': active,
    'progress': progress,
    'claimed': claimed.toList()..sort(),
  };
}
