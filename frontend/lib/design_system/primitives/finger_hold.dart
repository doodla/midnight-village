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
/// busy drawing (a press's first frames on a slow phone) hands the app the
/// timer and a lift it was keeping back together, the timer often first, so
/// the lift is let in before the hold is decided: by its own time it is a
/// tap. The hold draws in that frame, as it would have: nothing waits longer.
class FingerTimedLongPress extends LongPressGestureRecognizer {
  FingerTimedLongPress({required super.duration, super.debugOwner});

  Duration? _landed;
  var _accepted = false;

  /// The frame callback that takes a hold whose timer has run.
  int? _nextFrame;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (state == GestureRecognizerState.ready) {
      _landed = event.timeStamp;
      _accepted = false;
    }
    super.addAllowedPointer(event);
  }

  @override
  void didExceedDeadline() {
    if (_accepted || _nextFrame != null) return;
    _nextFrame = SchedulerBinding.instance.scheduleFrameCallback((_) {
      _nextFrame = null;
      // A lift handled since then made it a tap and stopped the tracking.
      if (state == GestureRecognizerState.possible) _hold();
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
    _accepted = false;
    super.didStopTrackingLastPointer(pointer);
  }

  @override
  void dispose() {
    _cancelFrame();
    super.dispose();
  }
}
