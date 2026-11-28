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
/// tap. The hold draws in that frame, as it would have: nothing waits longer.
/// On a page drawing long frames (a slow phone) Chrome hands a lift over up
/// to three frames after the finger left, after that frame too: there the
/// hold is decided one frame later, once, so a real hold shows at most one
/// frame later and only on a phone that is not keeping up ([_Frames]).
class FingerTimedLongPress extends LongPressGestureRecognizer {
  FingerTimedLongPress({required super.duration, super.debugOwner});

  Duration? _landed;
  var _accepted = false;

  /// [_Frames.count] when the finger landed.
  var _framesAtLanding = 0;

  /// The frame callback that takes a hold whose timer has run.
  int? _nextFrame;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (state == GestureRecognizerState.ready) {
      _landed = event.timeStamp;
      _accepted = false;
      _framesAtLanding = _Frames.watch();
    }
    super.addAllowedPointer(event);
  }

  @override
  void didExceedDeadline() {
    if (_accepted || _nextFrame != null) return;
    _decideAtNextFrame(mayWait: true);
  }

  void _decideAtNextFrame({required bool mayWait}) {
    _nextFrame = SchedulerBinding.instance.scheduleFrameCallback((_) {
      _nextFrame = null;
      // A lift handled since then made it a tap and stopped the tracking.
      if (state != GestureRecognizerState.possible) return;
      if (mayWait && _waitOnSlowPage && _Frames.slow(since: _framesAtLanding)) {
        _decideAtNextFrame(mayWait: false);
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
    _accepted = false;
    super.didStopTrackingLastPointer(pointer);
  }

  @override
  void dispose() {
    _cancelFrame();
    super.dispose();
  }
}

/// Off only in the browser check's recorded break (`tool/tap_hold/`): a
/// build with `--dart-define=tap_hold_break=true` takes a hold at the first
/// frame after its timer, slow page or not.
const _waitOnSlowPage = !bool.fromEnvironment('tap_hold_break');

/// The frames the page draws, to tell a phone that is keeping up from one
/// that is not: a frame that began more than two of the display's frames
/// after the one before it, which already wanted it (an animation running).
/// A page that went still in between was waiting, not slow.
abstract final class _Frames {
  static SchedulerBinding? _watched;
  static Duration? _last;
  static var _lastWantedNext = false;
  static var _count = 0;

  /// Starts watching (once), and says how many frames have been drawn.
  static int watch() {
    final binding = SchedulerBinding.instance;
    if (!identical(_watched, binding)) {
      _watched = binding;
      binding.addPersistentFrameCallback((_) {
        _last = binding.currentSystemFrameTimeStamp;
        _lastWantedNext = binding.hasScheduledFrame;
        _count++;
      });
    }
    return _count;
  }

  /// Whether the frame being drawn began long after the one before it, that
  /// one drawn since the count was [since] and asking for this one.
  static bool slow({required int since}) {
    final binding = SchedulerBinding.instance;
    final last = _last;
    if (_count <= since || last == null || !_lastWantedNext) return false;
    final hz = binding.platformDispatcher.displays.firstOrNull?.refreshRate;
    final frame = Duration(
      microseconds: 1000000 ~/ (hz != null && hz > 0 ? hz : 60),
    );
    return binding.currentSystemFrameTimeStamp - last > frame * 2;
  }
}
