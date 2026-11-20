import 'package:flutter_test/flutter_test.dart';

import 'package:midnight_village/design_system/skin/ground.dart';

import '../test/helpers/component_sheet.dart';
import 'screen_fixtures.dart';
import 'shell_fixtures.dart';

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
  /// the reading floor (reading_floor.dart). The app's screens in the old
  /// look are not, until they are rebuilt.
  final bool playerScreen;
}

/// Every screen and state, in the order of the design brief's table, then the
/// component sheet. Adding a screen or a state is one entry here.
final screenCatalogue = <ScreenEntry>[
  ScreenEntry(
    '01-join',
    mock: '01-join.png',
    build: (tester) => pumpHome(tester, signedIn: false),
  ),
  ScreenEntry(
    '01-join-signed-in',
    mock: '01-join.png',
    build: (tester) => pumpHome(tester, signedIn: true),
  ),
  ScreenEntry('02-table', mock: '02-table.png', build: pumpLobby),
  ScreenEntry(
    '02-table-guest',
    mock: '02-table.png',
    build: (tester) => pumpLobby(tester, viewer: ben),
  ),
  // The deck is built in the host's lobby today, further down the page.
  ScreenEntry(
    '03-deck',
    mock: '03-deck.png',
    build: (tester) async {
      await pumpLobby(tester);
      await tester.ensureVisible(find.text('Role Configuration'));
      await tester.pumpAndSettle();
    },
  ),
  const ScreenEntry.notBuilt(
    '03b-deck-role',
    mock: '03b-deck-role-explained.png',
    why: 'no role sheet (press and hold a role card)',
  ),
  // The rebuilt screens, through the real shell (shell_fixtures.dart).
  ..._rebuilt('04-your-card', '04-your-card.png', {
    '': pumpYourCard,
    '-held': pumpYourCardHeld,
    '-ready': pumpYourCardReady,
    '-x1.3': (tester) => pumpYourCard(tester, textScale: 1.3),
  }),
  ..._rebuilt('05-night-loading', '05-night-waiting.png', {
    '': pumpNightLoading,
  }),
  ..._rebuilt('06-night-board', '06-night-action.png', {
    '': pumpNightBoard,
    '-picked': pumpNightPicked,
    '-chosen': pumpNightChosen,
    '-follow-up': pumpNightFollowUp,
    '-3': pumpNightThree,
    '-9': pumpNightNine,
    '-10-long': pumpNightTenLong,
    '-x1.3': (tester) => pumpNightBoard(tester, textScale: 1.3),
  }),
  // The old look's night (protocol 1), until it is deleted.
  ScreenEntry(
    '05-night-waiting',
    mock: '05-night-waiting.png',
    build: pumpSeerWaiting,
  ),
  ScreenEntry(
    '06-night-action-seer',
    mock: '06-night-action.png',
    build: pumpSeerPrompt,
  ),
  ScreenEntry(
    '06-night-action-seer-player',
    mock: '06-night-action.png',
    build: (tester) async {
      await pumpSeerPrompt(tester);
      await tester.tap(find.text("Look at a player's card"));
    },
  ),
  ScreenEntry(
    '06-night-action-robber',
    mock: '06-night-action.png',
    build: pumpRobberPrompt,
  ),
  ScreenEntry(
    '07-night-what-you-saw',
    mock: '07-night-what-you-saw.png',
    build: pumpSeerResult,
  ),
  ScreenEntry('08-talk', mock: '08-talk.png', build: pumpTalk),
  ScreenEntry('09-vote', mock: '09-vote.png', build: pumpVote),
  ScreenEntry('10-the-count', mock: '10-the-count.png', build: pumpCount),
  ScreenEntry('11-results', mock: '11-results.png', build: pumpResults),
  ...componentSheet,
];

/// A rebuilt screen's states ([states]: suffix to builder), each a player
/// screen next to [mock].
List<ScreenEntry> _rebuilt(
  String id,
  String mock,
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
