import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/domain/user.dart';
import '../logging/app_logger.dart';

/// Secure storage for user profile data.
class UserStorage {
  UserStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _displayNameKey = 'display_name';
  static const _userIdKey = 'user_id';

  /// Retrieves stored user data.
  ///
  /// Returns [User] if both id and displayName are stored and valid,
  /// null otherwise. Clears corrupted data if validation fails.
  Future<User?> getUser() async {
    final displayName = await _storage.read(key: _displayNameKey);
    final userIdStr = await _storage.read(key: _userIdKey);

    if (displayName == null || userIdStr == null) {
      return null;
    }

    final userId = int.tryParse(userIdStr);
    if (userId == null) {
      logger.w('UserStorage.getUser: stored userId "$userIdStr" is not an integer, clearing corrupted data');
      await clear();
      return null;
    }

    try {
      return User(id: userId, displayName: displayName);
    } on ArgumentError catch (e) {
      logger.w('UserStorage.getUser: invalid stored data: $e, clearing corrupted data');
      await clear();
      return null;
    }
  }

  /// Checks if valid user data is stored.
  Future<bool> get hasUser async => await getUser() != null;

  /// Saves user data with rollback on partial failure.
  ///
  /// Throws [ArgumentError] if id is not positive or displayName is empty.
  Future<void> saveUser({required int id, required String displayName}) async {
    if (id <= 0) {
      throw ArgumentError.value(id, 'id', 'must be positive');
    }
    if (displayName.trim().isEmpty) {
      throw ArgumentError.value(displayName, 'displayName', 'must not be empty');
    }

    try {
      await _storage.write(key: _userIdKey, value: id.toString());
    } catch (e, stack) {
      logger.e('Failed to save user id', error: e, stackTrace: stack);
      rethrow;
    }
    try {
      await _storage.write(key: _displayNameKey, value: displayName);
    } catch (e) {
      // Rollback the first write, but don't mask the original error
      try {
        await _storage.delete(key: _userIdKey);
      } catch (rollbackError) {
        logger.w('Rollback failed during saveUser: $rollbackError');
      }
      rethrow;
    }
    logger.d('UserStorage.saveUser: id=$id');
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _userIdKey),
      _storage.delete(key: _displayNameKey),
    ]);
    logger.d('UserStorage.clear completed');
  }
}
