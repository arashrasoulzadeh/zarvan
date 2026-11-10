/// Where the player stands on ad consent (GDPR/UMP on Android, ATT on iOS).
enum AdConsent {
  /// Not asked yet, or the request is still running.
  unknown,

  /// The player agreed; ads may be requested.
  granted,

  /// The player declined, or the consent check failed. The game keeps
  /// running; ads simply report unavailable.
  denied,

  /// This region/platform/network needs no consent (e.g. Tapsell, desktop).
  notRequired;

  /// Whether ads may be requested in this state.
  bool get allowsAds => this == granted || this == notRequired;
}

/// Asks the platform for consent. Separate from the ad networks so one flow
/// serves several of them and tests can script the answer.
abstract class ConsentSource {
  /// Shows whatever consent UI the platform requires and reports the result.
  Future<AdConsent> request();
}

/// A [ConsentSource] for networks and platforms that need no consent.
class NoConsentRequired implements ConsentSource {
  const NoConsentRequired();

  @override
  Future<AdConsent> request() async => AdConsent.notRequired;
}

/// Runs a [ConsentSource] once and remembers the answer, so every caller
/// (`initialize`, a settings button, a banner) shares one consent flow and
/// ad networks wait on [resolve] before touching any SDK.
class ConsentGate {
  ConsentGate(this.source);

  /// A gate whose answer is already known and needs no question -- for fakes
  /// and for networks that never need consent.
  ConsentGate.resolved(AdConsent answer)
    : source = _Known(answer),
      _state = answer,
      _pending = Future.value(answer);

  final ConsentSource source;
  AdConsent _state = AdConsent.unknown;
  Future<AdConsent>? _pending;

  /// The latest known state; [AdConsent.unknown] until [resolve] completes.
  AdConsent get state => _state;

  /// Whether ads may be requested right now.
  bool get allowsAds => _state.allowsAds;

  /// Asks for consent (once) and completes with the result. A source that
  /// throws counts as [AdConsent.denied] so a broken consent SDK can never
  /// crash or stall the game.
  Future<AdConsent> resolve() => _pending ??= _run();

  /// Asks again, e.g. from a settings "privacy" button after the player
  /// changed their mind.
  Future<AdConsent> reset() {
    _pending = null;
    return resolve();
  }

  Future<AdConsent> _run() async {
    try {
      _state = await source.request();
    } catch (_) {
      _state = AdConsent.denied;
    }
    return _state;
  }
}

class _Known implements ConsentSource {
  const _Known(this.answer);
  final AdConsent answer;

  @override
  Future<AdConsent> request() async => answer;
}
