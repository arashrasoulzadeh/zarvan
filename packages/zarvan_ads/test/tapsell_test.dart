import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_ads/zarvan_ads.dart';

class _Client implements TapsellClient {
  bool initOk = true;
  String nextId = 'r1';
  int requests = 0;
  List<String> shown = [];
  List<String> destroyed = [];
  String bannerId = 'b1';

  /// What the "SDK" does when asked to show: call these in order.
  void Function(TapsellShowCallbacks) script = (c) {
    c.onRewarded?.call();
    c.onClosed?.call();
  };

  @override
  Future<bool> initialize(String appKey) async => initOk;

  @override
  Future<String> request(TapsellKind kind, String zoneId) async {
    requests++;
    return nextId;
  }

  @override
  Future<void> show(
    TapsellKind kind,
    String responseId,
    TapsellShowCallbacks c,
  ) async {
    shown.add('${kind.name}:$responseId');
    script(c);
  }

  @override
  Future<String> showBanner(String zoneId) async => bannerId;

  @override
  Future<void> destroyBanner(String responseId) async =>
      destroyed.add(responseId);
}

const _ids = TapsellIds(
  appKey: 'k',
  banner: 'zb',
  interstitial: 'zi',
  rewarded: 'zr',
);

TapsellAdService _service(_Client c) => TapsellAdService(
  ids: _ids,
  client: c,
  pacing: InterstitialPacing(minMoments: 0, minInterval: Duration.zero),
);

void main() {
  test('ids parse from .env and report configured', () {
    final ids = TapsellIds.fromEnv(
      'TAPSELL_KEY=abc\nTAPSELL_REWARDED_ZONE="z9"\n',
    );
    expect(ids.appKey, 'abc');
    expect(ids.rewarded, 'z9');
    expect(ids.banner, '');
    expect(ids.isConfigured, isTrue);
    expect(TapsellIds.fromEnv('').isConfigured, isFalse);
  });

  test('unconfigured or failed init preloads nothing', () async {
    final c = _Client();
    await TapsellAdService(ids: TapsellIds.fromEnv(''), client: c).initialize();
    expect(c.requests, 0);
    final failed = _Client()..initOk = false;
    final s = _service(failed);
    await s.initialize();
    expect(failed.requests, 0);
    expect(s.isRewardedReady, isFalse);
  });

  test(
    'rewarded is true only when the reward callback fired, and reloads',
    () async {
      final c = _Client();
      final s = _service(c);
      await s.initialize();
      expect(s.isRewardedReady, isTrue);
      expect(await s.showRewarded(), isTrue);
      await Future<void>.delayed(Duration.zero);
      expect(s.isRewardedReady, isTrue, reason: 'next ad requested after use');

      c.script = (cb) => cb.onClosed?.call();
      expect(await s.showRewarded(), isFalse, reason: 'closed without reward');

      c.script = (cb) => cb.onError?.call();
      expect(await s.showRewarded(), isFalse);
    },
  );

  test('rewarded with nothing loaded returns false without showing', () async {
    final c = _Client()..nextId = '';
    final s = _service(c);
    await s.initialize();
    expect(await s.showRewarded(), isFalse);
    expect(c.shown, isEmpty);
  });

  test('interstitial honours pacing and reports a failed show', () async {
    final c = _Client();
    final s = TapsellAdService(
      ids: _ids,
      client: c,
      pacing: InterstitialPacing(minMoments: 1, minInterval: Duration.zero),
    );
    await s.initialize();
    expect(await s.showInterstitial(), isFalse);
    s.pacing.recordMoment();
    expect(await s.showInterstitial(), isTrue);
    await Future<void>.delayed(Duration.zero);
    s.pacing.recordMoment();
    c.script = (cb) => cb.onError?.call();
    expect(await s.showInterstitial(), isFalse);
  });

  testWidgets('banner is destroyed with its widget', (tester) async {
    final c = _Client();
    final s = _service(c);
    await tester.pumpWidget(
      Directionality(textDirection: TextDirection.ltr, child: s.buildBanner()),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(c.destroyed, ['b1']);
  });

  test(
    'FallbackAdService uses the secondary when the primary has nothing',
    () async {
      final primary = FakeAdService(rewardedReady: false);
      final secondary = FakeAdService();
      final f = FallbackAdService(primary, secondary);
      expect(f.isRewardedReady, isTrue);
      expect(await f.showRewarded(), isTrue);
      expect(primary.rewardedShown, 0);
      expect(secondary.rewardedShown, 1);
      primary.rewardedReady = true;
      await f.showRewarded();
      expect(primary.rewardedShown, 1);
    },
  );
}
