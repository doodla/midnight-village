import 'package:flutter/gestures.dart';

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
/// A finger that really is still down gets the timer as before.
class FingerTimedLongPress extends LongPressGestureRecognizer {
  FingerTimedLongPress({required super.duration, super.debugOwner});

  Duration? _landed;
  var _accepted = false;

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
    _accepted = true;
    super.didExceedDeadline();
  }

  @override
  void handleEvent(PointerEvent event) {
    final landed = _landed;
    if (!_accepted &&
        landed != null &&
        state == GestureRecognizerState.possible &&
        event.pointer == primaryPointer &&
        (event is PointerUpEvent || event is PointerMoveEvent) &&
        fingerTime(landed, event.timeStamp) >= deadline!) {
      didExceedDeadline();
    }
    super.handleEvent(event);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _landed = null;
    _accepted = false;
    super.didStopTrackingLastPointer(pointer);
  }
}
