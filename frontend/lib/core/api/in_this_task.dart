import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../perf/perf.dart';

/// Runs [send] (a request through Dio) so that it leaves in the task that
/// called it: the tap's own, on a phone.
///
/// Dio passes a request from one interceptor to the next, and on to the
/// adapter, through `Future(...)`: a timer of no length each, which on the
/// web is a new browser task. Between two tasks the browser draws whatever
/// frame the app has asked for, and on a busy phone a frame takes 200 to
/// 800 ms, so a request with five such steps left the phone a second after
/// the finger. Here, until the request has left ([requestLeft]), a timer of
/// no length is run as a microtask instead (still after the code that made
/// it, in the order made, but before anything else the browser has
/// queued); a timer with a length is left as it is, and once the request
/// has left everything runs as it always did (the answer is handled as
/// before). Nothing waits more for it: it only waits less.
///
/// The field recorder (`core/perf/`) hears each request queued here, leaving
/// ([requestLeft]), answered ([LeavesHere]) and handed back; off, it is a
/// null object and nothing more is done.
Future<T> inThisTask<T>(Future<T> Function() send) {
  final way = _WayOut()..perf = Perf.recorder.httpQueued();
  final sent = runZoned(
    send,
    zoneValues: {_WayOut: way},
    zoneSpecification: ZoneSpecification(
      createTimer: (self, parent, zone, duration, callback) {
        if (way.left || duration > Duration.zero) {
          return parent.createTimer(zone, duration, callback);
        }
        final timer = _MicrotaskTimer();
        parent.scheduleMicrotask(zone, () {
          if (timer._active) {
            timer._active = false;
            callback();
          }
        });
        return timer;
      },
    ),
  );
  return way.perf?.watch(sent) ?? sent;
}

/// The request of this zone has left the phone (handed to the network, or
/// to a test's stand-in server): from here on its timers are ordinary.
void requestLeft([RequestOptions? options]) {
  final way = Zone.current[_WayOut] as _WayOut?;
  if (way == null) return;
  way.left = true;
  way.perf?.left(options);
}

class _WayOut {
  var left = false;
  HttpMark? perf;
}

/// An adapter that says when the request leaves ([requestLeft]), then hands
/// it to [inner].
class LeavesHere implements HttpClientAdapter {
  LeavesHere(this.inner);

  final HttpClientAdapter inner;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requestLeft(options);
    final answer = inner.fetch(options, requestStream, cancelFuture);
    final perf = (Zone.current[_WayOut] as _WayOut?)?.perf;
    if (perf == null) return answer;
    return answer.then((body) {
      perf.arrived(body.statusCode, body.headers);
      return body;
    });
  }

  @override
  void close({bool force = false}) => inner.close(force: force);
}

/// A timer of no length, run as a microtask.
class _MicrotaskTimer implements Timer {
  var _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;

  @override
  void cancel() => _active = false;
}
