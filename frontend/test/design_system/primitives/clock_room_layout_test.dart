import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/countdown.dart';
import 'package:midnight_village/design_system/primitives/band.dart';
import 'package:midnight_village/design_system/primitives/square_sky.dart';
import 'package:midnight_village/design_system/primitives/world_timer.dart';
import 'package:midnight_village/design_system/skin/dress.dart';

import '../../helpers/pump_skinned.dart';

/// The clock's room only stops a tick's layout from escaping: it must never
/// change what is drawn. For every clock primitive, at three text sizes, in
/// both dresses and in every form of the number, the size and place of every
/// part inside [ClockTick] are the same as the same widget laid out with no
/// room (a candle once shrank, and its number with it, when the room laid
/// its child out a second time at a tight size).
void main() {
  final primitives = <String, Widget Function(Countdown)>{
    'WorldTimer.candle (05)': (c) => WorldTimer.candle(countdown: c),
    'WorldTimer.candleCompact': (c) => WorldTimer.candleCompact(countdown: c),
    'WorldTimer quiet line': (c) => WorldTimer.candleCompact(
      countdown: c,
      lineHeight: WorldTimer.quietLine,
    ),
    'TimerBand.bar': (c) => TimerBand.bar(countdown: c, title: 'Vote'),
    'SquareSky': (c) => SquareSky(countdown: c, title: 'Talk'),
  };
  // "12:34", "1:11", "59 s", "16 s", "5 s".
  const forms = [754, 71, 59, 16, 5];
  const widths = [358.0, 320.0];

  /// Every part's size and place in the clock, from the clock's corner.
  Future<List<String>> parts(
    WidgetTester tester,
    Widget clock, {
    required double scale,
    required Dress dress,
    required double width,
    required bool noRoom,
  }) async {
    // Built from nothing each time: a widget kept from the last pump would
    // not be built again, and the room (or its absence) with it.
    await tester.pumpWidget(const SizedBox());
    ClockTick.debugNoRoom = noRoom;
    await pumpSkinned(
      tester,
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: DressScope(
          dress: dress,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: Align(alignment: Alignment.topLeft, child: clock),
            ),
          ),
        ),
      ),
    );
    final root = tester.renderObject<RenderBox>(find.byType(ClockTick));
    final origin = root.localToGlobal(Offset.zero);
    final found = <String>[];
    void visit(RenderObject o) {
      // The room and the scope are what is under test, not parts.
      final own =
          o is RenderClockRoom || '${o.runtimeType}' == '_RenderClockScope';
      if (o is RenderBox && o.hasSize && !own) {
        final at = o.localToGlobal(Offset.zero) - origin;
        found.add(
          '${o.runtimeType} ${at.dx.toStringAsFixed(2)},'
          '${at.dy.toStringAsFixed(2)} '
          '${o.size.width.toStringAsFixed(2)}x${o.size.height.toStringAsFixed(2)}',
        );
      }
      o.visitChildren(visit);
    }

    visit(root);
    return found;
  }

  tearDown(() => ClockTick.debugNoRoom = false);

  for (final MapEntry(key: name, value: make) in primitives.entries) {
    testWidgets('$name: inside its room every part is where and as large '
        'as with no room', (tester) async {
      for (final scale in const [1.0, 1.3, 2.0]) {
        for (final dress in Dress.values) {
          for (final width in widths) {
            for (final seconds in forms) {
              final clock = make(Countdown.held(seconds, share: 0.6));
              final without = await parts(
                tester,
                clock,
                scale: scale,
                dress: dress,
                width: width,
                noRoom: true,
              );
              final within = await parts(
                tester,
                clock,
                scale: scale,
                dress: dress,
                width: width,
                noRoom: false,
              );
              expect(
                within,
                without,
                reason:
                    '$name at text $scale, ${dress.name}, ${width}px wide, '
                    '$seconds s',
              );
            }
          }
        }
      }
    });
  }
}
