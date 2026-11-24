import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/world_timer.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/presentation/shell/your_card_screen.dart';

import '../../../helpers/component_sheet.dart' show holdDown;
import '../../../helpers/finger.dart';
import '../../../helpers/shell_setup.dart';

// 04's clock (the owner, 24 November 2026: "there's no timer in some stages,
// even though there's one under the hood"): the look stage's time left, by
// the server's deadline, in every state of the screen. A table that sets
// no look length has no look stage (the night opens at its first window),
// so 04 always has a deadline (stage_clock_test.dart holds the samples to
// it).

/// The seconds the 04 clock reads, or null when there is none.
int? _shown(WidgetTester tester) {
  final clocks = find.descendant(
    of: find.byType(YourCardScreen),
    matching: find.byType(WorldTimer),
  );
  if (clocks.evaluate().isEmpty) return null;
  return tester.widget<WorldTimer>(clocks).secondsLeft;
}

/// The look stage's `/me/` and a clock 14 s before its deadline.
(Map<String, dynamic>, DateTime) _look(String sample) {
  final me = recordedMe(sample);
  final deadline = DateTime.parse(me['deadline'] as String);
  return (me, deadline.subtract(const Duration(seconds: 14)));
}

void main() {
  testWidgets('the time left by the server deadline shows before Ready, '
      'with the card held open and after Ready', (tester) async {
    final (me, clock) = _look('me_look_stage');
    final s = await ShellSetup.pump(
      tester,
      me,
      clock: clock,
      learned: Cue.values.toSet(),
    );
    await s.settle(tester);
    expect(_shown(tester), 14, reason: 'before Ready (locked)');

    final hold = await holdDown(tester, find.byType(FaceDownCard));
    expect(_shown(tester), 14, reason: 'the card held open');
    await hold.up();
    await tester.pump();

    s.answerPost('/ready/', 'game/ready_look');
    await pressLikeAFinger(tester, find.byType(PrimaryButton).last);
    await s.settle(tester);
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton).last).label,
      CommonCopy.readyDone,
    );
    expect(_shown(tester), 14, reason: 'after Ready, waiting');
    await s.close(tester);
  });

  testWidgets('a restart after Ready opens with the time left', (tester) async {
    final (me, clock) = _look('me_look_ready');
    final s = await ShellSetup.pump(tester, me, clock: clock);
    await s.settle(tester);
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton).last).label,
      CommonCopy.readyDone,
    );
    expect(_shown(tester), 14);
    await s.close(tester);
  });
}
