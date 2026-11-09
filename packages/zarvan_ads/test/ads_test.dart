import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_ads/zarvan_ads.dart';

void main() {
  group('InterstitialPacing', () {
    test('waits for enough moments before the first ad', () {
      final p = InterstitialPacing(minMoments: 2, minInterval: Duration.zero);
      expect(p.canShow, isFalse);
      p.recordMoment();
      expect(p.canShow, isFalse);
      p.recordMoment();
      expect(p.canShow, isTrue);
    });

    test('after a show it needs both the interval and fresh moments', () {
      var t = DateTime(2026);
      final p =
          InterstitialPacing(
              minMoments: 1,
              minInterval: const Duration(minutes: 3),
              now: () => t,
            )
            ..recordMoment()
            ..markShown();
      p.recordMoment();
      expect(p.canShow, isFalse, reason: 'interval not elapsed');
      t = t.add(const Duration(minutes: 3));
      expect(p.canShow, isTrue);
      p.markShown();
      t = t.add(const Duration(minutes: 5));
      expect(p.canShow, isFalse, reason: 'markShown reset the moment count');
    });
  });

  group('NoAdsService', () {
    test('never shows or rewards', () async {
      const s = NoAdsService();
      await s.initialize();
      expect(await s.showInterstitial(), isFalse);
      expect(await s.showRewarded(), isFalse);
      expect(s.isRewardedReady, isFalse);
    });

    testWidgets('banner takes no space', (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(child: const NoAdsService().buildBanner()),
        ),
      );
      expect(
        tester.getSize(
          find.descendant(
            of: find.byType(Align),
            matching: find.byType(SizedBox),
          ),
        ),
        Size.zero,
      );
    });
  });

  group('FakeAdService', () {
    test(
      'rewarded reports earned or dismissed, and unready shows nothing',
      () async {
        final s = FakeAdService();
        expect(await s.showRewarded(), isTrue);
        s.rewardEarned = false;
        expect(await s.showRewarded(), isFalse);
        s.rewardedReady = false;
        expect(await s.showRewarded(), isFalse);
        expect(s.rewardedShown, 2);
      },
    );

    test('interstitials respect pacing', () async {
      final s = FakeAdService(
        pacing: InterstitialPacing(minMoments: 1, minInterval: Duration.zero),
      );
      expect(await s.showInterstitial(), isFalse);
      s.pacing.recordMoment();
      expect(await s.showInterstitial(), isTrue);
      expect(s.interstitialsShown, 1);
      expect(await s.showInterstitial(), isFalse);
    });
  });

  test('test ids are Google sample units', () {
    for (final ids in [AdUnitIds.androidTest, AdUnitIds.iosTest]) {
      expect(ids.banner, startsWith('ca-app-pub-3940256099942544/'));
      expect(ids.interstitial, startsWith('ca-app-pub-3940256099942544/'));
      expect(ids.rewarded, startsWith('ca-app-pub-3940256099942544/'));
    }
  });

  group('AdUnitIds.fromEnv', () {
    const env = """
# comment
ADMOB_BANNER_ANDROID=ca-app-pub-1/banner
ADMOB_REWARDED_ANDROID="ca-app-pub-1/rewarded"
ADMOB_BANNER_IOS=ca-app-pub-1/ios-banner
""";

    test('picks the platform keys and falls back per missing key', () {
      final a = AdUnitIds.fromEnv(env, ios: false);
      expect(a.banner, 'ca-app-pub-1/banner');
      expect(a.rewarded, 'ca-app-pub-1/rewarded');
      expect(a.interstitial, AdUnitIds.androidTest.interstitial);
      final i = AdUnitIds.fromEnv(env, ios: true);
      expect(i.banner, 'ca-app-pub-1/ios-banner');
      expect(i.rewarded, AdUnitIds.iosTest.rewarded);
    });

    test('load falls back to sample ids when the asset is missing', () async {
      expect(
        (await AdUnitIds.load(asset: 'nope.env')).banner,
        AdUnitIds.test.banner,
      );
    });
  });
}
