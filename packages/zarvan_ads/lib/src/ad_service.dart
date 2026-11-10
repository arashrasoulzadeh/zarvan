import 'package:flutter/widgets.dart';

import 'consent.dart';

/// What a game needs from an ad network, and nothing else, so the network can be swapped or faked.
abstract class AdService {
  /// Where the player stands on consent. Ads are only requested once this
  /// [AdConsent.allowsAds]; a declined player still plays, with ads unavailable.
  AdConsent get consent;

  /// Runs the consent flow (once; later calls return the same answer) and
  /// completes with the result. `initialize` calls this first and waits for it.
  Future<AdConsent> requestConsent();

  /// Starts the SDK and preloads the first full-screen ads. Safe to call more than once.
  Future<void> initialize();

  /// Shows a full-screen ad at a natural break, if pacing allows and one is loaded. Returns whether it
  /// was shown; callers never wait on a missing ad.
  Future<bool> showInterstitial();

  /// Offers a rewarded ad. Completes true only when the player watched enough to earn the reward, so
  /// the caller grants the bonus (for example `IdleSession.doubleOffline`) exactly on true.
  Future<bool> showRewarded();

  /// Whether a rewarded ad is ready, so the UI can hide the "watch an ad" button instead of failing.
  bool get isRewardedReady;

  /// A banner to place in the layout; an empty box when ads are off or not loaded yet.
  Widget buildBanner();

  /// Frees native ad objects.
  void dispose();
}
