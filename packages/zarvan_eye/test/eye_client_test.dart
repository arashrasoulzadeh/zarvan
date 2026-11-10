import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:test/test.dart';
import 'package:zarvan_eye/zarvan_eye.dart';

class _Client extends http.BaseClient {
  final requests = <http.Request>[];
  bool fail = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request as http.Request);
    if (fail)
      return http.StreamedResponse(Stream.value(utf8.encode('no')), 500);
    final body = request.url.path.endsWith('/sessions')
        ? '{"ID":"session-1"}'
        : '{"accepted":1}';
    return http.StreamedResponse(Stream.value(utf8.encode(body)), 200);
  }
}

void main() {
  test(
    'creates a session, enriches events, and flushes Eye wire format',
    () async {
      final transport = _Client();
      final client = EyeClient(
        EyeOptions(
          endpoint: 'https://eye.test/',
          apiKey: 'key',
          tenantId: 'game',
          httpClient: transport,
          flushInterval: Duration.zero,
          batchSize: 0,
        ),
      );
      expect(await client.ensureSession(), 'session-1');
      client.identify('player', {'plan': 'pro'});
      client.track('start', dims: {'level': 2});
      await client.flush();
      final data =
          jsonDecode(transport.requests.last.body) as Map<String, dynamic>;
      expect(data['events'][0]['session_id'], 'session-1');
      expect(data['events'][0]['dims'], {
        'level': 2,
        'plan': 'pro',
        'user_id': 'player',
      });
      client.close();
    },
  );

  test('requeues events after a failed flush', () async {
    final transport = _Client();
    final client = EyeClient(
      EyeOptions(
        endpoint: 'https://eye.test',
        apiKey: 'key',
        tenantId: 'game',
        httpClient: transport,
        flushInterval: Duration.zero,
        batchSize: 0,
      ),
    );
    await client.ensureSession();
    client.track('start');
    transport.fail = true;
    await expectLater(client.flush(), throwsA(isA<EyeRequestException>()));
    expect(client.bufferedEvents, hasLength(1));
    client.close();
  });

  test('keeps the newest events within the configured buffer cap', () async {
    final transport = _Client();
    final client = EyeClient(
      EyeOptions(
        endpoint: 'https://eye.test',
        apiKey: 'key',
        tenantId: 'game',
        httpClient: transport,
        maxBufferSize: 2,
        flushInterval: Duration.zero,
        batchSize: 0,
      ),
    );
    await client.ensureSession();
    client.track('first');
    client.track('second');
    client.track('third');

    expect(client.bufferedEvents.map((event) => event.eventName), [
      'second',
      'third',
    ]);
    client.close();
  });

  test('forceNew creates a replacement session', () async {
    final transport = _Client();
    final client = EyeClient(
      EyeOptions(
        endpoint: 'https://eye.test',
        apiKey: 'key',
        tenantId: 'game',
        httpClient: transport,
        flushInterval: Duration.zero,
        batchSize: 0,
      ),
    );
    expect(await client.ensureSession(), 'session-1');
    expect(await client.ensureSession(), 'session-1');
    expect(await client.ensureSession(forceNew: true), 'session-1');
    expect(
      transport.requests.where(
        (request) => request.url.path.endsWith('/sessions'),
      ),
      hasLength(2),
    );
    client.close();
  });

  test('init creates the default session before returning', () async {
    final transport = _Client();
    final client = await EyeClient.init(
      EyeOptions(
        endpoint: 'https://eye.test',
        apiKey: 'key',
        tenantId: 'game',
        httpClient: transport,
        flushInterval: Duration.zero,
        batchSize: 0,
      ),
    );
    expect(client.sessionId, 'session-1');
    expect(transport.requests, hasLength(1));
    client.close();
  });

  test('activity records focus, idle and game time events', () async {
    final transport = _Client();
    final client = await EyeClient.init(
      EyeOptions(
        endpoint: 'https://eye.test',
        apiKey: 'key',
        tenantId: 'game',
        httpClient: transport,
        flushInterval: Duration.zero,
        batchSize: 0,
      ),
    );
    final activity = GameActivity(
      client,
      idleAfter: const Duration(milliseconds: 1),
      heartbeat: const Duration(milliseconds: 10),
    );
    activity.setFocused(false);
    activity.setFocused(true);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    activity.close();
    expect(
      client.bufferedEvents.map((event) => event.eventName),
      containsAll(<String>['game_blurred', 'game_focused', 'game_time']),
    );
    client.close();
  });
}
