import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/countdown.dart';

import '../../helpers/pump_skinned.dart';

/// When the server's clock is read again and moves, the clocks on screen
/// read again at once, not at their own next tick. A clock never counts back
/// up for the same deadline (owner, 28 November 2026: "Keeps jumping
/// around"): only a new deadline shows more.
void main() {
  testWidgets('a clock reads again at once when the server clock moves, '
      'never counts up, and counts again when the deadline moves', (
    tester,
  ) async {
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

    // A reading that says more time is left than shown: not shown.
    left = const Duration(seconds: 9);
    moved.value++;
    await tester.pump();
    expect(find.text('7'), findsOneWidget);
    left = const Duration(milliseconds: 6500);
    moved.value++;
    await tester.pump();
    expect(find.text('7'), findsOneWidget);
    left = const Duration(milliseconds: 5900);
    moved.value++;
    await tester.pump();
    expect(find.text('6'), findsOneWidget);

    // At 0 s no timer is set, and it stays at 0.
    left = Duration.zero;
    moved.value++;
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
    left = const Duration(milliseconds: 700);
    moved.value++;
    await tester.pump();
    expect(find.text('0'), findsOneWidget);

    // The deadline moves: a clock at 0 s counts again.
    left = Duration.zero;
    await pumpSkinned(
      tester,
      face(clock(deadline.add(const Duration(seconds: 30)))),
    );
    expect(find.text('30'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
