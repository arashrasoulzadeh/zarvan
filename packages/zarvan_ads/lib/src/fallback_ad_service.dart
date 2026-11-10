import 'package:flutter/widgets.dart';

import 'ad_service.dart';
import 'consent.dart';

/// Tries [primary] and falls back to [secondary] when it has nothing to show, e.g. Tapsell first and
/// AdMob second so an unfilled request costs no impression.
class FallbackAdService implements AdService {
  FallbackAdService(this.primary, this.secondary);
  final AdService primary;
  final AdService secondary;

  @override
  AdConsent get consent => _combine(primary.consent, secondary.consent);

  @override
  Future<AdConsent> requestConsent() async {
    final both = await Future.wait([
      primary.requestConsent(),
      secondary.requestConsent(),
    ]);
    return _combine(both[0], both[1]);
  }

  static AdConsent _combine(AdConsent a, [AdConsent? b]) {
    final all = [a, ?b];
    if (all.any((c) => c == AdConsent.unknown)) return AdConsent.unknown;
    return all.any((c) => c.allowsAds) ? AdConsent.granted : AdConsent.denied;
  }

  @override
  Future<void> initialize() =>
      Future.wait([primary.initialize(), secondary.initialize()]);

  @override
  Future<bool> showInterstitial() async =>
      await primary.showInterstitial() || await secondary.showInterstitial();

  @override
  Future<bool> showRewarded() async {
    if (primary.isRewardedReady) return primary.showRewarded();
    return secondary.showRewarded();
  }

  @override
  bool get isRewardedReady =>
      primary.isRewardedReady || secondary.isRewardedReady;

  @override
  Widget buildBanner() => primary.buildBanner();

  @override
  void dispose() {
    primary.dispose();
    secondary.dispose();
  }
}
