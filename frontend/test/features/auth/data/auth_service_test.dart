import 'package:midnight_village/core/requests/player_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/api_client.dart';
import 'package:midnight_village/core/api/api_exception.dart';
import 'package:midnight_village/features/auth/data/auth_service.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/mock_http_client.dart';

void main() {
  late MockHttpClient http;
  late AuthService authService;

  setUp(() {
    http = MockHttpClient();
    authService = AuthService(apiClient: ApiClient(dio: http.dio));
  });

  /// The server's answer to [path] with [status], as recorded.
  void answer(String path, String sample, {int status = 200}) =>
      http.answer('POST', path, ContractSamples.load(sample), status: status);

  group('AuthService', () {
    group('createGuest', () {
      test('returns the tokens and the user the server created', () async {
        answer('/auth/guest/', 'http/auth/guest_created', status: 201);
        final created = ContractSamples.map('http/auth/guest_created');

        final result = await authService.createGuest(
          Door.forTest(),
          displayName: 'Ana',
        );

        expect(result.tokens.access, created['access']);
        expect(result.tokens.refresh, created['refresh']);
        expect(result.user.id, created['user']['id']);
        expect(result.user.displayName, created['user']['display_name']);
      });

      test('sends the display name, trimmed', () async {
        answer('/auth/guest/', 'http/auth/guest_created', status: 201);

        await authService.createGuest(Door.forTest(), displayName: '  Ana  ');

        expect(http.requests.single.data, {'display_name': 'Ana'});
      });

      test('sends no display name when it is blank', () async {
        answer('/auth/guest/', 'http/auth/guest_created', status: 201);

        await authService.createGuest(Door.forTest(), displayName: '   ');

        expect(http.requests.single.data, <String, dynamic>{});
      });

      test('a name the server refuses says why', () async {
        answer('/auth/guest/', 'http/auth/guest_invalid_name', status: 400);

        await expectLater(
          authService.createGuest(Door.forTest(), displayName: 'Ana!!'),
          throwsA(
            isA<ValidationException>().having(
              (e) => e.firstErrorFor('display_name'),
              'display_name error',
              'Display name can only contain letters, numbers, and single '
                  'spaces.',
            ),
          ),
        );
      });

      test('too many sign-ins is a rate limit', () async {
        answer('/auth/guest/', 'http/auth/guest_throttled', status: 429);

        await expectLater(
          authService.createGuest(Door.forTest()),
          throwsA(isA<RateLimitException>()),
        );
      });
    });

    group('refreshToken', () {
      test('returns the new (rotated) token pair', () async {
        answer('/auth/token/refresh/', 'http/auth/token_refreshed');
        final refreshed = ContractSamples.map('http/auth/token_refreshed');

        final tokens = await authService.refreshToken('old-refresh');

        expect(tokens.access, refreshed['access']);
        expect(tokens.refresh, refreshed['refresh']);
        expect(http.requests.single.data, {'refresh': 'old-refresh'});
      });

      test('an answer with no tokens (a wifi sign-in page) is no answer, '
          'never a refusal', () async {
        http.answer(
          'POST',
          '/auth/token/refresh/',
          '<html>Sign in to the wifi</html>',
          offContract: true,
        );

        await expectLater(
          authService.refreshToken('old-refresh'),
          throwsA(
            allOf(isA<ApiException>(), isNot(isA<UnauthorizedException>())),
          ),
        );
      });

      test('a refresh token the server refuses is unauthorized', () async {
        answer(
          '/auth/token/refresh/',
          'http/auth/token_refresh_refused',
          status: 401,
        );

        await expectLater(
          authService.refreshToken('stale'),
          throwsA(isA<UnauthorizedException>()),
        );
      });
    });
  });
}
