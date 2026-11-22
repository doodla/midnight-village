import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/panels.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';

import '../test/helpers/component_sheet.dart' show holdDown;
import '../test/helpers/sheet/sheet_data.dart' as sheet;
import '../test/helpers/shell_setup.dart';

// The rebuilt screens through the real shell (TableShell), as a phone of a
// recorded game has them: every answer is a recorded payload
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
    // The talk acknowledges a night it shows open: answered as recorded.
    before: me['phase'] == 'discussion' ? _answerSeen : null,
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

/// 06 on a phone with nothing to choose (Esme, the Villager): the village
/// sleeps, "Nothing to do" quiet in the button's place.
Future<void> pumpNightSleeper(WidgetTester tester) =>
    _shell(tester, sheet.recordedMe('me_choose_prompt_villager'));

/// 06 with Cleo picked: "See Cleo".
Future<void> pumpNightPicked(WidgetTester tester) async {
  await pumpNightBoard(tester);
  await tester.tap(find.text(sheet.cleo.name).last);
  await tester.pump();
}

/// 06 on the Seer's phone with one center card picked: "Choose 1 more".
Future<void> pumpNightSeerCenter(WidgetTester tester) async {
  await pumpNightBoard(tester);
  await tester.tap(find.text(NightCopy.left).last);
  await tester.pump();
}

/// 06 as the window opens on the phone of a recorded prompt (game 7 unless
/// the name says otherwise): the Robber, the Troublemaker, the lone Werewolf,
/// the Doppelganger's look.
Future<void> pumpNightAs(WidgetTester tester, String recordedPrompt) =>
    _shell(tester, sheet.recordedMe(recordedPrompt));

/// 06 on the Troublemaker's phone with two of the longest names the server
/// allows picked: "Swap {name}, {name}" wraps between words.
Future<void> pumpNightTroublemakerLong(WidgetTester tester) async {
  const long = ['Rosalind Fairweather', 'Bartholomew Longname'];
  await _shell(
    tester,
    sheet.tableOf(
      sheet.recordedMe('me_choose_prompt_troublemaker'),
      rename: {sheet.ana.name: long[0], sheet.ben.name: long[1]},
    ),
  );
  for (final name in long) {
    await tester.tap(find.text(name).last);
    await tester.pump();
  }
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

/// 06 at four: game 7 without Esme: three others stand as a pair with the
/// third centred under them.
Future<void> pumpNightFour(WidgetTester tester) => _shell(
  tester,
  sheet.tableOf(
    sheet.recordedMe('me_choose_prompt_seer'),
    leave: {sheet.esme.name},
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

// ---------------------------------------------------------------------------
// 08 Talk
// ---------------------------------------------------------------------------

/// What a phone has learned by its first talk: the hold (04) and the
/// board's wave.
const _firstTalk = {Cue.hold, Cue.nightChoose};

/// 08 as the night ends: the sun, and My night open once, no hold (the
/// night told this phone something it has not seen at the talk), nobody
/// ready. Game 7, Ana the Seer: "Cleo's card was: Werewolf."
Future<ShellSetup> pumpTalkOpen(
  WidgetTester tester, {
  double textScale = 1,
  Set<Cue> learned = _firstTalk,
}) => _shell(
  tester,
  sheet.recordedMe('me_discussion_choose_seer'),
  learned: learned,
  textScale: textScale,
);

/// A tap puts the open My night away: the box, the deck under it.
Future<void> _putAway(WidgetTester tester, ShellSetup setup) async {
  final face = find.byType(HeldFace);
  if (face.evaluate().isEmpty) return;
  await tester.tapAt(tester.getRect(face).topCenter + const Offset(0, 24));
  await setup.settle(tester);
}

/// 08 once the open My night is put away: the box and the deck.
Future<ShellSetup> pumpTalkPutAway(
  WidgetTester tester, {
  double textScale = 1,
}) async {
  final setup = await pumpTalkOpen(tester, textScale: textScale);
  await _putAway(tester, setup);
  return setup;
}

/// 08 on the Drunk's phone at game 8's nine-seat table, as the talk opens:
/// "You took Middle, unseen.", open.
Future<void> pumpTalkOpenDrunk(WidgetTester tester) => _shell(
  tester,
  sheet.recordedMe('me_discussion_choose_drunk'),
  learned: Cue.values.toSet(),
);

/// 08 on a phone whose night told it nothing (Esme, a Villager): nothing
/// opens; My night says "You slept." when held.
Future<void> pumpTalkSlept(WidgetTester tester) => _shell(
  tester,
  sheet.recordedMe('me_discussion_choose_villager'),
  learned: Cue.values.toSet(),
);

/// 08 with My night held: the result first (Cleo's card).
Future<void> pumpTalkHeld(WidgetTester tester) async {
  await pumpTalkPutAway(tester);
  await holdDown(tester, find.byType(PeekBox));
}

/// The talk's ack of the night's results.
void _answerSeen(ShellSetup setup) =>
    setup.answerPost('/night-results/seen/', 'game/night_results_seen');

/// 08 on the Doppelganger's phone (game 8), held a second time: window 1's
/// page, after the result.
Future<void> pumpTalkDoppelgangerHeld(WidgetTester tester) async {
  final setup = await _shell(
    tester,
    sheet.recordedMe('me_discussion_choose_doppelganger'),
    learned: _firstTalk,
  );
  await _putAway(tester, setup);
  final first = await holdDown(tester, find.byType(PeekBox));
  await first.up();
  await tester.pump();
  await holdDown(tester, find.byType(PeekBox));
}

/// 08 after "Ready to vote", as `/me/` has it: "Ready ✓", one of five
/// ready (My night put away).
Future<void> pumpTalkReady(WidgetTester tester) async {
  final setup = await _shell(tester, sheet.recordedMe('me_talk_ready'));
  await _putAway(tester, setup);
}

/// 08 when a ready got no answer: "Not sent." with "Try again".
Future<void> pumpTalkNotSent(WidgetTester tester) async {
  final setup = await pumpTalkOpen(tester, learned: Cue.values.toSet());
  await _putAway(tester, setup);
  setup.failPost('/ready/');
  await tester.tap(find.byType(PrimaryButton).last);
  await setup.settle(tester);
}

/// 08 at game 8's nine-seat table, on the Drunk's phone (put away).
Future<void> pumpTalkNine(WidgetTester tester) async {
  final setup = await _shell(
    tester,
    sheet.recordedMe('me_discussion_choose_drunk'),
    learned: Cue.values.toSet(),
  );
  await _putAway(tester, setup);
}

/// 08 at three: game 7 without Dev and Esme (put away).
Future<void> pumpTalkThree(WidgetTester tester) async {
  final setup = await _shell(
    tester,
    sheet.tableOf(
      sheet.recordedMe('me_discussion_choose_seer'),
      leave: {sheet.dev.name, sheet.esme.name},
    ),
    learned: Cue.values.toSet(),
  );
  await _putAway(tester, setup);
}

/// 08 at ten, with long names (game 8 and one more seat; put away).
Future<void> pumpTalkTenLong(WidgetTester tester) async {
  final setup = await _shell(
    tester,
    sheet.tableOf(
      sheet.recordedMe('me_discussion_choose_drunk'),
      add: 1,
      rename: sheet.longNames,
    ),
    learned: Cue.values.toSet(),
  );
  await _putAway(tester, setup);
}

// ---------------------------------------------------------------------------
// 09 Vote
// ---------------------------------------------------------------------------

/// Game 7 at ten: its five and five more seats, with long names.
const _tenLongNames = {
  'Ana': 'Christopher',
  'Ben': 'Maximiliano',
  'Cleo': 'Jo',
  'Dev': 'Esmeralda',
  'Esme': 'Bartholomew',
  'Seat 32': 'Ida',
  'Seat 33': 'Rosalind Fairweather',
  'Seat 34': 'Wolfgang',
  'Seat 35': 'Penelope',
  'Seat 36': 'Gus',
};

/// 09 as the vote opens, in a first vote: nobody picked, the rows nudge
/// once. Game 7, Ana.
Future<ShellSetup> pumpVoteOpen(WidgetTester tester, {double textScale = 1}) =>
    _shell(
      tester,
      sheet.recordedMe('me_voting_unpicked'),
      learned: Cue.values.toSet().difference({Cue.voteLock}),
      textScale: textScale,
    );

/// 09 with Cleo picked: "Lock in Cleo", the one amber action.
Future<ShellSetup> pumpVotePicked(WidgetTester tester) async {
  final setup = await pumpVoteOpen(tester);
  setup.answerPost('/vote/', 'game/vote_repicked');
  await tester.tap(find.text(sheet.cleo.name));
  await setup.settle(tester);
  return setup;
}

/// 09 after Lock in: "Locked", every row dimmed alike.
Future<void> pumpVoteLocked(WidgetTester tester) async {
  final setup = await pumpVotePicked(tester);
  setup.answerPost('/vote/', 'game/vote_locked');
  await tester.tap(find.byType(PrimaryButton).last);
  await setup.settle(tester);
}

/// 09 on a restart after a pick: `/me/`'s own `my_vote` (Cleo), not locked.
Future<void> pumpVoteRestartPicked(WidgetTester tester) => _shell(
  tester,
  sheet.recordedMe('me_voting_picked'),
  learned: Cue.values.toSet(),
);

/// 09 on a restart after Lock in: `/me/` says locked.
Future<void> pumpVoteRestartLocked(WidgetTester tester) => _shell(
  tester,
  sheet.recordedMe('me_voting_locked'),
  learned: Cue.values.toSet(),
);

/// 09 at ten with long names.
Future<void> pumpVoteTenLong(WidgetTester tester) => _shell(
  tester,
  sheet.tableOf(
    sheet.recordedMe('me_voting_unpicked'),
    add: 5,
    rename: _tenLongNames,
  ),
  learned: Cue.values.toSet(),
);

/// 09 at three: game 7 without Dev and Esme.
Future<void> pumpVoteThree(WidgetTester tester) => _shell(
  tester,
  sheet.tableOf(
    sheet.recordedMe('me_voting_unpicked'),
    leave: {sheet.dev.name, sheet.esme.name},
  ),
  learned: Cue.values.toSet(),
);
