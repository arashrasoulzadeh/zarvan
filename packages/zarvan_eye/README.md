# zarvan_eye

Flutter-free Dart integration for the [Eye analytics collector](https://github.com/arashrasoulzadeh/eye).

```dart
final eye = EyeClient(const EyeOptions(
  endpoint: 'https://analytics.example.com',
  apiKey: 'tenant-key',
  tenantId: 'my-game',
));

await eye.ensureSession();
eye.identify('player-42', {'plan': 'pro'});
eye.track('level_started', dims: {'level': 1});
await eye.flush();
eye.close();
```

For game lifecycle telemetry, use the async initializer and activity tracker:

```dart
final eye = await EyeClient.init(EyeOptions(
  endpoint: 'https://analytics.example.com',
  apiKey: 'tenant-key',
  tenantId: 'my-game',
  installationStore: myPersistentStore,
)); // creates the launch session and installation id
final activity = GameActivity(eye);
activity.track('game_started');
activity.activity(); // call from input handlers
activity.setFocused(false); // app/window lost focus
activity.setFocused(true);
activity.close(); // records final active time
eye.close();
```

`GameActivity` emits `game_focused`, `game_blurred`, `game_idle`,
`game_resumed`, and periodic/final `game_time` events.

`EyeClient.init()` always creates the launch session. It also loads or creates
an anonymous installation id and adds it to every event as
`anonymous_user_id`. Supply an `EyeInstallationStore` backed by
`shared_preferences`, a save file, or another durable store to keep that id
across app launches. The store is intentionally injected so this package stays
Flutter-free.

Events are bounded, batch automatically, and are retained for retry when ingestion fails. The package has no Flutter dependency and can be used from a game service, CLI, or Flutter app.

## Game helpers

Standard events are available as typed helpers:

```dart
eye.levelStarted('forest_01');
eye.levelCompleted('forest_01', duration: const Duration(seconds: 42));
eye.levelFailed('forest_01', reason: 'player_died');
eye.purchase('starter_pack', price: 2.99, currency: 'USD');
eye.adWatched('continue', rewarded: true);
eye.trackError(error, stackTrace: stack, fatal: false);
```

Pass game metadata through `EyeOptions.metadata`; it is attached to every
event:

```dart
EyeOptions(
  endpoint: endpoint,
  apiKey: apiKey,
  tenantId: tenant,
  metadata: {'app_version': '1.4.0', 'build': '83', 'platform': 'android'},
)
```

For offline games, provide an `EyeQueueStore` backed by durable storage.
Events are restored on launch, retained when ingestion fails, and removed from
the durable queue after a successful flush. `login()` and `logout()` manage an
optional authenticated user while preserving the installation-wide anonymous
id:

```dart
eye.login('account-42', {'plan': 'pro'});
eye.logout();
```
