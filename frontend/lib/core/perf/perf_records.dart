// What the field recorder keeps (`field_recorder.dart`): times on the page's
// own clock (ms since it opened), kinds and paths. Never a name, a role, a
// card, a vote or anything a server answer says.

/// One touch on something that takes a tap, from the finger to the screen
/// that answered it.
class TapRecord {
  TapRecord({
    required this.screen,
    required this.control,
    required this.downAt,
    required this.heardDownAt,
  });

  /// The screen it was on (`HomeGate`'s place) and the kind of control.
  final String screen;
  final String control;

  /// The pointer-down's own time stamp, and when the app handled it.
  final double downAt;
  final double heardDownAt;

  /// The lift's own time stamp, and when the app handled it (a tap's
  /// handler runs as the finger lifts).
  double? upAt;
  double? heardUpAt;

  /// Held (the finger stayed down at least a long press): timed from the
  /// down, since a hold answers while the finger is still on the glass.
  var hold = false;

  /// The first frame drawn after the down was handled, and after the lift.
  double? downFrameAt;
  double? upFrameAt;

  /// The request the tap caused (the first it made), if any.
  HttpRecord? request;

  /// A player request (`playerRequest`) started by the tap: its answer was
  /// applied at [appliedAt], and the next frame after that at [shownAt].
  var madePlayerRequest = false;
  double? appliedAt;
  double? shownAt;

  /// The worst frame drawn between the finger and [shownAt].
  double worstFrame = 0;

  var done = false;

  /// The moment the tap acts: the lift, or the down of a hold.
  double get from => hold ? downAt : (upAt ?? downAt);
  double? get heardAt => hold ? heardDownAt : heardUpAt;
  double? get screenAt => hold ? downFrameAt : upFrameAt;

  /// The kind of tap, for the summary: where, what, and what it sent.
  String get kind {
    final sent = request;
    final what = sent == null ? '' : ' ${sent.method} ${sent.path}';
    return '$screen ${hold ? 'hold' : 'tap'} $control$what';
  }

  /// Each leg, in ms (null: did not happen, or not yet).
  double? get heard => _gap(from, heardAt);
  double? get toScreen => _gap(from, screenAt);
  double? get toLeft => _gap(from, request?.leftAt);
  double? get roundTrip => request?.roundTrip;
  double? get toApplied =>
      _gap(request?.arrivedAt ?? request?.doneAt, appliedAt);
  double? get toShown => _gap(appliedAt, shownAt);
  double? get total => _gap(from, shownAt ?? screenAt);

  Map<String, Object?> toJson() => {
    'screen': screen,
    'control': control,
    'hold': hold,
    'down': _r(downAt),
    'heard_down': _r(heardDownAt),
    'up': _r(upAt),
    'heard_up': _r(heardUpAt),
    'down_frame': _r(downFrameAt),
    'up_frame': _r(upFrameAt),
    'request': request?.id,
    'applied': _r(appliedAt),
    'shown': _r(shownAt),
    'worst_frame': _r(worstFrame),
    'done': done,
  };
}

/// One HTTP request.
class HttpRecord {
  HttpRecord({
    required this.id,
    required this.queuedAt,
    required this.screen,
    required this.cause,
  });

  final int id;
  final double queuedAt;
  final String screen;

  /// What led to it: `tap` (made by a tap's handler), `event` (within a
  /// second of a socket message, a screen change or another answer), or
  /// `poll` (nothing did: a timer).
  final String cause;

  var method = '';

  /// The path with every id, code and query removed.
  var path = '';
  double? leftAt;
  double? arrivedAt;
  double? doneAt;
  int? status;

  /// The server's own `Server-Timing` (connection, total), when the browser
  /// may read it.
  double? serverConnect;
  double? serverTotal;

  bool get isPoll => cause == 'poll';
  double? get waited => _gap(queuedAt, leftAt);
  double? get roundTrip => _gap(leftAt, arrivedAt ?? doneAt);

  Map<String, Object?> toJson() => {
    'id': id,
    'method': method,
    'path': path,
    'screen': screen,
    'cause': cause,
    'queued': _r(queuedAt),
    'left': _r(leftAt),
    'arrived': _r(arrivedAt),
    'done': _r(doneAt),
    'status': status,
    'server_connect': serverConnect,
    'server_total': serverTotal,
  };
}

/// A socket message (its kind only) or a change of the socket's state.
class SocketRecord {
  SocketRecord(this.socket, this.what, this.at, {this.state = false});

  /// `lobby` or `game`.
  final String socket;

  /// The event's type (`phase_change`), or the state (`connected`).
  final String what;
  final double at;
  final bool state;

  Map<String, Object?> toJson() => {
    'socket': socket,
    if (state) 'state': what else 'event': what,
    'at': _r(at),
  };
}

/// A screen change, from its cause to its first frame and to its content
/// (the first frame with no `Waiting` on it).
class ScreenRecord {
  ScreenRecord({
    required this.from,
    required this.to,
    required this.at,
    required this.cause,
    required this.causeAt,
  });

  final String from;
  final String to;
  final double at;

  /// `tap`, `socket <type>`, or `none` (the app's own start, an answer
  /// long after any tap).
  final String cause;
  final double causeAt;
  double? firstFrameAt;
  double? contentAt;

  double? get toFirstFrame => _gap(causeAt, firstFrameAt);
  double? get toContent => _gap(causeAt, contentAt);

  Map<String, Object?> toJson() => {
    'from': from,
    'to': to,
    'at': _r(at),
    'cause': cause,
    'cause_at': _r(causeAt),
    'first_frame': _r(firstFrameAt),
    'content': _r(contentAt),
  };
}

/// The frames drawn on one screen (`FrameTiming`).
class FrameStats {
  static const _kept = 3000;

  var frames = 0;
  var over16 = 0;
  var over32 = 0;
  var over50 = 0;
  var over100 = 0;
  double worst = 0;
  final builds = <double>[];
  final rasters = <double>[];
  final totals = <double>[];

  /// Frames drawn at rest (no touch, socket message or screen change in the
  /// second before), and how long the screen was at rest.
  var restFrames = 0;
  double restMs = 0;

  void add(double build, double raster, double total, {required bool rest}) {
    frames++;
    if (total > 16) over16++;
    if (total > 32) over32++;
    if (total > 50) over50++;
    if (total > 100) over100++;
    if (total > worst) worst = total;
    if (rest) restFrames++;
    if (totals.length < _kept) {
      builds.add(build);
      rasters.add(raster);
      totals.add(total);
    }
  }

  double? get restPerMinute =>
      restMs < 1000 ? null : restFrames / (restMs / 60000);

  Map<String, Object?> toJson() => {
    'frames': frames,
    'over_16': over16,
    'over_32': over32,
    'over_50': over50,
    'over_100': over100,
    'worst': _r(worst),
    'build_median': _r(median(builds)),
    'raster_median': _r(median(rasters)),
    'total_median': _r(median(totals)),
    'rest_frames': restFrames,
    'rest_ms': restMs.round(),
  };
}

/// The middle value (null for none).
double? median(Iterable<double> values) {
  final sorted = values.toList()..sort();
  if (sorted.isEmpty) return null;
  return sorted[sorted.length ~/ 2];
}

double? _gap(double? from, double? to) =>
    from == null || to == null ? null : to - from;

double? _r(double? ms) => ms == null ? null : (ms * 10).round() / 10;

/// A path with every id, code and query removed: only the words of the API
/// stay (`/api/v2/games/·/vote/`).
String cleanPath(String pathOrUrl) {
  final path = Uri.tryParse(pathOrUrl)?.path ?? '';
  final word = RegExp(r'^([a-z][a-z_-]*|v\d)$');
  return path
      .split('/')
      .map((s) => s.isEmpty || word.hasMatch(s) ? s : '·')
      .join('/');
}

/// The `Server-Timing` header's `connect` and `total`, in ms.
({double? connect, double? total}) serverTiming(String? header) {
  double? connect;
  double? total;
  for (final part in (header ?? '').split(',')) {
    final bits = part.trim().split(';');
    final dur = bits
        .map((b) => b.trim())
        .where((b) => b.startsWith('dur='))
        .map((b) => double.tryParse(b.substring(4)))
        .firstOrNull;
    switch (bits.first.trim()) {
      case 'connect':
        connect = dur;
      case 'total':
        total = dur;
    }
  }
  return (connect: connect, total: total);
}
