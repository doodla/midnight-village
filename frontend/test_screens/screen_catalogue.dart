import 'package:flutter_test/flutter_test.dart';

import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/werewolf_portrait.dart';

import '../test/helpers/component_sheet.dart';
import '../test/helpers/shell_setup.dart';
import 'end_fixtures.dart';
import 'shell_fixtures.dart';
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
  }) : notBuilt = null;

  /// A screen the mocks have and the app does not yet: listed so the summary
  /// shows the gap.
  const ScreenEntry.notBuilt(this.id, {required this.mock, required String why})
    : notBuilt = why,
      build = null,
      playerScreen = false,
      frames = null;

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
}

/// Every screen and state, in the order of the design brief's table, then the
/// component sheet. Adding a screen or a state is one entry here.
final screenCatalogue = <ScreenEntry>[
  // 01 to 03b through the app's routes (table_fixtures.dart).
  // Home before 01: the saved account read back (then a try unanswered).
  ..._rebuilt('01-home-reading-account', null, {
    '': pumpHomeReading,
    '-unanswered': pumpHomeUnanswered,
    '-slow': pumpHomeSlow,
    '-seat-unknown': pumpHomeSeatUnknown,
  }),
  // The opening in its first frame (no sign yet: an answer that comes now
  // shows none).
  ScreenEntry(
    '01-home-reading-account-first-frame',
    mock: null,
    build: pumpHomeFirstFrame,
    playerScreen: true,
    frames: 1,
  ),
  // What 01's taps look like while they are on their way and when they fail.
  ..._rebuilt('01-join', null, {
    '-starting': pumpJoinStarting,
    '-joining': pumpJoinJoining,
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
    '-link-elsewhere': pumpJoinLinkElsewhere,
    '-closed': pumpJoinClosed,
    '-keyboard': pumpJoinKeyboard,
    '-android-web': pumpJoinAndroidWeb,
    '-android-web-fresh': pumpJoinAndroidWebFresh,
    '-android-web-keyboard': pumpJoinAndroidWebKeyboard,
    '-android-web-x2': (tester) => pumpJoinAndroidWeb(tester, textScale: 2),
    '-x1.3': (tester) => pumpJoinFresh(tester, textScale: 1.3),
    '-x2': (tester) => pumpJoinFresh(tester, textScale: 2),
  }),
  // The scanner 01 opens (no mock: its pictures are the build's own).
  ..._rebuilt('01b-scan', null, {
    '': pumpScanLooking,
    '-found': pumpScanFound,
    '-refused': pumpScanRefused,
    '-x1.3': (tester) => pumpScanLooking(tester, textScale: 1.3),
  }),
  ..._rebuilt('02-table', '02-table.png', {
    '': pumpTableHost,
    '-4': pumpTableHostFour,
    '-7-chaos': pumpTableHostChaos,
    '-alone': pumpTableHostAlone,
    '-9-long': pumpTableHostNine,
    '-9-long-x1.6': (tester) => pumpTableHostNine(tester, textScale: 1.6),
    '-custom': pumpTableHostCustom,
    '-custom-short': pumpTableHostMismatch,
    '-dropped': pumpTableDropped,
    '-guest': pumpTableGuest,
    '-handover': pumpTableHandover,
    '-seats-alone': pumpTableSeatsAlone,
    '-seats-3': pumpTableSeatsThree,
    '-seats-3-guest': (tester) => pumpTableSeatsThree(tester, viewer: 'Ugo'),
    '-seats-4': pumpTableSeatsFour,
    '-seats-4-guest': pumpTableSeatsGuest,
    '-seats-7': pumpTableSeatsSeven,
    '-seats-lowered': pumpTableSeatsLowered,
    '-blocked': pumpTableLowered,
    '-blocked-guest': pumpTableLoweredGuest,
    '-seats-full': pumpTableSeatsFull,
    '-practice': pumpTablePractice,
    '-practice-guest': (tester) => pumpTablePractice(tester, viewer: 'Quin'),
    '-practice-short': pumpTablePracticeShort,
    '-seats-x1.3': (tester) => pumpTableSeatsAlone(tester, textScale: 1.3),
    '-x1.3': (tester) => pumpTableHost(tester, textScale: 1.3),
    '-guest-x2': (tester) => pumpTableGuest(tester, textScale: 2),
  }),
  // 02 while its table is read, and while it is not reachable; its taps
  // while they are on their way and when they fail.
  ..._rebuilt('02-table', null, {
    '-waiting': pumpTableWaiting,
    '-offline': pumpTableOffline,
    '-dealing': pumpTableDealing,
    '-deal-not-sent': pumpTableDealNotSent,
    '-leaving': pumpTableLeaving,
    '-leave-not-sent': pumpTableLeaveNotSent,
  }),
  ..._rebuilt('03-deck', null, {
    '-waiting': pumpDeckWaiting,
    '-offline': pumpDeckOffline,
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
    '-x1.3': (tester) => pumpDeckAlone(tester, textScale: 1.3),
  }),
  ..._rebuilt('03b-deck-role', '03b-deck-role-explained.png', {
    '': pumpDeckRole,
    // The Werewolf's card sheet with no game (the lunge), as a player sees it
    // before a table is dealt.
    '-werewolf-no-game': pumpDeckRoleWerewolf,
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
  // 04 to 11, through the real shell (shell_fixtures.dart, end_fixtures.dart).
  ..._rebuilt('04-your-card', '04-your-card.png', {
    '': pumpYourCard,
    '-held': pumpYourCardHeld,
    '-held-minion': pumpYourCardHeldMinion,
    '-ready': pumpYourCardReady,
    '-x1.3': (tester) => pumpYourCard(tester, textScale: 1.3),
  }),
  ..._rebuilt('04-your-card', null, {
    '-waiting': pumpYourCardWaiting,
    '-wait-failing': pumpYourCardWaitFailing,
    '-not-sent': pumpYourCardNotSent,
  }),
  ..._rebuilt('05-night-loading', '05-night-waiting.png', {
    '': pumpNightLoading,
  }),
  ..._rebuilt('06-night-board', null, {'-offline': pumpNightOffline}),
  ..._rebuilt('08-talk', null, {
    '-waiting': pumpTalkWaiting,
    '-wait-failing': pumpTalkWaitFailing,
    '-offline': pumpTalkOffline,
  }),
  ..._rebuilt('09-vote', null, {
    '-waiting': pumpVoteWaiting,
    '-not-sent': pumpVoteNotSent,
    '-offline': pumpVoteOffline,
  }),
  ..._rebuilt('10-count', null, {'-loading': pumpCountLoading}),
  ..._rebuilt('11-results', null, {
    '-loading': pumpResultsLoading,
    '-playing-again': pumpResultsPlayingAgain,
    '-leaving': pumpResultsLeaving,
    '-not-sent': pumpResultsNotSent,
    '-refused': pumpResultsRefused,
  }),
  ..._rebuilt('06-night-board', '06-night-action.png', {
    '': pumpNightBoard,
    '-sleeper': pumpNightSleeper,
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
    '-chosen': pumpNightChosen,
    '-follow-up': pumpNightFollowUp,
    '-3': pumpNightThree,
    '-4': pumpNightFour,
    '-9': pumpNightNine,
    '-10-long': pumpNightTenLong,
    '-10-long-x1.6': (tester) => pumpNightTenLong(tester, textScale: 1.6),
    '-x1.3': (tester) => pumpNightBoard(tester, textScale: 1.3),
  }),
  ..._rebuilt('08-talk', '08-talk.png', {
    '': pumpTalkOpen,
    '-open-drunk': pumpTalkOpenDrunk,
    '-open-x1.3': (tester) => pumpTalkOpen(tester, textScale: 1.3),
    '-put-away': pumpTalkPutAway,
    '-slept': pumpTalkSlept,
    '-held': pumpTalkHeld,
    '-held-doppelganger': pumpTalkDoppelgangerHeld,
    '-ready': pumpTalkReady,
    '-not-sent': pumpTalkNotSent,
    '-3': pumpTalkThree,
    '-9': pumpTalkNine,
    '-10-long': pumpTalkTenLong,
    '-x1.3': (tester) => pumpTalkPutAway(tester, textScale: 1.3),
  }),
  ..._rebuilt('09-vote', '09-vote.png', {
    '': pumpVoteOpen,
    '-picked': pumpVotePicked,
    '-locked': pumpVoteLocked,
    '-restart-picked': pumpVoteRestartPicked,
    '-restart-locked': pumpVoteRestartLocked,
    '-3': pumpVoteThree,
    '-10-long': pumpVoteTenLong,
    '-10-long-x1.6': (tester) => pumpVoteTenLong(tester, textScale: 1.6),
    '-practice': pumpVotePractice,
    '-x1.3': (tester) => pumpVoteOpen(tester, textScale: 1.3),
  }),
  ..._rebuilt('10-count', '10-the-count.png', {
    '-one': pumpCountOne,
    '-opening': pumpCountOpening,
    '-hunter': pumpCountHunter,
    '-moved': pumpCountMoved,
    '-nobody': pumpCountNobody,
    '-tanner': pumpCountTanner,
    '-ten-long': pumpCountTen,
    '-waiting': pumpCountWaiting,
    '-x1.3': (tester) => pumpCountOne(tester, textScale: 1.3),
  }),
  ..._rebuilt('11-results', '11-results.png', {
    '-village': pumpResultsVillage,
    '-werewolves': pumpResultsWerewolves,
    '-nobody': pumpResultsNobody,
    '-tanner': pumpResultsTanner,
    '-night': pumpResultsNight,
    '-folded': pumpResultsFolded,
    '-end': pumpResultsEnd,
    '-five-end': pumpResultsFiveEnd,
    '-ten-long': pumpResultsTen,
    '-x1.3': (tester) => pumpResultsVillage(tester, textScale: 1.3),
  }),
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

/// A rebuilt screen's states ([states]: suffix to builder), each a player
/// screen next to [mock].
List<ScreenEntry> _rebuilt(
  String id,
  String? mock,
  Map<String, Future<void> Function(WidgetTester tester)> states,
) => [
  for (final MapEntry(key: suffix, value: build) in states.entries)
    ScreenEntry('$id$suffix', mock: mock, build: build, playerScreen: true),
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
