import 'package:flutter/widgets.dart';

import 'ad_service.dart';
import 'consent.dart';
import 'interstitial_pacing.dart';

/// A scriptable [AdService] for widget tests and editor previews: no SDK, no network.
class FakeAdService implements AdService {
  FakeAdService({
    this.rewardEarned = true,
    this.rewardedReady = true,
    InterstitialPacing? pacing,
    ConsentSource? consentSource,
  }) : _gate = consentSource == null
           ? ConsentGate.resolved(AdConsent.notRequired)
           : ConsentGate(consentSource),
       pacing =
           pacing ??
           InterstitialPacing(minMoments: 0, minInterval: Duration.zero);

  /// What [showRewarded] reports, to test both the earned and the dismissed-early paths.
  bool rewardEarned;
  bool rewardedReady;
  final InterstitialPacing pacing;

  final ConsentGate _gate;

  int interstitialsShown = 0;
  int rewardedShown = 0;
  bool initialized = false;
  bool disposed = false;

  @override
  AdConsent get consent => _gate.state;

  @override
  Future<AdConsent> requestConsent() => _gate.resolve();

  /// Mirrors a real network: nothing is requested until consent resolves,
  /// and a declined player gets no ads.
  @override
  Future<void> initialize() async {
    if (!(await requestConsent()).allowsAds) return;
    initialized = true;
  }

  @override
  Future<bool> showInterstitial() async {
    if (!_gate.allowsAds || !pacing.canShow) return false;
    pacing.markShown();
    interstitialsShown++;
    return true;
  }

  @override
  Future<bool> showRewarded() async {
    if (!_gate.allowsAds || !rewardedReady) return false;
    rewardedShown++;
    return rewardEarned;
  }

  @override
  bool get isRewardedReady => _gate.allowsAds && rewardedReady;

  @override
  Widget buildBanner() => const SizedBox(height: 50, key: Key('fake-banner'));

  @override
  void dispose() => disposed = true;
}
