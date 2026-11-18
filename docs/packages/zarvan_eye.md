# zarvan_eye

**Runtime:** pure Dart · **Audience:** game makers · **Depends on:** nothing

A Flutter-free Dart client for the [Eye analytics collector](https://github.com/arashrasoulzadeh/eye).
Use it from a game, a service or a CLI.

## What's inside

| Piece | What it does |
|---|---|
| `EyeClient` | `init`, `ensureSession`, `identify`, `track`, `flush`, `login`/`logout`, `close`. Events batch automatically and are retained for retry. |
| `EyeOptions` | Endpoint, API key, tenant, metadata, `redactKeys`, `maxPayloadBytes`, and the two stores. |
| `EyeInstallationStore`, `EyeQueueStore` | Two small interfaces you back with `shared_preferences` or a file; the package picks no storage library. |
| `GameActivity` | Emits `game_focused`, `game_blurred`, `game_idle`, `game_resumed` and `game_time`. |
| Game helpers | `levelStarted`, `levelCompleted`, `levelFailed`, `purchase`, `adWatched`, `achievementUnlocked`, `quest`, `checkpointReached`, `currencyChanged`, `itemAcquired`, `tutorialStep`, `trackError`. |

## Quick example

```dart
final eye = await EyeClient.init(EyeOptions(
  endpoint: const String.fromEnvironment('EYE_ENDPOINT'),
  apiKey: const String.fromEnvironment('EYE_API_KEY'),
  tenantId: 'my-game',
  installationStore: myInstallationStore,
  queueStore: myQueueStore,
  redactKeys: {'email', 'token', 'password'},
));
eye.levelStarted('forest_01');
```

Keep **one** client for the process lifetime. Every event carries a stable
`anonymous_user_id` when an installation store is supplied. See
[Analytics and error reporting](../concepts/analytics-and-errors.md).

## Install

Not on pub.dev yet (pre-1.0). Depend on it through git, the same way `zarvan create` wires generated projects:

```yaml
dependencies:
  zarvan_eye:
    git:
      url: https://github.com/arashrasoulzadeh/zarvan.git
      path: packages/zarvan_eye
      ref: main
```

## Links

- [Source and README](https://github.com/arashrasoulzadeh/zarvan/tree/main/packages/zarvan_eye)
- [Changelog](https://github.com/arashrasoulzadeh/zarvan/blob/main/packages/zarvan_eye/CHANGELOG.md)

- [All packages](../packages.md)
