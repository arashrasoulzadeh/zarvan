# zarvan_ads

**Runtime:** Flutter (Android/iOS for real ads) · **Audience:** game makers · **Depends on:** `google_mobile_ads` only

Banner, interstitial and rewarded ads behind one small `AdService` interface.
It is a leaf package: it does not depend on any engine package, and the game
wires rewards into gameplay itself.

## What's inside

| Piece | What it does |
|---|---|
| `AdService` | The interface: `initialize`, `requestConsent`, `showInterstitial`, `showRewarded`, `isRewardedReady`, `buildBanner`. |
| `AdMobAdService` | AdMob, Android and iOS. Preloads and reloads after each use. |
| `TapsellAdService` | Tapsell, Android only. |
| `FallbackAdService` | Primary then secondary network. |
| `NoAdsService` | Web, desktop and "remove ads" purchases. |
| `FakeAdService` | Scriptable, for widget tests. |
| `InterstitialPacing` | Minimum interval and moment count between interstitials. |
| `AdUnitIds`, `TapsellIds` | Ids loaded from the game's `.env` asset; missing keys fall back to Google's sample ids. |

## Consent

`initialize()` runs `requestConsent()` first: no ad SDK starts and no ad is
requested before the answer. A player who declines still plays: the show
methods return false. See [Ads](../concepts/ads.md) for the full flow.

## Quick example

```dart
final ads = AdMobAdService(ids: await AdUnitIds.load());
await ads.initialize();
if (ads.isRewardedReady && await ads.showRewarded()) {
  session.doubleOffline(summary); // zarvan_idle
}
```

## Install

Not on pub.dev yet (pre-1.0). Depend on it through git, the same way `zarvan create` wires generated projects:

```yaml
dependencies:
  zarvan_ads:
    git:
      url: https://github.com/arashrasoulzadeh/zarvan.git
      path: packages/zarvan_ads
      ref: main
```

## Links

- [Source and README](https://github.com/arashrasoulzadeh/zarvan/tree/main/packages/zarvan_ads)
- [Changelog](https://github.com/arashrasoulzadeh/zarvan/blob/main/packages/zarvan_ads/CHANGELOG.md)

- [All packages](../packages.md)
