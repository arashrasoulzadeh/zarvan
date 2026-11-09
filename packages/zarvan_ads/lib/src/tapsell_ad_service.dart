import 'dart:async';

import 'package:flutter/widgets.dart';

import 'ad_service.dart';
import 'interstitial_pacing.dart';
import 'tapsell_client.dart';
import 'tapsell_ids.dart';

/// [AdService] backed by Tapsell. Android only (the SDK does nothing elsewhere), so on other platforms
/// every call reports "no ad" and the game carries on.
///
/// Like the AdMob service it preloads one ad of each full-screen kind and requests the next as soon as
/// one is used.
class TapsellAdService implements AdService {
  TapsellAdService({
    required this.ids,
    TapsellClient? client,
    InterstitialPacing? pacing,
  }) : client = client ?? TapsellPlusClient(),
       pacing = pacing ?? InterstitialPacing();

  final TapsellIds ids;
  final TapsellClient client;
  final InterstitialPacing pacing;

  String _interstitial = '';
  String _rewarded = '';
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized || !ids.isConfigured) return;
    _initialized = true;
    if (!await client.initialize(ids.appKey)) return;
    await Future.wait([
      _preload(TapsellKind.interstitial),
      _preload(TapsellKind.rewarded),
    ]);
  }

  Future<void> _preload(TapsellKind kind) async {
    final zone = kind == TapsellKind.interstitial
        ? ids.interstitial
        : ids.rewarded;
    var id = '';
    if (zone.isNotEmpty) {
      try {
        id = await client.request(kind, zone);
      } catch (_) {}
    }
    if (kind == TapsellKind.interstitial) {
      _interstitial = id;
    } else {
      _rewarded = id;
    }
  }

  /// Shows [responseId]; completes when the ad closes (true) or fails to show (false).
  Future<bool> _showAndWait(
    TapsellKind kind,
    String responseId,
    void Function() onRewarded,
  ) {
    final done = Completer<bool>();
    void finish(bool ok) {
      if (!done.isCompleted) done.complete(ok);
    }

    client
        .show(
          kind,
          responseId,
          TapsellShowCallbacks(
            onRewarded: onRewarded,
            onClosed: () => finish(true),
            onError: () => finish(false),
          ),
        )
        .catchError((_) => finish(false));
    return done.future;
  }

  @override
  Future<bool> showInterstitial() async {
    final id = _interstitial;
    if (id.isEmpty || !pacing.canShow) return false;
    _interstitial = '';
    pacing.markShown();
    final shown = await _showAndWait(TapsellKind.interstitial, id, () {});
    _preload(TapsellKind.interstitial);
    return shown;
  }

  @override
  bool get isRewardedReady => _rewarded.isNotEmpty;

  @override
  Future<bool> showRewarded() async {
    final id = _rewarded;
    if (id.isEmpty) return false;
    _rewarded = '';
    var earned = false;
    await _showAndWait(TapsellKind.rewarded, id, () => earned = true);
    _preload(TapsellKind.rewarded);
    return earned;
  }

  @override
  Widget buildBanner() => ids.banner.isEmpty
      ? const SizedBox.shrink()
      : _TapsellBanner(client: client, zone: ids.banner);

  @override
  void dispose() {}
}

/// The SDK draws banners over the app's main view rather than as a widget, so this reserves the
/// banner's height in the layout and owns the native banner's lifetime.
class _TapsellBanner extends StatefulWidget {
  const _TapsellBanner({required this.client, required this.zone});
  final TapsellClient client;
  final String zone;

  @override
  State<_TapsellBanner> createState() => _TapsellBannerState();
}

class _TapsellBannerState extends State<_TapsellBanner> {
  String _id = '';
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    widget.client
        .showBanner(widget.zone)
        .then((id) {
          if (_disposed) {
            if (id.isNotEmpty) widget.client.destroyBanner(id);
          } else {
            _id = id;
          }
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    _disposed = true;
    if (_id.isNotEmpty) widget.client.destroyBanner(_id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox(height: 50);
}
