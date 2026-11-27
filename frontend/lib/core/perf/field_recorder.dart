import 'dart:async';
import 'dart:collection';
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'perf.dart';
import 'perf_records.dart';

part 'field_marks.dart';

/// Names what a finger went down on: a kind of control (`main_button`,
/// `player_row`), `perf` for the recorder's own strip, or null when nothing
/// there takes a tap. Never words from the screen.
typedef ControlAt = String? Function(Offset position, int viewId);

/// The recorder when `?perf=1` switched it on: everything is kept in memory
/// on this phone, and leaves it only when the player copies the report.
///
/// - A tap: from the pointer event's own time stamp to when the app handled
///   it, the first frame after, the request it made leaving and its answer,
///   the answer applied, and the frame after that.
/// - Every frame (`FrameTiming`), counted per screen.
/// - Every request, socket message and screen change.
///
/// A frame's time is when the engine finished drawing it (its own
/// `FrameTiming`, found by a time taken inside the frame); until that
/// timing arrives (the engine hands timings over in batches), the first
/// timer after the frame stands in. A request's round trip is the
/// browser's own record of it (Resource Timing), so the time its answer
/// waited for a busy page is told apart. Nothing here schedules a frame or
/// waits for anything.
class FieldRecorder implements PerfRecorder {
  FieldRecorder({
    required this.now,
    required this.controlAt,
    this.environment = const {},
    this.resourceTiming,
  });

  /// The page's clock, in ms (the clock pointer events and frames use).
  final double Function() now;
  final ControlAt controlAt;
  final Map<String, Object?> environment;

  /// The browser's record of the request to [url] that went out after
  /// [after] (ms): when it went and when its answer was in. Null: unknown.
  final ({double start, double end})? Function(String url, double after)?
  resourceTiming;

  /// Whether the engine reports frame timings here (a test's binding does
  /// not): a tap then finishes on its frames' own timings.
  var _timed = false;

  static const _keptTaps = 400;
  static const _keptRequests = 1500;
  static const _keptSockets = 1500;
  static const _keptScreens = 400;

  /// How long after a touch, a socket message or a screen change the app is
  /// still busy with it (a frame or a read then is not "at rest").
  static const busyFor = 1000.0;

  final taps = <TapRecord>[];
  final requests = <HttpRecord>[];
  final sockets = <SocketRecord>[];
  final screens = <ScreenRecord>[];
  final frames = <String, FrameStats>{};

  /// The last tap that finished: the strip shows it (and repaints only then).
  final finished = ValueNotifier<TapRecord?>(null);

  /// When the app's first frame was drawn (ms since the page opened).
  double? firstFrameAt;

  var _screen = 'opening';
  var _screenSince = 0.0;
  var _waiting = 0;
  var _requestIds = 0;
  final _down = <int, TapRecord>{};
  TapRecord? _current;
  TapRecord? _lastTap;
  SocketRecord? _lastSocket;
  double _lastActivity = -busyFor;
  final _recentActivity = ListQueue<double>();
  var _installed = false;

  @override
  bool get on => true;

  String get currentScreen => _screen;

  /// Whether nothing happened for [busyFor]: no touch, socket message,
  /// screen change or answer (the beacon builds a summary only then).
  bool get atRest => now() - _lastActivity >= busyFor;

  // What the bindings call: guarded, so nothing the recorder throws reaches
  // the pointer, the frames or the app (`quietly`).
  void _onPointer(PointerEvent e) => quietly(() => _pointer(e));
  void _onTimings(List<FrameTiming> t) => quietly(() => _timings(t));

  /// Starts listening: the pointer (all of it, after the app's own
  /// handlers), the frames' timings, the first frame.
  void install() {
    if (_installed) return;
    _installed = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    unawaited(
      WidgetsBinding.instance.waitUntilFirstFrameRasterized.then(
        (_) => firstFrameAt ??= now(),
        onError: (_) {},
      ),
    );
  }

  void uninstall() {
    if (!_installed) return;
    _installed = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_onPointer);
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  /// Forgets everything recorded (the sheet's "Clear").
  void clear() {
    taps.clear();
    requests.clear();
    sockets.clear();
    screens.clear();
    frames.clear();
    _down.clear();
    finished.value = null;
  }

  // ---------------------------------------------------------------------------
  // The finger
  // ---------------------------------------------------------------------------

  static double _stamp(Duration timeStamp) => timeStamp.inMicroseconds / 1000;

  void _pointer(PointerEvent event) {
    switch (event) {
      case PointerDownEvent():
        final heard = now();
        final control = controlAt(event.position, event.viewId);
        if (control == null || control == 'perf') return;
        final tap = TapRecord(
          screen: _screen,
          control: control,
          downAt: _stamp(event.timeStamp),
          heardDownAt: heard,
        );
        _activity(heard);
        _down[event.pointer] = tap;
        _keep(taps, tap, _keptTaps);
        // From the down until the lift has been handled, a request made
        // belongs to this tap: a tap's handler runs as the finger lifts,
        // before this route hears the lift, and a hold's while it is down.
        _current = tap;
        _finishWaiting();
        _frameAfter((mark, at) {
          tap
            ..downFrameMark = mark
            ..downFrameAt ??= at;
          _maybeFinish(tap);
        });
      case PointerUpEvent():
        final tap = _down.remove(event.pointer);
        if (tap == null) return;
        final up = _stamp(event.timeStamp);
        // The handler ran in this dispatch, just before this route: a
        // request it queued says when.
        final queued = tap.request?.queuedAt;
        final routed = now();
        final heard = queued != null && queued >= up && queued < routed
            ? queued
            : routed;
        _activity(heard);
        tap
          ..upAt = up
          ..heardUpAt = heard
          ..hold = up - tap.downAt >= kLongPressTimeout.inMilliseconds;
        _lastTap = tap;
        // What the handler started in this task still belongs to it (the
        // request leaves in the tap's task: `inThisTask`).
        Timer.run(() {
          if (identical(_current, tap)) _current = null;
        });
        _frameAfter((mark, at) {
          tap
            ..upFrameMark = mark
            ..upFrameAt ??= at;
          _maybeFinish(tap);
        });
      case PointerCancelEvent():
        final tap = _down.remove(event.pointer);
        if (tap != null) taps.remove(tap);
        if (identical(_current, tap)) _current = null;
      default:
    }
  }

  /// Calls [then] once the next frame is drawn: with a time inside it (its
  /// own callbacks, before the engine finishes it), and the first timer
  /// after it (the stand-in until its timing arrives).
  void _frameAfter(void Function(double mark, double at) then) {
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => quietly(() {
        final mark = now();
        _refine();
        Timer.run(
          () => quietly(() {
            then(mark, now());
            _refine();
          }),
        );
      }),
    );
  }

  /// Finishes [tap] once every frame it waits for is known: by its own
  /// timing, or with [force] by the stand-in (a new touch came first).
  void _maybeFinish(TapRecord tap, {bool force = false}) {
    if (tap.done || tap.upAt == null || tap.screenAt == null) return;
    final request = tap.request;
    final last = (tap.madePlayerRequest || request != null)
        ? tap.shownMark
        : (tap.hold ? tap.downFrameMark : tap.upFrameMark);
    if (last == null) return;
    if (_timed && !force && _frameOf(last) == null) return;
    tap
      ..done = true
      ..worstFrame = _worstBetween(tap.from, tap.shownAt ?? tap.screenAt!);
    finished.value = tap;
  }

  // ---------------------------------------------------------------------------
  // Requests
  // ---------------------------------------------------------------------------

  @override
  HttpMark? httpQueued() {
    final at = now();
    final tap = _current;
    final record = HttpRecord(
      id: ++_requestIds,
      queuedAt: at,
      screen: _screen,
      cause: tap != null
          ? 'tap'
          : at - _lastActivity < busyFor
          ? 'event'
          : 'poll',
    );
    _keep(requests, record, _keptRequests);
    if (tap != null && tap.request == null) tap.request = record;
    return _HttpMark(this, record);
  }

  @override
  RequestMark? playerRequestStarted() {
    final tap = _current;
    if (tap == null || tap.madePlayerRequest) return null;
    tap.madePlayerRequest = true;
    return _RequestMark(this, tap);
  }

  void _answered(HttpRecord record) {
    _activity(record.doneAt!);
    // A tap that made a read only: the read's answer is what it applied.
    for (final tap in _lastTaps) {
      if (identical(tap.request, record) && !tap.madePlayerRequest) {
        _applied(tap);
      }
    }
  }

  void _applied(TapRecord tap) {
    tap.appliedAt = now();
    _frameAfter((mark, at) {
      tap
        ..shownMark = mark
        ..shownAt ??= at;
      _maybeFinish(tap);
    });
  }

  /// A new touch: the taps still waiting for their frames' timings finish
  /// on what is known (on a still screen the engine holds the last timings
  /// until it draws again).
  /// The last few taps, oldest first (so the newest finishes last, and the
  /// strip shows it).
  Iterable<TapRecord> get _lastTaps =>
      taps.length <= 8 ? taps.toList() : taps.sublist(taps.length - 8);

  void _finishWaiting() {
    for (final tap in _lastTaps) {
      _maybeFinish(tap, force: true);
    }
  }

  // ---------------------------------------------------------------------------
  // The socket
  // ---------------------------------------------------------------------------

  static final _type = RegExp(r'"type"\s*:\s*"([a-z_]+)"');
  static final _word = RegExp(r'^[a-z_]+$');

  static String _socketKind(String url) => url.contains('/ws/game/')
      ? 'game'
      : url.contains('/ws/lobby/')
      ? 'lobby'
      : 'socket';

  @override
  void socketMessage(String url, Object? message) {
    final type = switch (message) {
      String() => _type.firstMatch(message)?.group(1),
      Map() => message['type'],
      _ => null,
    };
    final at = now();
    final record = SocketRecord(
      _socketKind(url),
      type is String && _word.hasMatch(type) ? type : 'message',
      at,
    );
    _lastSocket = record;
    _activity(at);
    _keep(sockets, record, _keptSockets);
  }

  @override
  void socketState(String url, Enum state) {
    _keep(
      sockets,
      SocketRecord(_socketKind(url), state.name, now(), state: true),
      _keptSockets,
    );
  }

  // ---------------------------------------------------------------------------
  // Screens
  // ---------------------------------------------------------------------------

  @override
  void screen(Object place) {
    final name = place is Enum ? place.name : '$place';
    if (name == _screen) return;
    final at = now();
    final tapAt = _lastTap?.heardUpAt;
    final socketAt = _lastSocket?.at;
    final (cause, causeAt) = switch ((tapAt, socketAt)) {
      (final t?, final s?) when s > t => ('socket ${_lastSocket!.what}', s),
      (final t?, _) => ('tap', t),
      (null, final s?) => ('socket ${_lastSocket!.what}', s),
      _ => ('none', at),
    };
    final change = ScreenRecord(
      from: _screen,
      to: name,
      at: at,
      cause: cause,
      causeAt: causeAt,
    );
    _closeRest(at);
    _screen = name;
    _screenSince = at;
    _activity(at);
    _keep(screens, change, _keptScreens);
    _frameAfter((mark, at) => _firstFrame(change, mark, at));
    screenChanged?.call(name);
  }

  /// Told each new screen's name (the quiet mode's beacon: `FieldBeacon`).
  void Function(String screen)? screenChanged;

  void _firstFrame(ScreenRecord change, double mark, double at) {
    change.firstMark ??= mark;
    change.firstFrameAt ??= at;
    if (_waiting == 0) {
      change
        ..contentMark ??= mark
        ..contentAt ??= at;
    } else if (identical(screens.lastOrNull, change)) {
      _frameAfter((m, t) => _firstFrame(change, m, t));
    }
  }

  @override
  void waitingShown() => _waiting++;

  @override
  void waitingGone() => _waiting = _waiting > 0 ? _waiting - 1 : 0;

  // ---------------------------------------------------------------------------
  // Frames
  // ---------------------------------------------------------------------------

  /// Recent frames (build start, raster finish, total ms): a tap's worst
  /// frame, and each leg's frame by its own timing.
  final _recent = ListQueue<(double, double, double)>();

  void _timings(List<FrameTiming> timings) {
    _timed = true;
    for (final timing in timings) {
      final start =
          timing.timestampInMicroseconds(FramePhase.buildStart) / 1000;
      final end =
          timing.timestampInMicroseconds(FramePhase.rasterFinish) / 1000;
      final total = timing.totalSpan.inMicroseconds / 1000;
      final rest = !_recentActivity.any(
        (a) => a <= start && start - a < busyFor,
      );
      frames
          .putIfAbsent(_screenAt(start), FrameStats.new)
          .add(
            timing.buildDuration.inMicroseconds / 1000,
            timing.rasterDuration.inMicroseconds / 1000,
            total,
            rest: rest,
          );
      _recent.addLast((start, end, total));
      if (_recent.length > 600) _recent.removeFirst();
      // A tap that finished before its last frames' timings came in.
      for (final tap in taps.reversed.take(4)) {
        final end = tap.shownAt ?? tap.screenAt;
        if (tap.done && end != null && start >= tap.from && start <= end) {
          if (total > tap.worstFrame) tap.worstFrame = total;
        }
      }
    }
    _refine();
  }

  /// When the frame that [mark] (a time inside it) belongs to was drawn:
  /// the first frame the engine finished after it.
  double? _frameOf(double? mark) {
    if (mark == null) return null;
    // From the newest back: a mark is recent, so this stops in a few steps.
    double? found;
    for (var i = _recent.length - 1; i >= 0; i--) {
      final end = _recent.elementAt(i).$2;
      if (end < mark) break;
      found = end;
    }
    return found;
  }

  /// Puts each recent leg's frame on its own timing, and finishes the taps
  /// that were waiting for it.
  void _refine() {
    if (!_timed) return;
    for (final tap in _lastTaps) {
      if (tap.done) continue;
      tap
        ..downFrameAt = _frameOf(tap.downFrameMark) ?? tap.downFrameAt
        ..upFrameAt = _frameOf(tap.upFrameMark) ?? tap.upFrameAt
        ..shownAt = _frameOf(tap.shownMark) ?? tap.shownAt;
      _maybeFinish(tap);
    }
    for (final change in screens.reversed.take(4)) {
      change
        ..firstFrameAt = _frameOf(change.firstMark) ?? change.firstFrameAt
        ..contentAt = _frameOf(change.contentMark) ?? change.contentAt;
    }
  }

  /// FrameTiming for frames already drawn and not yet seen (the engine
  /// hands them over in batches): the stats include them.
  @visibleForTesting
  void takeTimings(List<FrameTiming> timings) => _timings(timings);

  double _worstBetween(double from, double to) {
    var worst = 0.0;
    for (var i = _recent.length - 1; i >= 0; i--) {
      final (start, _, total) = _recent.elementAt(i);
      if (start < from) break;
      if (start <= to && total > worst) worst = total;
    }
    return worst;
  }

  String _screenAt(double at) {
    for (final change in screens.reversed) {
      if (change.at <= at) return change.to;
    }
    return screens.firstOrNull?.from ?? _screen;
  }

  // ---------------------------------------------------------------------------
  // Rest
  // ---------------------------------------------------------------------------

  void _activity(double at) {
    _closeRest(at);
    _lastActivity = at;
    _recentActivity.addLast(at);
    if (_recentActivity.length > 64) _recentActivity.removeFirst();
  }

  /// Adds the time the shown screen was at rest up to [at].
  void _closeRest(double at) {
    final restFrom = [
      _lastActivity + busyFor,
      _screenSince,
    ].reduce((a, b) => a > b ? a : b);
    if (at > restFrom) {
      frames.putIfAbsent(_screen, FrameStats.new).restMs += at - restFrom;
    }
  }

  /// Brings the rest time up to now (before a report).
  void settleRest() {
    final at = now();
    _closeRest(at);
    _screenSince = at;
    if (_lastActivity + busyFor < at) _lastActivity = at - busyFor;
  }

  static void _keep<T>(List<T> list, T item, int most) {
    list.add(item);
    if (list.length > most) list.removeAt(0);
  }
}
