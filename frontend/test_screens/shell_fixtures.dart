import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';

import '../test/helpers/component_sheet.dart' show holdDown;
import '../test/helpers/sheet/sheet_data.dart' as sheet;
import '../test/helpers/shell_setup.dart';

// The rebuilt screens through the real shell (TableShell), as a phone of a
// recorded game has them: every answer is a recorded protocol-2 payload
// (contract_samples/), each state reached the way a player reaches it (a
// hold, taps, Choose) or the way the server moves on (a fetch, an event).
// Game 7 (five at the table, no Doppelganger): Ana the Seer is the phone.
// Game 8 (nine, with the Doppelganger): her phone, or the Drunk's.

/// The countdown drawn as at 14 s before [me]'s deadline, so a capture does
/// not depend on the clock.
DateTime _fourteenBefore(Map<String, dynamic> me) => DateTime.parse(
  me['deadline'] as String,
).subtract(const Duration(seconds: 14));

/// Pumps the shell on the phone of [me] (with the board's cue learned or
/// not as in a first game: the hold learned on 04).
Future<ShellSetup> _shell(
  WidgetTester tester,
  Map<String, dynamic> me, {
  Set<Cue> learned = const {Cue.hold},
  double textScale = 1,
  bool holdMe = false,
}) async {
  final setup = await ShellSetup.pump(
    tester,
    me,
    learned: learned,
    clock: _fourteenBefore(me),
    textScale: textScale,
    holdMe: holdMe,
  );
  await setup.settle(tester);
  return setup;
}

// ---------------------------------------------------------------------------
// 04 Your card
// ---------------------------------------------------------------------------

/// 04 as the deal lands, in a first game: the card face down with the hold
/// ring, "Ready" locked, nobody has looked.
Future<void> pumpYourCard(WidgetTester tester, {double textScale = 1}) =>
    _shell(
      tester,
      sheet.recordedMe('me_look_stage'),
      learned: const {},
      textScale: textScale,
    );

/// 04 held: the role card above the thumb; "Ready" has opened.
Future<void> pumpYourCardHeld(WidgetTester tester) async {
  await pumpYourCard(tester);
  await holdDown(tester, find.byType(FaceDownCard));
}

/// 04 held on the Minion's phone: the longest role text. Game 9's deal
/// (its deck holds the Minion), this phone dealt her (a value changed).
Future<void> pumpYourCardHeldMinion(WidgetTester tester) async {
  final me = sheet.recordedMe('me_auto_deck_9');
  (me['your_role'] as Map<String, dynamic>)['original_role'] = 'Minion';
  await _shell(tester, me, learned: const {});
  await holdDown(tester, find.byType(FaceDownCard));
}

/// 04 after Ready, as `/me/` has it (a restart lands here too).
Future<void> pumpYourCardReady(WidgetTester tester) =>
    _shell(tester, sheet.recordedMe('me_look_ready'));

// ---------------------------------------------------------------------------
// The night board
// ---------------------------------------------------------------------------

/// 05: a cold start in the night, while `/me/` loads.
Future<void> pumpNightLoading(WidgetTester tester) =>
    _shell(tester, sheet.recordedMe('me_choose_prompt_seer'), holdMe: true);

/// 06 as the window opens: nothing picked, the "You" ring (first board).
Future<void> pumpNightBoard(WidgetTester tester, {double textScale = 1}) =>
    _shell(
      tester,
      sheet.recordedMe('me_choose_prompt_seer'),
      textScale: textScale,
    );

/// 06 with Cleo picked: "Choose Cleo".
Future<void> pumpNightPicked(WidgetTester tester) async {
  await pumpNightBoard(tester);
  await tester.tap(find.text(sheet.cleo.name).last);
  await tester.pump();
}

/// 06 after Choose: "Chosen", the pick still lifted; the server's answer and
/// the `/me/` after it have landed.
Future<void> pumpNightChosen(WidgetTester tester) async {
  final setup = await _shell(tester, sheet.recordedMe('me_choose_prompt_seer'));
  setup
    ..answerPost('/action/', 'game/choose_submitted_seer')
    ..answerMe(sheet.recordedMe('me_choose_chosen'));
  await tester.tap(find.text(sheet.cleo.name).last);
  await tester.pump();
  await tester.tap(find.byType(PrimaryButton).last);
  await setup.settle(tester);
}

/// 06, the Doppelganger's follow-up: her look is back with `/me/`, the board
/// has armed again, and she holds "You" for what her copy may do.
Future<void> pumpNightFollowUp(WidgetTester tester) async {
  final look = sheet.recordedMe('me_choose_prompt_doppelganger_look');
  final setup = await _shell(tester, look);
  final board = tester.widget<NightBoard>(find.byType(NightBoard));
  final other = board.seats.firstWhere((s) => s.id != board.selfId);
  setup
    ..answerPost('/action/', 'game/choose_submitted_doppelganger_look')
    ..answerMe(sheet.recordedMe('me_choose_doppelganger_followup'));
  await tester.tap(find.text(other.name).last);
  await tester.pump();
  await tester.tap(find.byType(PrimaryButton).last);
  await setup.settle(tester);
  await holdDown(
    tester,
    find.ancestor(
      of: find.text(NightCopy.you),
      matching: find.byType(FaceDownCard),
    ),
  );
}

/// 06 at game 8's nine-seat table, on the Drunk's phone.
Future<void> pumpNightNine(WidgetTester tester) =>
    _shell(tester, sheet.recordedMe('me_choose_prompt_drunk'));

/// 06 at three: game 7 without Dev and Esme.
Future<void> pumpNightThree(WidgetTester tester) => _shell(
  tester,
  sheet.tableOf(
    sheet.recordedMe('me_choose_prompt_seer'),
    leave: {sheet.dev.name, sheet.esme.name},
  ),
);

/// 06 at ten, as many as the server seats, with long names (game 8 and one
/// more seat).
Future<void> pumpNightTenLong(WidgetTester tester) => _shell(
  tester,
  sheet.tableOf(
    sheet.recordedMe('me_choose_prompt_drunk'),
    add: 1,
    rename: sheet.longNames,
  ),
);
