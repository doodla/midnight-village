import '../../../core/api/api_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/user.dart';
import 'auth_service.dart';

/// Repository coordinating auth service and token storage.
///
/// Single source of truth for authentication state.
class AuthRepository {
  AuthRepository({
    required AuthService authService,
    required TokenStorage tokenStorage,
  })  : _authService = authService,
        _tokenStorage = tokenStorage;

  final AuthService _authService;
  final TokenStorage _tokenStorage;

  /// Checks for stored tokens and attempts silent refresh.
  ///
  /// Returns user if refresh succeeds, null if no tokens or refresh fails.
  Future<User?> tryRestoreSession() async {
    final hasTokens = await _tokenStorage.hasTokens;
    if (!hasTokens) {
      logger.d('No stored tokens found');
      return null;
    }

    final refreshToken = await _tokenStorage.refreshToken;
    if (refreshToken == null) {
      logger.d('No refresh token found');
      await _tokenStorage.deleteTokens();
      return null;
    }

    try {
      logger.d('Attempting silent token refresh');
      final tokens = await _authService.refreshToken(refreshToken);
      await _tokenStorage.saveTokens(
        accessToken: tokens.access,
        refreshToken: tokens.refresh,
      );
      logger.i('Session restored successfully');

      // For MVP, we don't have a /me endpoint, so return minimal user
      // In future, call /auth/me/ to get full user data
      return const User(id: 0, displayName: 'Returning User');
    } on ApiException catch (e) {
      logger.w('Session restore failed: $e');
      await _tokenStorage.deleteTokens();
      return null;
    }
  }

  /// Creates a guest account and stores tokens.
  ///
  /// [displayName] is optional - server generates one if not provided.
  /// Returns the created user.
  /// Throws [ApiException] on failure.
  Future<User> createGuest({String? displayName}) async {
    final response = await _authService.createGuest(displayName: displayName);

    await _tokenStorage.saveTokens(
      accessToken: response.tokens.access,
      refreshToken: response.tokens.refresh,
    );

    logger.i('Guest account created: ${response.user.displayName}');
    return response.user;
  }

  /// Clears stored tokens (logout).
  Future<void> logout() async {
    await _tokenStorage.deleteTokens();
    logger.i('Logged out');
  }
}
