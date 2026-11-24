import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// How long a wait may take for something the server does AT ONCE (an event
/// sent in answer to a request, a read, no timer involved). A wait for a timer
/// takes [TimeBox.timeout] instead.
///
/// The ONE ceiling of the harness: every wait polls its own condition and
/// stops the moment it holds, so this costs nothing while tests pass. It is
/// generous on purpose: a machine running other suites is slow, not broken
/// (10 and 15 s ceilings failed runs that passed alone). No wait names a
/// number of its own.
const Duration eventTimeout = Duration(seconds: 30);

/// Polls until [condition] holds. Bounded: throws a [StateError] naming
/// [reason] (plus [context], if given) when [timeout] runs out. The one poller
/// of the harness (socket events and oracle reads both use it).
Future<void> pollUntil(
  FutureOr<bool> Function() condition, {
  required String reason,
  required Duration timeout,
  String Function()? context,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (await condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw StateError(
    'Timed out after $timeout waiting for $reason'
    '${context == null ? '' : '. ${context()}'}',
  );
}

/// A period the SERVER times with its own clock (a grace period, a window's
/// minimum length), measured on the client from before the move that starts it.
///
/// A check that something has NOT happened yet is only meaningful while the
/// period is still running, so such a read goes through [readInside]: if the
/// machine was too slow and the period was over by the time the read returned,
/// the test fails as INCONCLUSIVE instead of blaming the server. Because the
/// stopwatch starts before the server's clock does, [expectOver] (the period
/// really lasted) can never fail on the client's own measuring error.
class TimeBox {
  TimeBox(this.what, this.length) : _clock = Stopwatch()..start();

  /// What the period is, for failure messages ("the 8 s grace period").
  final String what;
  final Duration length;
  final Stopwatch _clock;

  Duration get elapsed => _clock.elapsed;

  /// How long to wait for the event that ENDS the period: its length plus
  /// [eventTimeout] for the server to get to it.
  Duration get timeout => length + eventTimeout;

  /// Runs [read] and returns its value, unless the period was already over when
  /// it returned: then the read says nothing about the server.
  Future<T> readInside<T>(Future<T> Function() read) async {
    final value = await read();
    if (elapsed >= length) {
      fail(
        'inconclusive: machine too slow (elapsed $elapsed of $what, $length)',
      );
    }
    return value;
  }

  /// Asserts that at least the whole period has passed since the box started.
  void expectOver(String reason) {
    expect(
      elapsed,
      greaterThanOrEqualTo(length),
      reason: '$reason ($what is $length, only $elapsed passed)',
    );
  }
}
