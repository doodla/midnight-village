import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/api_client.dart';
import 'package:midnight_village/core/api/auth_interceptor.dart';
import 'package:midnight_village/core/storage/token_storage.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/contract/contract_samples.dart';
import '../../helpers/mock_http_client.dart';

class MockTokenStorage extends Mock implements TokenStorage {}

class MockRequestInterceptorHandler extends Mock
    implements RequestInterceptorHandler {}

class MockErrorInterceptorHandler extends Mock
    implements ErrorInterceptorHandler {}

/// The server's answer to a refresh: a new access token and a rotated
/// refresh token.
final _refreshed = ContractSamples.map('http/auth/token_refreshed');

void main() {
  late MockTokenStorage mockStorage;
  late MockHttpClient http;
  late int authFailureCount;

  setUpAll(() {
    // Mocktail requires fallback values for any non-primitive types used with
    // any() or captureAny() matchers.
    registerFallbackValue(RequestOptions(path: ''));
    registerFallbackValue(
      DioException(requestOptions: RequestOptions(path: '')),
    );
    registerFallbackValue(
      Response<dynamic>(requestOptions: RequestOptions(path: '')),
    );
  });

  setUp(() {
    mockStorage = MockTokenStorage();
    http = MockHttpClient();
    authFailureCount = 0;

    // Default stubs — individual tests override as needed.
    when(() => mockStorage.accessToken).thenAnswer((_) async => null);
    when(() => mockStorage.refreshToken).thenAnswer((_) async => null);
    when(() => mockStorage.deleteTokens()).thenAnswer((_) async {});
    when(
      () => mockStorage.saveTokens(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
      ),
    ).thenAnswer((_) async {});
  });

  AuthInterceptor buildInterceptor({
    Future<Response<dynamic>> Function(RequestOptions)? retryFetch,
  }) => AuthInterceptor(
    tokenStorage: mockStorage,
    unauthenticatedClient: ApiClient(dio: http.dio),
    onAuthFailure: () => authFailureCount++,
    retryFetch: retryFetch,
  );

  DioException make401({Map<String, dynamic>? headers}) => DioException(
    requestOptions: RequestOptions(
      path: '/api/resource/',
      headers: headers ?? {},
    ),
    response: Response(
      requestOptions: RequestOptions(path: '/api/resource/'),
      statusCode: 401,
    ),
    type: DioExceptionType.badResponse,
  );

  group('AuthInterceptor', () {
    group('onRequest', () {
      test('adds Bearer token when access token is present', () async {
        when(
          () => mockStorage.accessToken,
        ).thenAnswer((_) async => 'my_access_token');

        final options = RequestOptions(path: '/api/resource/');
        final handler = MockRequestInterceptorHandler();

        await buildInterceptor().onRequest(options, handler);

        final captured =
            verify(() => handler.next(captureAny())).captured.single
                as RequestOptions;
        expect(captured.headers['Authorization'], 'Bearer my_access_token');
      });

      test(
        'does not add Authorization header when no token in storage',
        () async {
          when(() => mockStorage.accessToken).thenAnswer((_) async => null);

          final options = RequestOptions(path: '/api/resource/');
          final handler = MockRequestInterceptorHandler();

          await buildInterceptor().onRequest(options, handler);

          final captured =
              verify(() => handler.next(captureAny())).captured.single
                  as RequestOptions;
          expect(captured.headers.containsKey('Authorization'), false);
        },
      );
    });

    group('onError', () {
      test('passes through non-401 errors unchanged', () async {
        final err = DioException(
          requestOptions: RequestOptions(path: '/api/resource/'),
          response: Response(
            requestOptions: RequestOptions(path: '/api/resource/'),
            statusCode: 403,
          ),
          type: DioExceptionType.badResponse,
        );
        final handler = MockErrorInterceptorHandler();

        await buildInterceptor().onError(err, handler);

        verify(() => handler.next(err)).called(1);
        expect(http.requests, isEmpty);
      });

      test(
        'calls refresh and retries on 401 when refresh token present',
        () async {
          when(
            () => mockStorage.accessToken,
          ).thenAnswer((_) async => 'old_access');
          when(
            () => mockStorage.refreshToken,
          ).thenAnswer((_) async => 'my_refresh');
          http.answer('POST', '/auth/token/refresh/', _refreshed);

          final handler = MockErrorInterceptorHandler();
          var retryCalled = false;
          RequestOptions? retryOptions;

          final interceptor = buildInterceptor(
            retryFetch: (opts) async {
              retryCalled = true;
              retryOptions = opts;
              return Response(requestOptions: opts, statusCode: 200, data: {});
            },
          );

          await interceptor.onError(
            make401(headers: {'Authorization': 'Bearer old_access'}),
            handler,
          );

          // Refresh was called with the refresh token
          expect(http.requests.single.path, '/auth/token/refresh/');
          expect(http.requests.single.data, {'refresh': 'my_refresh'});

          // The new (rotated) tokens were saved
          verify(
            () => mockStorage.saveTokens(
              accessToken: _refreshed['access'] as String,
              refreshToken: _refreshed['refresh'] as String,
            ),
          ).called(1);

          // Original request was retried with new token
          expect(retryCalled, true);
          expect(
            retryOptions?.headers['Authorization'],
            'Bearer ${_refreshed['access']}',
          );

          // Success was resolved
          verify(() => handler.resolve(any())).called(1);
          expect(authFailureCount, 0);
        },
      );

      test(
        'detects token already refreshed by concurrent request and retries without refresh',
        () async {
          // Storage now has a *newer* token than what the failing request used —
          // this simulates QueuedInterceptorsWrapper serializing a second 401
          // after the first already completed a refresh.
          when(
            () => mockStorage.accessToken,
          ).thenAnswer((_) async => 'new_token');

          final handler = MockErrorInterceptorHandler();
          var retryCalled = false;
          RequestOptions? retryOptions;

          final interceptor = buildInterceptor(
            retryFetch: (opts) async {
              retryCalled = true;
              retryOptions = opts;
              return Response(requestOptions: opts, statusCode: 200, data: {});
            },
          );

          // Request had the OLD token when it failed
          await interceptor.onError(
            make401(headers: {'Authorization': 'Bearer old_token'}),
            handler,
          );

          // Refresh must NOT be called again
          expect(http.requests, isEmpty);

          // Retry was performed with the current (new) token
          expect(retryCalled, true);
          expect(retryOptions?.headers['Authorization'], 'Bearer new_token');

          verify(() => handler.resolve(any())).called(1);
          expect(authFailureCount, 0);
        },
      );

      test(
        'calls onAuthFailure and rejects when no refresh token stored',
        () async {
          when(() => mockStorage.accessToken).thenAnswer((_) async => null);
          when(() => mockStorage.refreshToken).thenAnswer((_) async => null);

          final handler = MockErrorInterceptorHandler();

          await buildInterceptor().onError(make401(), handler);

          expect(authFailureCount, 1);
          verify(() => handler.next(any())).called(1);
          expect(http.requests, isEmpty);
        },
      );

      test(
        'clears tokens, calls onAuthFailure and rejects when refresh returns 401',
        () async {
          when(
            () => mockStorage.accessToken,
          ).thenAnswer((_) async => 'old_access');
          when(
            () => mockStorage.refreshToken,
          ).thenAnswer((_) async => 'my_refresh');
          http.answer(
            'POST',
            '/auth/token/refresh/',
            ContractSamples.load('http/auth/token_refresh_refused'),
            status: 401,
          );

          final handler = MockErrorInterceptorHandler();

          await buildInterceptor().onError(
            make401(headers: {'Authorization': 'Bearer old_access'}),
            handler,
          );

          verify(() => mockStorage.deleteTokens()).called(1);
          expect(authFailureCount, 1);
          verify(() => handler.next(any())).called(1);
        },
      );
    });
  });
}
