/// Decides when an interstitial may be shown, so a game never interrupts the player back to back.
///
/// Two independent gates must both be open: enough wall time since the last interstitial, and enough
/// natural "moments" (a level finished, a run lost) since then. [now] is injectable so the rules are
/// testable without waiting.
class InterstitialPacing {
  InterstitialPacing({
    this.minInterval = const Duration(minutes: 3),
    this.minMoments = 2,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Duration minInterval;
  final int minMoments;
  final DateTime Function() _now;

  DateTime? _lastShownAt;
  int _moments = 0;

  /// Records one natural break in play. Call it at every point an ad would be acceptable.
  void recordMoment() => _moments++;

  /// Whether an interstitial may be shown right now. The first one waits only for [minMoments], so a
  /// fresh install is not shown an ad before the player has done anything.
  bool get canShow {
    if (_moments < minMoments) return false;
    final last = _lastShownAt;
    return last == null || _now().difference(last) >= minInterval;
  }

  /// Marks an interstitial as shown: restarts the interval and the moment count.
  void markShown() {
    _lastShownAt = _now();
    _moments = 0;
  }
}
