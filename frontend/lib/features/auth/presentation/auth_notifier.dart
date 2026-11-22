import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/api/auth_interceptor.dart';
import '../../../core/api/authenticated_client.dart';
import '../../../core/config/env.dart';
import '../../../core/healing/healing.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/requests/player_request.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/storage/user_storage.dart';
import '../../../design_system/skin/skin_choice.dart'
    show devicePreferencesProvider;
import '../../lobby/presentation/last_seat.dart';
import '../data/auth_repository.dart';
import '../data/auth_service.dart';
import '../domain/auth_state.dart';
import '../domain/user.dart';

part 'auth_notifier.g.dart';

/// Provides the API client.
@Riverpod(keepAlive: true)
ApiClient apiClient(Ref ref) => ApiClient();

/// Provides the token storage.
@Riverpod(keepAlive: true)
TokenStorage tokenStorage(Ref ref) => TokenStorage();

/// Provides the user storage.
@Riverpod(keepAlive: true)
UserStorage userStorage(Ref ref) => UserStorage();

/// Provides the auth service.
@Riverpod(keepAlive: true)
AuthService authService(Ref ref) =>
    AuthService(apiClient: ref.watch(apiClientProvider));

/// Provides the auth repository.
@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) => AuthRepository(
  authService: ref.watch(authServiceProvider),
  tokenStorage: ref.watch(tokenStorageProvider),
  userStorage: ref.watch(userStorageProvider),
  now: ref.watch(clockProvider),
);

/// Provides the authenticated HTTP client with JWT injection and auto-refresh.
///
/// Uses [AuthInterceptor] to add bearer tokens to every request and handle
/// 401 responses by refreshing the access token. On refresh failure, the
/// interceptor signals auth failure by invalidating [authProvider], which
/// resets auth state to unauthenticated.
@Riverpod(keepAlive: true)
AuthenticatedClient authenticatedClient(Ref ref) {
  final interceptor = AuthInterceptor(
    tokenStorage: ref.watch(tokenStorageProvider),
    unauthenticatedClient: ref.watch(apiClientProvider),
    onAuthFailure: () => ref.invalidate(authProvider),
  );
  return AuthenticatedClient(baseUrl: Env.apiUrl, interceptor: interceptor);
}

/// Manages authentication state.
///
/// The saved account is read back at start ([AuthRepository.tryRestoreSession]:
/// from storage alone while its access token works). A try the server does
/// not answer (no network, a timeout, a 5xx) is made again by itself, with
/// the backoff every healing fetch uses ([HealTiming.retryAfter]), until it
/// answers; meanwhile the state stays [AuthInitial] (`unanswered`), never
/// "signed out", so no screen offers a new account. Only the server refusing
/// the saved account (it is gone) signs out.
@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  /// Each build's restore; an older one (before an invalidate) stops.
  int _restores = 0;

  @override
  AuthState build() {
    unawaited(_restore(++_restores));
    return const AuthState.initial();
  }

  Future<void> _restore(int restore) async {
    bool current() => ref.mounted && restore == _restores;
    for (var attempt = 0; ; attempt++) {
      try {
        final user = await ref.read(authRepositoryProvider).tryRestoreSession();
        if (!current()) return;
        if (user == null) {
          // No account (none saved, or the server refused it: it is gone):
          // whatever this device kept for one goes too.
          LastSeat.forgetAccount(ref.read(devicePreferencesProvider));
          state = const AuthState.unauthenticated();
        } else {
          state = AuthState.authenticated(user);
        }
        return;
      } catch (e) {
        if (!current()) return;
        logger.w('Saved account not read back yet (try ${attempt + 1})');
        state = const AuthState.initial(unanswered: true);
        await Future<void>.delayed(
          ref.read(healTimingProvider).retryAfter(attempt),
        );
        if (!current()) return;
      }
    }
  }

  /// Creates a guest account with optional display name.
  ///
  /// Never while the saved account is still being read back (nothing to do:
  /// the state stays as it is), and never over a saved account the server
  /// has not refused unless the player is signed in with it
  /// ([AuthRepository.createGuest]); a saved account found then is read
  /// back instead.
  ///
  /// True when the request was sent (it may have failed: [AuthError]); false
  /// when nothing was sent at all, so there is nothing to call "Not sent.".
  Future<bool> createGuest(Door door, {String? displayName}) async {
    final before = state;
    if (before is AuthInitial || before is AuthLoading) return false;
    state = const AuthState.loading();

    try {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.createGuest(
        door,
        displayName: displayName,
        replacing: before is AuthAuthenticated,
      );
      state = AuthState.authenticated(user);
    } on SavedAccountExists {
      logger.w('A saved account is here: reading it back, no new one');
      ref.invalidateSelf();
      return false;
    } on ValidationException catch (e) {
      logger.w('Validation error during guest creation', error: e);
      state = AuthState.error(
        e.firstErrorFor(
          'display_name',
          fallback: 'Validation failed. Please check your input.',
        ),
      );
    } on NetworkException catch (e) {
      logger.e('Network error during guest creation', error: e);
      state = const AuthState.error('Check your connection and try again');
    } on ApiException catch (e) {
      logger.e('API error during guest creation', error: e);
      state = const AuthState.error('Something went wrong. Please try again.');
    } catch (e, stack) {
      logger.e(
        'Unexpected error during guest creation',
        error: e,
        stackTrace: stack,
      );
      state = const AuthState.error(
        'An unexpected error occurred. Please try again.',
      );
    }
    return true;
  }

  /// DEBUG-ONLY perspective switch: adopts [user]'s session directly from a
  /// previously-issued access token, with NO refresh round-trip.
  ///
  /// The production restore path ([AuthRepository.tryRestoreSession]) refreshes
  /// an expired access token, and the backend rotates refresh tokens
  /// (`ROTATE_REFRESH_TOKENS`; a used one is not blacklisted). Reusing the
  /// original access token avoids rotation entirely.
  ///
  /// Writes [accessToken]/[refreshToken] and [user] to storage so that the
  /// shared [AuthInterceptor] (and any provider that reads [TokenStorage], e.g.
  /// the game WebSocket) picks up the new identity, then sets
  /// [AuthState.authenticated] directly.
  ///
  /// Gated by [Env.isDev] — a no-op in prod. The debug toolbar / harness is the
  /// only caller. This is intentionally NOT routed through `tryRestoreSession`.
  Future<void> adoptSession(
    User user, {
    required String accessToken,
    required String refreshToken,
  }) async {
    if (!Env.isDev) return;
    // A restore still trying is over: this session is the one.
    _restores++;

    final tokenStorage = ref.read(tokenStorageProvider);
    final userStorage = ref.read(userStorageProvider);

    await tokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    await userStorage.saveUser(id: user.id, displayName: user.displayName);

    state = AuthState.authenticated(user);
  }

  /// Logs out the current user.
  ///
  /// Shows error state if logout fails to ensure user knows
  /// their session may not have been fully cleared.
  Future<void> logout() async {
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.logout();
      LastSeat.forgetAccount(ref.read(devicePreferencesProvider));
      state = const AuthState.unauthenticated();
    } catch (e, stack) {
      logger.e('Error during logout', error: e, stackTrace: stack);
      // Security: Don't pretend logout succeeded if it failed
      // User needs to know their session may still be active
      state = const AuthState.error(
        'Logout failed. Please try again to ensure your session is cleared.',
      );
    }
  }
}
