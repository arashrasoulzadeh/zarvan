import '../progress/gear.dart';

/// Every word a wave-combat scene draws itself, so a game can translate or
/// reword it (pass your own to `WaveCombatConfig.strings`). Enemy names and
/// descriptions come from the fighters' own data, not from here.
class WaveStrings {
  const WaveStrings({
    this.coins = 'Coins',
    this.max = 'MAX',
    this.retry = 'Retry',
    this.ascend = 'Ascend',
    this.upgradesMenu = 'Upgrades',
    this.dodge = 'Dodge',
    this.combo = 'Combo',
    this.elite = 'Elite',
    this.golden = 'Golden',
    this.loot = 'Loot',
    this.ready = 'READY',
    this.wave = 'Wave',
    this.kills = 'Kills',
    this.best = 'Best',
    this.stars = 'Stars',
    this.coinsWhileAway = 'coins earned while away',
    this.hintUpgrade = 'Spend coins on upgrades to grow stronger',
    this.hintSkill = 'Tap a skill when it is ready',
    this.parry = 'Parry!',
    this.perfect = 'Perfect!',
    this.tooEarly = 'Too early',
    this.hintParry = 'Tap when an enemy flashes to parry',
    this.victory = 'VICTORY',
    this.defeat = 'DEFEAT',
    this.comingSoon = 'Coming soon',
    this.ultimate = 'ULT',
    this.waveTemplate = '{wave} {n}/{total}',
    this.digits = '0123456789',
  });

  final String coins;
  final String max;
  final String retry;
  final String ascend;

  /// The label of the button that opens the upgrade panel (`UpgradeLayout.menu`).
  final String upgradesMenu;
  final String dodge;
  final String combo;
  final String elite;
  final String golden;
  final String loot;
  final String ready;
  final String wave;
  final String kills;
  final String best;
  final String stars;
  final String coinsWhileAway;
  final String hintUpgrade;
  final String hintSkill;
  final String parry;
  final String perfect;
  final String tooEarly;
  final String hintParry;

  /// Banner of the end-of-run popup after a won / lost run.
  final String victory;
  final String defeat;

  /// Shown when a navigation tab that has no screen yet is tapped.
  final String comingSoon;

  /// Label of the ultimate meter ("ULT 60%").
  final String ultimate;

  /// The wave counter's layout; `{wave}`, `{n}` and `{total}` are replaced.
  /// Reword it (and [wave]) for a language that puts the number elsewhere.
  final String waveTemplate;

  /// The ten digits as the language writes them, in 0-9 order; [localize]
  /// swaps ASCII digits for these (`۰۱۲۳۴۵۶۷۸۹` for Persian).
  final String digits;

  /// [text] with its ASCII digits written in the language's [digits].
  String localize(String text) =>
      text.replaceAllMapped(RegExp(r'[0-9]'), (m) => digits[int.parse(m[0]!)]);

  /// The wave counter, e.g. `Wave 4/10`.
  String waveLabel(int n, int total) => localize(
    waveTemplate
        .replaceAll('{wave}', wave)
        .replaceAll('{n}', '$n')
        .replaceAll('{total}', '$total'),
  );

  /// The ultimate meter's label at [fraction] (0..1), e.g. `ULT 60%`.
  String ultimateLabel(double fraction) =>
      localize('$ultimate ${(fraction * 100).floor()}%');

  String coinsLabel(int n) => '$coins $n';
  String comboLabel(int n) => '$combo x$n';
  String eliteName(String name) => '$elite $name';
  String goldenName(String name) => '$golden $name';

  /// The retry button text; names the wave a checkpoint restarts at.
  String retryLabel(int startWave) =>
      startWave > 1 ? '$retry ($wave $startWave)' : retry;

  String awayMessage(int coinsEarned) => '+$coinsEarned $coinsWhileAway';

  /// The one-line summary under a finished run.
  String summary({
    required int wave,
    required int killCount,
    required int bestWave,
  }) => localize(
    '${this.wave} $wave · $kills $killCount · $best ${bestWave + 1}',
  );

  String lootLabel(Gear gear) =>
      '$loot: ${gear.name} +${(gear.bonus * 100).round()}%';

  /// A short "what am I wearing" line.
  String gearSummary(Iterable<Gear> worn) =>
      worn.map((g) => '${g.name} +${(g.bonus * 100).round()}%').join(' · ');
}
