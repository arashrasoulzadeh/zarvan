import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'env.dart';

/// The Tapsell app key and zone ids. Unlike AdMob there are no public sample ids, so an unconfigured
/// set is simply [isConfigured] false and the game should use another service.
class TapsellIds {
  const TapsellIds({
    required this.appKey,
    required this.banner,
    required this.interstitial,
    required this.rewarded,
  });

  final String appKey;
  final String banner;
  final String interstitial;
  final String rewarded;

  /// Keys: `TAPSELL_KEY`, `TAPSELL_BANNER_ZONE`, `TAPSELL_INTERSTITIAL_ZONE`, `TAPSELL_REWARDED_ZONE`.
  factory TapsellIds.fromEnv(String contents) {
    final v = parseEnv(contents);
    return TapsellIds(
      appKey: v['TAPSELL_KEY'] ?? '',
      banner: v['TAPSELL_BANNER_ZONE'] ?? '',
      interstitial: v['TAPSELL_INTERSTITIAL_ZONE'] ?? '',
      rewarded: v['TAPSELL_REWARDED_ZONE'] ?? '',
    );
  }

  /// Loads the game's bundled `.env`; a missing asset gives an unconfigured set.
  static Future<TapsellIds> load({
    AssetBundle? bundle,
    String asset = '.env',
  }) async {
    try {
      return TapsellIds.fromEnv(await (bundle ?? rootBundle).loadString(asset));
    } catch (_) {
      return const TapsellIds(
        appKey: '',
        banner: '',
        interstitial: '',
        rewarded: '',
      );
    }
  }

  bool get isConfigured => appKey.isNotEmpty;
}
