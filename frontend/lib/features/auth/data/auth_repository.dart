import '../../../core/api/api_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/storage/user_storage.dart';
import '../domain/user.dart';
import 'auth_service.dart';

/// Repository coordinating auth service and token storage.
///
/// Single source of truth for authentication state.
class AuthRepository {
  AuthRepository({
    required AuthService authService,
    required TokenStorage tokenStorage,
    required UserStorage userStorage,
  }) : _authService = authService,
       _tokenStorage = tokenStorage,
       _userStorage = userStorage;

  final AuthService _authService;
  final TokenStorage _tokenStorage;
  final UserStorage _userStorage;

  /// Checks for stored tokens and attempts silent refresh.
  ///
  /// Returns user if refresh succeeds, null if no tokens or refresh fails.
  Future<User?> tryRestoreSession() async {
    try {
      logger.d('Checking for stored tokens...');
      final hasTokens = await _tokenStorage.hasTokens;
      if (!hasTokens) {
        logger.d('No tokens found');
        return null;
      }

      final refreshToken = await _tokenStorage.refreshToken;
      if (refreshToken == null) {
        logger.w('Refresh token unexpectedly null after hasTokens check');
        return null;
      }

      logger.d('Attempting token refresh...');
      final tokens = await _authService.refreshToken(refreshToken);
      await _tokenStorage.saveTokens(
        accessToken: tokens.access,
        refreshToken: tokens.refresh,
      );

      // Retrieve stored user data
      final user = await _userStorage.getUser();
      if (user == null) {
        logger.w('User data missing or invalid, clearing session');
        await _tokenStorage.deleteTokens();
        await _userStorage.clear();
        return null;
      }

      logger.i('Session restored: userId=${user.id}');
      return user;
    } on UnauthorizedException catch (e) {
      // Session expired - clear tokens and let user re-authenticate
      logger.w('Session expired: $e');
      await _cleanupSession();
      return null;
    } on NetworkException catch (e) {
      // Network issues are transient - don't delete tokens
      logger.w('Network error during session restore: $e');
      rethrow;
    } on ServerException catch (e) {
      // Server issues are transient - don't delete tokens
      logger.w('Server error during session restore: $e');
      rethrow;
    } on ApiException catch (e) {
      // Other API errors (MalformedResponse, etc.) - clear potentially corrupted state
      logger.w('Session restore failed (API): $e');
      await _cleanupSession();
      return null;
    } catch (e, stack) {
      logger.e(
        'Session restore failed (unexpected)',
        error: e,
        stackTrace: stack,
      );
      // Attempt cleanup but log if it also fails
      try {
        await _cleanupSession();
      } catch (cleanupError, cleanupStack) {
        logger.w(
          'Cleanup also failed during session restore error handling',
          error: cleanupError,
          stackTrace: cleanupStack,
        );
      }
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

    // Save tokens first
    await _tokenStorage.saveTokens(
      accessToken: response.tokens.access,
      refreshToken: response.tokens.refresh,
    );

    // Save user data - rollback tokens if this fails
    try {
      await _userStorage.saveUser(
        id: response.user.id,
        displayName: response.user.displayName,
      );
    } catch (e) {
      logger.w('User save failed, rolling back tokens');
      await _tokenStorage.deleteTokens();
      rethrow;
    }

    logger.i('Guest account created: userId=${response.user.id}');
    return response.user;
  }

  /// Clears stored tokens and user data (logout).
  ///
  /// Throws if cleanup fails - caller should handle appropriately.
  Future<void> logout() async {
    await _cleanupSession();
    logger.i('Logged out');
  }

  /// Internal helper to clean up session data.
  Future<void> _cleanupSession() async {
    await Future.wait([_tokenStorage.deleteTokens(), _userStorage.clear()]);
  }
}
