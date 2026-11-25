import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/feel/ambient.dart';
import 'package:midnight_village/design_system/layout/space.dart';

// `Ambient`'s bursts and rests (feel/ambient.dart): one burst, then a true
// rest (no ticker, no frame asked for) for a gap seeded by its id; a taught
// one rests for good until asked again; a finger down anywhere holds every
// loop; `Ambient.continuous` never rests. All on the test's fake clock.

const _frame = Duration(milliseconds: 16);
const _period = Duration(milliseconds: 500);

class _Seen {
  late Animation<double> loop;
}

Widget _ambient(
  _Seen seen, {
  String id = 'probe',
  int cycles = 1,
  AmbientCue? cue,
  bool continuous = false,
  bool ticking = true,
  bool reduce = false,
}) {
  Widget build(BuildContext context, Animation<double> loop, Widget? _) {
    seen.loop = loop;
    return const SizedBox(width: 40, height: 40);
  }

  return MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: TickerMode(
        enabled: ticking,
        child: Center(
          child: continuous
              ? Ambient.continuous(still: 0, period: _period, builder: build)
              : Ambient(
                  id: id,
                  still: 0,
                  period: _period,
                  cycles: cycles,
                  cue: cue,
                  builder: build,
                ),
        ),
      ),
    ),
  );
}

bool _ticking(WidgetTester tester) => tester.binding.transientCallbackCount > 0;

/// Pumps frame by frame for [length].
Future<void> _run(WidgetTester tester, Duration length) async {
  for (var t = Duration.zero; t < length; t += _frame) {
    await tester.pump(_frame);
  }
}

/// A burst of [cycles] breaths (there and back), and a frame to spare.
Duration _burst(int cycles) => _period * 2 * cycles + _frame * 4;

/// The rest: nothing ticks and no frame is asked for, the loop at its still
/// value, for all of [length].
Future<void> _rests(WidgetTester tester, _Seen seen, Duration length) async {
  final step = length ~/ 8;
  for (var i = 0; i < 8; i++) {
    expect(_ticking(tester), isFalse, reason: 'no ticker while it rests');
    expect(
      tester.binding.hasScheduledFrame,
      isFalse,
      reason: 'no frame is asked for while it rests',
    );
    expect(seen.loop.value, 0);
    await tester.pump(step);
  }
}

void main() {
  tearDown(() {
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });

  test('its rests are seeded by its id: the same on every phone, in range', () {
    for (final id in ['hold-cue', 'lantern-mark', 'probe']) {
      for (var k = 0; k < 20; k++) {
        final rest = Ambient.restFor(id, k);
        expect(rest, Ambient.restFor(id, k));
        expect(rest, greaterThanOrEqualTo(Motion.restLeast));
        expect(rest, lessThanOrEqualTo(Motion.restMost));
      }
    }
    final gaps = {for (var k = 0; k < 6; k++) Ambient.restFor('probe', k)};
    expect(gaps.length, greaterThan(1), reason: 'not one gap over and over');
  });

  testWidgets('one burst, then a true rest, then the next burst', (
    tester,
  ) async {
    final seen = _Seen();
    await tester.pumpWidget(_ambient(seen));
    expect(_ticking(tester), isTrue);
    await _run(tester, _period);
    expect(seen.loop.value, greaterThan(0.9), reason: 'it breathes out');
    await _run(tester, _period + _frame * 4);
    expect(seen.loop.value, 0, reason: 'and back to its still value');

    final rest = Ambient.restFor('probe', 0);
    await _rests(tester, seen, rest - _frame * 8);
    await tester.pump(_frame * 8);
    expect(_ticking(tester), isTrue, reason: 'the timer wakes the next burst');
    await _run(tester, _burst(1));
    await _rests(tester, seen, Ambient.restFor('probe', 1) - _frame * 8);
  });

  testWidgets('a taught one breathes its cycles, rests for good, and once '
      'more when asked', (tester) async {
    final seen = _Seen();
    final cue = AmbientCue();
    addTearDown(cue.dispose);
    await tester.pumpWidget(_ambient(seen, cycles: 3, cue: cue));
    await _run(tester, _period * 5);
    expect(_ticking(tester), isTrue, reason: 'still in its third breath');
    await _run(tester, _period + _frame * 4);
    await _rests(tester, seen, Motion.restMost * 3);

    cue.again();
    expect(_ticking(tester), isTrue);
    await _run(tester, _burst(1));
    await _rests(tester, seen, Motion.restMost * 2);
  });

  testWidgets('a finger down anywhere holds it, with no frame of its own; it '
      'goes on after the lift', (tester) async {
    final seen = _Seen();
    await tester.pumpWidget(_ambient(seen));
    await _run(tester, _period ~/ 2);
    final finger = await tester.startGesture(const Offset(5, 5));
    expect(_ticking(tester), isFalse);
    final held = seen.loop.value;
    await tester.pump(_period);
    expect(seen.loop.value, held, reason: 'it holds where it was');
    expect(tester.binding.hasScheduledFrame, isFalse);

    await finger.up();
    expect(_ticking(tester), isTrue);
    await tester.pump(_frame);
    expect((seen.loop.value - held).abs(), lessThan(0.1), reason: 'no jump');
    await _run(tester, _burst(1));
    expect(_ticking(tester), isFalse, reason: 'the burst ended, it rests');
  });

  testWidgets('a rest that ends under a finger waits for the lift', (
    tester,
  ) async {
    final seen = _Seen();
    await tester.pumpWidget(_ambient(seen));
    await _run(tester, _burst(1));
    final finger = await tester.startGesture(const Offset(5, 5));
    await tester.pump(Ambient.restFor('probe', 0) + _frame);
    expect(_ticking(tester), isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await finger.up();
    expect(_ticking(tester), isTrue);
  });

  testWidgets('hidden during a rest, its timer stops; back, a rest starts '
      'whole', (tester) async {
    final seen = _Seen();
    await tester.pumpWidget(_ambient(seen));
    await _run(tester, _burst(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await _rests(tester, seen, Motion.restMost * 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    // The binding draws one frame as the app comes back; that one is its own.
    await tester.pump();
    await _rests(tester, seen, Motion.restLeast - _frame * 8);
    await tester.pump(Motion.restMost);
    expect(_ticking(tester), isTrue);
  });

  testWidgets('TickerMode off during a rest stops its timer too', (
    tester,
  ) async {
    final seen = _Seen();
    await tester.pumpWidget(_ambient(seen));
    await _run(tester, _burst(1));
    await tester.pumpWidget(_ambient(seen, ticking: false));
    await _rests(tester, seen, Motion.restMost * 2);
  });

  testWidgets('reduce motion: no burst and no timer, ever', (tester) async {
    final seen = _Seen();
    await tester.pumpWidget(_ambient(seen, reduce: true));
    await _rests(tester, seen, Motion.restMost * 3);
  });

  testWidgets('gone during a rest, nothing of it is left to wake', (
    tester,
  ) async {
    final seen = _Seen();
    await tester.pumpWidget(_ambient(seen));
    await _run(tester, _burst(1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Motion.restMost * 2);
    expect(_ticking(tester), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('continuous never rests, but still holds under a finger', (
    tester,
  ) async {
    final seen = _Seen();
    await tester.pumpWidget(_ambient(seen, continuous: true));
    await _run(tester, _burst(3));
    expect(_ticking(tester), isTrue);
    final finger = await tester.startGesture(const Offset(5, 5));
    expect(_ticking(tester), isFalse);
    await finger.up();
    expect(_ticking(tester), isTrue);
  });
}
