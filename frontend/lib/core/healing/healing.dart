import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'healing.g.dart';

// How a phone recovers from what it may have missed (a dropped event, a lost
// answer, no network). One rule: every fetch a screen depends on is either
// retried with backoff until it succeeds or polled until its reason ends.
// None of it is a wait a player can feel: the screen moves the moment the
// server's event or answer arrives; these only bound how long a miss lasts.

@immutable
class HealTiming {
  const HealTiming({
    this.afterDeadline = const Duration(seconds: 2),
    this.poll = const Duration(seconds: 5),
    this.firstRetry = const Duration(seconds: 1),
    this.maxRetry = const Duration(seconds: 10),
    this.tablePoll = const Duration(seconds: 15),
  });

  /// After a stage's deadline (by the server's clock), one fetch: a close
  /// this phone did not hear about (spec: "Drops and missed closes").
  final Duration afterDeadline;

  /// Past the deadline and still in the same stage: fetch this often until
  /// it changes (the server's backstop may be late, never the phone's call).
  final Duration poll;

  /// A failed fetch is made again after this, doubling up to [maxRetry],
  /// until one succeeds.
  final Duration firstRetry;
  final Duration maxRetry;

  /// At a waiting table (02) or a finished game (10, 11), where only an
  /// event would say the table moved on (a deal, play again), `/me/table/`
  /// is fetched this often while the socket that would bring it is down. A
  /// socket that looks open but has died counts as down once its beats stop
  /// (`ReconnectingWebSocket`), and coming back reads everything.
  final Duration tablePoll;

  /// The backoff before retry number [attempt] (0: the first).
  Duration retryAfter(int attempt) => Duration(
    microseconds: math.min(
      firstRetry.inMicroseconds * (1 << math.min(attempt, 20)),
      maxRetry.inMicroseconds,
    ),
  );
}

@Riverpod(keepAlive: true)
HealTiming healTiming(Ref ref) => const HealTiming();

/// The clock the app compares server deadlines with when the server's own
/// (its `Date` header) cannot be read. Tests set it.
@Riverpod(keepAlive: true)
DateTime Function() clock(Ref ref) => DateTime.now;

/// The time since the app started, by a clock that only counts: it never
/// steps when the phone's clock is set ([clockProvider] does). Tests set it.
final phoneStopwatchProvider = Provider<Duration Function()>((ref) {
  final watch = Stopwatch()..start();
  return () => watch.elapsed;
});

/// Counts the app coming back to the foreground (each value a new resume).
@riverpod
Stream<int> appResumes(Ref ref) {
  final resumes = StreamController<int>();
  var count = 0;
  final listener = AppLifecycleListener(onResume: () => resumes.add(++count));
  ref.onDispose(() {
    listener.dispose();
    resumes.close();
  });
  return resumes.stream;
}

/// Riverpod's own retry, off: for a notifier that retries its fetches
/// itself, so a rebuild can never drop the state it holds (taps in flight).
Duration? noRetry(int retryCount, Object error) => null;

/// Riverpod's retry, never giving up (its default stops after about 40 s):
/// for a fetch a screen depends on. 200 ms, doubling, at most 10 s apart.
Duration? retryForever(int retryCount, Object error) => Duration(
  milliseconds: math.min(200 * (1 << math.min(retryCount, 10)), 10000),
);
