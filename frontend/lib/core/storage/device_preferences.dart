import 'package:shared_preferences/shared_preferences.dart';

import '../logging/app_logger.dart';

/// Cosmetic choices remembered on this device (not game state, not synced, not
/// secret), kept in the platform's plain preferences: NSUserDefaults,
/// Android's SharedPreferences, and the browser's localStorage. localStorage
/// works on a page served over plain http too, where the secure storage used
/// for tokens (WebCrypto) is not available.
///
/// A failed read or write is logged and otherwise ignored: losing a cosmetic
/// preference must never stop the app.
class DevicePreferences {
  DevicePreferences({Future<SharedPreferences> Function()? open})
    : _open = open ?? SharedPreferences.getInstance;

  final Future<SharedPreferences> Function() _open;

  static const _skinKey = 'skin';

  /// The name of the chosen skin, or null when none was saved or it could
  /// not be read. Fast enough to await before the first frame.
  Future<String?> readSkin() async {
    try {
      return (await _open()).getString(_skinKey);
    } catch (e) {
      logger.w('DevicePreferences: could not read the skin: $e');
      return null;
    }
  }

  Future<void> saveSkin(String name) async {
    try {
      await (await _open()).setString(_skinKey, name);
    } catch (e) {
      logger.w('DevicePreferences: could not save the skin: $e');
    }
  }
}
