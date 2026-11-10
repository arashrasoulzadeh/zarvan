import 'dart:async';

import 'eye_client.dart';

/// Tracks foreground time and idle periods for a game session.
class GameActivity {
  /// Creates an activity tracker attached to [eye].
  GameActivity(
    this.eye, {
    this.idleAfter = const Duration(minutes: 2),
    this.heartbeat = const Duration(seconds: 30),
  }) {
    if (idleAfter <= Duration.zero) {
      throw ArgumentError.value(idleAfter, 'idleAfter');
    }
    if (heartbeat <= Duration.zero) {
      throw ArgumentError.value(heartbeat, 'heartbeat');
    }
    _lastActivity = DateTime.now();
    _activeSince = DateTime.now();
    _timer = Timer.periodic(heartbeat, (_) => _poll());
  }

  /// Analytics client receiving activity events.
  final EyeClient eye;

  /// Inactivity duration before an idle event is emitted.
  final Duration idleAfter;

  /// Interval for recording active game time and checking idleness.
  final Duration heartbeat;

  Timer? _timer;
  DateTime _lastActivity = DateTime.now();
  DateTime? _activeSince;
  Duration _activeTime = Duration.zero;
  bool _focused = true;
  bool _idle = false;
  bool _closed = false;

  /// Whether the game currently has foreground focus.
  bool get isFocused => _focused;

  /// Whether the tracker currently considers the player idle.
  bool get isIdle => _idle;

  /// Total foreground time observed by this tracker.
  Duration get activeTime => _activeTime + _currentActiveTime;

  /// Marks player activity, such as input, a tap, or a completed action.
  void activity([Map<String, Object?>? dims]) {
    _checkOpen();
    _lastActivity = DateTime.now();
    if (_idle) {
      _idle = false;
      eye.track('game_resumed', dims: dims);
    }
  }

  /// Updates focus state and emits `game_focused` or `game_blurred`.
  void setFocused(bool focused) {
    _checkOpen();
    if (_focused == focused) return;
    _recordActiveTime();
    _focused = focused;
    if (focused) {
      _activeSince = DateTime.now();
      eye.track('game_focused');
      activity();
    } else {
      _activeSince = null;
      eye.track('game_blurred');
    }
  }

  /// Records a named game lifecycle event and refreshes idle detection.
  void track(
    String name, {
    Map<String, Object?>? payload,
    Map<String, Object?>? dims,
  }) {
    _checkOpen();
    activity(dims);
    eye.track(name, payload: payload, dims: dims);
  }

  /// Stops timers and emits the final accumulated game-time event.
  void close() {
    if (_closed) return;
    _recordActiveTime();
    if (_activeTime > Duration.zero) {
      eye.track('game_time', dims: {'active_ms': _activeTime.inMilliseconds});
    }
    _timer?.cancel();
    _closed = true;
  }

  Duration get _currentActiveTime => _activeSince == null
      ? Duration.zero
      : DateTime.now().difference(_activeSince!);

  void _poll() {
    if (_closed) return;
    _recordActiveTime();
    if (_focused &&
        !_idle &&
        DateTime.now().difference(_lastActivity) >= idleAfter) {
      _idle = true;
      eye.track('game_idle');
    }
    if (_focused && !_idle) {
      eye.track('game_time', dims: {'active_ms': heartbeat.inMilliseconds});
    }
  }

  void _recordActiveTime() {
    if (_activeSince == null) return;
    _activeTime += DateTime.now().difference(_activeSince!);
    _activeSince = DateTime.now();
  }

  void _checkOpen() {
    if (_closed) throw StateError('GameActivity is closed');
  }
}
