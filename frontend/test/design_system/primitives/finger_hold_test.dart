import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/finger_hold.dart';

/// A part that takes a tap and a hold, as a role card does.
class _Part {
  final taps = <String>[];

  /// [drawing]: an animation runs beside it, so the page draws every frame.
  Widget build({bool drawing = false}) => Directionality(
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
        child: SizedBox.square(
          dimension: 100,
          child: drawing ? const _Drawing() : null,
        ),
      ),
    ),
  );
}

/// Something moving on the page, as a pressed card's lift is.
class _Drawing extends StatefulWidget {
  const _Drawing();
  @override
  State<_Drawing> createState() => _DrawingState();
}

class _DrawingState extends State<_Drawing>
    with SingleTickerProviderStateMixin {
  late final _turn = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat();

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RotationTransition(turns: _turn, child: const SizedBox.expand());
}

const _hold = Duration(milliseconds: 300);

/// A frame of a phone that is not keeping up (Chrome slowed 8x draws a
/// pressed card in 130 to 200 ms).
const _longFrame = Duration(milliseconds: 150);

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

    testWidgets('on a page drawing long frames a lift kept back past the '
        'timer and its frame still makes a quick touch a tap', (tester) async {
      // Measured in Chrome slowed 8x: a lift is handed to the page up to
      // three frames after the finger left, after the timer and the frame
      // that would take the hold.
      final part = _Part();
      await tester.pumpWidget(part.build(drawing: true));
      final finger = TestPointer(5);
      final at = tester.getCenter(find.byType(RawGestureDetector));
      await tester.sendEventToBinding(
        finger.down(at, timeStamp: const Duration(seconds: 10)),
      );
      for (var i = 0; i < 2; i++) {
        await tester.pump(_longFrame);
      }
      expect(part.taps, isEmpty, reason: 'the timer has run, its frame too');
      await tester.sendEventToBinding(
        finger.up(timeStamp: const Duration(seconds: 10, milliseconds: 150)),
      );
      await tester.pump(_longFrame);

      expect(part.taps, ['tap']);
    });

    testWidgets('on a page drawing long frames a finger still down holds '
        'one frame later, never more', (tester) async {
      final part = _Part();
      await tester.pumpWidget(part.build(drawing: true));
      final finger = await tester.startGesture(
        tester.getCenter(find.byType(RawGestureDetector)),
      );
      for (var i = 0; i < 2; i++) {
        await tester.pump(_longFrame);
      }
      expect(part.taps, isEmpty);
      await tester.pump(_longFrame);
      expect(part.taps, ['hold']);
      await finger.up();
      await tester.pump();
      expect(part.taps, ['hold'], reason: 'once');
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
