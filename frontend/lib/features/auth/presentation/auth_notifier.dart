import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/storage/user_storage.dart';
import '../data/auth_repository.dart';
import '../data/auth_service.dart';
import '../domain/auth_state.dart';

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
);

/// Manages authentication state.
@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() {
    // Start in initial state, then check for stored session
    _checkStoredSession();
    return const AuthState.initial();
  }

  Future<void> _checkStoredSession() async {
    try {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.tryRestoreSession();

      if (user != null) {
        state = AuthState.authenticated(user);
      } else {
        state = const AuthState.unauthenticated();
      }
    } on NetworkException catch (e) {
      logger.w('Network error checking stored session', error: e);
      state = const AuthState.error(
        'Could not connect. Check your connection and try again.',
      );
    } on ServerException catch (e) {
      logger.w('Server error checking stored session', error: e);
      state = const AuthState.error(
        'Server temporarily unavailable. Please try again later.',
      );
    } catch (e, stack) {
      logger.e('Error checking stored session', error: e, stackTrace: stack);
      state = const AuthState.error(
        'Could not restore your session. Please try again.',
      );
    }
  }

  /// Creates a guest account with optional display name.
  Future<void> createGuest({String? displayName}) async {
    state = const AuthState.loading();

    try {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.createGuest(displayName: displayName);
      state = AuthState.authenticated(user);
    } on ValidationException catch (e) {
      logger.w('Validation error during guest creation', error: e);
      state = AuthState.error(
        e.firstErrorFor('display_name', fallback: 'Validation failed. Please check your input.'),
      );
    } on NetworkException catch (e) {
      logger.e('Network error during guest creation', error: e);
      state = const AuthState.error('Check your connection and try again');
    } on ApiException catch (e) {
      logger.e('API error during guest creation', error: e);
      state = const AuthState.error('Something went wrong. Please try again.');
    } catch (e, stack) {
      logger.e('Unexpected error during guest creation', error: e, stackTrace: stack);
      state = const AuthState.error('An unexpected error occurred. Please try again.');
    }
  }

  /// Logs out the current user.
  ///
  /// Shows error state if logout fails to ensure user knows
  /// their session may not have been fully cleared.
  Future<void> logout() async {
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.logout();
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
