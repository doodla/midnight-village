import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/api_exception.dart';
import 'package:midnight_village/core/debug/debug_api_client.dart';

import '../../helpers/contract/contract_samples.dart';
import '../../helpers/contract/contract_shape.dart';

/// A Dio adapter that answers every request with the server's own body for
/// one endpoint (checked against the recorded samples like every mocked
/// body), and records the last request's headers so a test can assert the
/// explicit Bearer. The debug client builds its own Dio, so it cannot use
/// `MockHttpClient`.
class _ServerAdapter implements HttpClientAdapter {
  _ServerAdapter(String method, String path, this.statusCode, Object? body)
    : body = body == null ? '' : jsonEncode(body) {
    if (body != null) checkHttpBody(method, path, statusCode, body);
  }

  /// The recorded [sample], the answer to [method] [path] with [status].
  _ServerAdapter.sample(String method, String path, int status, String sample)
    : this(method, path, status, ContractSamples.load(sample));

  final int statusCode;
  final String body;
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

DebugApiClient _clientWith(_ServerAdapter adapter) {
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
      final adapter = _ServerAdapter.sample(
        'GET',
        '/onuw/games/g1/debug-state/',
        200,
        'http/debug/state_night',
      );
      final client = _clientWith(adapter);

      await client.get('/onuw/games/g1/debug-state/', token: 'player-7-token');

      expect(
        adapter.lastRequest!.headers['Authorization'],
        'Bearer player-7-token',
      );
    });

    test('omits the Authorization header for an empty token', () async {
      // An empty token is the unauthenticated path (e.g. POST /auth/guest/). A
      // `Bearer ` header with no token trips the JWT middleware and 401s before
      // the AllowAny guest view runs; omitting it lets the request through.
      final adapter = _ServerAdapter.sample(
        'POST',
        '/auth/guest/',
        201,
        'http/auth/guest_created',
      );
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
      final adapter = _ServerAdapter.sample(
        'GET',
        '/onuw/me/current-game/',
        401,
        'http/auth/token_expired',
      );
      final client = _clientWith(adapter);

      await expectLater(
        client.get('/onuw/me/current-game/', token: 'stale'),
        throwsA(isA<DebugAuthException>()),
      );
    });

    test(
      'treats 409 as success when idempotent409 is set (re-action)',
      () async {
        final adapter = _ServerAdapter.sample(
          'POST',
          '/onuw/games/g1/action/',
          409,
          'http/game/action_already_acted',
        );
        final client = _clientWith(adapter);

        final result = await client.post(
          '/onuw/games/g1/action/',
          token: 't',
          data: const {'action_type': 'peek_player'},
          idempotent409: true,
        );
        expect(result, isEmpty);
      },
    );

    test('409 fails loudly by default, with the server\'s message', () async {
      // A conflict the caller did not opt into is never swallowed.
      final adapter = _ServerAdapter.sample(
        'POST',
        '/lobbies/ABC/leave/',
        409,
        'http/lobby/leave_owner_in_game',
      );
      final client = _clientWith(adapter);

      await expectLater(
        client.post('/lobbies/ABC/leave/', token: 't'),
        throwsA(
          isA<UnhandledHttpException>().having(
            (e) => e.toString(),
            'message',
            contains('Cannot leave while a game is in progress.'),
          ),
        ),
      );
    });

    test('maps 403 to ForbiddenException', () async {
      final adapter = _ServerAdapter.sample(
        'GET',
        '/onuw/games/g1/results/',
        403,
        'http/game/results_not_ready',
      );
      final client = _clientWith(adapter);

      await expectLater(
        client.get('/onuw/games/g1/results/', token: 't'),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test(
      'maps 400 to ValidationException with the server\'s message',
      () async {
        final adapter = _ServerAdapter.sample(
          'POST',
          '/onuw/lobbies/AB/start/',
          400,
          'http/game/start_not_all_ready',
        );
        final client = _clientWith(adapter);
        final message = ContractSamples.map(
          'http/game/start_not_all_ready',
        )['detail'];

        await expectLater(
          client.post('/onuw/lobbies/AB/start/', token: 't', data: const {}),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.firstErrorFor('detail'),
              'detail',
              message,
            ),
          ),
        );
      },
    );

    test('reads the field errors the server wraps in "error"', () async {
      final adapter = _ServerAdapter.sample(
        'POST',
        '/auth/guest/',
        400,
        'http/auth/guest_invalid_name',
      );
      final client = _clientWith(adapter);

      await expectLater(
        client.post('/auth/guest/', token: '', data: const {}),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.firstErrorFor('display_name'),
            'display_name error',
            'Display name can only contain letters, numbers, and single spaces.',
          ),
        ),
      );
    });

    test('decodes a 200 JSON object', () async {
      final me = ContractSamples.map('http/game/me_look_stage')
        ..['game_id'] = 'g1';
      final adapter = _ServerAdapter('GET', '/onuw/games/g1/me/', 200, me);
      final client = _clientWith(adapter);

      final result = await client.get('/onuw/games/g1/me/', token: 't');
      expect(result['game_id'], 'g1');
      expect(result['phase'], me['phase']);
    });
  });
}
