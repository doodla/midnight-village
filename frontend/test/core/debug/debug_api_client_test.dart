import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/api_exception.dart';
import 'package:midnight_village/core/debug/debug_api_client.dart';

/// A Dio adapter that returns a canned status + JSON body for any request, and
/// records the last request's headers so we can assert the explicit Bearer.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({required this.statusCode, this.body = '{}'});

  int statusCode;
  String body;
  RequestOptions? lastRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

DebugApiClient _clientWith(_StubAdapter adapter) {
  final dio = Dio(BaseOptions(validateStatus: (_) => true));
  dio.httpClientAdapter = adapter;
  return DebugApiClient(
    baseUrl: 'http://127.0.0.1:8001/api',
    origin: 'http://127.0.0.1:8001',
    dio: dio,
  );
}

void main() {
  group('DebugApiClient', () {
    test('attaches an explicit Bearer token per call', () async {
      final adapter = _StubAdapter(statusCode: 200, body: '{"ok":true}');
      final client = _clientWith(adapter);

      await client.get('/onuw/games/1/debug-state/', token: 'player-7-token');

      expect(
        adapter.lastRequest!.headers['Authorization'],
        'Bearer player-7-token',
      );
    });

    test('omits the Authorization header for an empty token', () async {
      // An empty token is the unauthenticated path (e.g. POST /auth/guest/). A
      // `Bearer ` header with no token trips the JWT middleware and 401s before
      // the AllowAny guest view runs; omitting it lets the request through.
      final adapter = _StubAdapter(statusCode: 201, body: '{"user":{}}');
      final client = _clientWith(adapter);

      await client.post(
        '/auth/guest/',
        token: '',
        data: const {'display_name': 'Guest'},
      );

      expect(
        adapter.lastRequest!.headers.containsKey('Authorization'),
        isFalse,
      );
    });

    test('fails LOUDLY on 401 (never refreshes)', () async {
      final adapter = _StubAdapter(statusCode: 401, body: '{"detail":"x"}');
      final client = _clientWith(adapter);

      await expectLater(
        client.get('/onuw/games/1/me/', token: 'stale'),
        throwsA(isA<DebugAuthException>()),
      );
    });

    test(
      'treats 409 as success when idempotent409 is set (re-action)',
      () async {
        final adapter = _StubAdapter(statusCode: 409, body: '');
        final client = _clientWith(adapter);

        final result = await client.post(
          '/onuw/games/1/action/',
          token: 't',
          data: const {'action_type': 'peek_player'},
          idempotent409: true,
        );
        expect(result, isEmpty);
      },
    );

    test('409 fails loudly by default (real conflict, not opted in)', () async {
      // e.g. a 409 from lobby join / game start is a genuine conflict and must
      // NOT be silently swallowed.
      final adapter = _StubAdapter(statusCode: 409, body: '{"detail":"x"}');
      final client = _clientWith(adapter);

      await expectLater(
        client.post('/lobbies/ABC/join/', token: 't'),
        throwsA(isA<ApiException>()),
      );
    });

    test('maps 403 to ForbiddenException (prod-gated endpoint)', () async {
      final adapter = _StubAdapter(statusCode: 403, body: '{"detail":"no"}');
      final client = _clientWith(adapter);

      await expectLater(
        client.get('/onuw/games/1/debug-state/', token: 't'),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('maps 400 to ValidationException', () async {
      final adapter = _StubAdapter(
        statusCode: 400,
        body: '{"center":["must have exactly 3"]}',
      );
      final client = _clientWith(adapter);

      await expectLater(
        client.post('/onuw/lobbies/AB/start/', token: 't', data: const {}),
        throwsA(isA<ValidationException>()),
      );
    });

    test('decodes a 200 JSON object', () async {
      final adapter = _StubAdapter(
        statusCode: 200,
        body: '{"game_id":"g1","phase":"night"}',
      );
      final client = _clientWith(adapter);

      final result = await client.get('/onuw/games/g1/me/', token: 't');
      expect(result['game_id'], 'g1');
      expect(result['phase'], 'night');
    });
  });
}
