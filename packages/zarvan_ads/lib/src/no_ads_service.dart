import 'package:flutter/widgets.dart';

import 'ad_service.dart';

/// An [AdService] that never shows anything: for web and desktop, where AdMob does not run, and for
/// players who bought "remove ads".
class NoAdsService implements AdService {
  const NoAdsService();

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> showInterstitial() async => false;

  @override
  Future<bool> showRewarded() async => false;

  @override
  bool get isRewardedReady => false;

  @override
  Widget buildBanner() => const SizedBox.shrink();

  @override
  void dispose() {}
}
