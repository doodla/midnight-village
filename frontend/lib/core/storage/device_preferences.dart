import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../logging/app_logger.dart';

/// Cosmetic choices remembered on this device (not game state, not synced).
/// A failed read or write is logged and otherwise ignored: losing a cosmetic
/// preference must never stop the app.
class DevicePreferences {
  DevicePreferences({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _skinKey = 'skin';

  /// The name of the chosen skin, or null when none was saved.
  Future<String?> get skin async {
    try {
      return await _storage.read(key: _skinKey);
    } catch (e) {
      logger.w('DevicePreferences: could not read the skin: $e');
      return null;
    }
  }

  Future<void> saveSkin(String name) async {
    try {
      await _storage.write(key: _skinKey, value: name);
    } catch (e) {
      logger.w('DevicePreferences: could not save the skin: $e');
    }
  }
}
