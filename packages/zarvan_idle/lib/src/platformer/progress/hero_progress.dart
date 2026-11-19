import 'dart:math' as math;

import 'gear.dart';

/// One purchasable hero improvement in a wave-combat game.
class HeroUpgrade {
  const HeroUpgrade({
    required this.id,
    required this.label,
    required this.stat,
    this.perLevel = 0.25,
    this.baseCost = 20,
    this.costGrowth = 1.6,
    this.maxLevel = 20,
    this.icon,
    this.description,
  });

  /// Stable key progress is stored under.
  final String id;

  /// Button text.
  final String label;

  /// Frame index in the icon strip (`WaveUiArt.iconsStem`) drawn on the
  /// button, or null for a text-only button.
  final int? icon;

  /// A line under the name in the upgrades dialog (`UpgradeLayout.menu`),
  /// e.g. what a level gives; null shows none.
  final String? description;

  /// Which fighter stat it raises: `hp`, `attack`, `armor` or `attack_speed`.
  final String stat;

  /// Each level adds this fraction of the base stat (0.25 = +25% of base).
  final double perLevel;

  /// Coins for the first level; each further level costs [costGrowth] times
  /// the previous one.
  final double baseCost;
  final double costGrowth;
  final int maxLevel;
}

/// Everything about the hero that outlives a run: coins, upgrade levels,
/// prestige stars, the best wave reached, worn gear and small counters. The
/// game keeps one, so it survives a retry; [toJson]/[fromJson] let it survive
/// closing the app (see `HeroProgressStore`).
class HeroProgress {
  HeroProgress({
    this.coins = 0,
    Map<String, int>? levels,
    this.stars = 0,
    this.bestWave = 0,
    this.kills = 0,
    this.runs = 0,
    this.lastActiveMs,
    Map<String, Gear>? gear,
    List<Gear>? bag,
    Set<String>? hintsSeen,
    this.onChanged,
  }) : _levels = {...?levels},
       gear = {...?gear},
       bag = [...?bag],
       hintsSeen = {...?hintsSeen};

  int coins;
  final Map<String, int> _levels;

  /// Prestige stars: each adds a permanent bonus (see `WaveCombatConfig`).
  int stars;

  /// Highest wave index (0-based) the hero has reached in any run since the
  /// last prestige; checkpoints are derived from it.
  int bestWave;
  int kills;
  int runs;

  /// Wall-clock time of the last save, in ms since the epoch, for offline
  /// earnings; null before the first save.
  int? lastActiveMs;

  /// Worn gear by slot.
  final Map<String, Gear> gear;

  /// Gear owned but not worn: spares, and items replaced by better ones.
  /// Browse, equip and merge them (see [equipFromBag], [mergeBag]).
  final List<Gear> bag;

  /// Most items the [bag] holds; a drop that does not fit is lost.
  static const bagCapacity = 40;

  /// Hints the player has already seen, so they show once.
  final Set<String> hintsSeen;

  /// Called after every change worth saving; the game wires it to a store.
  void Function()? onChanged;

  /// Coins earned while away, waiting to be shown once (not saved).
  int pendingOfflineCoins = 0;
  Duration pendingOfflineAway = Duration.zero;

  void _changed() => onChanged?.call();

  int levelOf(HeroUpgrade upgrade) => _levels[upgrade.id] ?? 0;

  bool isMaxed(HeroUpgrade upgrade) => levelOf(upgrade) >= upgrade.maxLevel;

  /// Coins the next level costs, rounded up to a whole coin.
  int costOf(HeroUpgrade upgrade) =>
      (upgrade.baseCost * math.pow(upgrade.costGrowth, levelOf(upgrade)))
          .ceil();

  bool canBuy(HeroUpgrade upgrade) =>
      !isMaxed(upgrade) && coins >= costOf(upgrade);

  /// Buys one level; false (and nothing changes) when it cannot be afforded
  /// or is already at its maximum.
  bool buy(HeroUpgrade upgrade) {
    if (!canBuy(upgrade)) return false;
    coins -= costOf(upgrade);
    _levels[upgrade.id] = levelOf(upgrade) + 1;
    _changed();
    return true;
  }

  void addCoins(int amount) {
    if (amount == 0) return;
    coins += amount;
    _changed();
  }

  void recordKill() {
    kills++;
    _changed();
  }

  void startRun() {
    runs++;
    _changed();
  }

  /// Notes that the hero reached wave [index]; raises [bestWave] if higher.
  void reachWave(int index) {
    if (index <= bestWave) return;
    bestWave = index;
    _changed();
  }

  /// The wave a new run starts at: the best wave rounded down to a multiple
  /// of [every] (0 = always from the start).
  int checkpoint(int every) => every <= 0 ? 0 : (bestWave ~/ every) * every;

  /// Trades the run for a permanent star: coins, upgrades and the best wave
  /// reset; stars, gear and counters stay.
  void ascend() {
    stars++;
    coins = 0;
    _levels.clear();
    bestWave = 0;
    _changed();
  }

  /// Wears [item] if it beats what is in its slot; returns whether it did.
  bool equipIfBetter(Gear item) {
    final worn = gear[item.slot];
    if (!item.betterThan(worn)) return false;
    gear[item.slot] = item;
    if (worn != null) _stash(worn);
    _changed();
    return true;
  }

  /// Puts [item] in the bag; false (and nothing changes) when it is full.
  bool addToBag(Gear item) {
    if (!_stash(item)) return false;
    _changed();
    return true;
  }

  bool _stash(Gear item) {
    if (bag.length >= bagCapacity) return false;
    bag.add(item);
    return true;
  }

  /// How much [item] would change the bonus of its slot if worn now
  /// (positive = an upgrade; a stat change between slots is not compared).
  double compareToWorn(Gear item) => item.bonus - (gear[item.slot]?.bonus ?? 0);

  /// Wears bag item [index] and puts what was worn there back in the bag.
  /// False when [index] is out of range.
  bool equipFromBag(int index) {
    if (index < 0 || index >= bag.length) return false;
    final item = bag.removeAt(index);
    final worn = gear[item.slot];
    gear[item.slot] = item;
    if (worn != null) bag.add(worn);
    _changed();
    return true;
  }

  /// How many bag items of this kind can merge, in groups of
  /// [mergeCount].
  int mergeablePairs(Gear like) => _kind(like).length ~/ mergeCount;

  /// Bag items that count as the same kind for merging.
  List<Gear> _kind(Gear like) => [
    for (final g in bag)
      if (g.slot == like.slot && g.stat == like.stat && g.rarity == like.rarity) g,
  ];

  /// Items of one kind needed to make one of the next rarity.
  static const mergeCount = 3;

  /// Multiplier on the average bonus of the merged items, by their rarity.
  static const mergeBoost = {GearRarity.common: 2.0, GearRarity.rare: 1.8};

  /// Merges the [mergeCount] best bag items of [like]'s slot, stat and
  /// rarity into one of the next rarity whose bonus is their average times
  /// [mergeBoost]. Returns it, or null when there are too few or the rarity
  /// is already the top.
  Gear? mergeBag(Gear like) {
    final boost = mergeBoost[like.rarity];
    if (boost == null) return null;
    final kind = _kind(like);
    if (kind.length < mergeCount) return null;
    kind.sort((a, b) => b.bonus.compareTo(a.bonus));
    final used = kind.take(mergeCount).toList();
    for (final g in used) {
      bag.remove(g);
    }
    final average = used.fold(0.0, (sum, g) => sum + g.bonus) / mergeCount;
    final merged = Gear(
      slot: like.slot,
      name: used.first.name,
      stat: like.stat,
      bonus: average * boost,
      rarity: GearRarity.values[like.rarity.index + 1],
    );
    bag.add(merged);
    _changed();
    return merged;
  }

  /// Bonus fraction of [stat] from worn gear.
  double gearBonus(String stat) => gear.values
      .where((g) => g.stat == stat)
      .fold(0.0, (sum, g) => sum + g.bonus);

  /// Marks [id] seen; true the first time (so the hint shows once).
  bool markHintSeen(String id) {
    if (!hintsSeen.add(id)) return false;
    _changed();
    return true;
  }

  /// The factor applied to the base [stat]: 1 plus every bought level's
  /// `perLevel` of the upgrades in [upgrades] that raise it.
  double multiplier(String stat, Iterable<HeroUpgrade> upgrades) {
    var m = 1.0;
    for (final u in upgrades) {
      if (u.stat == stat) m += u.perLevel * levelOf(u);
    }
    return m;
  }

  Map<String, dynamic> toJson() => {
    'coins': coins,
    'levels': _levels,
    'stars': stars,
    'bestWave': bestWave,
    'kills': kills,
    'runs': runs,
    if (lastActiveMs != null) 'lastActiveMs': lastActiveMs,
    'gear': {for (final e in gear.entries) e.key: e.value.toJson()},
    if (bag.isNotEmpty) 'bag': [for (final g in bag) g.toJson()],
    'hintsSeen': hintsSeen.toList(),
  };

  factory HeroProgress.fromJson(Map<String, dynamic> json) => HeroProgress(
    coins: (json['coins'] as num?)?.toInt() ?? 0,
    levels: {
      for (final e in ((json['levels'] as Map?) ?? const {}).entries)
        e.key as String: (e.value as num).toInt(),
    },
    stars: (json['stars'] as num?)?.toInt() ?? 0,
    bestWave: (json['bestWave'] as num?)?.toInt() ?? 0,
    kills: (json['kills'] as num?)?.toInt() ?? 0,
    runs: (json['runs'] as num?)?.toInt() ?? 0,
    lastActiveMs: (json['lastActiveMs'] as num?)?.toInt(),
    gear: {
      for (final e in ((json['gear'] as Map?) ?? const {}).entries)
        e.key as String: Gear.fromJson(
          (e.value as Map).cast<String, dynamic>(),
        ),
    },
    bag: [
      for (final g in (json['bag'] as List? ?? const []))
        Gear.fromJson((g as Map).cast<String, dynamic>()),
    ],
    hintsSeen: {...?(json['hintsSeen'] as List?)?.cast<String>()},
  );
}
