import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// What a clock counts down: a stage's deadline by the server's clock, or a
/// clock held still (a picture, a test page). A screen hands one to its clock
/// and never reads the seconds itself: only [ClockTick], inside a clock
/// primitive (`WorldTimer`, `SquareSky`, `TimerBand`), does, so a second
/// going by rebuilds and repaints the clock and nothing else (the owner, 24
/// November 2026: "it felt like I was watching a ppt"; every screen with a
/// clock drew itself whole once a second). `clock_users_test.dart` holds
/// [ClockTick] to the clock primitives; the screen sweep's rest rule
/// (`test/helpers/still_screen.dart`) holds every screen to it at rest.
@immutable
class Countdown {
  /// Counting down to [deadline]; [until] is how long until a moment by the
  /// server's clock (`LiveGameNotifier.untilServer`). [startedAt] is when
  /// the stage began, by the server: with it the clock knows its share of
  /// the stage (the candle's wax, the vote's bar); without it, none.
  const Countdown.to(
    DateTime this.deadline, {
    required Duration Function(DateTime moment) this.until,
    this.startedAt,
  }) : _heldSeconds = null,
       _heldShare = null;

  /// A clock held at [seconds] (and [share] of the stage left): it never
  /// ticks. For pictures and tests.
  const Countdown.held(int seconds, {double? share})
    : deadline = null,
      until = null,
      startedAt = null,
      _heldSeconds = seconds,
      _heldShare = share;

  final DateTime? deadline;
  final Duration Function(DateTime moment)? until;
  final DateTime? startedAt;
  final int? _heldSeconds;
  final double? _heldShare;

  /// The seconds shown for [left]: rounded up, so "1" shows until the end.
  static int secondsFor(Duration left) =>
      left <= Duration.zero ? 0 : (left.inMicroseconds / 1e6).ceil();

  /// Read now: the seconds, the share, and how long until the number drops
  /// (null when it never will: held, or at 0). Only [ClockTick] reads it.
  ({int seconds, double? share, Duration? next}) _read() {
    final held = _heldSeconds;
    if (held != null) return (seconds: held, share: _heldShare, next: null);
    final left = until!(deadline!);
    final seconds = secondsFor(left);
    return (
      seconds: seconds,
      share: StageShare.left(
        startedAt: startedAt,
        deadline: deadline,
        secondsLeft: seconds,
      ),
      // The moment the number drops by one.
      next: seconds > 0 ? left - Duration(seconds: seconds - 1) : null,
    );
  }

  /// The seconds a clock shows now, for a test to read (a screen never
  /// does: it hands the countdown to its clock).
  @visibleForTesting
  int get secondsNow => _read().seconds;

  /// The share of the stage left now (null: unknown), for a test to read.
  @visibleForTesting
  double? get shareNow => _read().share;

  @override
  bool operator ==(Object other) =>
      other is Countdown &&
      other.deadline == deadline &&
      other.until == until &&
      other.startedAt == startedAt &&
      other._heldSeconds == _heldSeconds &&
      other._heldShare == _heldShare;

  @override
  int get hashCode =>
      Object.hash(deadline, until, startedAt, _heldSeconds, _heldShare);
}

/// How much of a stage is left, 0 to 1, for the candle's wax (04, 06) and
/// the vote's bar: the [secondsLeft] over the stage's length, from the
/// server's own `stage_started_at` and `deadline`. The same on every phone
/// and after a restart. Null for an untimed stage (the server sends
/// neither): then no share is drawn (the stage's length is the table's
/// setting, never assumed).
abstract final class StageShare {
  static double? left({
    required DateTime? startedAt,
    required DateTime? deadline,
    required int? secondsLeft,
  }) {
    if (startedAt == null || deadline == null || secondsLeft == null) {
      return null;
    }
    final length = deadline.difference(startedAt).inMilliseconds / 1000;
    if (length <= 0) return 0;
    return (secondsLeft / length).clamp(0, 1).toDouble();
  }
}

/// A clock's reading: what [ClockTick] gives its builder.
typedef ClockReading = ({int? seconds, double? share});

/// The one place a clock's seconds are read: [builder] is built again each
/// time the number changes, and only it. It stands in its own room: a
/// repaint boundary that is also where layout stops, at the size its
/// clock took when it last changed form ("9 s", "14 s", "4:12" and
/// "12:00" are four forms), so a tick lays out and paints the clock alone.
/// It counts down to 0 and stays there: the server says when the stage
/// ends, never this. A null [countdown] (an untimed stage) builds once,
/// with no seconds.
class ClockTick extends StatefulWidget {
  const ClockTick({super.key, required this.countdown, required this.builder});

  final Countdown? countdown;
  final Widget Function(BuildContext context, ClockReading reading) builder;

  @override
  State<ClockTick> createState() => _ClockTickState();
}

class _ClockTickState extends State<ClockTick> {
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  /// The clock's shape, which holds while it ticks: minutes or seconds, and
  /// how many digits.
  static Object _form(int? seconds) => switch (seconds) {
    null => 'none',
    >= 60 => 'm${seconds ~/ 60 >= 10 ? 2 : 1}',
    >= 10 => 's2',
    _ => 's1',
  };

  @override
  Widget build(BuildContext context) {
    _tick?.cancel();
    final reading = widget.countdown?._read();
    final next = reading?.next;
    if (next != null) {
      _tick = Timer(
        Duration(microseconds: math.max(1, next.inMicroseconds)),
        () {
          if (mounted) setState(() {});
        },
      );
    }
    final seconds = reading?.seconds;
    return _ClockRoom(
      form: _form(seconds),
      child: widget.builder(context, (seconds: seconds, share: reading?.share)),
    );
  }
}

class _ClockRoom extends SingleChildRenderObjectWidget {
  const _ClockRoom({required this.form, super.child});

  final Object form;

  @override
  RenderClockRoom createRenderObject(BuildContext context) =>
      RenderClockRoom(form);

  @override
  void updateRenderObject(BuildContext context, RenderClockRoom room) {
    room.form = form;
  }
}

/// [ClockTick]'s room: its child is laid out once at the size it asks for
/// (when the clock first shows, changes form, or is given other room), then
/// held at that size, so the child is where a tick's layout stops; and it
/// is a repaint boundary, so a tick's paint stops here too.
class RenderClockRoom extends RenderProxyBox {
  RenderClockRoom(this._form);

  Object _form;
  set form(Object value) {
    if (value == _form) return;
    _form = value;
    markNeedsLayout();
  }

  BoxConstraints? _measuredIn;
  Object? _measuredForm;

  @override
  bool get isRepaintBoundary => true;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    if (_measuredIn != constraints || _measuredForm != _form || !hasSize) {
      child.layout(constraints, parentUsesSize: true);
      _measuredIn = constraints;
      _measuredForm = _form;
    }
    size = constraints.constrain(child.size);
    // Held at its size: tight, so the child is its own relayout boundary.
    child.layout(BoxConstraints.tight(size));
  }
}
