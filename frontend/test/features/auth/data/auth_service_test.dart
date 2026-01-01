import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/api_client.dart';
import 'package:midnight_village/core/api/api_exception.dart';
import 'package:midnight_village/features/auth/data/auth_service.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient mockApiClient;
  late AuthService authService;

  setUp(() {
    mockApiClient = MockApiClient();
    authService = AuthService(apiClient: mockApiClient);
  });

  group('AuthService', () {
    group('createGuest', () {
      test('returns tokens and user on successful response', () async {
        when(() => mockApiClient.post<Map<String, dynamic>>(
              '/auth/guest/',
              data: any(named: 'data'),
            )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: '/auth/guest/'),
              data: {
                'access': 'access_token',
                'refresh': 'refresh_token',
                'user': {'id': 1, 'display_name': 'Guest1'},
              },
            ));

        final result = await authService.createGuest();

        expect(result.tokens.access, 'access_token');
        expect(result.tokens.refresh, 'refresh_token');
        expect(result.user.id, 1);
        expect(result.user.displayName, 'Guest1');
      });

      test('sends display_name in request when provided', () async {
        when(() => mockApiClient.post<Map<String, dynamic>>(
              '/auth/guest/',
              data: {'display_name': 'MyName'},
            )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: '/auth/guest/'),
              data: {
                'access': 'access',
                'refresh': 'refresh',
                'user': {'id': 1, 'display_name': 'MyName'},
              },
            ));

        await authService.createGuest(displayName: 'MyName');

        verify(() => mockApiClient.post<Map<String, dynamic>>(
              '/auth/guest/',
              data: {'display_name': 'MyName'},
            )).called(1);
      });

      test('trims display_name before sending', () async {
        when(() => mockApiClient.post<Map<String, dynamic>>(
              '/auth/guest/',
              data: {'display_name': 'Trimmed'},
            )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: '/auth/guest/'),
              data: {
                'access': 'access',
                'refresh': 'refresh',
                'user': {'id': 1, 'display_name': 'Trimmed'},
              },
            ));

        await authService.createGuest(displayName: '  Trimmed  ');

        verify(() => mockApiClient.post<Map<String, dynamic>>(
              '/auth/guest/',
              data: {'display_name': 'Trimmed'},
            )).called(1);
      });

      test('does not send display_name when empty after trim', () async {
        when(() => mockApiClient.post<Map<String, dynamic>>(
              '/auth/guest/',
              data: <String, dynamic>{},
            )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: '/auth/guest/'),
              data: {
                'access': 'access',
                'refresh': 'refresh',
                'user': {'id': 1, 'display_name': 'Generated'},
              },
            ));

        await authService.createGuest(displayName: '   ');

        verify(() => mockApiClient.post<Map<String, dynamic>>(
              '/auth/guest/',
              data: <String, dynamic>{},
            )).called(1);
      });

      test('throws MalformedResponseException when response body is null',
          () async {
        when(() => mockApiClient.post<Map<String, dynamic>>(
              '/auth/guest/',
              data: any(named: 'data'),
            )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: '/auth/guest/'),
              data: null,
            ));

        await expectLater(
          () => authService.createGuest(),
          throwsA(isA<MalformedResponseException>().having(
            (e) => e.message,
            'message',
            'Response body is null',
          )),
        );
      });

      test('throws MalformedResponseException when access token missing',
          () async {
        when(() => mockApiClient.post<Map<String, dynamic>>(
              '/auth/guest/',
              data: any(named: 'data'),
            )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: '/auth/guest/'),
              data: {
                'refresh': 'refresh_token',
                'user': {'id': 1, 'display_name': 'Test'},
              },
            ));

        await expectLater(
          () => authService.createGuest(),
          throwsA(isA<MalformedResponseException>().having(
            (e) => e.message,
            'message',
            'Missing or invalid token fields in response',
          )),
        );
      });

      test('throws MalformedResponseException when refresh token missing',
          () async {
        when(() => mockApiClient.post<Map<String, dynamic>>(
              '/auth/guest/',
              data: any(named: 'data'),
            )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: '/auth/guest/'),
              data: {
                'access': 'access_token',
                'user': {'id': 1, 'display_name': 'Test'},
              },
            ));

        await expectLater(
          () => authService.createGuest(),
          throwsA(isA<MalformedResponseException>().having(
            (e) => e.message,
            'message',
            'Missing or invalid token fields in response',
          )),
        );
      });

      test('throws MalformedResponseException when user field missing',
          () async {
        when(() => mockApiClient.post<Map<String, dynamic>>(
              '/auth/guest/',
              data: any(named: 'data'),
            )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: '/auth/guest/'),
              data: {
                'access': 'access_token',
                'refresh': 'refresh_token',
              },
            ));

        await expectLater(
          () => authService.createGuest(),
          throwsA(isA<MalformedResponseException>().having(
            (e) => e.message,
            'message',
            'Missing or invalid user field in response',
          )),
        );
      });

      test('throws MalformedResponseException when user field is not a map',
          () async {
        when(() => mockApiClient.post<Map<String, dynamic>>(
              '/auth/guest/',
              data: any(named: 'data'),
            )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: '/auth/guest/'),
              data: {
                'access': 'access_token',
                'refresh': 'refresh_token',
                'user': 'not_a_map',
              },
            ));

        await expectLater(
          () => authService.createGuest(),
          throwsA(isA<MalformedResponseException>().having(
            (e) => e.message,
            'message',
            'Missing or invalid user field in response',
          )),
        );
      });

      test('throws MalformedResponseException when user data has invalid id',
          () async {
        when(() => mockApiClient.post<Map<String, dynamic>>(
              '/auth/guest/',
              data: any(named: 'data'),
            )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: '/auth/guest/'),
              data: {
                'access': 'access_token',
                'refresh': 'refresh_token',
                'user': {'id': 0, 'display_name': 'Test'},
              },
            ));

        await expectLater(
          () => authService.createGuest(),
          throwsA(isA<MalformedResponseException>().having(
            (e) => e.message,
            'message',
            contains('Invalid user data'),
          )),
        );
      });

      test('maps DioException to ApiException', () async {
        when(() => mockApiClient.post<Map<String, dynamic>>(
              '/auth/guest/',
              data: any(named: 'data'),
            )).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/auth/guest/'),
          type: DioExceptionType.connectionError,
        ));

        await expectLater(
          () => authService.createGuest(),
          throwsA(isA<NetworkException>()),
        );
      });
    });

    group('refreshToken', () {
      test('returns new token pair on success', () async {
        when(() => mockApiClient.post<Map<String, dynamic>>(
              '/auth/token/refresh/',
              data: {'refresh': 'old_refresh'},
            )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: '/auth/token/refresh/'),
              data: {
                'access': 'new_access',
                'refresh': 'new_refresh',
              },
            ));

        final result = await authService.refreshToken('old_refresh');

        expect(result.access, 'new_access');
        expect(result.refresh, 'new_refresh');
      });

      test('reuses original refresh token when not returned', () async {
        when(() => mockApiClient.post<Map<String, dynamic>>(
              '/auth/token/refresh/',
              data: {'refresh': 'original_refresh'},
            )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: '/auth/token/refresh/'),
              data: {
                'access': 'new_access',
              },
            ));

        final result = await authService.refreshToken('original_refresh');

        expect(result.access, 'new_access');
        expect(result.refresh, 'original_refresh');
      });

      test('throws MalformedResponseException when response body is null',
          () async {
        when(() => mockApiClient.post<Map<String, dynamic>>(
              '/auth/token/refresh/',
              data: {'refresh': 'token'},
            )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: '/auth/token/refresh/'),
              data: null,
            ));

        await expectLater(
          () => authService.refreshToken('token'),
          throwsA(isA<MalformedResponseException>().having(
            (e) => e.message,
            'message',
            'Response body is null',
          )),
        );
      });

      test('throws MalformedResponseException when access token missing',
          () async {
        when(() => mockApiClient.post<Map<String, dynamic>>(
              '/auth/token/refresh/',
              data: {'refresh': 'token'},
            )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: '/auth/token/refresh/'),
              data: {'refresh': 'new_refresh'},
            ));

        await expectLater(
          () => authService.refreshToken('token'),
          throwsA(isA<MalformedResponseException>().having(
            (e) => e.message,
            'message',
            'Missing or invalid access token in response',
          )),
        );
      });

      test('throws MalformedResponseException when access token is not string',
          () async {
        when(() => mockApiClient.post<Map<String, dynamic>>(
              '/auth/token/refresh/',
              data: {'refresh': 'token'},
            )).thenAnswer((_) async => Response(
              requestOptions: RequestOptions(path: '/auth/token/refresh/'),
              data: {'access': 12345},
            ));

        await expectLater(
          () => authService.refreshToken('token'),
          throwsA(isA<MalformedResponseException>()),
        );
      });

      test('maps DioException to ApiException', () async {
        when(() => mockApiClient.post<Map<String, dynamic>>(
              '/auth/token/refresh/',
              data: {'refresh': 'expired'},
            )).thenThrow(DioException(
          requestOptions: RequestOptions(path: '/auth/token/refresh/'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/token/refresh/'),
            statusCode: 401,
          ),
          type: DioExceptionType.badResponse,
        ));

        await expectLater(
          () => authService.refreshToken('expired'),
          throwsA(isA<UnauthorizedException>()),
        );
      });
    });
  });
}
