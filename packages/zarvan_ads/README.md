# zarvan_ads

Banner, interstitial and rewarded ads for ZARVAN games, behind one small `AdService` interface.
Independent of the engine packages: a game wires it into gameplay itself.

```dart
final ads = AdMobAdService(ids: await AdUnitIds.load()); // reads the game's .env asset
await ads.initialize();

// Rewarded: grant the bonus exactly when this returns true.
if (ads.isRewardedReady && await ads.showRewarded()) {
  session.doubleOffline(summary); // zarvan_idle
}

// Interstitial at a natural break, paced so it never nags.
ads.pacing.recordMoment(); // level finished
await ads.showInterstitial();

// Banner anywhere in the layout.
ads.buildBanner();
```

- `AdMobAdService`: Android and iOS only. Ads are preloaded and reloaded after each use.
- `TapsellAdService`: Tapsell (Android only; the SDK does nothing elsewhere). Keys in `.env`: `TAPSELL_KEY`, `TAPSELL_BANNER_ZONE`, `TAPSELL_INTERSTITIAL_ZONE`, `TAPSELL_REWARDED_ZONE`; load with `TapsellIds.load()`. Its banner is drawn by the SDK over the main view, so `buildBanner()` reserves 50px and destroys it on dispose.
- `FallbackAdService(primary, secondary)`: e.g. Tapsell first, AdMob second.
- `NoAdsService`: web, desktop and "remove ads" purchases.
- `FakeAdService`: scriptable, for widget tests.
- `InterstitialPacing`: minimum interval plus minimum number of moments between interstitials.

## Configuring ids

Put a `.env` in the game folder, list it under `flutter: assets:` in the game's `pubspec.yaml`:

```
ADMOB_BANNER_ANDROID=ca-app-pub-xxx/111
ADMOB_INTERSTITIAL_ANDROID=ca-app-pub-xxx/222
ADMOB_REWARDED_ANDROID=ca-app-pub-xxx/333
ADMOB_BANNER_IOS=...
```

Unit ids are not secrets. A missing file or key falls back to Google's sample ids.

## Platform setup (the app, not this package)

Add your AdMob app id to `AndroidManifest.xml` (`com.google.android.gms.ads.APPLICATION_ID`) and
`Info.plist` (`GADApplicationIdentifier`). Until you ship, keep the default `AdUnitIds.test` ids.
Gate on consent (UMP / ATT) before `initialize()` where your audience requires it.
