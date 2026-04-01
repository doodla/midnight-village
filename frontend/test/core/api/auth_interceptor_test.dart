import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/api_client.dart';
import 'package:midnight_village/core/api/auth_interceptor.dart';
import 'package:midnight_village/core/storage/token_storage.dart';
import 'package:mocktail/mocktail.dart';

class MockTokenStorage extends Mock implements TokenStorage {}

class MockApiClient extends Mock implements ApiClient {}

class MockRequestInterceptorHandler extends Mock
    implements RequestInterceptorHandler {}

class MockErrorInterceptorHandler extends Mock
    implements ErrorInterceptorHandler {}

void main() {
  late MockTokenStorage mockStorage;
  late MockApiClient mockApiClient;
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
    mockApiClient = MockApiClient();
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
    unauthenticatedClient: mockApiClient,
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
        verifyNever(
          () => mockApiClient.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          ),
        );
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
          when(
            () => mockApiClient.post<Map<String, dynamic>>(
              '/auth/token/refresh/',
              data: {'refresh': 'my_refresh'},
            ),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/auth/token/refresh/'),
              statusCode: 200,
              data: {'access': 'new_access', 'refresh': 'new_refresh'},
            ),
          );

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
          verify(
            () => mockApiClient.post<Map<String, dynamic>>(
              '/auth/token/refresh/',
              data: {'refresh': 'my_refresh'},
            ),
          ).called(1);

          // New tokens were saved
          verify(
            () => mockStorage.saveTokens(
              accessToken: 'new_access',
              refreshToken: 'new_refresh',
            ),
          ).called(1);

          // Original request was retried with new token
          expect(retryCalled, true);
          expect(retryOptions?.headers['Authorization'], 'Bearer new_access');

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
          verifyNever(
            () => mockApiClient.post<Map<String, dynamic>>(
              '/auth/token/refresh/',
              data: any(named: 'data'),
            ),
          );

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
          verifyNever(
            () => mockApiClient.post<Map<String, dynamic>>(
              any(),
              data: any(named: 'data'),
            ),
          );
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
          when(
            () => mockApiClient.post<Map<String, dynamic>>(
              '/auth/token/refresh/',
              data: {'refresh': 'my_refresh'},
            ),
          ).thenThrow(
            DioException(
              requestOptions: RequestOptions(path: '/auth/token/refresh/'),
              response: Response(
                requestOptions: RequestOptions(path: '/auth/token/refresh/'),
                statusCode: 401,
              ),
              type: DioExceptionType.badResponse,
            ),
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

      test(
        'uses original refresh token when server does not return a new one',
        () async {
          when(
            () => mockStorage.accessToken,
          ).thenAnswer((_) async => 'old_access');
          when(
            () => mockStorage.refreshToken,
          ).thenAnswer((_) async => 'original_refresh');
          when(
            () => mockApiClient.post<Map<String, dynamic>>(
              '/auth/token/refresh/',
              data: {'refresh': 'original_refresh'},
            ),
          ).thenAnswer(
            (_) async => Response(
              requestOptions: RequestOptions(path: '/auth/token/refresh/'),
              statusCode: 200,
              data: {'access': 'new_access'}, // no refresh field returned
            ),
          );

          final handler = MockErrorInterceptorHandler();

          final interceptor = buildInterceptor(
            retryFetch: (opts) async =>
                Response(requestOptions: opts, statusCode: 200, data: {}),
          );

          await interceptor.onError(
            make401(headers: {'Authorization': 'Bearer old_access'}),
            handler,
          );

          verify(
            () => mockStorage.saveTokens(
              accessToken: 'new_access',
              refreshToken: 'original_refresh', // original reused
            ),
          ).called(1);
          verify(() => handler.resolve(any())).called(1);
        },
      );
    });
  });
}
