import 'dart:convert';

import '../../../core/api/api_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/storage/token_storage.dart';
import '../../../core/storage/user_storage.dart';
import '../domain/user.dart';
import 'auth_service.dart';

/// A new guest account was asked for while this device holds one the server
/// has not refused: refused here, so a seat is never lost to a second
/// account (see [AuthRepository.createGuest]).
class SavedAccountExists implements Exception {
  const SavedAccountExists();

  @override
  String toString() => 'SavedAccountExists';
}

/// When the access token [jwt] stops working, as the server wrote it in the
/// token (its `exp`); null when the token cannot be read (then it is used
/// as it is, and a refusal is renewed by `AuthInterceptor`).
DateTime? accessTokenExpiry(String jwt) {
  final parts = jwt.split('.');
  if (parts.length != 3) return null;
  try {
    final payload = json.decode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    final exp = payload is Map ? payload['exp'] : null;
    if (exp is! num) return null;
    return DateTime.fromMillisecondsSinceEpoch(
      (exp * 1000).round(),
      isUtc: true,
    );
  } on FormatException {
    return null;
  }
}

/// Repository coordinating auth service and token storage.
///
/// Single source of truth for authentication state.
class AuthRepository {
  AuthRepository({
    required AuthService authService,
    required TokenStorage tokenStorage,
    required UserStorage userStorage,
    DateTime Function()? now,
  }) : _authService = authService,
       _tokenStorage = tokenStorage,
       _userStorage = userStorage,
       _now = now ?? DateTime.now;

  final AuthService _authService;
  final TokenStorage _tokenStorage;
  final UserStorage _userStorage;
  final DateTime Function() _now;

  /// An access token this close to its end is renewed before it is used,
  /// so the first read does not go out only to be refused.
  static const renewBefore = Duration(minutes: 1);

  /// Reads this device's saved account back.
  ///
  /// - No account saved: null.
  /// - Its access token still works (its own `exp`, or unreadable): the
  ///   account, with no request at all.
  /// - Else the tokens are renewed (one request). The server refusing them
  ///   (401: the account is gone) clears them: null. Anything else (no
  ///   network, a timeout, a 5xx, an answer that is not the server's) keeps
  ///   them and is thrown: the account is there, it could not be asked
  ///   about yet, and the caller asks again. A failure to reach the server
  ///   is never "no account".
  Future<User?> tryRestoreSession() async {
    try {
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

      final user = await _userStorage.getUser();
      if (user == null) {
        logger.w('User data missing or invalid, clearing session');
        await _cleanupSession();
        return null;
      }

      final access = await _tokenStorage.accessToken;
      final expiry = access == null ? null : accessTokenExpiry(access);
      if (access != null &&
          (expiry == null || _now().add(renewBefore).isBefore(expiry))) {
        logger.i('Session restored from storage: userId=${user.id}');
        return user;
      }

      logger.d('Access token expired, renewing...');
      final tokens = await _authService.refreshToken(refreshToken);
      await _tokenStorage.saveTokens(
        accessToken: tokens.access,
        refreshToken: tokens.refresh,
      );
      logger.i('Session restored: userId=${user.id}');
      return user;
    } on UnauthorizedException catch (e) {
      // The server refused the saved tokens: the account is gone.
      logger.w('Session refused: $e');
      await _cleanupSession();
      return null;
    } on ApiException catch (e) {
      // No usable answer: the account is kept, and asked about again.
      logger.w('Session not restored yet: $e');
      rethrow;
    } catch (e, stack) {
      // This device's storage could not be read: nothing to restore.
      logger.e(
        'Session restore failed (unexpected)',
        error: e,
        stackTrace: stack,
      );
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
  /// While this device holds a saved account, a new one is made only when
  /// [replacing] it (the player is signed in with it and the server has
  /// said where they sit): otherwise [SavedAccountExists] is thrown and
  /// nothing is sent, so a seat is never lost to a second account.
  /// Returns the created user.
  /// Throws [ApiException] on failure.
  Future<User> createGuest({
    String? displayName,
    bool replacing = false,
  }) async {
    if (!replacing && await _tokenStorage.hasTokens) {
      throw const SavedAccountExists();
    }
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
