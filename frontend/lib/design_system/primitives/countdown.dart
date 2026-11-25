import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
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
///
/// A tick rebuilds in the clock's own build scope ([_ClockScope]), as a
/// `LayoutBuilder` rebuilds in its own: a second going by never reaches the
/// screen's layout builders, which would lay out and paint the screen
/// around the clock again (measured on the night board: every tick
/// repainted the whole screen through the board's `LayoutBuilder`).
class ClockTick extends StatefulWidget {
  const ClockTick({super.key, required this.countdown, required this.builder});

  final Countdown? countdown;
  final Widget Function(BuildContext context, ClockReading reading) builder;

  /// Ticks every clock shown now, as its timer would, ready for the next
  /// `drawFrame` alone (no ticker runs in it): a test of what a tick
  /// redraws (`test/helpers/still_screen.dart`).
  @visibleForTesting
  static void debugTickAll() {
    for (final face in _ClockFaceState._shown.toList()) {
      face._onTick();
    }
    for (final scope in _ClockScopeElement._mounted.toList()) {
      scope._flushNow();
    }
  }

  @override
  State<ClockTick> createState() => _ClockTickState();
}

class _ClockTickState extends State<ClockTick> {
  /// The clock's shape, which holds while it ticks: minutes or seconds, and
  /// how many digits.
  static Object _form(int? seconds) => switch (seconds) {
    null => 'none',
    >= 60 => 'm${seconds ~/ 60 >= 10 ? 2 : 1}',
    >= 10 => 's2',
    _ => 's1',
  };

  /// A new form: the room is measured again, through the screen's layout
  /// (a few times a stage at most).
  void _reform() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final form = _form(widget.countdown?._read().seconds);
    return _ClockRoom(
      form: form,
      child: _ClockScope(
        child: _ClockFace(
          countdown: widget.countdown,
          builder: widget.builder,
          form: form,
          reform: _reform,
        ),
      ),
    );
  }
}

/// The clock's number and candle, rebuilt at each tick inside the clock's
/// own build scope.
class _ClockFace extends StatefulWidget {
  const _ClockFace({
    required this.countdown,
    required this.builder,
    required this.form,
    required this.reform,
  });

  final Countdown? countdown;
  final Widget Function(BuildContext context, ClockReading reading) builder;

  /// The form its room was measured for.
  final Object form;
  final VoidCallback reform;

  @override
  State<_ClockFace> createState() => _ClockFaceState();
}

class _ClockFaceState extends State<_ClockFace> {
  static final _shown = <_ClockFaceState>{};
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _shown.add(this);
  }

  @override
  void dispose() {
    _shown.remove(this);
    _tick?.cancel();
    super.dispose();
  }

  /// The number drops: the face alone is built again, unless the clock
  /// changes form (its room is measured again, from [ClockTick]).
  void _onTick() {
    if (!mounted) return;
    final seconds = widget.countdown?._read().seconds;
    if (_ClockTickState._form(seconds) != widget.form) {
      widget.reform();
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    _tick?.cancel();
    final reading = widget.countdown?._read();
    final next = reading?.next;
    if (next != null) {
      _tick = Timer(
        Duration(microseconds: math.max(1, next.inMicroseconds)),
        _onTick,
      );
    }
    final seconds = reading?.seconds;
    if (_ClockTickState._form(seconds) != widget.form) {
      // Built for another reason just as the form changed: the room is
      // measured again after this frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.reform());
    }
    return widget.builder(context, (seconds: seconds, share: reading?.share));
  }
}

/// The clock's own build scope: a widget under it that is marked to build
/// (the tick) is built in this render object's layout, and this render
/// object is a relayout boundary inside the clock's room, so the tick lays
/// out and paints inside the room alone.
class _ClockScope extends SingleChildRenderObjectWidget {
  const _ClockScope({super.child});

  @override
  _ClockScopeElement createElement() => _ClockScopeElement(this);

  @override
  _RenderClockScope createRenderObject(BuildContext context) =>
      _RenderClockScope();
}

class _ClockScopeElement extends SingleChildRenderObjectElement {
  _ClockScopeElement(_ClockScope super.widget);

  static final _mounted = <_ClockScopeElement>{};

  @override
  _RenderClockScope get renderObject => super.renderObject as _RenderClockScope;

  @override
  BuildScope get buildScope => _scope;
  late final _scope = BuildScope(scheduleRebuild: _scheduleRebuild);

  // As `LayoutBuilder` does: the render tree stays clean between frames, so
  // a tick from a timer marks the layout at the start of the next frame.
  int? _deferred;

  void _scheduleRebuild() {
    if (_deferred != null) return;
    final idle = switch (SchedulerBinding.instance.schedulerPhase) {
      SchedulerPhase.idle || SchedulerPhase.postFrameCallbacks => true,
      _ => false,
    };
    if (!idle) {
      renderObject.scheduleLayoutCallback();
      return;
    }
    _deferred = SchedulerBinding.instance.scheduleFrameCallback((_) {
      _deferred = null;
      if (mounted) renderObject.scheduleLayoutCallback();
    });
  }

  /// The deferred mark, now ([ClockTick.debugTickAll]).
  void _flushNow() {
    final deferred = _deferred;
    if (deferred == null) return;
    SchedulerBinding.instance.cancelFrameCallbackWithId(deferred);
    _deferred = null;
    renderObject.scheduleLayoutCallback();
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    renderObject._element = this;
    _mounted.add(this);
  }

  @override
  void unmount() {
    _mounted.remove(this);
    final deferred = _deferred;
    if (deferred != null) {
      SchedulerBinding.instance.cancelFrameCallbackWithId(deferred);
    }
    renderObject._element = null;
    super.unmount();
  }

  void _buildDirty() => owner!.buildScope(this);
}

class _RenderClockScope extends RenderProxyBox
    with RenderObjectWithLayoutCallbackMixin {
  _ClockScopeElement? _element;

  @override
  void layoutCallback() => _element?._buildDirty();

  @override
  void performLayout() {
    runLayoutCallback();
    super.performLayout();
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
  Size? _measured;

  @override
  bool get isRepaintBoundary => true;

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    if (_measured == null ||
        _measuredIn != constraints ||
        _measuredForm != _form) {
      child.layout(constraints, parentUsesSize: true);
      _measured = child.size;
      _measuredIn = constraints;
      _measuredForm = _form;
    }
    size = constraints.constrain(_measured!);
    // Held at its size: tight, so the child is its own relayout boundary.
    child.layout(BoxConstraints.tight(size));
  }
}
