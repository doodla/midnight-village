import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/update/worker_renewal.dart';

/// The service worker is brought up to date before the page reloads, and
/// nothing is let go of: the fake registration can only `update()` and wait;
/// it has no way to unregister or to clear a cache, so a test that passes
/// with it proves the app never reaches for either.
class _Registration implements WorkerRegistration {
  _Registration({this.updateFails = false, this.takeOver});

  final bool updateFails;

  /// When the new worker takes over; null: never (it stays installing).
  final Completer<void>? takeOver;
  var updates = 0;

  @override
  Future<void> update() async {
    updates++;
    if (updateFails) throw StateError('the network dropped');
  }

  @override
  Future<void> untilCurrent() => takeOver?.future ?? Completer<void>().future;
}

void main() {
  test('no worker registered: nothing to renew, the reload may go', () {
    fakeAsync((async) {
      bool? result;
      renewWorker(registration: () async => null).then((v) => result = v);
      async.flushMicrotasks();
      expect(result, isTrue);
    });
  });

  test('a new worker that takes over lets the reload go', () {
    fakeAsync((async) {
      final registration = _Registration(takeOver: Completer()..complete());
      bool? result;
      renewWorker(
        registration: () async => registration,
      ).then((v) => result = v);
      async.flushMicrotasks();
      expect(result, isTrue);
      expect(registration.updates, 1);
    });
  });

  test('a failed update leaves the app as it is: no reload, no throw', () {
    fakeAsync((async) {
      final registration = _Registration(updateFails: true);
      bool? result;
      renewWorker(
        registration: () async => registration,
      ).then((v) => result = v);
      async.flushMicrotasks();
      expect(result, isFalse);
      expect(registration.updates, 1);
    });
  });

  test('a worker that does not take over within its bound is given up on, '
      'with nothing changed', () {
    fakeAsync((async) {
      final registration = _Registration();
      bool? result;
      renewWorker(
        registration: () async => registration,
      ).then((v) => result = v);
      async.elapse(workerBound - const Duration(seconds: 1));
      expect(result, isNull, reason: 'still waiting inside the bound');
      async.elapse(const Duration(seconds: 2));
      expect(result, isFalse);
    });
  });

  test('a registration that cannot be read is a failure, not a reload', () {
    fakeAsync((async) {
      bool? result;
      renewWorker(
        registration: () async => throw StateError('no access'),
      ).then((v) => result = v);
      async.flushMicrotasks();
      expect(result, isFalse);
    });
  });
}
