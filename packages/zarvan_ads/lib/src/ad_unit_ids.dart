import 'dart:io' show Platform;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'env.dart';

/// The AdMob ad unit ids for one platform.
///
/// Kept as plain data so a game can read them from its own config; the engine never hardcodes a real id.
class AdUnitIds {
  const AdUnitIds({
    required this.banner,
    required this.interstitial,
    required this.rewarded,
  });

  final String banner;
  final String interstitial;
  final String rewarded;

  /// Google's published sample ids for Android. Using these during development avoids invalid-traffic
  /// flags on a real account, which is why they are the default.
  static const androidTest = AdUnitIds(
    banner: 'ca-app-pub-3940256099942544/6300978111',
    interstitial: 'ca-app-pub-3940256099942544/1033173712',
    rewarded: 'ca-app-pub-3940256099942544/5224354917',
  );

  /// Google's published sample ids for iOS.
  static const iosTest = AdUnitIds(
    banner: 'ca-app-pub-3940256099942544/2934735716',
    interstitial: 'ca-app-pub-3940256099942544/4411468910',
    rewarded: 'ca-app-pub-3940256099942544/1712485313',
  );

  /// The sample ids matching the running platform (Android's anywhere that is not iOS).
  static AdUnitIds get test => Platform.isIOS ? iosTest : androidTest;

  /// Reads ids from `.env` text (`KEY=value` lines, `#` comments). Keys, per platform suffix `ANDROID`
  /// or `IOS`: `ADMOB_BANNER_<P>`, `ADMOB_INTERSTITIAL_<P>`, `ADMOB_REWARDED_<P>`. Any missing key falls
  /// back to the sample id, so a half-filled file never ships a blank unit id.
  factory AdUnitIds.fromEnv(String contents, {bool? ios}) {
    final isIos = ios ?? Platform.isIOS;
    final suffix = isIos ? 'IOS' : 'ANDROID';
    final fallback = isIos ? iosTest : androidTest;
    final values = parseEnv(contents);
    String pick(String name, String sample) {
      final v = values['ADMOB_${name}_$suffix'];
      return v == null || v.isEmpty ? sample : v;
    }

    return AdUnitIds(
      banner: pick('BANNER', fallback.banner),
      interstitial: pick('INTERSTITIAL', fallback.interstitial),
      rewarded: pick('REWARDED', fallback.rewarded),
    );
  }

  /// Loads the game's bundled `.env` asset (declare it under `flutter: assets:` in the game's pubspec).
  /// A missing asset yields the sample ids, so a fresh game runs with test ads and no setup.
  static Future<AdUnitIds> load({
    AssetBundle? bundle,
    String asset = '.env',
  }) async {
    try {
      return AdUnitIds.fromEnv(await (bundle ?? rootBundle).loadString(asset));
    } catch (_) {
      return test;
    }
  }
}
