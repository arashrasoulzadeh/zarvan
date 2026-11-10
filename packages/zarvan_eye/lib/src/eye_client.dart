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
}

/// Batching Dart client for the Eye analytics collector.
class EyeClient {
  /// Creates a client and establishes its default session before returning.
  static Future<EyeClient> init(EyeOptions options) async {
    final client = EyeClient(options);
    try {
      await client._ensureAnonymousUserId();
      await client.ensureSession();
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
        'device': _deviceInfo(),
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
    if (options.debug && name.isEmpty) throw ArgumentError.value(name, 'name');
    if (options.debug && payload != null) jsonEncode(payload);
    final merged = <String, Object?>{
      if (_anonymousUserId != null) 'anonymous_user_id': _anonymousUserId,
      ...?(dims),
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
        payload: payload,
        dims: merged,
      ),
    );
    if (options.batchSize > 0 && _buffer.length >= options.batchSize)
      unawaited(flush());
  }

  /// Adds identity data to dimensions of subsequent events.
  void identify(String userId, [Map<String, Object?> traits = const {}]) {
    _checkOpen();
    _userId = userId;
    _traits = Map.unmodifiable(traits);
  }

  /// Sends all buffered events, retaining them when the request fails.
  Future<void> flush() async {
    _checkOpen();
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
    } catch (_) {
      _buffer.insertAll(0, events);
      while (_buffer.length > options.maxBufferSize) _buffer.removeAt(0);
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

  String _newAnonymousUserId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
