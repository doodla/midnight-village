import 'package:dio/dio.dart';

/// The field recorder: where a tap's time goes on a real phone (`?perf=1`
/// on the web address; `lib/design_system/perf/` draws its strip).
///
/// One mechanism, called from the few places time is spent: the HTTP
/// client's way out (`core/api/in_this_task.dart`), the door every player
/// request goes through (`core/requests/player_request.dart`), the socket
/// (`core/websocket/reconnecting_websocket.dart`), the one place that says
/// which screen is shown (`HomeGate`) and the one wait (`Waiting`). The
/// pointer and the frames it reads itself, from the bindings. They all call
/// [Perf.recorder]; while it is off (always, unless switched on) that is
/// [PerfOff]: a constant with no state, whose hooks take only what the caller
/// already holds and return null, so a tap costs nothing more.
abstract final class Perf {
  /// The recorder in use: off unless `?perf=1` switched it on at start.
  static PerfRecorder recorder = const PerfOff();
}

/// What the app tells the recorder. Nothing here may carry a player's name,
/// a role, a card or a vote: the hooks take kinds, paths and times only.
abstract interface class PerfRecorder {
  /// Whether this recorder records (the strip is drawn).
  bool get on;

  /// A request is queued (the client was called): its mark, or null.
  HttpMark? httpQueued();

  /// A player request ([playerRequest]) starts: its mark, or null.
  RequestMark? playerRequestStarted();

  /// A message arrived on the socket at [url] (never recorded: only its
  /// kind, lobby or game).
  void socketMessage(String url, Object? message);

  /// The socket at [url] changed state (opening, open, closed, retrying).
  void socketState(String url, Enum state);

  /// The screen now shown: an `AppScreen` or one of `HomeGate`'s names.
  void screen(Object place);

  /// A `Waiting` came on screen, or went.
  void waitingShown();
  void waitingGone();
}

/// One HTTP request on its way.
abstract interface class HttpMark {
  /// Handed to the browser (the adapter, or a test's stand-in server).
  void left(RequestOptions? options);

  /// The answer's head arrived from the browser.
  void arrived(int status, Map<String, List<String>> headers);

  /// [sent] is the request's future; its end is when the app has it.
  Future<T> watch<T>(Future<T> sent);
}

/// One player request: its end is when the app has applied the answer.
abstract interface class RequestMark {
  void applied();
}

/// Off: nothing is recorded, nothing is held, nothing is listened to.
final class PerfOff implements PerfRecorder {
  const PerfOff();

  @override
  bool get on => false;

  @override
  HttpMark? httpQueued() => null;

  @override
  RequestMark? playerRequestStarted() => null;

  @override
  void socketMessage(String url, Object? message) {}

  @override
  void socketState(String url, Enum state) {}

  @override
  void screen(Object place) {}

  @override
  void waitingShown() {}

  @override
  void waitingGone() {}
}
