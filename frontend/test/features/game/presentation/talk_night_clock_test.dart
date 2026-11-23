// "My night" held on 08 while the clock runs: the countdown rebuilds the
// screen every second, and the picture story under the held note does no
// layout work for it (it is not measured, laid out or built again), nor for a
// fresh `/me/` that tells the same night. A new text size or phone does lay it
// out again.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/night/story_plan.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_square.dart';

import '../../../helpers/component_sheet.dart' show learnedOverrides;
import '../../../helpers/pump_skinned.dart';
import '../../../helpers/sheet/story_samples.dart';

/// A talk with its night shown, its clock and its `/me/` set from outside.
class _Clock extends StatelessWidget {
  const _Clock(this.seconds, this.night);

  final ValueNotifier<int> seconds;
  final ValueNotifier<String> night;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: learnedOverrides({...Cue.values}),
    child: ValueListenableBuilder(
      valueListenable: night,
      builder: (context, night, _) => ValueListenableBuilder(
        valueListenable: seconds,
        builder: (context, left, _) => TalkView(
          // A new object each time, as every `/me/` read is.
          me: GameMe.fromJson(allNights[night]!()),
          secondsLeft: left,
          onReady: () {},
          openNight: true,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a clock tick while the night is held does no story layout', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final seconds = ValueNotifier(90);
    final night = ValueNotifier('doppelganger-troublemaker');
    await pumpSkinned(tester, _Clock(seconds, night));
    await tester.pump();

    final laidOut = StoryPlan.layouts;
    final panel = tester.widget(find.byType(MyNightPanel));
    expect(laidOut, greaterThan(0), reason: 'the first sight lays it out');

    for (var left = 89; left > 80; left--) {
      seconds.value = left;
      await tester.pump();
    }
    expect(
      tester.widget(find.byType(MyNightPanel)),
      same(panel),
      reason: 'the panel is not built again for a tick',
    );
    expect(StoryPlan.layouts, laidOut, reason: 'a tick laid the story out');

    // The same night read again (a new `/me/` every few seconds): still none.
    night.value = 'doppelganger-troublemaker';
    await tester.pump();
    expect(StoryPlan.layouts, laidOut, reason: 'the same night laid out again');

    // Another night is another picture.
    night.value = 'troublemaker';
    await tester.pump();
    expect(StoryPlan.layouts, laidOut + 1);

    // Larger text is another layout, once.
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pump();
    final scaled = StoryPlan.layouts;
    expect(scaled, laidOut + 2);
    seconds.value = 5;
    await tester.pump();
    expect(StoryPlan.layouts, scaled);
  });
}
