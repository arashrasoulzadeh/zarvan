import 'package:flutter/widgets.dart';

import 'ad_service.dart';
import 'interstitial_pacing.dart';

/// A scriptable [AdService] for widget tests and editor previews: no SDK, no network.
class FakeAdService implements AdService {
  FakeAdService({
    this.rewardEarned = true,
    this.rewardedReady = true,
    InterstitialPacing? pacing,
  }) : pacing =
           pacing ??
           InterstitialPacing(minMoments: 0, minInterval: Duration.zero);

  /// What [showRewarded] reports, to test both the earned and the dismissed-early paths.
  bool rewardEarned;
  bool rewardedReady;
  final InterstitialPacing pacing;

  int interstitialsShown = 0;
  int rewardedShown = 0;
  bool initialized = false;
  bool disposed = false;

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<bool> showInterstitial() async {
    if (!pacing.canShow) return false;
    pacing.markShown();
    interstitialsShown++;
    return true;
  }

  @override
  Future<bool> showRewarded() async {
    if (!rewardedReady) return false;
    rewardedShown++;
    return rewardEarned;
  }

  @override
  bool get isRewardedReady => rewardedReady;

  @override
  Widget buildBanner() => const SizedBox(height: 50, key: Key('fake-banner'));

  @override
  void dispose() => disposed = true;
}
