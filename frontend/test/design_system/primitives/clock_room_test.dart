import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/countdown.dart';

import '../../helpers/pump_skinned.dart';

/// A clock's room is held at its size so a tick lays out the clock alone;
/// it must still be measured again whenever the clock's content can have
/// changed size: the screen builds it again, the text grows, the form changes.
void main() {
  testWidgets('a clock\'s room is measured again when its screen builds it '
      'again, when the text grows and when its form changes', (tester) async {
    var now = DateTime.utc(2026, 11, 25, 20);
    final deadline = now.add(const Duration(seconds: 12));
    Duration until(DateTime moment) => moment.difference(now);
    final clock = Countdown.to(deadline, until: until);
    Widget screen({required double scale, required double extra}) => MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Align(
        alignment: Alignment.topLeft,
        child: ClockTick(
          countdown: clock,
          builder: (context, reading) => LayoutBuilder(
            builder: (context, room) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${reading.seconds}',
                  textScaler: MediaQuery.textScalerOf(context),
                ),
                SizedBox(height: extra, width: 10),
              ],
            ),
          ),
        ),
      ),
    );
    Size room() => tester.getSize(find.byType(ClockTick));
    await pumpSkinned(tester, screen(scale: 1, extra: 10));
    final first = room();
    // The screen builds it again with more under the number.
    await pumpSkinned(tester, screen(scale: 1, extra: 40));
    expect(room().height, first.height + 30);
    // The text grows.
    await pumpSkinned(tester, screen(scale: 2, extra: 40));
    expect(room().height, greaterThan(first.height + 30));
    // It changes form, "12" to "9", as its timer would.
    final before = room();
    now = now.add(const Duration(seconds: 3));
    ClockTick.debugTickAll();
    await tester.pump();
    await tester.pump();
    expect(find.text('9'), findsOneWidget);
    expect(room().height, before.height);
    expect(room().width, lessThan(before.width));
    expect(tester.takeException(), isNull);
  });
}
