import 'package:midnight_village/core/wakelock/wakelock_service.dart';

/// Records wakelock calls without touching the plugin.
class FakeWakelockService implements WakelockService {
  FakeWakelockService({this.failing = false});

  /// When true both calls throw, like a browser that refuses the lock.
  final bool failing;

  int enableCount = 0;
  int disableCount = 0;

  /// Whether the lock is held after the calls so far.
  bool isEnabled = false;

  @override
  Future<void> enable() async {
    enableCount++;
    if (failing) throw StateError('wake lock refused');
    isEnabled = true;
  }

  @override
  Future<void> disable() async {
    disableCount++;
    if (failing) throw StateError('wake lock refused');
    isEnabled = false;
  }
}
