import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'contract/contract_samples.dart';
import 'contract/contract_shape.dart';
import 'mock_http_client.dart';

/// Registers [data] for [method] [path]; off contract unless [checked], since
/// these tests are about the mock's plumbing, not about server payloads.
void _register(
  MockHttpClient client,
  String method,
  String path,
  dynamic data, {
  int status = 200,
  bool checked = false,
}) {
  client
      .when(method: method, path: path)
      .thenReturn(
        Response(
          requestOptions: RequestOptions(path: path),
          statusCode: status,
          data: data,
        ),
        offContract: !checked,
      );
}

/// Runs [request], which must hit no registered mock, and returns what the
/// request threw and what the mock reported to the test's zone.
Future<(Object?, List<Object>)> _unmocked(Future<void> Function() request) {
  final reported = <Object>[];
  final done = Completer<(Object?, List<Object>)>();
  runZonedGuarded(() async {
    Object? thrown;
    try {
      await request();
    } catch (e) {
      thrown = e;
    }
    done.complete((thrown, reported));
  }, (error, _) => reported.add(error));
  return done.future;
}

void main() {
  group('MockHttpClient', () {
    late MockHttpClient client;

    setUp(() {
      client = MockHttpClient();
    });

    test('returns canned response for registered GET endpoint', () async {
      _register(client, 'GET', '/api/v1/me/', {'id': 42, 'username': 'alice'});

      final response = await client.dio.get<Map<String, dynamic>>(
        '/api/v1/me/',
      );

      expect(response.statusCode, equals(200));
      expect(response.data, equals({'id': 42, 'username': 'alice'}));
    });

    test(
      'an unregistered request fails the test, not only the request',
      () async {
        final (thrown, reported) = await _unmocked(
          () => client.dio.get<dynamic>('/api/v1/unknown/'),
        );

        expect(thrown, isA<DioException>());
        final unmocked = (thrown! as DioException).error;
        expect(reported, [unmocked]);
        expect(
          unmocked,
          isA<UnmockedEndpointException>()
              .having((e) => e.method, 'method', 'GET')
              .having((e) => e.path, 'path', '/api/v1/unknown/'),
        );
      },
    );

    test('a registered path does not answer a different path', () async {
      _register(client, 'GET', '/api/v1/me/', <String, dynamic>{});

      final (thrown, reported) = await _unmocked(
        () => client.dio.get<dynamic>('/api/v1/other/'),
      );

      expect(thrown, isA<DioException>());
      expect(reported.single, isA<UnmockedEndpointException>());
    });

    test(
      'GET and POST on the same path return independent responses',
      () async {
        _register(client, 'GET', '/api/v1/games/', [
          {'id': 1},
        ]);
        _register(client, 'POST', '/api/v1/games/', {'id': 99}, status: 201);

        final getResponse = await client.dio.get<dynamic>('/api/v1/games/');
        final postResponse = await client.dio.post<dynamic>(
          '/api/v1/games/',
          data: {},
        );

        expect(getResponse.data, [
          {'id': 1},
        ]);
        expect(postResponse.statusCode, 201);
        expect(postResponse.data, {'id': 99});
      },
    );

    test('an error status fails the request, with the body', () async {
      _register(client, 'POST', '/api/v1/games/', {
        'detail': 'no',
      }, status: 409);

      await expectLater(
        client.dio.post<dynamic>('/api/v1/games/'),
        throwsA(
          isA<DioException>()
              .having((e) => e.type, 'type', DioExceptionType.badResponse)
              .having((e) => e.response?.statusCode, 'status', 409)
              .having((e) => e.response?.data, 'data', {'detail': 'no'}),
        ),
      );
    });

    test('a body is checked against the server samples when registered', () {
      // flutter_test_config.dart installs the check for every test.
      expect(MockHttpClient.responseCheck, isNotNull);
      expect(
        () => _register(client, 'GET', '/onuw/games/g/players/', {
          'players': [
            {'player_id': 1, 'name': 'Alice'},
          ],
        }, checked: true),
        throwsA(isA<OffContractPayload>()),
      );
      _register(
        client,
        'GET',
        '/onuw/games/g/players/',
        ContractSamples.load('http/game/players_night'),
        checked: true,
      );
    });
  });

  group('MockHttpClient.requests', () {
    test('the registered body is a copy, and so is each answer', () async {
      final client = MockHttpClient();
      final body = <String, dynamic>{
        'players': [
          {'id': 1},
        ],
      };
      _register(client, 'GET', '/api/v1/table/', body);
      (body['players'] as List).add({'id': 2});

      final first = await client.dio.get<Map<String, dynamic>>(
        '/api/v1/table/',
      );
      (first.data!['players'] as List).clear();
      final second = await client.dio.get<Map<String, dynamic>>(
        '/api/v1/table/',
      );

      expect(second.data, {
        'players': [
          {'id': 1},
        ],
      });
    });

    test('a stand-in that throws while answering fails the test, not only '
        'the request', () async {
      final client = MockHttpClient();
      final broken = StateError('the stand-in is wrong');
      client.answerEach(
        method: 'GET',
        path: '/api/v1/me/',
        answer: (_) => throw broken,
      );

      final (thrown, reported) = await _unmocked(
        () => client.dio.get<dynamic>('/api/v1/me/'),
      );

      expect((thrown! as DioException).error, broken);
      expect(reported, [broken]);
    });

    test('records each request with its method, path and body', () async {
      final client = MockHttpClient();
      _register(client, 'POST', '/api/v1/act/', <String, dynamic>{});

      await client.dio.post<dynamic>('/api/v1/act/', data: {'a': 1});
      await _unmocked(() => client.dio.get<dynamic>('/api/v1/unmocked/'));

      expect(client.requests.map((r) => '${r.method} ${r.path}'), [
        'POST /api/v1/act/',
        'GET /api/v1/unmocked/',
      ]);
      expect(client.requests.first.data, {'a': 1});
    });
  });

  group('UnmockedEndpointException', () {
    test('toString includes method and path', () {
      const ex = UnmockedEndpointException('GET', '/api/v1/me/');
      expect(ex.toString(), contains('GET'));
      expect(ex.toString(), contains('/api/v1/me/'));
    });
  });
}
