import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/helpers/timer_control.dart';

void main() {
  group('TimerControl', () {
    group('advanceBy', () {
      testWithTimerControl('advances fake time by the given Duration', (
        control,
      ) {
        var fired = false;
        Timer(const Duration(seconds: 5), () => fired = true);

        control.advanceBy(const Duration(seconds: 4));
        expect(fired, isFalse);

        control.advanceBy(const Duration(seconds: 1));
        expect(fired, isTrue);
      });
    });

    group('advanceBySeconds', () {
      testWithTimerControl(
        'advances fake time by the given number of seconds',
        (control) {
          var fired = false;
          Timer(const Duration(seconds: 3), () => fired = true);

          control.advanceBySeconds(2);
          expect(fired, isFalse);

          control.advanceBySeconds(1);
          expect(fired, isTrue);
        },
      );
    });

    group('Timer.periodic compatibility', () {
      testWithTimerControl('fires periodic Timer on each interval', (control) {
        var ticks = 0;
        Timer.periodic(const Duration(seconds: 1), (_) => ticks++);

        control.advanceBySeconds(3);
        expect(ticks, equals(3));
      });

      testWithTimerControl('does not fire Timer.periodic before interval', (
        control,
      ) {
        var ticks = 0;
        Timer.periodic(const Duration(seconds: 2), (_) => ticks++);

        control.advanceBySeconds(1);
        expect(ticks, equals(0));

        control.advanceBySeconds(1);
        expect(ticks, equals(1));
      });
    });

    group('Stream.periodic compatibility', () {
      testWithTimerControl('emits Stream.periodic events on each tick', (
        control,
      ) {
        var ticks = 0;
        Stream.periodic(const Duration(seconds: 1)).listen((_) => ticks++);

        control.advanceBySeconds(3);
        expect(ticks, equals(3));
      });
    });

    group('flushMicrotasks', () {
      testWithTimerControl(
        'processes pending microtasks without advancing clock',
        (control) {
          var completed = false;
          Future.value(42).then((_) => completed = true);

          control.flushMicrotasks();
          expect(completed, isTrue);
        },
      );
    });

    group('no real wall-clock delay', () {
      test('testWithTimerControl completes without real delay', () {
        // This test should complete almost instantly even though the body
        // uses a 60-second timer.
        final start = DateTime.now();

        fakeAsync((async) {
          var fired = false;
          Timer(const Duration(seconds: 60), () => fired = true);
          async.elapse(const Duration(seconds: 60));
          expect(fired, isTrue);
        });

        final elapsed = DateTime.now().difference(start);
        expect(elapsed.inSeconds, lessThan(5));
      });
    });
  });
}
