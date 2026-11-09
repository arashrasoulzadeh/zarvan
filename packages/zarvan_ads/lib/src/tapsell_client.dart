import 'package:flutter/widgets.dart';
import 'package:tapsell_plus/tapsell_plus.dart';

/// The kinds of Tapsell ad this package uses.
enum TapsellKind { interstitial, rewarded }

/// Callbacks for a shown full-screen ad.
class TapsellShowCallbacks {
  const TapsellShowCallbacks({this.onRewarded, this.onClosed, this.onError});
  final VoidCallback? onRewarded;
  final VoidCallback? onClosed;
  final VoidCallback? onError;
}

/// The slice of the Tapsell SDK the service needs. The SDK's `TapsellPlus` returns early on every
/// platform but Android and has no test seam, so the service talks to this instead and tests fake it.
abstract class TapsellClient {
  Future<bool> initialize(String appKey);

  /// Requests an ad; returns its response id, or an empty string when none is available.
  Future<String> request(TapsellKind kind, String zoneId);

  Future<void> show(
    TapsellKind kind,
    String responseId,
    TapsellShowCallbacks callbacks,
  );

  /// Requests and shows a 320x50 banner at the bottom of the screen; returns its response id or ''.
  Future<String> showBanner(String zoneId);

  Future<void> destroyBanner(String responseId);
}

/// The real client, over `tapsell_plus` (Android only).
class TapsellPlusClient implements TapsellClient {
  TapsellPlusClient([TapsellPlus? sdk]) : _sdk = sdk ?? TapsellPlus.instance;
  final TapsellPlus _sdk;

  @override
  Future<bool> initialize(String appKey) => _sdk.initialize(appKey);

  @override
  Future<String> request(TapsellKind kind, String zoneId) => switch (kind) {
    TapsellKind.interstitial => _sdk.requestInterstitialAd(zoneId),
    TapsellKind.rewarded => _sdk.requestRewardedVideoAd(zoneId),
  };

  @override
  Future<void> show(
    TapsellKind kind,
    String responseId,
    TapsellShowCallbacks c,
  ) async {
    void rewarded(Map<String, String> _) => c.onRewarded?.call();
    void closed(Map<String, String> _) => c.onClosed?.call();
    void error(Map<String, String> _) => c.onError?.call();
    switch (kind) {
      case TapsellKind.interstitial:
        await _sdk.showInterstitialAd(
          responseId,
          onRewarded: rewarded,
          onClosed: closed,
          onError: error,
        );
      case TapsellKind.rewarded:
        await _sdk.showRewardedVideoAd(
          responseId,
          onRewarded: rewarded,
          onClosed: closed,
          onError: error,
        );
    }
  }

  @override
  Future<String> showBanner(String zoneId) async {
    final id = await _sdk.requestStandardBannerAd(
      zoneId,
      TapsellPlusBannerType.BANNER_320x50,
    );
    if (id.isEmpty) return '';
    // The SDK's gravity enums are named the other way round: "horizontal" is top/center/bottom.
    await _sdk.showStandardBannerAd(
      id,
      TapsellPlusHorizontalGravity.BOTTOM,
      TapsellPlusVerticalGravity.CENTER,
    );
    return id;
  }

  @override
  Future<void> destroyBanner(String responseId) async {
    await _sdk.destroyStandardBanner(responseId);
  }
}
