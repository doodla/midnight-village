// Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/world_timer.dart';

import '../../helpers/pump_skinned.dart';
import '../../helpers/still_screen.dart';

/// Only a clock reads the seconds (the owner, 24 November 2026: "it felt
/// like I was watching a ppt"; a screen that took the seconds was built,
/// laid out and painted whole every second). A screen hands its clock a
/// `Countdown`; `ClockTick`, which turns it into seconds, is used by the
/// clock primitives and nothing else in `lib/`.
const clockPrimitives = {
  'lib/design_system/primitives/countdown.dart',
  'lib/design_system/primitives/world_timer.dart',
  'lib/design_system/primitives/square_sky.dart',
  'lib/design_system/primitives/timer_band.dart',
};

void main() {
  test('ClockTick is used by the clock primitives alone', () {
    final users = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final path = file.path.replaceAll(r'\', '/');
      if (clockPrimitives.contains(path)) continue;
      if (RegExp(r'\bClockTick\b').hasMatch(file.readAsStringSync())) {
        users.add(path);
      }
    }
    expect(
      users,
      isEmpty,
      reason:
          'a screen hands its clock a Countdown and never reads the seconds '
          'itself: a tick would redraw the screen',
    );
  });

  testWidgets('a held clock never ticks, and a counting one asks for one '
      'frame a second, redrawing the clock alone', (tester) async {
    var now = DateTime.utc(2026, 11, 25, 20);
    final deadline = now.add(const Duration(seconds: 75));
    Duration until(DateTime moment) => moment.difference(now);
    await pumpSkinned(
      tester,
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('The board'),
            WorldTimer.candleCompact(
              countdown: Countdown.to(
                deadline,
                until: until,
                startedAt: deadline.subtract(const Duration(seconds: 150)),
              ),
            ),
          ],
        ),
      ),
    );
    expect(find.text('1:15'), findsOneWidget);
    final room = tester.getRect(find.byType(WorldTimer));
    var frames = 0;
    for (var i = 0; i < 30; i++) {
      now = now.add(const Duration(milliseconds: 100));
      await tester.binding.delayed(const Duration(milliseconds: 100));
      if (tester.binding.hasScheduledFrame) frames++;
      await tester.pump();
    }
    expect(frames, 3, reason: 'one frame a second, for the number');
    expect(find.text('1:12'), findsOneWidget);
    expect(tester.getRect(find.byType(WorldTimer)), room);
    expect(await clockTickProblems(tester), isEmpty);
  });

  testWidgets('a held clock asks for no frame', (tester) async {
    await pumpSkinned(
      tester,
      const Center(child: WorldTimer.candle(countdown: Countdown.held(19))),
    );
    for (var i = 0; i < 20; i++) {
      await tester.binding.delayed(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, isFalse);
    }
  });
}
