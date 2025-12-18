import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';
import '../data/auth_service.dart';
import '../domain/auth_state.dart';

part 'auth_notifier.g.dart';

/// Provides the API client.
@riverpod
ApiClient apiClient(ApiClientRef ref) => ApiClient();

/// Provides the token storage.
@riverpod
TokenStorage tokenStorage(TokenStorageRef ref) => TokenStorage();

/// Provides the auth service.
@riverpod
AuthService authService(AuthServiceRef ref) =>
    AuthService(apiClient: ref.watch(apiClientProvider));

/// Provides the auth repository.
@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) => AuthRepository(
      authService: ref.watch(authServiceProvider),
      tokenStorage: ref.watch(tokenStorageProvider),
    );

/// Manages authentication state.
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() {
    // Start in initial state, then check for stored session
    _checkStoredSession();
    return const AuthState.initial();
  }

  Future<void> _checkStoredSession() async {
    final repository = ref.read(authRepositoryProvider);
    final user = await repository.tryRestoreSession();

    if (user != null) {
      state = AuthState.authenticated(user);
    } else {
      state = const AuthState.unauthenticated();
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
      final message = e.errors['display_name']?.first ??
          e.errors['detail']?.first ??
          'Invalid display name';
      state = AuthState.error(message);
    } on NetworkException catch (e) {
      logger.e('Network error during guest creation', error: e);
      state = const AuthState.error('Check your connection and try again');
    } on ApiException catch (e) {
      logger.e('API error during guest creation', error: e);
      state = const AuthState.error('Something went wrong. Please try again.');
    }
  }

  /// Logs out the current user.
  Future<void> logout() async {
    final repository = ref.read(authRepositoryProvider);
    await repository.logout();
    state = const AuthState.unauthenticated();
  }
}
