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

## Consent

`AdService.initialize()` first runs `requestConsent()` and waits for it: no ad
SDK starts and no ad is requested before the answer. `AdMobAdService` uses
Google's UMP (`UmpConsentSource`); on iOS the same UMP message drives the ATT
prompt once an IDFA message is set up in the AdMob console. Tapsell and
`NoAdsService` report `AdConsent.notRequired`.

A player who declines (or whose consent check fails) still plays: `consent` is
`AdConsent.denied`, `isRewardedReady` is false and the show methods return false.
`requestConsent()` returns the cached answer; for a settings "privacy" button
use a `ConsentGate.reset()`-style re-ask through your own source. Tests script it:

```dart
final ads = FakeAdService(consentSource: myManualSource);
```

## Platform setup (the app, not this package)

Add your AdMob app id to `AndroidManifest.xml` (`com.google.android.gms.ads.APPLICATION_ID`) and
`Info.plist` (`GADApplicationIdentifier`). Until you ship, keep the default `AdUnitIds.test` ids.
Gate on consent (UMP / ATT) before `initialize()` where your audience requires it.
