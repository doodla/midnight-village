import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/feel/ambient.dart';
import 'package:midnight_village/design_system/layout/space.dart';

// `Ambient` (feel/ambient.dart): a loop asks for frames only while the app is
// in front, its TickerMode is on and motion is allowed; with reduce motion it
// rests at its still value; it paints and never rebuilds.

const _still = 0.25;
const _frame = Duration(milliseconds: 16);

class _Probe {
  late Animation<double> loop;
  var builds = 0;
  var childBuilds = 0;
}

class _Painter extends CustomPainter {
  _Painter(this.loop) : super(repaint: loop);

  final Animation<double> loop;
  var paints = 0;

  @override
  void paint(Canvas canvas, Size size) => paints++;

  @override
  bool shouldRepaint(_Painter old) => old.loop != loop;
}

/// The loop under the switches a screen can flip: [ticking] (TickerMode),
/// [reduce] (reduce motion) and [running] (its owner's say). [child] is built
/// once by the caller and passed through.
Widget _loop(
  _Probe probe,
  Widget child, {
  bool ticking = true,
  bool reduce = false,
  bool running = true,
}) => MediaQuery(
  data: MediaQueryData(disableAnimations: reduce),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: TickerMode(
      enabled: ticking,
      child: Ambient(
        still: _still,
        running: running,
        builder: (context, loop, child) {
          probe
            ..loop = loop
            ..builds += 1;
          return CustomPaint(painter: _Painter(loop), child: child);
        },
        child: child,
      ),
    ),
  ),
);

Widget _child(_Probe probe) => Builder(
  builder: (context) {
    probe.childBuilds += 1;
    return const SizedBox(width: 40, height: 40);
  },
);

bool _ticking(WidgetTester tester) => tester.binding.transientCallbackCount > 0;

/// Whether the loop moves over a few frames.
Future<bool> _moves(WidgetTester tester, _Probe probe) async {
  final from = probe.loop.value;
  for (var i = 0; i < 4; i++) {
    await tester.pump(_frame);
  }
  return probe.loop.value != from;
}

void main() {
  tearDown(() {
    // Leave the app in front for the next test.
    TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });

  testWidgets('it loops, painting only: nothing below is rebuilt per tick', (
    tester,
  ) async {
    final probe = _Probe();
    await tester.pumpWidget(_loop(probe, _child(probe)));
    expect(_ticking(tester), isTrue);
    expect(await _moves(tester, probe), isTrue);
    final painter =
        tester.widget<CustomPaint>(find.byType(CustomPaint)).painter!
            as _Painter;
    final paintsBefore = painter.paints;
    for (var t = Duration.zero; t < Motion.ambient * 2; t += _frame) {
      await tester.pump(_frame);
    }
    expect(painter.paints, greaterThan(paintsBefore + 10));
    expect((probe.builds, probe.childBuilds), (1, 1));
    expect(
      find.descendant(
        of: find.byType(Ambient),
        matching: find.byType(RepaintBoundary),
      ),
      findsWidgets,
    );
  });

  for (final away in [AppLifecycleState.hidden, AppLifecycleState.paused]) {
    testWidgets('it stops while the app is ${away.name}, and goes on after', (
      tester,
    ) async {
      final probe = _Probe();
      await tester.pumpWidget(_loop(probe, _child(probe)));
      await tester.pump(_frame);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(away);
      expect(_ticking(tester), isFalse);
      final held = probe.loop.value;
      await tester.pump(Motion.ambient);
      expect(probe.loop.value, held, reason: 'it holds where it was');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(_ticking(tester), isTrue);
      expect(await _moves(tester, probe), isTrue);
      expect((probe.builds, probe.childBuilds), (1, 1));
    });
  }

  testWidgets('inactive is still on screen: it keeps going', (tester) async {
    final probe = _Probe();
    await tester.pumpWidget(_loop(probe, _child(probe)));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(await _moves(tester, probe), isTrue);
  });

  testWidgets('TickerMode off stops it (a covered or leaving screen)', (
    tester,
  ) async {
    final probe = _Probe();
    final child = _child(probe);
    await tester.pumpWidget(_loop(probe, child));
    await tester.pump(_frame);
    await tester.pumpWidget(_loop(probe, child, ticking: false));
    expect(_ticking(tester), isFalse);
    final held = probe.loop.value;
    await tester.pump(Motion.ambient ~/ 2);
    expect(probe.loop.value, held);

    await tester.pumpWidget(_loop(probe, child));
    expect(_ticking(tester), isTrue);
    await tester.pump(_frame);
    expect(
      (probe.loop.value - held).abs(),
      lessThan(0.05),
      reason: 'it goes on from where it held, with no jump',
    );
    expect(await _moves(tester, probe), isTrue);
    expect(probe.childBuilds, 1);
  });

  testWidgets('its owner can stop it, and start it again', (tester) async {
    final probe = _Probe();
    final child = _child(probe);
    await tester.pumpWidget(_loop(probe, child, running: false));
    expect(_ticking(tester), isFalse);
    await tester.pumpWidget(_loop(probe, child));
    expect(await _moves(tester, probe), isTrue);
  });

  testWidgets('reduce motion: it rests at its still value, asking no frames', (
    tester,
  ) async {
    final probe = _Probe();
    final child = _child(probe);
    await tester.pumpWidget(_loop(probe, child, reduce: true));
    expect(_ticking(tester), isFalse);
    expect(probe.loop.value, _still);
    await tester.pump(Motion.ambient);
    expect(probe.loop.value, _still);

    await tester.pumpWidget(_loop(probe, child));
    expect(_ticking(tester), isTrue);
    expect(await _moves(tester, probe), isTrue);
    expect(probe.childBuilds, 1);
  });

  testWidgets('no ticker and no lifecycle listener is left after it goes', (
    tester,
  ) async {
    final probe = _Probe();
    await tester.pumpWidget(_loop(probe, _child(probe)));
    await tester.pump(_frame);
    await tester.pumpWidget(const SizedBox());
    expect(_ticking(tester), isFalse);
    // A state that still listened would start a disposed clock here.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(tester.takeException(), isNull);
    expect(_ticking(tester), isFalse);
  });

  testWidgets('many loops share the one foreground', (tester) async {
    final probes = [_Probe(), _Probe(), _Probe()];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            for (final probe in probes)
              Ambient(
                still: _still,
                builder: (context, loop, child) {
                  probe.loop = loop;
                  return const SizedBox(width: 10, height: 10);
                },
              ),
          ],
        ),
      ),
    );
    await tester.pump(_frame);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    expect(_ticking(tester), isFalse);
    expect(AppForeground.instance.value, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(AppForeground.instance.value, isTrue);
    await tester.pump(_frame);
    for (final probe in probes) {
      expect(await _moves(tester, probe), isTrue);
    }
  });
}
