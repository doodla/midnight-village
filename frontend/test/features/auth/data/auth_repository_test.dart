import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/api_exception.dart';
import 'package:midnight_village/core/storage/token_storage.dart';
import 'package:midnight_village/core/storage/user_storage.dart';
import 'package:midnight_village/features/auth/data/auth_repository.dart';
import 'package:midnight_village/features/auth/data/auth_service.dart';
import 'package:midnight_village/features/auth/domain/user.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthService extends Mock implements AuthService {}

class MockTokenStorage extends Mock implements TokenStorage {}

class MockUserStorage extends Mock implements UserStorage {}

void main() {
  late MockAuthService mockAuthService;
  late MockTokenStorage mockTokenStorage;
  late MockUserStorage mockUserStorage;
  late AuthRepository repository;

  setUp(() {
    mockAuthService = MockAuthService();
    mockTokenStorage = MockTokenStorage();
    mockUserStorage = MockUserStorage();
    repository = AuthRepository(
      authService: mockAuthService,
      tokenStorage: mockTokenStorage,
      userStorage: mockUserStorage,
    );
  });

  group('AuthRepository', () {
    group('tryRestoreSession', () {
      test('returns null when no tokens stored', () async {
        when(() => mockTokenStorage.hasTokens).thenAnswer((_) async => false);

        final user = await repository.tryRestoreSession();

        expect(user, isNull);
        verifyNever(() => mockAuthService.refreshToken(any()));
      });

      test('returns null when hasTokens true but refreshToken is null',
          () async {
        when(() => mockTokenStorage.hasTokens).thenAnswer((_) async => true);
        when(() => mockTokenStorage.refreshToken).thenAnswer((_) async => null);

        final user = await repository.tryRestoreSession();

        expect(user, isNull);
        verifyNever(() => mockAuthService.refreshToken(any()));
      });

      test('returns user on successful refresh and user retrieval', () async {
        final storedUser = User(id: 1, displayName: 'TestUser');

        when(() => mockTokenStorage.hasTokens).thenAnswer((_) async => true);
        when(() => mockTokenStorage.refreshToken)
            .thenAnswer((_) async => 'old_refresh');
        when(() => mockAuthService.refreshToken('old_refresh')).thenAnswer(
          (_) async => (access: 'new_access', refresh: 'new_refresh'),
        );
        when(() => mockTokenStorage.saveTokens(
              accessToken: 'new_access',
              refreshToken: 'new_refresh',
            )).thenAnswer((_) async {});
        when(() => mockUserStorage.getUser())
            .thenAnswer((_) async => storedUser);

        final user = await repository.tryRestoreSession();

        expect(user, storedUser);
        verify(() => mockTokenStorage.saveTokens(
              accessToken: 'new_access',
              refreshToken: 'new_refresh',
            )).called(1);
      });

      test('clears session and returns null when user data missing', () async {
        when(() => mockTokenStorage.hasTokens).thenAnswer((_) async => true);
        when(() => mockTokenStorage.refreshToken)
            .thenAnswer((_) async => 'refresh');
        when(() => mockAuthService.refreshToken('refresh')).thenAnswer(
          (_) async => (access: 'access', refresh: 'refresh'),
        );
        when(() => mockTokenStorage.saveTokens(
              accessToken: 'access',
              refreshToken: 'refresh',
            )).thenAnswer((_) async {});
        when(() => mockUserStorage.getUser()).thenAnswer((_) async => null);
        when(() => mockTokenStorage.deleteTokens()).thenAnswer((_) async {});
        when(() => mockUserStorage.clear()).thenAnswer((_) async {});

        final user = await repository.tryRestoreSession();

        expect(user, isNull);
        verify(() => mockTokenStorage.deleteTokens()).called(1);
        verify(() => mockUserStorage.clear()).called(1);
      });

      test('clears session on UnauthorizedException', () async {
        when(() => mockTokenStorage.hasTokens).thenAnswer((_) async => true);
        when(() => mockTokenStorage.refreshToken)
            .thenAnswer((_) async => 'expired_refresh');
        when(() => mockAuthService.refreshToken('expired_refresh'))
            .thenThrow(const UnauthorizedException());
        when(() => mockTokenStorage.deleteTokens()).thenAnswer((_) async {});
        when(() => mockUserStorage.clear()).thenAnswer((_) async {});

        final user = await repository.tryRestoreSession();

        expect(user, isNull);
        verify(() => mockTokenStorage.deleteTokens()).called(1);
        verify(() => mockUserStorage.clear()).called(1);
      });

      test('rethrows NetworkException without clearing tokens', () async {
        when(() => mockTokenStorage.hasTokens).thenAnswer((_) async => true);
        when(() => mockTokenStorage.refreshToken)
            .thenAnswer((_) async => 'refresh');
        when(() => mockAuthService.refreshToken('refresh'))
            .thenThrow(const NetworkException('No connection'));

        await expectLater(
          () => repository.tryRestoreSession(),
          throwsA(isA<NetworkException>()),
        );

        verifyNever(() => mockTokenStorage.deleteTokens());
        verifyNever(() => mockUserStorage.clear());
      });

      test('rethrows ServerException without clearing tokens', () async {
        when(() => mockTokenStorage.hasTokens).thenAnswer((_) async => true);
        when(() => mockTokenStorage.refreshToken)
            .thenAnswer((_) async => 'refresh');
        when(() => mockAuthService.refreshToken('refresh'))
            .thenThrow(const ServerException(500));

        await expectLater(
          () => repository.tryRestoreSession(),
          throwsA(isA<ServerException>()),
        );

        verifyNever(() => mockTokenStorage.deleteTokens());
        verifyNever(() => mockUserStorage.clear());
      });

      test('clears session on MalformedResponseException', () async {
        when(() => mockTokenStorage.hasTokens).thenAnswer((_) async => true);
        when(() => mockTokenStorage.refreshToken)
            .thenAnswer((_) async => 'refresh');
        when(() => mockAuthService.refreshToken('refresh'))
            .thenThrow(const MalformedResponseException('Invalid JSON'));
        when(() => mockTokenStorage.deleteTokens()).thenAnswer((_) async {});
        when(() => mockUserStorage.clear()).thenAnswer((_) async {});

        final user = await repository.tryRestoreSession();

        expect(user, isNull);
        verify(() => mockTokenStorage.deleteTokens()).called(1);
        verify(() => mockUserStorage.clear()).called(1);
      });

      test('clears session on unexpected exception', () async {
        when(() => mockTokenStorage.hasTokens).thenAnswer((_) async => true);
        when(() => mockTokenStorage.refreshToken)
            .thenAnswer((_) async => 'refresh');
        when(() => mockAuthService.refreshToken('refresh'))
            .thenThrow(Exception('Unexpected'));
        when(() => mockTokenStorage.deleteTokens()).thenAnswer((_) async {});
        when(() => mockUserStorage.clear()).thenAnswer((_) async {});

        final user = await repository.tryRestoreSession();

        expect(user, isNull);
        verify(() => mockTokenStorage.deleteTokens()).called(1);
      });

      test('handles cleanup failure during unexpected exception', () async {
        when(() => mockTokenStorage.hasTokens).thenAnswer((_) async => true);
        when(() => mockTokenStorage.refreshToken)
            .thenAnswer((_) async => 'refresh');
        when(() => mockAuthService.refreshToken('refresh'))
            .thenThrow(Exception('Unexpected'));
        when(() => mockTokenStorage.deleteTokens())
            .thenThrow(Exception('Cleanup failed'));
        when(() => mockUserStorage.clear())
            .thenThrow(Exception('Cleanup failed'));

        // Should not throw - cleanup errors are logged but not propagated
        final user = await repository.tryRestoreSession();

        expect(user, isNull);
      });
    });

    group('createGuest', () {
      test('saves tokens and user data on success', () async {
        final createdUser = User(id: 42, displayName: 'Guest42');

        when(() => mockAuthService.createGuest(displayName: 'TestGuest'))
            .thenAnswer((_) async => (
                  tokens: (access: 'access', refresh: 'refresh'),
                  user: createdUser,
                ));
        when(() => mockTokenStorage.saveTokens(
              accessToken: 'access',
              refreshToken: 'refresh',
            )).thenAnswer((_) async {});
        when(() => mockUserStorage.saveUser(id: 42, displayName: 'Guest42'))
            .thenAnswer((_) async {});

        final user =
            await repository.createGuest(displayName: 'TestGuest');

        expect(user, createdUser);
        verify(() => mockTokenStorage.saveTokens(
              accessToken: 'access',
              refreshToken: 'refresh',
            )).called(1);
        verify(() => mockUserStorage.saveUser(id: 42, displayName: 'Guest42'))
            .called(1);
      });

      test('rolls back tokens when user save fails', () async {
        final createdUser = User(id: 42, displayName: 'Guest42');

        when(() => mockAuthService.createGuest(displayName: null))
            .thenAnswer((_) async => (
                  tokens: (access: 'access', refresh: 'refresh'),
                  user: createdUser,
                ));
        when(() => mockTokenStorage.saveTokens(
              accessToken: 'access',
              refreshToken: 'refresh',
            )).thenAnswer((_) async {});
        when(() => mockUserStorage.saveUser(id: 42, displayName: 'Guest42'))
            .thenThrow(Exception('Storage full'));
        when(() => mockTokenStorage.deleteTokens()).thenAnswer((_) async {});

        await expectLater(
          () => repository.createGuest(),
          throwsA(isA<Exception>()),
        );

        verify(() => mockTokenStorage.deleteTokens()).called(1);
      });

      test('propagates API exceptions', () async {
        when(() => mockAuthService.createGuest(displayName: null))
            .thenThrow(const NetworkException('No connection'));

        await expectLater(
          () => repository.createGuest(),
          throwsA(isA<NetworkException>()),
        );
      });
    });

    group('logout', () {
      test('clears tokens and user data', () async {
        when(() => mockTokenStorage.deleteTokens()).thenAnswer((_) async {});
        when(() => mockUserStorage.clear()).thenAnswer((_) async {});

        await repository.logout();

        verify(() => mockTokenStorage.deleteTokens()).called(1);
        verify(() => mockUserStorage.clear()).called(1);
      });

      test('propagates cleanup errors', () async {
        when(() => mockTokenStorage.deleteTokens())
            .thenThrow(Exception('Delete failed'));
        when(() => mockUserStorage.clear()).thenAnswer((_) async {});

        await expectLater(
          () => repository.logout(),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}
