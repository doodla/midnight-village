import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mock_http_client.dart';

void main() {
  group('MockHttpClient', () {
    late MockHttpClient client;

    setUp(() {
      client = MockHttpClient();
    });

    test('returns canned response for registered GET endpoint', () async {
      client
          .when(method: 'GET', path: '/api/v1/me/')
          .thenReturn(Response(
            requestOptions: RequestOptions(path: '/api/v1/me/'),
            statusCode: 200,
            data: {'id': 42, 'username': 'alice'},
          ));

      final response = await client.dio.get<Map<String, dynamic>>('/api/v1/me/');

      expect(response.statusCode, equals(200));
      expect(response.data, equals({'id': 42, 'username': 'alice'}));
    });

    test('throws DioException wrapping UnmockedEndpointException for unregistered endpoint',
        () async {
      Object? caught;
      try {
        await client.dio.get('/api/v1/unknown/');
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<DioException>());
      final dioException = caught as DioException;
      expect(dioException.error, isA<UnmockedEndpointException>());

      final unmocked = dioException.error as UnmockedEndpointException;
      expect(unmocked.method, equals('GET'));
      expect(unmocked.path, equals('/api/v1/unknown/'));
    });

    test('UnmockedEndpointException includes method and path in message',
        () async {
      Object? caught;
      try {
        await client.dio.post('/api/v1/games/', data: {});
      } catch (e) {
        caught = e;
      }

      final unmocked = (caught as DioException).error as UnmockedEndpointException;
      expect(
        unmocked.toString(),
        contains('POST'),
      );
      expect(
        unmocked.toString(),
        contains('/api/v1/games/'),
      );
    });

    test('GET and POST on the same path return independent responses', () async {
      client
          .when(method: 'GET', path: '/api/v1/games/')
          .thenReturn(Response(
            requestOptions: RequestOptions(path: '/api/v1/games/'),
            statusCode: 200,
            data: [{'id': 1}],
          ));
      client
          .when(method: 'POST', path: '/api/v1/games/')
          .thenReturn(Response(
            requestOptions: RequestOptions(path: '/api/v1/games/'),
            statusCode: 201,
            data: {'id': 99, 'created': true},
          ));

      final getResponse = await client.dio.get('/api/v1/games/');
      final postResponse = await client.dio.post('/api/v1/games/', data: {});

      expect(getResponse.statusCode, equals(200));
      expect(getResponse.data, equals([{'id': 1}]));

      expect(postResponse.statusCode, equals(201));
      expect(postResponse.data, equals({'id': 99, 'created': true}));
    });

    test('multiple endpoints each return their own response', () async {
      client
          .when(method: 'GET', path: '/api/v1/me/')
          .thenReturn(Response(
            requestOptions: RequestOptions(path: '/api/v1/me/'),
            statusCode: 200,
            data: {'user': 'alice'},
          ));
      client
          .when(method: 'GET', path: '/api/v1/lobbies/')
          .thenReturn(Response(
            requestOptions: RequestOptions(path: '/api/v1/lobbies/'),
            statusCode: 200,
            data: {'lobbies': []},
          ));
      client
          .when(method: 'GET', path: '/api/v1/games/42/')
          .thenReturn(Response(
            requestOptions: RequestOptions(path: '/api/v1/games/42/'),
            statusCode: 200,
            data: {'id': 42, 'phase': 'lobby'},
          ));

      final me = await client.dio.get('/api/v1/me/');
      final lobbies = await client.dio.get('/api/v1/lobbies/');
      final game = await client.dio.get('/api/v1/games/42/');

      expect(me.data, equals({'user': 'alice'}));
      expect(lobbies.data, equals({'lobbies': []}));
      expect(game.data, equals({'id': 42, 'phase': 'lobby'}));
    });

    test('registered path does not match different path', () async {
      client
          .when(method: 'GET', path: '/api/v1/me/')
          .thenReturn(Response(
            requestOptions: RequestOptions(path: '/api/v1/me/'),
            statusCode: 200,
            data: {},
          ));

      // Different path should throw
      expect(
        () => client.dio.get('/api/v1/other/'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('UnmockedEndpointException', () {
    test('toString includes method and path', () {
      const ex = UnmockedEndpointException('GET', '/api/v1/me/');
      expect(ex.toString(), contains('GET'));
      expect(ex.toString(), contains('/api/v1/me/'));
    });

    test('exposes method and path fields', () {
      const ex = UnmockedEndpointException('POST', '/api/v1/games/');
      expect(ex.method, equals('POST'));
      expect(ex.path, equals('/api/v1/games/'));
    });
  });
}
