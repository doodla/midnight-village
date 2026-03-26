import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// Utility for controlling fake time in tests.
///
/// Wraps the [FakeAsync] zone provided by [fakeAsync] so that tests can
/// advance time programmatically without real delays. Works with both
/// [Timer]/[Timer.periodic] and [Stream.periodic] patterns.
///
/// Do not instantiate directly — use [testWithTimerControl].
///
/// ```dart
/// testWithTimerControl('countdown ticks every second', (control) {
///   var ticks = 0;
///   Stream.periodic(const Duration(seconds: 1)).listen((_) => ticks++);
///
///   control.advanceBySeconds(3);
///   expect(ticks, equals(3));
/// });
/// ```
class TimerControl {
  TimerControl._({
    required void Function(Duration) elapse,
    required void Function() flushMicrotasks,
    required void Function() flushTimers,
  })  : _elapse = elapse,
        _flushMicrotasks = flushMicrotasks,
        _flushTimers = flushTimers;

  final void Function(Duration) _elapse;
  final void Function() _flushMicrotasks;
  final void Function() _flushTimers;

  /// Advances fake time by [duration], firing any timers that fall within
  /// the elapsed range.
  void advanceBy(Duration duration) => _elapse(duration);

  /// Advances fake time by [seconds] seconds.
  void advanceBySeconds(int seconds) => advanceBy(Duration(seconds: seconds));

  /// Processes pending microtasks without advancing the fake clock.
  ///
  /// Useful after synchronous state changes that queue microtasks (e.g.
  /// [Future.value], [Completer.complete]).
  void flushMicrotasks() => _flushMicrotasks();

  /// Runs all pending timers (including periodic ones until no more remain)
  /// and flushes any resulting microtasks.
  ///
  /// Advances the fake clock as needed to fire each timer.
  void flushTimers() => _flushTimers();
}

/// Creates a test that runs [body] inside a fake-time zone.
///
/// All [Timer], [Timer.periodic], [Future.delayed], and [Stream.periodic]
/// calls within [body] are intercepted — no real wall-clock time elapses.
/// Use the provided [TimerControl] to drive time forward.
///
/// ```dart
/// testWithTimerControl('auto-skip fires after timer expires', (control) {
///   var skipped = false;
///   Timer(const Duration(seconds: 30), () => skipped = true);
///
///   control.advanceBySeconds(29);
///   expect(skipped, isFalse);
///
///   control.advanceBySeconds(1);
///   expect(skipped, isTrue);
/// });
/// ```
void testWithTimerControl(
  String description,
  void Function(TimerControl control) body,
) {
  test(description, () {
    fakeAsync((async) {
      body(
        TimerControl._(
          elapse: async.elapse,
          flushMicrotasks: async.flushMicrotasks,
          flushTimers: async.flushTimers,
        ),
      );
    });
  });
}
