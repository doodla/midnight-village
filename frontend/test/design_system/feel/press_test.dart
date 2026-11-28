import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/feel/press.dart';
import 'package:midnight_village/design_system/layout/space.dart';

// `Pressable` (feel/press.dart, feel.md principle 1): down in the frame the
// finger lands, up on the lift, a cancel or a slide past the slop; it never takes or
// delays the tap of the detector inside; it rebuilds nothing below it.

const _sink = Offset(0, 2);
const _shrink = 0.02;
const _box = Size(120, 48);
const _frame = Duration(milliseconds: 16);

class _Probe {
  late Animation<double> press;
  var builds = 0;
  var childBuilds = 0;

  double get value => press.value;
}

/// A pressable part on its own: [inner] is what sits inside it (a detector,
/// or a plain box), built once and passed through.
Widget _part(
  _Probe probe, {
  Widget? inner,
  bool reduce = false,
  bool enabled = true,
  bool holds = false,
}) {
  final child = Builder(
    builder: (context) {
      probe.childBuilds++;
      return inner ?? const ColoredBox(color: Color(0xFF808080));
    },
  );
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Center(
        child: SizedBox.fromSize(
          size: _box,
          child: Pressable(
            enabled: enabled,
            holds: holds,
            builder: (context, press, child) {
              probe
                ..press = press
                ..builds += 1;
              return PressSink(
                press: press,
                by: _sink,
                shrink: _shrink,
                child: child,
              );
            },
            child: child,
          ),
        ),
      ),
    ),
  );
}

Future<void> _frames(WidgetTester tester, Duration length) async {
  for (var t = Duration.zero; t < length; t += _frame) {
    await tester.pump(_frame);
  }
}

/// Whether [PressSink] paints its child moved (a transform on the canvas).
bool _paintsMoved(WidgetTester tester) {
  final sink = tester.renderObject<RenderPressSink>(find.byType(PressSink));
  final context = TestRecordingPaintingContext(TestRecordingCanvas());
  sink.paint(context, Offset.zero);
  return (context.canvas as TestRecordingCanvas).invocations.any(
    (call) => call.invocation.memberName == #transform,
  );
}

void main() {
  testWidgets('down shows in the pointer-down handler and the first frame', (
    tester,
  ) async {
    final probe = _Probe();
    await tester.pumpWidget(_part(probe));
    expect(probe.value, 0);
    final finger = await tester.startGesture(
      tester.getCenter(find.byType(Pressable)),
    );
    // Set in the handler itself, before any frame is drawn.
    expect(probe.value, greaterThan(0));
    await tester.pump();
    expect(probe.value, greaterThan(0));
    expect(_paintsMoved(tester), isTrue);
    await _frames(tester, Motion.press);
    expect(probe.value, 1);
    await finger.up();
  });

  testWidgets('a lift releases with a small settle, then rests', (
    tester,
  ) async {
    final probe = _Probe();
    await tester.pumpWidget(_part(probe));
    final finger = await tester.startGesture(
      tester.getCenter(find.byType(Pressable)),
    );
    await _frames(tester, Motion.press);
    await finger.up();
    var lowest = 1.0;
    for (var t = Duration.zero; t <= Motion.quick; t += _frame) {
      await tester.pump(_frame);
      if (probe.value < lowest) lowest = probe.value;
    }
    await tester.pumpAndSettle();
    expect(lowest, lessThan(0), reason: 'the paper springs just past rest');
    expect(lowest, greaterThan(-0.1), reason: 'under a tenth');
    expect(probe.value, 0);
    expect(_paintsMoved(tester), isFalse);
  });

  testWidgets('a cancel releases', (tester) async {
    final probe = _Probe();
    await tester.pumpWidget(_part(probe));
    final finger = await tester.startGesture(
      tester.getCenter(find.byType(Pressable)),
    );
    await _frames(tester, Motion.press);
    await finger.cancel();
    await tester.pumpAndSettle();
    expect(probe.value, 0);
  });

  testWidgets('sliding past the slop releases while the finger is still '
      'down', (tester) async {
    final probe = _Probe();
    await tester.pumpWidget(_part(probe));
    final rect = tester.getRect(find.byType(Pressable));
    final finger = await tester.startGesture(rect.center);
    await _frames(tester, Motion.press);
    // A wobble inside the tap's slop keeps it down.
    await finger.moveBy(const Offset(4, 2));
    await tester.pump(_frame);
    expect(probe.value, 1);
    await finger.moveTo(rect.bottomCenter + const Offset(0, 30));
    await tester.pumpAndSettle();
    expect(probe.value, 0);
    await finger.up();
  });

  testWidgets('just past the edge but within the slop it stays down (the tap '
      'inside still fires); past the slop it comes up', (tester) async {
    final probe = _Probe();
    var taps = 0;
    await tester.pumpWidget(
      _part(
        probe,
        inner: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
        ),
      ),
    );
    final rect = tester.getRect(find.byType(Pressable));
    final landing = rect.bottomCenter - const Offset(0, 4);
    final slop = computeHitSlop(PointerDeviceKind.touch, null);
    // Out of the box by a few pixels, still inside the slop.
    final out = await tester.startGesture(landing);
    await _frames(tester, Motion.press);
    await out.moveTo(landing + Offset(0, slop / 2));
    await _frames(tester, Motion.quick);
    expect(rect.contains(landing + Offset(0, slop / 2)), isFalse);
    expect(probe.value, 1, reason: 'outside the box, within the slop');
    await out.up();
    await tester.pumpAndSettle();
    expect(taps, 1, reason: 'the tap inside fired there too');

    final past = await tester.startGesture(landing);
    await _frames(tester, Motion.press);
    await past.moveTo(landing + Offset(0, slop * 1.5));
    await tester.pumpAndSettle();
    expect(probe.value, 0, reason: 'past the slop');
    await past.up();
    await tester.pumpAndSettle();
    expect(taps, 1, reason: 'the tap inside was cancelled with it');
  });

  testWidgets('a hold stays down wherever the finger wanders', (tester) async {
    final probe = _Probe();
    await tester.pumpWidget(_part(probe, holds: true));
    final rect = tester.getRect(find.byType(Pressable));
    final finger = await tester.startGesture(rect.center);
    await _frames(tester, Motion.press);
    await finger.moveTo(rect.bottomCenter + const Offset(0, 30));
    await tester.pumpAndSettle();
    expect(probe.value, 1);
    await finger.up();
    await tester.pumpAndSettle();
    expect(probe.value, 0);
  });

  testWidgets('reduce motion: a cut down and up, and nothing moves', (
    tester,
  ) async {
    final probe = _Probe();
    await tester.pumpWidget(_part(probe, reduce: true));
    final finger = await tester.startGesture(
      tester.getCenter(find.byType(Pressable)),
    );
    expect(probe.value, 1);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(_paintsMoved(tester), isFalse);
    await finger.up();
    expect(probe.value, 0);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a press rebuilds nothing: not the builder, not the child', (
    tester,
  ) async {
    final probe = _Probe();
    await tester.pumpWidget(_part(probe));
    expect((probe.builds, probe.childBuilds), (1, 1));
    final finger = await tester.startGesture(
      tester.getCenter(find.byType(Pressable)),
    );
    await _frames(tester, Motion.press);
    await finger.up();
    await _frames(tester, Motion.quick);
    await tester.pumpAndSettle();
    expect((probe.builds, probe.childBuilds), (1, 1));
  });

  testWidgets('a part with nothing to tap (locked) still answers', (
    tester,
  ) async {
    final probe = _Probe();
    await tester.pumpWidget(_part(probe));
    final finger = await tester.startGesture(
      tester.getCenter(find.byType(Pressable)),
    );
    await tester.pump();
    expect(probe.value, greaterThan(0));
    await finger.up();
  });

  testWidgets('turned off it does not press, and turning off releases', (
    tester,
  ) async {
    final probe = _Probe();
    await tester.pumpWidget(_part(probe, enabled: false));
    final at = tester.getCenter(find.byType(Pressable));
    var finger = await tester.startGesture(at);
    await tester.pump();
    expect(probe.value, 0);
    await finger.up();

    await tester.pumpWidget(_part(probe));
    finger = await tester.startGesture(at);
    await _frames(tester, Motion.press);
    await tester.pumpWidget(_part(probe, enabled: false));
    await tester.pumpAndSettle();
    expect(probe.value, 0);
    await finger.up();
  });

  testWidgets('a second finger does not take over the press', (tester) async {
    final probe = _Probe();
    await tester.pumpWidget(_part(probe));
    final at = tester.getCenter(find.byType(Pressable));
    final first = await tester.startGesture(at);
    await _frames(tester, Motion.press);
    final second = await tester.startGesture(at, pointer: 9);
    await second.up();
    await tester.pumpAndSettle();
    expect(probe.value, 1, reason: 'the first finger is still down');
    await first.up();
    await tester.pumpAndSettle();
    expect(probe.value, 0);
  });

  testWidgets('a part inside a pressable part takes the press alone, as it '
      'takes the tap; off, it leaves it to the part round it', (tester) async {
    final outer = _Probe();
    final inner = _Probe();
    Widget nested({required bool innerOn}) => _part(
      outer,
      inner: ColoredBox(
        color: const Color(0xFF808080),
        child: Center(
          child: SizedBox.square(
            dimension: 24,
            child: Pressable(
              enabled: innerOn,
              builder: (context, press, child) {
                inner.press = press;
                return PressSink(press: press, by: _sink, child: child);
              },
              child: const ColoredBox(color: Color(0xFF202020)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(nested(innerOn: true));
    final middle = tester.getCenter(find.byType(Pressable).last);
    var finger = await tester.startGesture(middle);
    await tester.pump();
    expect(inner.value, greaterThan(0));
    expect(outer.value, 0, reason: 'the inner part is pressed, not both');
    await finger.up();
    await tester.pumpAndSettle();

    // Beside the inner part the outer one presses.
    finger = await tester.startGesture(
      tester.getTopLeft(find.byType(Pressable).first) + const Offset(4, 4),
    );
    await tester.pump();
    expect(outer.value, greaterThan(0));
    await finger.up();
    await tester.pumpAndSettle();

    // A second finger on the inner part while it is down: it is still the
    // inner part's, so the part round it stays up.
    finger = await tester.startGesture(middle);
    await tester.pump();
    final second = await tester.startGesture(middle, pointer: 9);
    await tester.pump();
    expect(
      outer.value,
      0,
      reason:
          'a second finger on a pressed part does not press the one round it',
    );
    await second.up();
    await finger.up();
    await tester.pumpAndSettle();

    await tester.pumpWidget(nested(innerOn: false));
    finger = await tester.startGesture(middle);
    await tester.pump();
    expect(outer.value, greaterThan(0), reason: 'an inner part turned off');
    await finger.up();
    await tester.pumpAndSettle();
  });

  group('the tap inside fires exactly as it does without the press', () {
    // Returns, for a tap, whether onTap had fired the moment the lift was
    // dispatched (no frame after it), and for a long press, the frames of
    // holding after which it fired.
    Future<(bool, int)> timings(
      WidgetTester tester, {
      required bool wrap,
    }) async {
      var taps = 0;
      var longs = 0;
      final detector = GestureDetector(
        onTap: () => taps++,
        onLongPress: () => longs++,
        child: const ColoredBox(color: Color(0xFF808080)),
      );
      final probe = _Probe();
      await tester.pumpWidget(
        wrap
            ? _part(probe, inner: detector)
            : MaterialApp(
                home: Center(
                  child: SizedBox.fromSize(size: _box, child: detector),
                ),
              ),
      );
      final at = tester.getCenter(find.byType(GestureDetector));
      var finger = await tester.startGesture(at);
      await tester.pump(_frame);
      await finger.up();
      final tappedOnLift = taps == 1;
      await tester.pumpAndSettle(kDoubleTapTimeout);

      finger = await tester.startGesture(at);
      var frames = 0;
      while (longs == 0 && frames < 100) {
        await tester.pump(_frame);
        frames++;
      }
      await finger.up();
      await tester.pumpAndSettle();
      expect(taps, 1, reason: 'the long press is not also a tap');
      return (tappedOnLift, frames);
    }

    testWidgets('GestureDetector: onTap on the lift, long press on time', (
      tester,
    ) async {
      final bare = await timings(tester, wrap: false);
      final pressed = await timings(tester, wrap: true);
      expect(bare.$1, isTrue);
      expect(pressed, bare);
      expect(
        pressed.$2 * _frame.inMilliseconds,
        lessThan(kLongPressTimeout.inMilliseconds + _frame.inMilliseconds),
      );
    });

    testWidgets('InkWell: onTap on the lift', (tester) async {
      var taps = 0;
      final probe = _Probe();
      await tester.pumpWidget(
        _part(
          probe,
          inner: Material(child: InkWell(onTap: () => taps++)),
        ),
      );
      final finger = await tester.startGesture(
        tester.getCenter(find.byType(InkWell)),
      );
      expect(probe.value, greaterThan(0));
      await tester.pump(_frame);
      await finger.up();
      expect(taps, 1);
      await tester.pumpAndSettle();
    });
  });
}
