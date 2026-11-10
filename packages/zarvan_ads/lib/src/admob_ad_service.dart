import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as gma;

import 'ad_service.dart';
import 'consent.dart';
import 'ump_consent_source.dart';
import 'ad_unit_ids.dart';
import 'interstitial_pacing.dart';

/// [AdService] backed by Google AdMob. Mobile only (Android and iOS): use `NoAdsService` elsewhere.
///
/// Full-screen ads are preloaded and reloaded right after each use, because AdMob ads are single-shot
/// and loading on demand would make the player wait at the exact moment the ad is wanted.
class AdMobAdService implements AdService {
  AdMobAdService({
    AdUnitIds? ids,
    InterstitialPacing? pacing,
    ConsentSource consentSource = const UmpConsentSource(),
  }) : ids = ids ?? AdUnitIds.test,
       pacing = pacing ?? InterstitialPacing(),
       _gate = ConsentGate(consentSource);

  final AdUnitIds ids;
  final InterstitialPacing pacing;

  final ConsentGate _gate;
  gma.InterstitialAd? _interstitial;
  gma.RewardedAd? _rewarded;
  bool _initialized = false;

  @override
  AdConsent get consent => _gate.state;

  @override
  Future<AdConsent> requestConsent() => _gate.resolve();

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    // The SDK is not started, and no ad requested, before consent resolves.
    if (!(await requestConsent()).allowsAds) return;
    await gma.MobileAds.instance.initialize();
    _loadInterstitial();
    _loadRewarded();
  }

  void _loadInterstitial() {
    gma.InterstitialAd.load(
      adUnitId: ids.interstitial,
      request: const gma.AdRequest(),
      adLoadCallback: gma.InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  void _loadRewarded() {
    gma.RewardedAd.load(
      adUnitId: ids.rewarded,
      request: const gma.AdRequest(),
      rewardedAdLoadCallback: gma.RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (_) => _rewarded = null,
      ),
    );
  }

  @override
  Future<bool> showInterstitial() async {
    final ad = _interstitial;
    if (ad == null || !pacing.canShow) return false;
    _interstitial = null;
    pacing.markShown();
    final done = Completer<bool>();
    ad.fullScreenContentCallback = gma.FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
        done.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _loadInterstitial();
        done.complete(false);
      },
    );
    await ad.show();
    return done.future;
  }

  @override
  bool get isRewardedReady => _rewarded != null;

  @override
  Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) return false;
    _rewarded = null;
    var earned = false;
    final done = Completer<bool>();
    ad.fullScreenContentCallback = gma.FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewarded();
        done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _loadRewarded();
        done.complete(false);
      },
    );
    await ad.show(onUserEarnedReward: (_, _) => earned = true);
    return done.future;
  }

  @override
  Widget buildBanner() => _gate.allowsAds
      ? _BannerSlot(unitId: ids.banner)
      : const SizedBox.shrink();

  @override
  void dispose() {
    _interstitial?.dispose();
    _rewarded?.dispose();
    _interstitial = _rewarded = null;
  }
}

class _BannerSlot extends StatefulWidget {
  const _BannerSlot({required this.unitId});
  final String unitId;

  @override
  State<_BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<_BannerSlot> {
  gma.BannerAd? _ad;

  @override
  void initState() {
    super.initState();
    _ad = gma.BannerAd(
      adUnitId: widget.unitId,
      size: gma.AdSize.banner,
      request: const gma.AdRequest(),
      listener: gma.BannerAdListener(
        onAdLoaded: (_) => mounted ? setState(() {}) : null,
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: gma.AdWidget(ad: ad),
    );
  }
}
