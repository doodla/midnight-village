import 'package:flutter_test/flutter_test.dart';

import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/werewolf_portrait.dart';

import '../test/helpers/component_sheet.dart';
import '../test/helpers/screen_sweep.dart';
import '../test/helpers/sheet/story_samples.dart';
import '../test/helpers/shell_setup.dart';
import 'end_board_pages.dart';
import 'end_night_pages.dart';
import 'end_reveal_pages.dart';
import 'end_fixtures.dart';
import 'shell_fixtures.dart';
import 'story_fixtures.dart';
import 'table_fixtures.dart';

/// One screen, or one state of a screen, in the gallery.
class ScreenEntry {
  /// A screen the app has: [build] puts the app into that state.
  const ScreenEntry(
    this.id, {
    required this.mock,
    required this.build,
    this.playerScreen = false,
    this.frames,
    this.sweep = const SweepPlan(),
    this.textScale = 1,
  }) : notBuilt = null;

  /// A screen the mocks have and the app does not yet: listed so the summary
  /// shows the gap.
  const ScreenEntry.notBuilt(this.id, {required this.mock, required String why})
    : notBuilt = why,
      build = null,
      playerScreen = false,
      frames = null,
      sweep = const SweepPlan(),
      textScale = 1;

  /// File name stem of the PNG, e.g. `02-table`; states add a suffix.
  final String id;

  /// The mock in docs/design/mocks/ this is compared with, or null.
  final String? mock;

  final Future<void> Function(WidgetTester tester)? build;

  /// For a screen the app lacks: what is missing.
  final String? notBuilt;

  /// A screen built to the first-time play spec, which the gallery holds to
  /// the reading floor (reading_floor.dart): every app screen, and the
  /// component sheet's screen pages.
  final bool playerScreen;

  /// Frames drawn (100 ms each) after the build before the picture; null for
  /// the gallery's own settling. A first frame is 1.
  final int? frames;

  /// What the screen sweep (test/screen_cases/) holds this state to beyond
  /// the rules every state keeps (nothing cut, overflowing or off the screen;
  /// every name whole and uncovered; the main action there, on the screen,
  /// reachable, labelled, 48 to touch and pressed by a finger): what must be
  /// seen, what lies apart, the state's own rules. A state with no main
  /// action says why here (`SweepPlan.noMainAction`).
  /// Declared here, once, beside the state: the page, the sweep and the
  /// finger's press all come from this entry.
  final SweepPlan sweep;

  /// The phone's text size this page is drawn at (the gallery sets it on the
  /// phone). A page at another size than the phone's own is the twin of the
  /// state at 1, which the sweep turns through every text size already: it
  /// is drawn, not swept again.
  final double textScale;
}

/// Every screen and state, in the order of the design brief's table, then the
/// component sheet. Adding a screen or a state is one entry here.
final screenCatalogue = <ScreenEntry>[
  // 01 to 03b through the app's routes (table_fixtures.dart).
  // Home before 01: the saved account read back (then a try unanswered).
  ..._rebuilt('01-home-reading-account', null, {
    '': const _NoMain(_opening, pumpHomeReading),
    '-unanswered': const _NoMain(_opening, pumpHomeUnanswered),
    '-slow': const _NoMain(_opening, pumpHomeSlow),
    '-seat-unknown': const _NoMain(_opening, pumpHomeSeatUnknown),
  }),
  // The opening in its first frame (no sign yet: an answer that comes now
  // shows none).
  ScreenEntry(
    '01-home-reading-account-first-frame',
    mock: null,
    build: pumpHomeFirstFrame,
    playerScreen: true,
    frames: 1,
    sweep: SweepPlan.noMainAction(_opening),
  ),
  // What 01's taps look like while they are on their way and when they fail.
  ..._rebuilt('01-join', null, {
    '-starting': const _NoMain(_onItsWay, pumpJoinStarting),
    '-joining': const _NoMain(_onItsWay, pumpJoinJoining),
    '-join-not-sent': pumpJoinNotSent,
    '-start-not-sent': pumpStartNotSent,
    '-no-table': pumpJoinRefused,
    '-full': (tester) =>
        pumpJoinRefused(tester, sample: 'join_full', status: 400),
    '-playing': (tester) =>
        pumpJoinRefused(tester, sample: 'join_closed', status: 400),
  }),
  ..._rebuilt('01-join', '01-join.png', {
    '': pumpJoinFresh,
    '-returning': pumpJoinReturning,
    '-code': pumpJoinCode,
    '-link': pumpJoinLink,
    '-link-named': pumpJoinLinkNamed,
    '-link-elsewhere': const _NoMain(_elsewhere, pumpJoinLinkElsewhere),
    '-closed': pumpJoinClosed,
    '-keyboard': pumpJoinKeyboard,
    '-android-web': pumpJoinAndroidWeb,
    '-android-web-fresh': pumpJoinAndroidWebFresh,
    '-android-web-keyboard': pumpJoinAndroidWebKeyboard,
    '-android-web-x2': const _AtText(2.0, pumpJoinAndroidWeb),
    '-x1.3': const _AtText(1.3, pumpJoinFresh),
    '-x2': const _AtText(2.0, pumpJoinFresh),
  }),
  // The scanner 01 opens (no mock: its pictures are the build's own).
  ..._rebuilt('01b-scan', null, {
    '': const _NoMain(
      'the scanner looks for a code: nothing to press',
      pumpScanLooking,
    ),
    '-found': const _NoMain('a code is found: the table opens', pumpScanFound),
    '-refused': pumpScanRefused,
    '-x1.3': const _AtText(1.3, pumpScanLooking),
  }),
  ..._rebuilt('02-table', '02-table.png', {
    '': pumpTableHost,
    '-4': pumpTableHostFour,
    '-7-chaos': pumpTableHostChaos,
    '-alone': pumpTableHostAlone,
    '-9-long': pumpTableHostNine,
    '-9-long-x1.6': const _AtText(1.6, pumpTableHostNine),
    '-custom': pumpTableHostCustom,
    '-custom-short': pumpTableHostMismatch,
    '-dropped': pumpTableDropped,
    '-guest': const _NoMain(_guest, pumpTableGuest),
    '-handover': pumpTableHandover,
    '-seats-alone': pumpTableSeatsAlone,
    '-seats-3': pumpTableSeatsThree,
    '-seats-3-guest': _NoMain(
      _guest,
      (tester) => pumpTableSeatsThree(tester, viewer: 'Ugo'),
    ),
    '-seats-4': pumpTableSeatsFour,
    '-seats-4-guest': const _NoMain(_guest, pumpTableSeatsGuest),
    '-seats-7': pumpTableSeatsSeven,
    '-seats-lowered': pumpTableSeatsLowered,
    '-blocked': pumpTableLowered,
    '-blocked-guest': const _NoMain(_guest, pumpTableLoweredGuest),
    '-seats-full': pumpTableSeatsFull,
    '-practice': pumpTablePractice,
    '-practice-guest': _NoMain(
      _guest,
      (tester) => pumpTablePractice(tester, viewer: 'Quin'),
    ),
    '-practice-short': pumpTablePracticeShort,
    '-seats-x1.3': const _AtText(1.3, pumpTableSeatsAlone),
    '-x1.3': const _AtText(1.3, pumpTableHost),
    '-guest-x2': const _AtText(2.0, pumpTableGuest),
  }),
  // 02 while its table is read, and while it is not reachable; its taps
  // while they are on their way and when they fail.
  ..._rebuilt('02-table', null, {
    '-waiting': const _NoMain(_waits, pumpTableWaiting),
    '-offline': const _NoMain(_waits, pumpTableOffline),
    '-dealing': const _NoMain(_onItsWay, pumpTableDealing),
    '-deal-not-sent': pumpTableDealNotSent,
    '-leaving': const _NoMain(_onItsWay, pumpTableLeaving),
    '-leave-not-sent': const _NoMain(_guest, pumpTableLeaveNotSent),
  }),
  ..._rebuilt('03-deck', null, {
    '-waiting': const _NoMain(_waits, pumpDeckWaiting),
    '-offline': const _NoMain(_waits, pumpDeckOffline),
  }),
  ..._rebuilt('03-deck', '03-deck.png', {
    '': pumpDeckChips,
    '-chaos': pumpDeckChaos,
    '-edit': pumpDeckEdit,
    '-grid': pumpDeckGrid,
    '-grid-short': pumpDeckGridShort,
    '-grid-over': pumpDeckGridOver,
    '-seats-8': pumpDeckSeats,
    '-alone': pumpDeckAlone,
    '-lengths': pumpDeckLengths,
    '-lengths-doppelganger': pumpDeckLengthsDoppelganger,
    '-practice': pumpDeckPractice,
    '-practice-switched': pumpDeckPracticeSwitched,
    '-x1.3': const _AtText(1.3, pumpDeckAlone),
  }),
  ..._rebuilt('03b-deck-role', '03b-deck-role-explained.png', {
    '': const _NoMain(_sheet, pumpDeckRole),
    // The Werewolf's card sheet with no game (the lunge), as a player sees it
    // before a table is dealt.
    '-werewolf-no-game': const _NoMain(_sheet, pumpDeckRoleWerewolf),
  }),
  // The Werewolf in a game, each of its three portraits (the gallery pins one
  // for every other picture, so a missing or wrong one would hide behind it).
  for (final wolf in WerewolfPortrait.values)
    ..._rebuilt('06-night-board', '06-night-action.png', {
      '-lone-werewolf-${wolf.name}': (tester) => _withWerewolf(
        wolf,
        () => pumpNightAs(tester, 'me_choose_prompt_werewolf_lone'),
      ),
    }),
  // 04 to the end board, through the real shell (shell_fixtures.dart,
  // end_fixtures.dart).
  ..._rebuilt('04-your-card', '04-your-card.png', {
    '': pumpYourCard,
    '-held': pumpYourCardHeld,
    '-held-minion': pumpYourCardHeldMinion,
    '-ready': const _NoMain(_done, pumpYourCardReady),
    '-x1.3': const _AtText(1.3, pumpYourCard),
  }),
  ..._rebuilt('04-your-card', null, {
    '-waiting': const _NoMain(_waits, pumpYourCardWaiting),
    '-wait-failing': const _NoMain(_waits, pumpYourCardWaitFailing),
    '-not-sent': const _NoMain(_done, pumpYourCardNotSent),
  }),
  ..._rebuilt('05-night-loading', '05-night-waiting.png', {
    '': const _NoMain(_waits, pumpNightLoading),
  }),
  ..._rebuilt('06-night-board', null, {'-offline': pumpNightOffline}),
  ..._rebuilt('08-talk', null, {
    '-waiting': const _NoMain(_waits, pumpTalkWaiting),
    '-wait-failing': const _NoMain(_waits, pumpTalkWaitFailing),
    '-offline': pumpTalkOffline,
  }),
  ..._rebuilt('09-vote', null, {
    '-waiting': const _NoMain(_waits, pumpVoteWaiting),
    '-not-sent': pumpVoteNotSent,
    '-offline': const _NoMain(_waits, pumpVoteOffline),
  }),
  // The end board's live states, through the shell (end_fixtures.dart).
  ..._rebuilt('12-end-shell', null, {
    '-loading': const _NoMain(_waits, pumpResultsLoading),
    '-playing-again': const _NoMain(_onItsWay, pumpResultsPlayingAgain),
    '-leaving': const _NoMain(_onItsWay, pumpResultsLeaving),
    '-not-sent': pumpResultsNotSent,
    '-refused': pumpResultsRefused,
  }),
  ..._rebuilt('06-night-board', '06-night-action.png', {
    '': pumpNightBoard,
    '-sleeper': const _NoMain(
      'nothing to do tonight: the board waits for the day',
      pumpNightSleeper,
    ),
    '-picked': pumpNightPicked,
    '-seer-center': pumpNightSeerCenter,
    '-robber': (tester) => pumpNightAs(tester, 'me_choose_prompt_robber'),
    '-troublemaker': (tester) =>
        pumpNightAs(tester, 'me_choose_prompt_troublemaker'),
    '-troublemaker-long': pumpNightTroublemakerLong,
    '-lone-werewolf': (tester) =>
        pumpNightAs(tester, 'me_choose_prompt_werewolf_lone'),
    '-doppelganger': (tester) =>
        pumpNightAs(tester, 'me_choose_prompt_doppelganger_look'),
    '-chosen': const _NoMain(_done, pumpNightChosen),
    '-follow-up': pumpNightFollowUp,
    '-3': pumpNightThree,
    '-4': pumpNightFour,
    '-9': pumpNightNine,
    '-10-long': pumpNightTenLong,
    '-10-long-x1.6': const _AtText(1.6, pumpNightTenLong),
    '-x1.3': const _AtText(1.3, pumpNightBoard),
  }),
  ..._rebuilt('08-talk', '08-talk.png', {
    '': pumpTalkOpen,
    '-open-drunk': pumpTalkOpenDrunk,
    '-open-x1.3': const _AtText(1.3, pumpTalkOpen),
    '-put-away': pumpTalkPutAway,
    '-slept': pumpTalkSlept,
    '-held': pumpTalkHeld,
    '-held-doppelganger': pumpTalkDoppelgangerHeld,
    '-ready': pumpTalkReady,
    '-not-sent': pumpTalkNotSent,
    '-3': pumpTalkThree,
    '-9': pumpTalkNine,
    '-10-long': pumpTalkTenLong,
    '-x1.3': const _AtText(1.3, pumpTalkPutAway),
  }),
  // My night held, every night's picture story (each a recorded talk:
  // story_samples.dart).
  ..._rebuilt('08-talk', '08-talk.png', {
    for (final night in allNights.keys)
      '-held-$night': (tester) => pumpTalkStory(tester, night),
  }),
  ..._rebuilt('09-vote', '09-vote.png', {
    // "Pick a name" is the locked plaque: pressed, it nudges the slips.
    '': (tester) => pumpVoteOpen(tester),
    '-picked': pumpVotePicked,
    '-locked': const _NoMain(_done, pumpVoteLocked),
    '-restart-picked': pumpVoteRestartPicked,
    '-restart-locked': const _NoMain(_done, pumpVoteRestartLocked),
    '-3': pumpVoteThree,
    '-10-long': (tester) => pumpVoteTenLong(tester),
    '-10-long-x1.6': const _AtText(1.6, pumpVoteTenLong),
    '-practice': pumpVotePractice,
    '-x1.3': const _AtText(1.3, pumpVoteOpen),
  }),
  ...endBoardEntries,
  ...endRevealEntries,
  ...endNightEntries,
  ...componentSheet,
];

/// Runs [build] with every game drawn with the Werewolf portrait [wolf], then
/// puts the gallery's pin back.
Future<void> _withWerewolf(
  WerewolfPortrait wolf,
  Future<void> Function() build,
) async {
  final pinned = ShellSetup.pinnedWerewolf;
  ShellSetup.pinnedWerewolf = wolf;
  try {
    await build();
  } finally {
    ShellSetup.pinnedWerewolf = pinned;
  }
}

typedef _Pump = Future<void> Function(WidgetTester tester);

// Why a state has no main action (`SweepPlan.noMainAction`).
const _opening = 'the opening reads the saved account: it waits';
const _onItsWay = 'the tap is on its way: its button is busy';
const _waits = 'the screen waits for what it shows (a Waiting sign)';
const _elsewhere =
    'seated at another table: Join is not offered (never a second seat); the '
    "one way on is the text link \"Go there\" on the line \"You're at "
    "another table.\", which is also Back's";
const _guest = 'a guest waits for the host to deal';
const _sheet = 'a sheet the player opened: Close, the scrim or Back close it';
const _done =
    'done (ready, chosen or locked): it waits for the others; a send that '
    'failed is a quiet line with its own Try again';

/// A state with no main action, saying [why] (a wait for the others, a
/// lock): `SweepPlan.noMainAction`, the sweep's one opt-out.
class _NoMain {
  const _NoMain(this.why, this.build);

  final String why;
  final _Pump build;
}

/// The state [build] draws, at the phone's text size [scale]: a page of its
/// own in `just screens`. The sweep turns every state through the text sizes
/// already, so it sweeps the state once, as [build] draws it.
class _AtText {
  const _AtText(this.scale, this.build);

  final double scale;
  final _Pump build;
}

/// A rebuilt screen's states ([states]: suffix to a builder, a [_NoMain] or
/// an [_AtText]), each a player screen next to [mock].
List<ScreenEntry> _rebuilt(
  String id,
  String? mock,
  Map<String, Object> states,
) => [
  for (final MapEntry(key: suffix, value: state) in states.entries)
    switch (state) {
      final _Pump build => ScreenEntry(
        '$id$suffix',
        mock: mock,
        build: build,
        playerScreen: true,
      ),
      _NoMain(:final why, :final build) => ScreenEntry(
        '$id$suffix',
        mock: mock,
        build: build,
        playerScreen: true,
        sweep: SweepPlan.noMainAction(why),
      ),
      _AtText(:final scale, :final build) => ScreenEntry(
        '$id$suffix',
        mock: mock,
        build: build,
        playerScreen: true,
        textScale: scale,
      ),
      _ => throw ArgumentError('$id$suffix: not a state: $state'),
    },
];

/// The component sheet (test/helpers/component_sheet.dart): each screen
/// rebuilt from the primitives to the spec, next to its mock, and each state
/// page on every ground: `c-<page>-<ground>`. Its screen pages are player
/// screens.
final componentSheet = [
  for (final page in ComponentPage.values)
    for (final ground in page.grounds)
      ScreenEntry(
        sheetId(page, ground),
        mock: page.mock,
        build: (tester) => pumpComponentPage(tester, page, ground),
        playerScreen: page.playerScreen,
      ),
];

/// A component sheet page's catalogue id.
String sheetId(ComponentPage page, GroundKind ground) =>
    'c-${page.name}-${ground.name}';
