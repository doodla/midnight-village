import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../skin/dress.dart';

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
    this.moved,
  }) : _heldSeconds = null,
       _heldShare = null;

  /// A clock held at [seconds] (and [share] of the stage left): it never
  /// ticks. For pictures and tests.
  const Countdown.held(int seconds, {double? share})
    : deadline = null,
      until = null,
      startedAt = null,
      moved = null,
      _heldSeconds = seconds,
      _heldShare = share;

  final DateTime? deadline;
  final Duration Function(DateTime moment)? until;
  final DateTime? startedAt;

  /// Tells when the server's clock was re-read and moved ([until] now answers
  /// differently for the same moment): the clock reads again at once, not at
  /// its own next tick.
  final Listenable? moved;

  /// How far the server's clock must move between two answers to tell the
  /// clocks (the `Date` header is whole seconds, so most answers move it
  /// by less).
  static const movedBy = Duration(milliseconds: 50);
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
      other.moved == moved &&
      other._heldSeconds == _heldSeconds &&
      other._heldShare == _heldShare;

  @override
  int get hashCode =>
      Object.hash(deadline, until, startedAt, moved, _heldSeconds, _heldShare);
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
    // The registries below are filled in debug and test builds only.
    for (final face in _ClockFaceState._shown.toList()) {
      face._onTick();
    }
    for (final scope in _ClockScopeElement._mounted.toList()) {
      scope._flushNow();
    }
  }

  /// Lays clocks out with no room (debug and test builds only), the
  /// reference a test holds the room's layout against: the room must never
  /// change what is drawn (`test/design_system/primitives/clock_room_layout_test.dart`).
  @visibleForTesting
  static bool debugNoRoom = false;

  @override
  State<ClockTick> createState() => _ClockTickState();
}

class _ClockTickState extends State<ClockTick> {
  /// The clock's shape, which holds while it ticks: minutes or seconds, and
  /// how many digits.
  static int _form(int? seconds) => switch (seconds) {
    null => 0,
    >= 600 => 4, // 10:00 and up
    >= 60 => 3, // 1:00 to 9:59
    >= 10 => 2, // 10 to 59 s
    _ => 1, // 0 to 9 s
  };

  /// A new form: the room is measured again, through the screen's layout
  /// (a few times a stage at most).
  void _reform() {
    if (mounted) setState(() {});
  }

  /// Counts each build of this widget: a screen that builds the clock again
  /// (new words, a text size, a dress) may need another room, which a tick
  /// never does, so each build has the room measured again.
  int _builds = 0;

  @override
  Widget build(BuildContext context) {
    final form = _form(widget.countdown?._read().seconds);
    // What the clock's content is set from, so a change to any of it builds
    // here and has the room measured again (the room is held at its size,
    // and nothing below it would reach it).
    MediaQuery.maybeTextScalerOf(context);
    DressScope.of(context);
    var noRoom = false;
    assert(() {
      noRoom = ClockTick.debugNoRoom;
      return true;
    }());
    if (noRoom) {
      return _ClockFace(
        countdown: widget.countdown,
        builder: widget.builder,
        form: form,
        reform: _reform,
      );
    }
    return _ClockRoom(
      form: (form, ++_builds),
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
  final int form;
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
    assert(_shown.add(this));
    widget.countdown?.moved?.addListener(_onMoved);
  }

  @override
  void didUpdateWidget(_ClockFace old) {
    super.didUpdateWidget(old);
    if (old.countdown?.moved != widget.countdown?.moved) {
      old.countdown?.moved?.removeListener(_onMoved);
      widget.countdown?.moved?.addListener(_onMoved);
    }
  }

  @override
  void dispose() {
    assert(_shown.remove(this));
    widget.countdown?.moved?.removeListener(_onMoved);
    _tick?.cancel();
    super.dispose();
  }

  /// What the face drew last: the number, so a re-read that finds the same
  /// one only sets the next tick again.
  int? _drawn;

  /// The server's clock was re-read and moved: the clock reads again now. A
  /// number that is the same needs no build, only its timer set again (a
  /// clock at 0 s has none, and may have time left by the new reading).
  void _onMoved() {
    if (!mounted) return;
    final seconds = widget.countdown?._read().seconds;
    if (seconds == _drawn && _ClockTickState._form(seconds) == widget.form) {
      _arm(widget.countdown?._read().next);
    } else {
      _onTick();
    }
  }

  void _arm(Duration? next) {
    _tick?.cancel();
    if (next == null) return;
    _tick = Timer(
      Duration(microseconds: math.max(1, next.inMicroseconds)),
      _onTick,
    );
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
    final reading = widget.countdown?._read();
    _arm(reading?.next);
    final seconds = reading?.seconds;
    _drawn = seconds;
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
    assert(_mounted.add(this));
  }

  @override
  void unmount() {
    assert(_mounted.remove(this));
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

/// [ClockTick]'s room: the clock is laid out under the room's own
/// constraints, exactly as without a room, and the room takes its size. The
/// room's one job is that a tick's layout stops here: the child is then
/// told it is its own relayout boundary (the parent does not use its size
/// from then on), so a tick lays out and paints the clock alone, and the
/// room stays at the size the clock last asked for (when it first showed,
/// changed form, or was given other room). It is a repaint boundary, so a
/// tick's paint stops here too. [form] changes with each build of
/// [ClockTick] (never with a tick), which measures it again.
///
/// It never gives the child other constraints than its own: a tight
/// second pass would cut a clock made of flexible parts a second time.
class RenderClockRoom extends RenderProxyBox {
  RenderClockRoom(this._form);

  Object _form;
  set form(Object value) {
    if (value == _form) return;
    _form = value;
    markNeedsLayout();
  }

  /// The size the room last took, and what it was measured under.
  Size? _measured;
  BoxConstraints? _measuredIn;

  @override
  bool get isRepaintBoundary => true;

  bool _holds(BoxConstraints constraints) =>
      _measured != null && _measuredIn == constraints;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final child = this.child;
    if (child == null) return constraints.smallest;
    if (_holds(constraints)) return _measured!;
    return child.getDryLayout(constraints);
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _measured?.width ?? super.computeMinIntrinsicWidth(height);

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _measured?.width ?? super.computeMaxIntrinsicWidth(height);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _measured?.height ?? super.computeMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _measured?.height ?? super.computeMaxIntrinsicHeight(width);

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    // As the parent of a clock with no room would: the same constraints, the
    // size used.
    child.layout(constraints, parentUsesSize: true);
    size = child.size;
    _measured = size;
    _measuredIn = constraints;
    // The same constraints again, the size no longer used: the child is its
    // own relayout boundary (a clean child with the same constraints only
    // takes the new boundary, it is not laid out twice).
    child.layout(constraints);
  }
}
