import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart' as gma;

import 'consent.dart';

/// Consent through Google's User Messaging Platform. On iOS the same UMP
/// message also drives the App Tracking Transparency prompt when an IDFA
/// message is configured in the AdMob console, so one flow covers both
/// platforms.
class UmpConsentSource implements ConsentSource {
  const UmpConsentSource();

  @override
  Future<AdConsent> request() async {
    final info = gma.ConsentInformation.instance;
    final updated = Completer<bool>();
    info.requestConsentInfoUpdate(
      gma.ConsentRequestParameters(),
      () => updated.complete(true),
      (_) => updated.complete(false),
    );
    if (!await updated.future) return AdConsent.denied;

    final shown = Completer<void>();
    await gma.ConsentForm.loadAndShowConsentFormIfRequired(
      (_) => shown.complete(),
    );
    await shown.future;

    final status = await info.getConsentStatus();
    if (status == gma.ConsentStatus.notRequired) return AdConsent.notRequired;
    return await info.canRequestAds() ? AdConsent.granted : AdConsent.denied;
  }
}
