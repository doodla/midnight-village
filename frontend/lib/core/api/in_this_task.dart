import 'dart:async';

/// Runs [send] (a request through Dio) so that it leaves in the task that
/// called it: the tap's own, on a phone.
///
/// Dio passes a request from one interceptor to the next, and on to the
/// adapter, through `Future(...)`: a timer of no length each, which on the
/// web is a new browser task. Between two tasks the browser draws whatever
/// frame the app has asked for, and on a busy phone a frame takes 200 to
/// 800 ms, so a request with five such steps left the phone a second after
/// the finger. Here a timer of no length is run as a microtask instead (it
/// still runs after the code that made it, in the order it was made, before
/// anything else the browser has queued); a timer with a length is left
/// as it is. Nothing waits more for it: it only waits less.
Future<T> inThisTask<T>(Future<T> Function() send) =>
    runZoned(send, zoneSpecification: _noZeroTimers);

final _noZeroTimers = ZoneSpecification(
  createTimer: (self, parent, zone, duration, callback) {
    if (duration > Duration.zero) {
      return parent.createTimer(zone, duration, callback);
    }
    final timer = _MicrotaskTimer();
    parent.scheduleMicrotask(zone, () {
      if (timer._active) {
        timer._active = false;
        callback();
      }
    });
    return timer;
  },
);

/// A timer of no length, run as a microtask.
class _MicrotaskTimer implements Timer {
  var _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;

  @override
  void cancel() => _active = false;
}
