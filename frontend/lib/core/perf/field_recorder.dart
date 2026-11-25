import 'dart:async';
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'perf.dart';
import 'perf_records.dart';

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
/// A frame's time is when it was handed to the browser: the first timer
/// after the frame's own callbacks (the drawing ran in the frame's task,
/// before it). Nothing here schedules a frame or waits for anything.
class FieldRecorder implements PerfRecorder {
  FieldRecorder({
    required this.now,
    required this.controlAt,
    this.environment = const {},
  });

  /// The page's clock, in ms (the clock pointer events and frames use).
  final double Function() now;
  final ControlAt controlAt;
  final Map<String, Object?> environment;

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
  final _recentActivity = <double>[];
  var _installed = false;

  @override
  bool get on => true;

  String get currentScreen => _screen;

  /// Starts listening: the pointer (all of it, after the app's own
  /// handlers), the frames' timings, the first frame.
  void install() {
    if (_installed) return;
    _installed = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_pointer);
    SchedulerBinding.instance.addTimingsCallback(_timings);
    unawaited(
      WidgetsBinding.instance.waitUntilFirstFrameRasterized.then(
        (_) => firstFrameAt ??= now(),
      ),
    );
  }

  void uninstall() {
    if (!_installed) return;
    _installed = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_pointer);
    SchedulerBinding.instance.removeTimingsCallback(_timings);
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
        _frameAfter((at) {
          tap.downFrameAt = at;
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
        _frameAfter((at) {
          tap.upFrameAt = at;
          _maybeFinish(tap);
        });
      case PointerCancelEvent():
        final tap = _down.remove(event.pointer);
        if (tap != null) taps.remove(tap);
        if (identical(_current, tap)) _current = null;
      default:
    }
  }

  /// Calls [then] with the time the next frame was handed to the browser.
  void _frameAfter(void Function(double at) then) {
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => Timer.run(() => then(now())),
    );
  }

  void _maybeFinish(TapRecord tap) {
    if (tap.done || tap.upAt == null || tap.screenAt == null) return;
    final request = tap.request;
    if (tap.madePlayerRequest || request != null) {
      if (tap.shownAt == null) return;
    }
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
    for (final tap in taps.reversed.take(8)) {
      if (identical(tap.request, record) && !tap.madePlayerRequest) {
        _applied(tap);
      }
    }
  }

  void _applied(TapRecord tap) {
    tap.appliedAt = now();
    _frameAfter((at) {
      tap.shownAt = at;
      _maybeFinish(tap);
    });
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
    _frameAfter((t) => _firstFrame(change, t));
  }

  void _firstFrame(ScreenRecord change, double at) {
    change.firstFrameAt ??= at;
    if (_waiting == 0) {
      change.contentAt = at;
    } else if (identical(screens.lastOrNull, change)) {
      _frameAfter((t) => _firstFrame(change, t));
    }
  }

  @override
  void waitingShown() => _waiting++;

  @override
  void waitingGone() => _waiting = _waiting > 0 ? _waiting - 1 : 0;

  // ---------------------------------------------------------------------------
  // Frames
  // ---------------------------------------------------------------------------

  /// Recent frames (start, total ms), for a tap's worst frame.
  final _recent = <(double, double)>[];

  void _timings(List<FrameTiming> timings) {
    for (final timing in timings) {
      final start =
          timing.timestampInMicroseconds(FramePhase.buildStart) / 1000;
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
      _keep(_recent, (start, total), 600);
      // A tap that finished before its last frames' timings came in.
      for (final tap in taps.reversed.take(4)) {
        final end = tap.shownAt ?? tap.screenAt;
        if (tap.done && end != null && start >= tap.from && start <= end) {
          if (total > tap.worstFrame) tap.worstFrame = total;
        }
      }
    }
  }

  /// FrameTiming for frames already drawn and not yet seen (the engine
  /// hands them over in batches): the stats include them.
  @visibleForTesting
  void takeTimings(List<FrameTiming> timings) => _timings(timings);

  double _worstBetween(double from, double to) {
    var worst = 0.0;
    for (final (start, total) in _recent) {
      if (start >= from && start <= to && total > worst) worst = total;
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
    _keep(_recentActivity, at, 64);
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

class _HttpMark implements HttpMark {
  _HttpMark(this._recorder, this._record);

  final FieldRecorder _recorder;
  final HttpRecord _record;

  void _name(RequestOptions options) {
    if (_record.method.isNotEmpty) return;
    _record
      ..method = options.method.toUpperCase()
      ..path = cleanPath(options.uri.toString());
  }

  @override
  void left(RequestOptions? options) {
    _record.leftAt ??= _recorder.now();
    if (options != null) _name(options);
  }

  @override
  void arrived(int status, Map<String, List<String>> headers) {
    _record
      ..arrivedAt = _recorder.now()
      ..status = status;
    final timing = serverTiming(headers['server-timing']?.join(','));
    _record
      ..serverConnect = timing.connect
      ..serverTotal = timing.total;
  }

  @override
  Future<T> watch<T>(Future<T> sent) => sent.then(
    (answer) {
      _done(answer is Response ? answer : null, null);
      return answer;
    },
    onError: (Object error, StackTrace stack) {
      _done(null, error is DioException ? error : null);
      Error.throwWithStackTrace(error, stack);
    },
  );

  void _done(Response<Object?>? answer, DioException? failure) {
    _record.doneAt = _recorder.now();
    final options = answer?.requestOptions ?? failure?.requestOptions;
    if (options != null) _name(options);
    _record.status ??= answer?.statusCode ?? failure?.response?.statusCode;
    if (_record.serverTotal == null && answer != null) {
      final timing = serverTiming(answer.headers.value('server-timing'));
      _record
        ..serverConnect = timing.connect
        ..serverTotal = timing.total;
    }
    _recorder._answered(_record);
  }
}

class _RequestMark implements RequestMark {
  _RequestMark(this._recorder, this._tap);

  final FieldRecorder _recorder;
  final TapRecord _tap;

  @override
  void applied() => _recorder._applied(_tap);
}
