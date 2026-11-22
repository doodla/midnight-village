import 'package:flutter_test/flutter_test.dart';

import 'package:midnight_village/design_system/skin/ground.dart';

import '../test/helpers/component_sheet.dart';
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
  }) : notBuilt = null;

  /// A screen the mocks have and the app does not yet: listed so the summary
  /// shows the gap.
  const ScreenEntry.notBuilt(this.id, {required this.mock, required String why})
    : notBuilt = why,
      build = null,
      playerScreen = false;

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
}

/// Every screen and state, in the order of the design brief's table, then the
/// component sheet. Adding a screen or a state is one entry here.
final screenCatalogue = <ScreenEntry>[
  // 01 to 03b through the app's routes (table_fixtures.dart).
  ..._rebuilt('01-join', '01-join.png', {
    '': pumpJoinFresh,
    '-returning': pumpJoinReturning,
    '-code': pumpJoinCode,
    '-link': pumpJoinLink,
    '-link-named': pumpJoinLinkNamed,
    '-link-elsewhere': pumpJoinLinkElsewhere,
    '-closed': pumpJoinClosed,
    '-keyboard': pumpJoinKeyboard,
    '-x1.3': (tester) => pumpJoinFresh(tester, textScale: 1.3),
    '-x2': (tester) => pumpJoinFresh(tester, textScale: 2),
  }),
  ..._rebuilt('02-table', '02-table.png', {
    '': pumpTableHost,
    '-4': pumpTableHostFour,
    '-7-chaos': pumpTableHostChaos,
    '-alone': pumpTableHostAlone,
    '-9-long': pumpTableHostNine,
    '-custom': pumpTableHostCustom,
    '-custom-short': pumpTableHostMismatch,
    '-dropped': pumpTableDropped,
    '-guest': pumpTableGuest,
    '-handover': pumpTableHandover,
    '-seats-alone': pumpTableSeatsAlone,
    '-seats-4': pumpTableSeatsFour,
    '-seats-4-guest': pumpTableSeatsGuest,
    '-seats-7': pumpTableSeatsSeven,
    '-seats-lowered': pumpTableSeatsLowered,
    '-seats-full': pumpTableSeatsFull,
    '-seats-x1.3': (tester) => pumpTableSeatsAlone(tester, textScale: 1.3),
    '-x1.3': (tester) => pumpTableHost(tester, textScale: 1.3),
    '-guest-x2': (tester) => pumpTableGuest(tester, textScale: 2),
  }),
  ..._rebuilt('03-deck', '03-deck.png', {
    '': pumpDeckChips,
    '-chaos': pumpDeckChaos,
    '-edit': pumpDeckEdit,
    '-grid': pumpDeckGrid,
    '-grid-short': pumpDeckGridShort,
    '-seats-8': pumpDeckSeats,
    '-alone': pumpDeckAlone,
    '-lengths': pumpDeckLengths,
    '-x1.3': (tester) => pumpDeckAlone(tester, textScale: 1.3),
  }),
  ..._rebuilt('03b-deck-role', '03b-deck-role-explained.png', {
    '': pumpDeckRole,
  }),
  // 04 to 11, through the real shell (shell_fixtures.dart, end_fixtures.dart).
  ..._rebuilt('04-your-card', '04-your-card.png', {
    '': pumpYourCard,
    '-held': pumpYourCardHeld,
    '-held-minion': pumpYourCardHeldMinion,
    '-ready': pumpYourCardReady,
    '-x1.3': (tester) => pumpYourCard(tester, textScale: 1.3),
  }),
  ..._rebuilt('05-night-loading', '05-night-waiting.png', {
    '': pumpNightLoading,
  }),
  ..._rebuilt('06-night-board', '06-night-action.png', {
    '': pumpNightBoard,
    '-sleeper': pumpNightSleeper,
    '-picked': pumpNightPicked,
    '-chosen': pumpNightChosen,
    '-follow-up': pumpNightFollowUp,
    '-3': pumpNightThree,
    '-9': pumpNightNine,
    '-10-long': pumpNightTenLong,
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
