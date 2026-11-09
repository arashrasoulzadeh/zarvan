# Changelog

## 0.1.0

- `AdService` interface, `AdMobAdService` (banner, interstitial, rewarded), `NoAdsService`, `FakeAdService`.
- `InterstitialPacing`: minimum interval and minimum number of moments between interstitials.
- `AdUnitIds.load`/`fromEnv`: ids from the game's `.env` asset.
- `TapsellAdService` over `tapsell_plus`, `TapsellIds`, `FallbackAdService`.
