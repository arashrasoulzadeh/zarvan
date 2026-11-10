# zarvan_eye

Flutter-free Dart integration for the [Eye analytics collector](https://github.com/arashrasoulzadeh/eye).

## Initialize in a game

Initialize Eye once during game startup, before creating the first scene. The
async initializer creates the first session before it returns:

```dart
Future<EyeClient> initAnalytics() {
  return EyeClient.init(EyeOptions(
    endpoint: const String.fromEnvironment('EYE_ENDPOINT'),
    apiKey: const String.fromEnvironment('EYE_API_KEY'),
    tenantId: 'my-game',
    installationStore: myInstallationStore,
    queueStore: myQueueStore,
    metadata: {
      'app_version': '1.0.0',
      'build': '42',
      'platform': 'android',
    },
    redactKeys: {'email', 'token', 'password'},
  ));
}

Future<void> main() async {
  final eye = await initAnalytics();
  final activity = GameActivity(eye);

  runGame(
    onInput: activity.activity,
    onFocusChanged: activity.setFocused,
  );

  // On the game's final shutdown callback:
  activity.close();
  await eye.flush();
  eye.close();
}
```

`EyeClient.init()` performs three startup tasks: it loads or creates the
installation-wide anonymous ID, creates the current Eye session, and restores
any events saved by the offline queue. Do not create a new client per scene;
keep one client for the lifetime of the game process.

The package does not choose a storage library. Implement the two small storage
interfaces with the persistence system used by the game:

```dart
class MyInstallationStore implements EyeInstallationStore {
  @override
  Future<String?> readAnonymousUserId() => storage.read('eye_anonymous_id');

  @override
  Future<void> writeAnonymousUserId(String id) =>
      storage.write('eye_anonymous_id', id);
}

class MyQueueStore implements EyeQueueStore {
  @override
  Future<List<Map<String, Object?>>> readEvents() async =>
      (await storage.readJsonList('eye_event_queue'));

  @override
  Future<void> writeEvents(List<Map<String, Object?>> events) =>
      storage.writeJsonList('eye_event_queue', events);
}
```

For Flutter, `storage` can be backed by `shared_preferences`; for a pure Dart
game it can be backed by a local JSON file. The anonymous ID must be stored
durably if it is intended to remain stable across app launches and upgrades.
Most mobile platforms clear this storage when the app is uninstalled.

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

Additional gameplay helpers include `achievementUnlocked`, `quest`,
`checkpointReached`, `currencyChanged`, `itemAcquired`, and `tutorialStep`.
Configure `redactKeys` and `maxPayloadBytes` in `EyeOptions` to protect event
data. `EyeQueueStore` supports durable queue implementations; malformed queued
records are ignored during recovery and concurrent flush calls are coalesced.
