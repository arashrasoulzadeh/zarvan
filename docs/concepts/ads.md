# Ads

[`zarvan_ads`](../packages/zarvan_ads.md) puts banner, interstitial and rewarded
ads behind one interface, `AdService`. It depends on no engine package: your game
decides when to show an ad and what a reward does.

## Choosing a service

| Service | Use for |
|---|---|
| `AdMobAdService` | Android and iOS. Preloads each format and reloads after use. |
| `TapsellAdService` | Android only. Its banner is drawn by the SDK over the main view, so `buildBanner()` reserves 50px. |
| `FallbackAdService(primary, secondary)` | Try one network, then another. |
| `NoAdsService` | Web, desktop, and players who bought "remove ads". |
| `FakeAdService` | Widget tests; scriptable results and consent. |

## Using it

```dart
final ads = AdMobAdService(ids: await AdUnitIds.load());
await ads.initialize();

// Grant the reward exactly when this returns true.
if (ads.isRewardedReady && await ads.showRewarded()) {
  session.doubleOffline(summary); // zarvan_idle
}

ads.pacing.recordMoment();      // a level finished
await ads.showInterstitial();   // shown only if pacing allows it
ads.buildBanner();              // anywhere in the layout
```

`InterstitialPacing` enforces a minimum interval **and** a minimum number of
natural breaks, so interstitials never nag.

## Unit ids

Put a `.env` in the game folder and list it under `flutter: assets:`:

```
ADMOB_BANNER_ANDROID=ca-app-pub-xxx/111
ADMOB_INTERSTITIAL_ANDROID=ca-app-pub-xxx/222
ADMOB_REWARDED_ANDROID=ca-app-pub-xxx/333
```

Unit ids are not secrets. A missing file or key falls back to Google's sample
ids, so development builds never serve real ads by accident.

## Consent

`initialize()` first awaits `requestConsent()`. No SDK starts and no ad is
requested before the answer. `AdMobAdService` uses Google's UMP; on iOS the same
message drives the ATT prompt. A player who declines still plays: `consent` is
`AdConsent.denied`, `isRewardedReady` is false and the show methods return false.
Tapsell and `NoAdsService` report `AdConsent.notRequired`.

Add your AdMob app id to `AndroidManifest.xml` and `Info.plist` in the app. Keep
the test ids until you ship. Pair ad events with
[analytics](analytics-and-errors.md) (`adWatched`).
