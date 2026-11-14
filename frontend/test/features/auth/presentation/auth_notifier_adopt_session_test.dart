import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/storage/token_storage.dart';
import 'package:midnight_village/core/storage/user_storage.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/auth/domain/user.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:mocktail/mocktail.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  // adoptSession is the DEBUG-only perspective switch. It must write the
  // target's token+user to storage and set authenticated state DIRECTLY from
  // the access token — with NO refresh round-trip (the refresh path rotates +
  // blacklists the token and breaks re-switching to the same player).
  group('AuthNotifier.adoptSession', () {
    late _MockSecureStorage secureStorage;
    late ProviderContainer container;

    setUp(() {
      secureStorage = _MockSecureStorage();
      when(
        () => secureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      // tryRestoreSession runs in build(); with no tokens it returns null.
      when(
        () => secureStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => null);

      container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(
            TokenStorage(storage: secureStorage),
          ),
          userStorageProvider.overrideWithValue(
            UserStorage(storage: secureStorage),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    test('writes token + user to storage and sets authenticated state', () async {
      final notifier = container.read(authProvider.notifier);
      // Let build()'s _checkStoredSession resolve to unauthenticated first.
      await Future<void>.delayed(Duration.zero);

      final user = User(id: 42, displayName: 'Alice');
      await notifier.adoptSession(
        user,
        accessToken: 'alice-access',
        refreshToken: 'alice-refresh',
      );

      final state = container.read(authProvider);
      expect(state, AuthState.authenticated(user));

      // Tokens were written exactly as given — no rotation/refresh.
      verify(
        () => secureStorage.write(key: 'access_token', value: 'alice-access'),
      ).called(1);
      verify(
        () => secureStorage.write(key: 'refresh_token', value: 'alice-refresh'),
      ).called(1);
      // User was persisted so providers that read storage pick up the identity.
      verify(() => secureStorage.write(key: 'user_id', value: '42')).called(1);
      verify(
        () => secureStorage.write(key: 'display_name', value: 'Alice'),
      ).called(1);
    });

    test('does NOT call the refresh endpoint (no rotation)', () async {
      // The mock secure storage has no token-refresh seam; the guarantee is
      // structural: adoptSession never touches the auth repository / service.
      // We assert it by confirming only storage writes happen — a refresh would
      // require a read of the refresh token to send, which we can detect.
      final notifier = container.read(authProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      clearInteractions(secureStorage);

      await notifier.adoptSession(
        User(id: 7, displayName: 'Bob'),
        accessToken: 'bob-access',
        refreshToken: 'bob-refresh',
      );

      // adoptSession only WRITES (saveTokens + saveUser); it never reads the
      // stored refresh token to perform a rotation.
      verifyNever(() => secureStorage.read(key: 'refresh_token'));
    });

    test(
      're-adopting the same player reuses the original access token',
      () async {
        final notifier = container.read(authProvider.notifier);
        await Future<void>.delayed(Duration.zero);

        final alice = User(id: 1, displayName: 'Alice');
        await notifier.adoptSession(
          alice,
          accessToken: 'alice-token-v1',
          refreshToken: 'alice-refresh-v1',
        );
        // Switch away to Bob...
        await notifier.adoptSession(
          User(id: 2, displayName: 'Bob'),
          accessToken: 'bob-token',
          refreshToken: 'bob-refresh',
        );
        // ...and back to Alice with her ORIGINAL access token (no rotation).
        await notifier.adoptSession(
          alice,
          accessToken: 'alice-token-v1',
          refreshToken: 'alice-refresh-v1',
        );

        expect(container.read(authProvider), AuthState.authenticated(alice));
        // The original access token was written again unchanged.
        verify(
          () =>
              secureStorage.write(key: 'access_token', value: 'alice-token-v1'),
        ).called(2);
      },
    );
  });
}
