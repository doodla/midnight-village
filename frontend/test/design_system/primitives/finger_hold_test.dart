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

    test('times out of order or missing say nothing', () {
      expect(
        fingerTime(const Duration(seconds: 2), const Duration(seconds: 1)),
        Duration.zero,
      );
      expect(fingerTime(Duration.zero, Duration.zero), Duration.zero);
    });
  });
}
