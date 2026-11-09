/// Ads for ZARVAN games: banner, interstitial and rewarded behind one [AdService].
///
/// Deliberately independent of the engine packages; a game wires the result into gameplay itself, for
/// example granting `IdleSession.doubleOffline` when `showRewarded` completes true.
library;

export 'src/ad_service.dart';
export 'src/ad_unit_ids.dart';
export 'src/admob_ad_service.dart';
export 'src/fake_ad_service.dart';
export 'src/fallback_ad_service.dart';
export 'src/tapsell_ad_service.dart';
export 'src/tapsell_client.dart';
export 'src/tapsell_ids.dart';
export 'src/interstitial_pacing.dart';
export 'src/no_ads_service.dart';
