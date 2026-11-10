import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

/// Raised when the Eye collector rejects a request.
class EyeRequestException implements Exception {
  /// Creates an exception for an unsuccessful collector response.
  const EyeRequestException(this.message);

  /// Human-readable failure details.
  final String message;

  @override
  String toString() => message;
}

/// Persistence used to keep the anonymous installation id across launches.
abstract interface class EyeInstallationStore {
  /// Reads the previously saved value, or null when this is a new install.
  Future<String?> readAnonymousUserId();

  /// Persists the installation-wide anonymous user id.
  Future<void> writeAnonymousUserId(String id);
}

/// Persistence for events that could not be uploaded while offline.
abstract interface class EyeQueueStore {
  /// Reads events saved by an earlier process.
  Future<List<Map<String, Object?>>> readEvents();

  /// Replaces the saved queue with [events].
  Future<void> writeEvents(List<Map<String, Object?>> events);
}

/// In-memory queue store for tests and applications with no persistence.
class MemoryEyeQueueStore implements EyeQueueStore {
  List<Map<String, Object?>> _events = [];

  @override
  Future<List<Map<String, Object?>>> readEvents() async => _events;

  @override
  Future<void> writeEvents(List<Map<String, Object?>> events) async {
    _events = List<Map<String, Object?>>.from(events);
  }
}

/// A non-persistent store useful for tests and short-lived processes.
class MemoryEyeInstallationStore implements EyeInstallationStore {
  String? _id;

  @override
  Future<String?> readAnonymousUserId() async => _id;

  @override
  Future<void> writeAnonymousUserId(String id) async {
    _id = id;
  }
}

/// Configuration for an [EyeClient].
class EyeOptions {
  /// Creates client options for an Eye tenant.
  const EyeOptions({
    required this.endpoint,
    required this.apiKey,
    required this.tenantId,
    this.maxBufferSize = 1000,
    this.batchSize = 20,
    this.flushInterval = const Duration(seconds: 5),
    this.httpClient,
    this.debug = false,
    this.installationStore,
    this.queueStore,
    this.metadata = const {},
    this.maxPayloadBytes = 64 * 1024,
    this.redactKeys = const {},
  });

  /// Base URL of the Eye collector, without a trailing slash.
  final String endpoint;

  /// Tenant API key sent in the `x-api-key` header.
  final String apiKey;

  /// Eye tenant identifier.
  final String tenantId;

  /// Maximum number of events retained when the collector is unavailable.
  final int maxBufferSize;

  /// Flushes after this many buffered events. Zero disables size flushing.
  final int batchSize;

  /// Periodic flush interval. Zero disables periodic flushing.
  final Duration flushInterval;

  /// Optional transport, primarily useful for tests or custom networking.
  final http.Client? httpClient;

  /// Enables validation and diagnostic logging.
  final bool debug;

  /// Store for the anonymous id shared by every session on this installation.
  final EyeInstallationStore? installationStore;

  /// Durable store used to retain events while offline.
  final EyeQueueStore? queueStore;

  /// Metadata attached to every event, such as app and device versions.
  final Map<String, Object?> metadata;

  /// Maximum JSON payload size accepted by [EyeClient.track].
  final int maxPayloadBytes;

  /// Keys whose values are replaced before events leave the client.
  final Set<String> redactKeys;
}

/// A serializable event queued for Eye ingestion.
class EyeEvent {
  /// Creates an event with its wire-format fields.
  const EyeEvent({
    required this.eventId,
    required this.sessionId,
    required this.eventName,
    required this.clientTimestamp,
    required this.payload,
    required this.dims,
  });

  final String eventId;
  final String sessionId;
  final String eventName;
  final int clientTimestamp;
  final Map<String, Object?>? payload;
  final Map<String, Object?> dims;

  /// Converts this event to Eye's `/ingest` JSON shape.
  Map<String, Object?> toJson() => {
    'event_id': eventId,
    'session_id': sessionId,
    'event_name': eventName,
    'client_ts': clientTimestamp,
    'payload': payload,
    'dims': dims,
  };

  /// Restores an event from a durable queue.
  factory EyeEvent.fromJson(Map<String, Object?> json) => EyeEvent(
    eventId: json['event_id']! as String,
    sessionId: json['session_id']! as String,
    eventName: json['event_name']! as String,
    clientTimestamp: json['client_ts']! as int,
    payload: (json['payload'] as Map?)?.cast<String, Object?>(),
    dims: (json['dims'] as Map?)?.cast<String, Object?>() ?? const {},
  );
}

/// Batching Dart client for the Eye analytics collector.
class EyeClient {
  /// Creates a client and establishes its default session before returning.
  static Future<EyeClient> init(EyeOptions options) async {
    final client = EyeClient(options);
    try {
      await client._ensureAnonymousUserId();
      await client.ensureSession();
      await client._restoreQueue();
      return client;
    } catch (_) {
      client.close();
      rethrow;
    }
  }

  /// Creates a client. Call [close] when the game or owning service ends.
  EyeClient(this.options)
    : _http = options.httpClient ?? http.Client(),
      _ownsHttp = options.httpClient == null {
    if (options.maxBufferSize <= 0)
      throw ArgumentError.value(options.maxBufferSize, 'maxBufferSize');
    if (options.batchSize < 0)
      throw ArgumentError.value(options.batchSize, 'batchSize');
    if (options.flushInterval.isNegative)
      throw ArgumentError.value(options.flushInterval, 'flushInterval');
    if (options.flushInterval > Duration.zero) {
      _timer = Timer.periodic(options.flushInterval, (_) {
        unawaited(flush());
      });
    }
  }

  final EyeOptions options;
  final http.Client _http;
  final bool _ownsHttp;
  final List<EyeEvent> _buffer = [];
  Timer? _timer;
  String? _sessionId;
  String? _anonymousUserId;
  String? _userId;
  Map<String, Object?> _traits = const {};
  bool _closed = false;
  Future<void>? _flushFuture;

  /// The current session, or null until [ensureSession] succeeds.
  String? get sessionId => _sessionId;

  /// The anonymous id shared across sessions for this installation.
  String? get anonymousUserId => _anonymousUserId;

  /// A snapshot of events currently waiting to be sent.
  List<EyeEvent> get bufferedEvents => List.unmodifiable(_buffer);

  /// Creates or reuses a session with Eye.
  Future<String> ensureSession({bool forceNew = false}) async {
    _checkOpen();
    if (forceNew) _sessionId = null;
    if (_sessionId != null) return _sessionId!;
    final response = await _http.post(
      _uri('/sessions'),
      headers: _headers,
      body: jsonEncode({
        'tenant_id': options.tenantId,
        'device': {..._deviceInfo(), ...options.metadata},
      }),
    );
    _checkResponse(response, 'create session');
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final id = data['session_id'] ?? data['ID'] ?? data['id'];
    if (id is! String || id.isEmpty)
      throw StateError('Eye session response did not contain an id');
    return _sessionId = id;
  }

  /// Adds an event to the bounded buffer and may start a background flush.
  void track(
    String name, {
    Map<String, Object?>? payload,
    Map<String, Object?>? dims,
  }) {
    _checkOpen();
    final session = _sessionId;
    if (session == null) throw StateError('Call ensureSession before track');
    if (name.isEmpty || !RegExp(r'^[a-zA-Z0-9_.:-]+$').hasMatch(name)) {
      throw ArgumentError.value(name, 'name');
    }
    final safePayload = payload == null ? null : _sanitize(payload);
    if (safePayload != null && utf8.encode(jsonEncode(safePayload)).length > options.maxPayloadBytes) {
      throw ArgumentError.value(payload, 'payload', 'Payload is too large');
    }
    final merged = <String, Object?>{
      if (_anonymousUserId != null) 'anonymous_user_id': _anonymousUserId,
      ...options.metadata,
      ...?_sanitize(dims),
      ..._traits,
    };
    if (_userId != null) merged['user_id'] = _userId;
    if (_buffer.length >= options.maxBufferSize) _buffer.removeAt(0);
    _buffer.add(
      EyeEvent(
        eventId: _eventId(),
        sessionId: session,
        eventName: name,
        clientTimestamp: DateTime.now().millisecondsSinceEpoch,
        payload: safePayload,
        dims: merged,
      ),
    );
    unawaited(_persistQueue());
    if (options.batchSize > 0 && _buffer.length >= options.batchSize)
      unawaited(flush());
  }

  /// Adds identity data to dimensions of subsequent events.
  void identify(String userId, [Map<String, Object?> traits = const {}]) {
    _checkOpen();
    _userId = userId;
    _traits = Map.unmodifiable(traits);
  }

  /// Clears authenticated identity while retaining the installation id.
  void logout() {
    _checkOpen();
    _userId = null;
    _traits = const {};
    track('logout');
  }

  /// Replaces the current authenticated identity.
  void login(String userId, [Map<String, Object?> traits = const {}]) {
    identify(userId, traits);
    track('login');
  }

  /// Records a standard level start event.
  void levelStarted(String level, {Map<String, Object?>? payload}) =>
      track('level_started', payload: payload, dims: {'level': level});

  /// Records a standard level completion event.
  void levelCompleted(String level, {Duration? duration}) => track(
    'level_completed',
    dims: {
      'level': level,
      if (duration != null) 'duration_ms': duration.inMilliseconds,
    },
  );

  /// Records a standard level failure event.
  void levelFailed(String level, {String? reason}) => track(
    'level_failed',
    dims: {'level': level, if (reason != null) 'reason': reason},
  );

  /// Records a purchase or virtual transaction.
  void purchase(String product, {num? price, String? currency}) => track(
    'purchase',
    dims: {
      'product': product,
      if (price != null) 'price': price,
      if (currency != null) 'currency': currency,
    },
  );

  /// Records a rewarded or interstitial advertisement.
  void adWatched(String placement, {bool rewarded = false}) =>
      track('ad_watched', dims: {'placement': placement, 'rewarded': rewarded});

  /// Reports a non-fatal or fatal application error.
  void trackError(Object error, {StackTrace? stackTrace, bool fatal = false}) =>
      track(
        'error',
        payload: {
          'error': '$error',
          if (stackTrace != null) 'stack_trace': '$stackTrace',
          'fatal': fatal,
        },
      );

  /// Records an achievement unlock.
  void achievementUnlocked(String achievement) => track('achievement_unlocked', dims: {'achievement': achievement});

  /// Records a quest start or completion.
  void quest(String questId, {required bool completed}) => track(completed ? 'quest_completed' : 'quest_started', dims: {'quest': questId});

  /// Records a checkpoint reached by the player.
  void checkpointReached(String checkpoint) => track('checkpoint_reached', dims: {'checkpoint': checkpoint});

  /// Records currency earned or spent.
  void currencyChanged(String currency, num amount, {required bool spent}) => track(spent ? 'currency_spent' : 'currency_earned', dims: {'currency': currency, 'amount': amount});

  /// Records an item acquisition.
  void itemAcquired(String item, {int quantity = 1}) => track('item_acquired', dims: {'item': item, 'quantity': quantity});

  /// Records tutorial progress.
  void tutorialStep(String step) => track('tutorial_step', dims: {'step': step});

  /// Sends all buffered events, retaining them when the request fails.
  Future<void> flush() async {
    _checkOpen();
    if (_flushFuture != null) return _flushFuture!;
    final future = _flush();
    _flushFuture = future;
    try {
      await future;
    } finally {
      _flushFuture = null;
    }
  }

  Future<void> _flush() async {
    if (_buffer.isEmpty) return;
    final events = List<EyeEvent>.from(_buffer);
    _buffer.clear();
    try {
      final response = await _http.post(
        _uri('/ingest'),
        headers: _headers,
        body: jsonEncode({
          'events': events.map((event) => event.toJson()).toList(),
        }),
      );
      _checkResponse(response, 'flush events');
      await options.queueStore?.writeEvents(
        _buffer.map((event) => event.toJson()).toList(),
      );
    } catch (_) {
      _buffer.insertAll(0, events);
      while (_buffer.length > options.maxBufferSize) _buffer.removeAt(0);
      await options.queueStore?.writeEvents(
        _buffer.map((event) => event.toJson()).toList(),
      );
      rethrow;
    }
  }

  /// Stops periodic flushing and releases the owned HTTP client.
  void close() {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    if (_ownsHttp) _http.close();
  }

  /// Drops all queued events and resets the authenticated identity.
  Future<void> clearIdentity() async {
    _checkOpen();
    _userId = null;
    _traits = const {};
    _buffer.clear();
    await options.queueStore?.writeEvents(const []);
  }

  Uri _uri(String path) =>
      Uri.parse('${options.endpoint.replaceFirst(RegExp(r'/$'), '')}$path');
  Map<String, String> get _headers => {
    'content-type': 'application/json',
    'x-api-key': options.apiKey,
  };
  void _checkOpen() {
    if (_closed) throw StateError('EyeClient is closed');
  }

  void _checkResponse(http.Response response, String action) {
    if (response.statusCode >= 300)
      throw EyeRequestException('Eye $action failed: ${response.statusCode}');
  }

  String _eventId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_buffer.length}';
  Map<String, Object?> _deviceInfo() => {'runtime': 'dart'};

  Future<void> _ensureAnonymousUserId() async {
    if (_anonymousUserId != null) return;
    final store = options.installationStore;
    final existing = await store?.readAnonymousUserId();
    _anonymousUserId = existing ?? _newAnonymousUserId();
    if (existing == null) await store?.writeAnonymousUserId(_anonymousUserId!);
  }

  Future<void> _restoreQueue() async {
    List<Map<String, Object?>> saved;
    try {
      saved = await options.queueStore?.readEvents() ?? const [];
    } catch (_) {
      saved = const [];
    }
    final ids = <String>{};
    for (final json in saved) {
      try {
        final event = EyeEvent.fromJson(json);
        if (ids.add(event.eventId)) _buffer.add(event);
      } catch (_) {}
    }
    while (_buffer.length > options.maxBufferSize) _buffer.removeAt(0);
  }

  Future<void> _persistQueue() =>
      options.queueStore?.writeEvents(
        _buffer.map((event) => event.toJson()).toList(),
      ) ??
      Future<void>.value();

  Map<String, Object?> _sanitize(Map<String, Object?>? input) {
    if (input == null) return {};
    final keys = options.redactKeys.map((key) => key.toLowerCase()).toSet();
    return input.map(
      (key, value) => MapEntry(
        key,
        keys.contains(key.toLowerCase()) ? '[REDACTED]' : value,
      ),
    );
  }

  String _newAnonymousUserId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
