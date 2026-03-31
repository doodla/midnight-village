import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logging/app_logger.dart';

/// Secure storage wrapper for JWT tokens.
///
/// Uses platform-specific secure storage (Keychain on iOS, EncryptedSharedPreferences on Android).
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  Future<String?> get accessToken async {
    final token = await _storage.read(key: _accessTokenKey);
    logger.d(
      'TokenStorage.accessToken: ${token != null ? "present" : "absent"}',
    );
    return token;
  }

  Future<String?> get refreshToken async {
    final token = await _storage.read(key: _refreshTokenKey);
    logger.d(
      'TokenStorage.refreshToken: ${token != null ? "present" : "absent"}',
    );
    return token;
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    logger.d('TokenStorage.saveTokens');
    try {
      await _storage.write(key: _accessTokenKey, value: accessToken);
    } catch (e, stack) {
      logger.e('Failed to save access token', error: e, stackTrace: stack);
      rethrow;
    }
    try {
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
    } catch (e) {
      // Rollback the first write, but don't mask the original error
      try {
        await _storage.delete(key: _accessTokenKey);
      } catch (rollbackError) {
        logger.w('Rollback failed during saveTokens: $rollbackError');
      }
      rethrow;
    }
  }

  Future<void> deleteTokens() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
    logger.d('TokenStorage.deleteTokens completed');
  }

  /// Checks if both access and refresh tokens are present and non-empty.
  ///
  /// Returns true only when both tokens exist. This ensures a complete
  /// token pair is available for JWT refresh flow. If you only have an
  /// access token without a refresh token, this returns false.
  Future<bool> get hasTokens async {
    final results = await Future.wait([
      _storage.read(key: _accessTokenKey),
      _storage.read(key: _refreshTokenKey),
    ]);
    final access = results[0];
    final refresh = results[1];
    return access != null &&
        access.isNotEmpty &&
        refresh != null &&
        refresh.isNotEmpty;
  }
}
