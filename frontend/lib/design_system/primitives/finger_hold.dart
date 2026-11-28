import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';

/// How long a finger has been on the glass, by the pointer events' own
/// times (when the finger landed and when it moved or lifted), not by when
/// the app got round to handling them. Zero when the times cannot say (a
/// synthesised event with no time, or times out of order).
Duration fingerTime(Duration down, Duration now) =>
    now > down ? now - down : Duration.zero;

/// A long press timed from the finger: what every hold in the app is (a
/// secret held, a role card held, a stepper's words held).
///
/// The stock recognizer starts its [deadline] timer when the app handles the
/// finger's landing. On a busy phone (frames of half a second and more) the
/// landing and the lift are handled one after the other, the timer never
/// fires in between, and a hold of a second and a half is taken for a tap.
/// This one also reads the events' own times: a move or the lift that comes
/// at least [deadline] after the landing makes it a long press first (the
/// tap competing for the finger loses), then the event is handled as usual.
/// A finger that really is still down gets the timer, and the hold is
/// taken at the start of the next frame, not in the timer itself: a browser
/// busy drawing hands the app a lift it kept back after the timer, so the
/// lift is let in before the hold is decided, and by its own time it is a
/// tap. The hold draws in that frame, as it would have.
/// A page that was blocked across the deadline (its timer ran more than a
/// display frame late: a long frame, a socket event rebuilding) gets the
/// lift from Chrome only at the start of a later frame, measured up to the
/// third after the block (`just tap-hold`, the busy rows): there the hold
/// waits [liftFrames] frames more for it, and a move or lift stamped past
/// the hold ends the wait at once. A page that keeps up never waits.
class FingerTimedLongPress extends LongPressGestureRecognizer {
  FingerTimedLongPress({required super.duration, super.debugOwner});

  /// The frames a hold waits for a lift on a page blocked across the
  /// deadline: Chrome handed it over at the latest at the start of the
  /// fourth frame after the block, seen by the fourth frame's callback;
  /// one more for headroom. So a real hold there shows four frames later.
  static const liftFrames = 4;

  Duration? _landed;
  var _accepted = false;

  /// Since the landing was handled, on the gestures' clock (the test's in a
  /// test): when the timer runs, how late it ran.
  Stopwatch? _sinceLanding;

  /// The frame callback that takes a hold whose timer has run.
  int? _nextFrame;

  /// The frames still to wait for a lift the browser kept back.
  var _framesLeft = 0;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (state == GestureRecognizerState.ready) {
      _landed = event.timeStamp;
      _accepted = false;
      _sinceLanding = GestureBinding.instance.samplingClock.stopwatch()
        ..start();
    }
    super.addAllowedPointer(event);
  }

  @override
  void didExceedDeadline() {
    if (_accepted || _nextFrame != null) return;
    if (_inTheTimer) return _hold();
    final ran = _sinceLanding?.elapsed;
    final blocked = ran != null && ran - deadline! > _displayFrame();
    _framesLeft = blocked ? liftFrames : 0;
    _decideAtNextFrame();
  }

  void _decideAtNextFrame() {
    _nextFrame = SchedulerBinding.instance.scheduleFrameCallback((_) {
      _nextFrame = null;
      // A lift handled since then made it a tap and stopped the tracking.
      if (state != GestureRecognizerState.possible) return;
      if (_framesLeft > 0) {
        _framesLeft--;
        _decideAtNextFrame();
      } else {
        _hold();
      }
    });
  }

  void _hold() {
    _cancelFrame();
    _accepted = true;
    super.didExceedDeadline();
  }

  void _cancelFrame() {
    if (_nextFrame case final id?) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(id);
    }
    _nextFrame = null;
  }

  @override
  void handleEvent(PointerEvent event) {
    final landed = _landed;
    if (!_accepted &&
        landed != null &&
        state == GestureRecognizerState.possible &&
        event.pointer == primaryPointer &&
        (event is PointerUpEvent || event is PointerMoveEvent)) {
      final held = fingerTime(landed, event.timeStamp);
      // Past the hold by the finger's own times; or the timer has run and
      // the times cannot say (events with none), so it decides, as before.
      if (held >= deadline! || (_nextFrame != null && held == Duration.zero)) {
        _hold();
      }
    }
    super.handleEvent(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _cancelFrame();
    _landed = null;
    _sinceLanding = null;
    _accepted = false;
    super.didStopTrackingLastPointer(pointer);
  }

  @override
  void dispose() {
    _cancelFrame();
    super.dispose();
  }
}

/// On only in the browser check's recorded break (`tool/tap_hold/`): a build
/// with `--dart-define=tap_hold_break=true` takes a hold in its timer itself,
/// as the stock recognizer does, so a lift Chrome kept back starts the hold.
const _inTheTimer = bool.fromEnvironment('tap_hold_break');

/// One frame of the display the app is drawn on (60 Hz when it cannot say).
Duration _displayFrame() {
  final hz = SchedulerBinding
      .instance
      .platformDispatcher
      .displays
      .firstOrNull
      ?.refreshRate;
  return Duration(microseconds: 1000000 ~/ (hz != null && hz > 0 ? hz : 60));
}
