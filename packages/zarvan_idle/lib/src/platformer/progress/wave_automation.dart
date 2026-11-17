import 'hero_progress.dart';
import 'hero_skill.dart';

/// What an automated run decided to do at the end of a fight.
enum AutoEnding { none, retry, ascend }

/// Automation for the wave-combat scene: auto-buy, auto-cast, auto-retry and
/// auto-ascend, each a toggle a game flips when the player unlocks it. Pure
/// decisions plus small timers, so the scene only applies them and tests
/// need no world.
class WaveAutomation {
  WaveAutomation({
    this.autoBuy = false,
    this.autoCast = false,
    this.autoRetry = false,
    this.autoAscend = false,
    this.buyIntervalSeconds = 0.5,
    this.endingDelaySeconds = 1.5,
    this.healBelow = 0.5,
    this.guardBelow = 0.7,
  }) : assert(buyIntervalSeconds > 0),
       assert(endingDelaySeconds >= 0);

  bool autoBuy;
  bool autoCast;

  /// Replay after a lost run, from the checkpoint.
  bool autoRetry;

  /// Ascend after clearing the boss instead of just replaying; wins over
  /// [autoRetry] for a cleared run.
  bool autoAscend;

  /// Seconds between purchase attempts.
  final double buyIntervalSeconds;

  /// How long the result stays up before an automatic retry or ascend, so
  /// the player still sees what happened.
  final double endingDelaySeconds;

  /// A heal skill is cast when the hero's hp fraction is below this.
  final double healBelow;

  /// A guard skill is cast when the hero's hp fraction is below this.
  final double guardBelow;

  double _buyClock = 0;
  double _endingClock = 0;

  /// True once per [buyIntervalSeconds] while [autoBuy] is on.
  bool buyDue(double dt) {
    if (!autoBuy) return false;
    _buyClock += dt;
    if (_buyClock < buyIntervalSeconds) return false;
    _buyClock = 0;
    return true;
  }

  /// The cheapest upgrade [progress] can afford, or null. Cheapest first so
  /// many small purchases are not starved by one expensive one.
  HeroUpgrade? pickPurchase(
    HeroProgress progress,
    Iterable<HeroUpgrade> upgrades,
  ) {
    HeroUpgrade? best;
    for (final u in upgrades) {
      if (!progress.canBuy(u)) continue;
      if (best == null || progress.costOf(u) < progress.costOf(best)) best = u;
    }
    return best;
  }

  /// Whether to cast [skill] now: strikes and ultimates whenever they can
  /// fire, heals and guards only when the hero is hurt. The runner still
  /// checks readiness and the ultimate meter.
  bool wantsCast(HeroSkill skill, double heroHpFraction) {
    if (!autoCast) return false;
    return switch (skill.kind) {
      SkillKind.strike => true,
      SkillKind.heal => heroHpFraction < healBelow,
      SkillKind.guard => heroHpFraction < guardBelow,
    };
  }

  /// Counts the finished screen and says when to leave it. Call with
  /// [finished] false during a fight to reset the wait.
  AutoEnding endingDue(
    double dt, {
    required bool finished,
    required bool won,
    required bool canAscend,
  }) {
    if (!finished) {
      _endingClock = 0;
      return AutoEnding.none;
    }
    final ascend = won && canAscend && autoAscend;
    if (!ascend && !autoRetry) return AutoEnding.none;
    _endingClock += dt;
    if (_endingClock < endingDelaySeconds) return AutoEnding.none;
    _endingClock = 0;
    return ascend ? AutoEnding.ascend : AutoEnding.retry;
  }

  factory WaveAutomation.fromJson(Map<String, dynamic> json) => WaveAutomation(
    autoBuy: json['autoBuy'] as bool? ?? false,
    autoCast: json['autoCast'] as bool? ?? false,
    autoRetry: json['autoRetry'] as bool? ?? false,
    autoAscend: json['autoAscend'] as bool? ?? false,
    buyIntervalSeconds: (json['buyIntervalSeconds'] as num?)?.toDouble() ?? 0.5,
    endingDelaySeconds: (json['endingDelaySeconds'] as num?)?.toDouble() ?? 1.5,
    healBelow: (json['healBelow'] as num?)?.toDouble() ?? 0.5,
    guardBelow: (json['guardBelow'] as num?)?.toDouble() ?? 0.7,
  );

  Map<String, dynamic> toJson() => {
    'autoBuy': autoBuy,
    'autoCast': autoCast,
    'autoRetry': autoRetry,
    'autoAscend': autoAscend,
    'buyIntervalSeconds': buyIntervalSeconds,
    'endingDelaySeconds': endingDelaySeconds,
    'healBelow': healBelow,
    'guardBelow': guardBelow,
  };
}
