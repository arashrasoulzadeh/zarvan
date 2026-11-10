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
final eye = await EyeClient.init(options); // creates the default session
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

Events are bounded, batch automatically, and are retained for retry when ingestion fails. The package has no Flutter dependency and can be used from a game service, CLI, or Flutter app.
