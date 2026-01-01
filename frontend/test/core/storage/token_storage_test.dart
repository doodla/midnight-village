import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/storage/token_storage.dart';
import 'package:mocktail/mocktail.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockFlutterSecureStorage mockStorage;
  late TokenStorage tokenStorage;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    tokenStorage = TokenStorage(storage: mockStorage);
  });

  group('TokenStorage', () {
    group('accessToken', () {
      test('returns token when present', () async {
        when(() => mockStorage.read(key: 'access_token'))
            .thenAnswer((_) async => 'test_access_token');

        final token = await tokenStorage.accessToken;

        expect(token, 'test_access_token');
      });

      test('returns null when not present', () async {
        when(() => mockStorage.read(key: 'access_token'))
            .thenAnswer((_) async => null);

        final token = await tokenStorage.accessToken;

        expect(token, isNull);
      });
    });

    group('refreshToken', () {
      test('returns token when present', () async {
        when(() => mockStorage.read(key: 'refresh_token'))
            .thenAnswer((_) async => 'test_refresh_token');

        final token = await tokenStorage.refreshToken;

        expect(token, 'test_refresh_token');
      });

      test('returns null when not present', () async {
        when(() => mockStorage.read(key: 'refresh_token'))
            .thenAnswer((_) async => null);

        final token = await tokenStorage.refreshToken;

        expect(token, isNull);
      });
    });

    group('saveTokens', () {
      test('saves both tokens', () async {
        when(() => mockStorage.write(key: 'access_token', value: 'access'))
            .thenAnswer((_) async {});
        when(() => mockStorage.write(key: 'refresh_token', value: 'refresh'))
            .thenAnswer((_) async {});

        await tokenStorage.saveTokens(
          accessToken: 'access',
          refreshToken: 'refresh',
        );

        verify(() => mockStorage.write(key: 'access_token', value: 'access'))
            .called(1);
        verify(() => mockStorage.write(key: 'refresh_token', value: 'refresh'))
            .called(1);
      });

      test('rolls back access token when refresh token write fails', () async {
        when(() => mockStorage.write(key: 'access_token', value: 'access'))
            .thenAnswer((_) async {});
        when(() => mockStorage.write(key: 'refresh_token', value: 'refresh'))
            .thenThrow(Exception('Storage full'));
        when(() => mockStorage.delete(key: 'access_token'))
            .thenAnswer((_) async {});

        await expectLater(
          () => tokenStorage.saveTokens(
            accessToken: 'access',
            refreshToken: 'refresh',
          ),
          throwsA(isA<Exception>()),
        );

        verify(() => mockStorage.delete(key: 'access_token')).called(1);
      });

      test('rethrows original error even if rollback fails', () async {
        final originalError = Exception('Storage full');
        when(() => mockStorage.write(key: 'access_token', value: 'access'))
            .thenAnswer((_) async {});
        when(() => mockStorage.write(key: 'refresh_token', value: 'refresh'))
            .thenThrow(originalError);
        when(() => mockStorage.delete(key: 'access_token'))
            .thenThrow(Exception('Rollback failed'));

        await expectLater(
          () => tokenStorage.saveTokens(
            accessToken: 'access',
            refreshToken: 'refresh',
          ),
          throwsA(same(originalError)),
        );
      });

      test('propagates error when first write (access token) fails', () async {
        final storageError = Exception('Keychain unavailable');
        when(() => mockStorage.write(key: 'access_token', value: 'access'))
            .thenThrow(storageError);

        await expectLater(
          () => tokenStorage.saveTokens(
            accessToken: 'access',
            refreshToken: 'refresh',
          ),
          throwsA(same(storageError)),
        );

        // Verify refresh token write was never attempted
        verifyNever(
            () => mockStorage.write(key: 'refresh_token', value: 'refresh'));
        // Verify no cleanup was attempted (nothing to clean up)
        verifyNever(() => mockStorage.delete(key: 'access_token'));
        verifyNever(() => mockStorage.delete(key: 'refresh_token'));
      });
    });

    group('deleteTokens', () {
      test('deletes both tokens', () async {
        when(() => mockStorage.delete(key: 'access_token'))
            .thenAnswer((_) async {});
        when(() => mockStorage.delete(key: 'refresh_token'))
            .thenAnswer((_) async {});

        await tokenStorage.deleteTokens();

        verify(() => mockStorage.delete(key: 'access_token')).called(1);
        verify(() => mockStorage.delete(key: 'refresh_token')).called(1);
      });
    });

    group('hasTokens', () {
      test('returns true when both tokens exist and are non-empty', () async {
        when(() => mockStorage.read(key: 'access_token'))
            .thenAnswer((_) async => 'access');
        when(() => mockStorage.read(key: 'refresh_token'))
            .thenAnswer((_) async => 'refresh');

        final hasTokens = await tokenStorage.hasTokens;

        expect(hasTokens, isTrue);
      });

      test('returns false when access token is null', () async {
        when(() => mockStorage.read(key: 'access_token'))
            .thenAnswer((_) async => null);
        when(() => mockStorage.read(key: 'refresh_token'))
            .thenAnswer((_) async => 'refresh');

        final hasTokens = await tokenStorage.hasTokens;

        expect(hasTokens, isFalse);
      });

      test('returns false when refresh token is null', () async {
        when(() => mockStorage.read(key: 'access_token'))
            .thenAnswer((_) async => 'access');
        when(() => mockStorage.read(key: 'refresh_token'))
            .thenAnswer((_) async => null);

        final hasTokens = await tokenStorage.hasTokens;

        expect(hasTokens, isFalse);
      });

      test('returns false when both tokens are null', () async {
        when(() => mockStorage.read(key: 'access_token'))
            .thenAnswer((_) async => null);
        when(() => mockStorage.read(key: 'refresh_token'))
            .thenAnswer((_) async => null);

        final hasTokens = await tokenStorage.hasTokens;

        expect(hasTokens, isFalse);
      });

      test('returns false when access token is empty', () async {
        when(() => mockStorage.read(key: 'access_token'))
            .thenAnswer((_) async => '');
        when(() => mockStorage.read(key: 'refresh_token'))
            .thenAnswer((_) async => 'refresh');

        final hasTokens = await tokenStorage.hasTokens;

        expect(hasTokens, isFalse);
      });

      test('returns false when refresh token is empty', () async {
        when(() => mockStorage.read(key: 'access_token'))
            .thenAnswer((_) async => 'access');
        when(() => mockStorage.read(key: 'refresh_token'))
            .thenAnswer((_) async => '');

        final hasTokens = await tokenStorage.hasTokens;

        expect(hasTokens, isFalse);
      });
    });
  });
}
