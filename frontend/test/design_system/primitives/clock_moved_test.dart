import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/countdown.dart';

import '../../helpers/pump_skinned.dart';

/// When the server's clock is read again and moves, the clocks on screen
/// read again at once, not at their own next tick: a number off by a second
/// until then, or a clock at "0 s" (which has no timer) that has time left.
void main() {
  testWidgets('a clock reads again at once when the server clock moves, '
      'also from 0 s, and when the deadline moves', (tester) async {
    var left = const Duration(seconds: 12);
    final moved = ValueNotifier<int>(0);
    final deadline = DateTime.utc(2026, 11, 25, 20);
    Countdown clock(DateTime at) => Countdown.to(
      at,
      until: (moment) => left + moment.difference(deadline),
      moved: moved,
    );
    Widget face(Countdown c) => ClockTick(
      countdown: c,
      builder: (context, reading) => Text('${reading.seconds}'),
    );
    await pumpSkinned(tester, face(clock(deadline)));
    expect(find.text('12'), findsOneWidget);

    // A poll says there are 7 s left, not 12.
    left = const Duration(seconds: 7);
    moved.value++;
    await tester.pump();
    expect(find.text('7'), findsOneWidget);

    // At 0 s no timer is set; the new reading has 0.7 s left.
    left = Duration.zero;
    moved.value++;
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
    left = const Duration(milliseconds: 700);
    moved.value++;
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    // The deadline moves: a clock at 0 s counts again.
    left = Duration.zero;
    moved.value++;
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
    await pumpSkinned(
      tester,
      face(clock(deadline.add(const Duration(seconds: 30)))),
    );
    expect(find.text('30'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
