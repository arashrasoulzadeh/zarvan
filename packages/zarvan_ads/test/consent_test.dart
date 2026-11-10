import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_ads/zarvan_ads.dart';

class _Manual implements ConsentSource {
  final done = Completer<AdConsent>();
  int calls = 0;
  @override
  Future<AdConsent> request() {
    calls++;
    return done.future;
  }
}

class _Throws implements ConsentSource {
  @override
  Future<AdConsent> request() async => throw StateError('boom');
}

class _Fixed implements ConsentSource {
  _Fixed(this.value);
  final AdConsent value;
  @override
  Future<AdConsent> request() async => value;
}

void main() {
  test('allowsAds only for granted and notRequired', () {
    expect(AdConsent.granted.allowsAds, isTrue);
    expect(AdConsent.notRequired.allowsAds, isTrue);
    expect(AdConsent.denied.allowsAds, isFalse);
    expect(AdConsent.unknown.allowsAds, isFalse);
  });

  test('gate asks the source once and shares the answer', () async {
    final src = _Manual();
    final gate = ConsentGate(src);
    final a = gate.resolve();
    final b = gate.resolve();
    expect(gate.state, AdConsent.unknown);
    src.done.complete(AdConsent.granted);
    expect(await a, AdConsent.granted);
    expect(await b, AdConsent.granted);
    expect(src.calls, 1);
    expect(gate.allowsAds, isTrue);
  });

  test('a throwing source becomes denied instead of crashing', () async {
    final gate = ConsentGate(_Throws());
    expect(await gate.resolve(), AdConsent.denied);
    expect(gate.allowsAds, isFalse);
  });

  test('reset asks again', () async {
    final src = _Manual();
    final gate = ConsentGate(src);
    src.done.complete(AdConsent.granted);
    await gate.resolve();
    await gate.reset();
    expect(src.calls, 2);
  });

  group('FakeAdService', () {
    test('requests nothing before consent resolves', () async {
      final src = _Manual();
      final ads = FakeAdService(consentSource: src);
      final init = ads.initialize();
      await Future<void>.delayed(Duration.zero);
      expect(ads.initialized, isFalse);
      expect(ads.isRewardedReady, isFalse);
      expect(await ads.showRewarded(), isFalse);
      expect(ads.consent, AdConsent.unknown);

      src.done.complete(AdConsent.granted);
      await init;
      expect(ads.initialized, isTrue);
      expect(ads.isRewardedReady, isTrue);
      expect(await ads.showRewarded(), isTrue);
    });

    test('declined consent: game runs, ads unavailable', () async {
      final ads = FakeAdService(consentSource: _Fixed(AdConsent.denied));
      await ads.initialize();
      expect(ads.initialized, isFalse);
      expect(ads.consent, AdConsent.denied);
      expect(ads.isRewardedReady, isFalse);
      expect(await ads.showRewarded(), isFalse);
      expect(await ads.showInterstitial(), isFalse);
      expect(ads.interstitialsShown, 0);
    });

    test('default fake needs no consent', () async {
      final ads = FakeAdService();
      await ads.initialize();
      expect(ads.consent, AdConsent.notRequired);
      expect(ads.initialized, isTrue);
    });
  });

  test('NoAdsService reports consent not required', () async {
    const ads = NoAdsService();
    expect(await ads.requestConsent(), AdConsent.notRequired);
    expect(ads.consent, AdConsent.notRequired);
  });

  group('FallbackAdService consent', () {
    test('granted if either network allows ads', () async {
      final a = FakeAdService(consentSource: _Fixed(AdConsent.denied));
      final b = FakeAdService();
      final f = FallbackAdService(a, b);
      expect(await f.requestConsent(), AdConsent.granted);
      expect(f.consent, AdConsent.granted);
    });

    test('denied when both decline', () async {
      final f = FallbackAdService(
        FakeAdService(consentSource: _Fixed(AdConsent.denied)),
        FakeAdService(consentSource: _Fixed(AdConsent.denied)),
      );
      expect(await f.requestConsent(), AdConsent.denied);
    });
  });
}
