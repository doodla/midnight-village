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

  /// The value a set flag holds.
  static const _flagOn = '1';

  /// The keys starting with [prefix] whose flag is set (an empty set when
  /// they could not be read). Fast enough to await before the first frame.
  Future<Set<String>> readFlags(String prefix) async {
    try {
      final preferences = await _open();
      return {
        for (final key in preferences.getKeys())
          if (key.startsWith(prefix) && preferences.get(key) == _flagOn) key,
      };
    } catch (e) {
      logger.w('DevicePreferences: could not read the flags $prefix*: $e');
      return {};
    }
  }

  Future<void> setFlag(String key) async {
    try {
      await (await _open()).setString(key, _flagOn);
    } catch (e) {
      logger.w('DevicePreferences: could not set the flag $key: $e');
    }
  }

  /// The text kept at [key], or null when there is none or it could not be
  /// read.
  Future<String?> readString(String key) async {
    try {
      final value = (await _open()).get(key);
      return value is String ? value : null;
    } catch (e) {
      logger.w('DevicePreferences: could not read $key: $e');
      return null;
    }
  }

  Future<void> writeString(String key, String value) async {
    try {
      await (await _open()).setString(key, value);
    } catch (e) {
      logger.w('DevicePreferences: could not write $key: $e');
    }
  }

  /// Clears every flag whose key starts with [prefix].
  Future<void> clearFlags(String prefix) async {
    try {
      final preferences = await _open();
      for (final key in preferences.getKeys().toList()) {
        if (key.startsWith(prefix)) await preferences.remove(key);
      }
    } catch (e) {
      logger.w('DevicePreferences: could not clear the flags $prefix*: $e');
    }
  }
}
