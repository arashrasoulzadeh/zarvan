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

Events are bounded, batch automatically, and are retained for retry when ingestion fails. The package has no Flutter dependency and can be used from a game service, CLI, or Flutter app.
