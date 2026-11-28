import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/finger_hold.dart';

/// A part that takes a tap and a hold, as a role card does.
class _Part {
  final taps = <String>[];

  Widget build() => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          TapGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                TapGestureRecognizer.new,
                (r) => r.onTap = () => taps.add('tap'),
              ),
          FingerTimedLongPress:
              GestureRecognizerFactoryWithHandlers<FingerTimedLongPress>(
                () => FingerTimedLongPress(duration: _hold),
                (r) => r.onLongPress = () => taps.add('hold'),
              ),
        },
        child: const SizedBox.square(dimension: 100),
      ),
    ),
  );
}

const _hold = Duration(milliseconds: 300);

const _frame = Duration(milliseconds: 16);

/// A finger down (10 s by its own clock) on a page then kept busy past the
/// hold: the hold's timer runs 100 ms late, then the first frame after it.
Future<TestPointer> _blockedPast(WidgetTester tester) async {
  final finger = TestPointer(5);
  final at = tester.getCenter(find.byType(RawGestureDetector));
  await tester.sendEventToBinding(
    finger.down(at, timeStamp: const Duration(seconds: 10)),
  );
  (tester.binding as AutomatedTestWidgetsFlutterBinding).elapseBlocking(
    _hold + const Duration(milliseconds: 100),
  );
  await tester.pump(Duration.zero);
  return finger;
}

/// A finger down at [downAt] and up at [upAt] by its own clock, handled by
/// a phone too busy to run a timer in between: one late frame, and no time
/// passes for the app.
Future<void> _busyPress(
  WidgetTester tester, {
  required Duration downAt,
  required Duration upAt,
}) async {
  final finger = TestPointer(5);
  final at = tester.getCenter(find.byType(RawGestureDetector));
  await tester.sendEventToBinding(finger.down(at, timeStamp: downAt));
  tester.binding.scheduleFrame();
  await tester.pump();
  await tester.sendEventToBinding(finger.up(timeStamp: upAt));
  await tester.pump();
}

void main() {
  group('a hold is timed from the finger', () {
    testWidgets('held past the hold by its own clock: a hold, never a tap, '
        'though the app could not run its timer', (tester) async {
      final part = _Part();
      await tester.pumpWidget(part.build());

      await _busyPress(
        tester,
        downAt: const Duration(seconds: 10),
        upAt: const Duration(seconds: 10, milliseconds: 1600),
      );

      expect(part.taps, ['hold']);
    });

    testWidgets('lifted before the hold by its own clock: a tap', (
      tester,
    ) async {
      final part = _Part();
      await tester.pumpWidget(part.build());

      await _busyPress(
        tester,
        downAt: const Duration(seconds: 10),
        upAt: const Duration(seconds: 10, milliseconds: 80),
      );

      expect(part.taps, ['tap']);
    });

    testWidgets('a finger still down gets the timer, as before', (
      tester,
    ) async {
      final part = _Part();
      await tester.pumpWidget(part.build());
      final finger = await tester.startGesture(
        tester.getCenter(find.byType(RawGestureDetector)),
      );
      await tester.pump(_hold);
      expect(part.taps, ['hold']);
      await finger.up();
      await tester.pump();
      expect(part.taps, ['hold'], reason: 'once');
    });

    testWidgets('a lift that waits behind a long frame wins over the '
        "hold's timer: a quick touch is a tap", (tester) async {
      // A browser busy drawing a press hands the app its timer and the lift
      // together: the timer runs first, the lift (80 ms by the finger) next.
      final part = _Part();
      await tester.pumpWidget(part.build());
      final finger = TestPointer(5);
      final at = tester.getCenter(find.byType(RawGestureDetector));
      await tester.sendEventToBinding(
        finger.down(at, timeStamp: const Duration(seconds: 10)),
      );
      await tester.binding.delayed(_hold);
      await tester.sendEventToBinding(
        finger.up(timeStamp: const Duration(seconds: 10, milliseconds: 80)),
      );
      await tester.pump();

      expect(part.taps, ['tap']);
    });

    testWidgets('on a page blocked across the hold a lift Chrome hands over '
        'up to four frames after the block still makes a quick touch a tap', (
      tester,
    ) async {
      // Measured in Chrome (`just tap-hold`, the busy rows): the lift reaches
      // the page after at most three frames began after the block; one more
      // for headroom.
      final part = _Part();
      await tester.pumpWidget(part.build());
      final finger = await _blockedPast(tester);
      for (var i = 1; i < FingerTimedLongPress.liftFrames; i++) {
        await tester.pump(_frame);
      }
      expect(part.taps, isEmpty, reason: 'the timer has run, four frames too');
      await tester.sendEventToBinding(
        finger.up(timeStamp: const Duration(seconds: 10, milliseconds: 80)),
      );
      await tester.pump(_frame);

      expect(part.taps, ['tap']);
    });

    testWidgets('on a page blocked across the hold a finger still down holds '
        'four frames after the timer, never more', (tester) async {
      final part = _Part();
      await tester.pumpWidget(part.build());
      final finger = await _blockedPast(tester);
      for (var i = 0; i < FingerTimedLongPress.liftFrames; i++) {
        expect(part.taps, isEmpty, reason: 'frame $i waits for a lift');
        await tester.pump(_frame);
      }
      expect(part.taps, ['hold']);
      await tester.sendEventToBinding(
        finger.up(timeStamp: const Duration(seconds: 11)),
      );
      await tester.pump();
      expect(part.taps, ['hold'], reason: 'once');
    });

    testWidgets('on a page blocked across the hold a lift stamped past it is '
        'a hold at once, no frame waited', (tester) async {
      final part = _Part();
      await tester.pumpWidget(part.build());
      final finger = await _blockedPast(tester);
      await tester.sendEventToBinding(
        finger.up(timeStamp: const Duration(seconds: 10, milliseconds: 350)),
      );

      expect(part.taps, ['hold']);
    });

    testWidgets('a lift with no times after the timer has run stays a hold, '
        'as before', (tester) async {
      final part = _Part();
      await tester.pumpWidget(part.build());
      final finger = TestPointer(5);
      final at = tester.getCenter(find.byType(RawGestureDetector));
      await tester.sendEventToBinding(finger.down(at));
      await tester.binding.delayed(_hold);
      await tester.sendEventToBinding(finger.up());
      await tester.pump();

      expect(part.taps, ['hold']);
    });

    test('times out of order or missing say nothing', () {
      expect(
        fingerTime(const Duration(seconds: 2), const Duration(seconds: 1)),
        Duration.zero,
      );
      expect(fingerTime(Duration.zero, Duration.zero), Duration.zero);
    });
  });
}
