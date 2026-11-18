import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../logging/app_logger.dart';

/// Keeps the phone's screen awake while a game is on screen.
///
/// A small seam over the `wakelock_plus` plugin so widgets and tests never
/// touch the plugin directly. Both calls succeed silently when the platform
/// refuses (some browsers do): a screen that may dim is not worth an error.
abstract class WakelockService {
  /// Asks the platform to keep the screen on.
  Future<void> enable();

  /// Lets the screen sleep again.
  Future<void> disable();
}

/// The real service, backed by `wakelock_plus` (web, iOS and Android).
class PluginWakelockService implements WakelockService {
  const PluginWakelockService();

  @override
  Future<void> enable() => _guard('enable', WakelockPlus.enable);

  @override
  Future<void> disable() => _guard('disable', WakelockPlus.disable);

  Future<void> _guard(String action, Future<void> Function() call) async {
    try {
      await call();
    } catch (e) {
      // Unsupported platform, no plugin (tests), or a browser that refuses.
      logger.d('Wakelock $action failed (ignored): $e');
    }
  }
}

/// Provides the [WakelockService]. Override in tests with a fake.
final wakelockServiceProvider = Provider<WakelockService>(
  (ref) => const PluginWakelockService(),
  name: 'wakelockServiceProvider',
);
