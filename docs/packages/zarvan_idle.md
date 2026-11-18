# zarvan_idle

**Runtime:** Flutter · **Audience:** developers, game makers · **Depends on:** `zarvan_core`, `zarvan_flutter`

Idle and incremental games. A whole game is one JSON file (resources,
generators, upgrades, achievements, prestige, challenges, golden offers,
offline rules, optional auto-buyer); you write Dart only for what is yours.

The Flutter-free rules (economy, prestige, offline progress, `BigNumber`, the
balance simulator) live in `zarvan_core` (`zarvan_core_idle.dart`) so the CLI
can use them. This package re-exports them and adds what needs Flutter.

## What's inside

| Piece | What it does |
|---|---|
| `IdleController` | Steps the world about ten times a second and notifies widgets. |
| `IdleSession` | Saving, loading, offline catch-up, lifecycle, export/import codes, cloud sync, return reminders. |
| Save stores | `FileSaveStore`, `BrowserSaveStore`, `MemorySaveStore`, `CloudSaveStore`, `HttpCloudSaveStore`. |
| Widgets | `ResourceHeader`, `GeneratorList`, `UpgradeList`, `PrestigePanel`, `AchievementList`, `ChallengePanel`, `StatsPanel`, `GoldenOffer`, `SaveCodePanel`, and more. |
| `IdleSfx`, `IdleAnalytics` | Sound hooks and consent-aware analytics events. |
| Menu scenes | `HomeScene` and `LevelSelectScene`, driven by data. |
| Wave combat | `WaveCombatScene`, `WaveCombatConfig`, `AutoCombatSystem` and friends, on top of `zarvan_platformer`. |

## Quick start

```bash
zarvan create bakery --template idle_game
cd bakery && flutter run
```

Tune pacing without running the app:

```bash
zarvan idle validate assets/idle_game.json
zarvan idle simulate assets/idle_game.json --days 2 --prestige-at 2
```

See [Idle games](../concepts/idle-games.md) and
[tutorial 5](../tutorials/05-idle-game.md).

## Install

Not on pub.dev yet (pre-1.0). Depend on it through git, the same way `zarvan create` wires generated projects:

```yaml
dependencies:
  zarvan_idle:
    git:
      url: https://github.com/arashrasoulzadeh/zarvan.git
      path: packages/zarvan_idle
      ref: main
```

## Links

- [Source and README](https://github.com/arashrasoulzadeh/zarvan/tree/main/packages/zarvan_idle)
- [Changelog](https://github.com/arashrasoulzadeh/zarvan/blob/main/packages/zarvan_idle/CHANGELOG.md)
- [Generated API reference](https://meetarash.ir/zarvan/api/zarvan_idle/)
- [All packages](../packages.md)
