import 'package:flutter_test/flutter_test.dart';

import 'screen_fixtures.dart';

/// One screen, or one state of a screen, in the gallery.
class ScreenEntry {
  /// A screen the app has: [build] puts the app into that state.
  const ScreenEntry(this.id, {required this.mock, required this.build})
    : notBuilt = null;

  /// A screen the mocks have and the app does not yet: listed so the summary
  /// shows the gap.
  const ScreenEntry.notBuilt(this.id, {required this.mock, required String why})
    : notBuilt = why,
      build = null;

  /// File name stem of the PNG, e.g. `02-table`; states add a suffix.
  final String id;

  /// The mock in docs/design/mocks/ this is compared with, or null.
  final String? mock;

  final Future<void> Function(WidgetTester tester)? build;

  /// For a screen the app lacks: what is missing.
  final String? notBuilt;
}

/// Every screen and state, in the order of the design brief's table. Adding a
/// screen or a state is one entry here.
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
  const ScreenEntry.notBuilt(
    '04-your-card',
    mock: '04-your-card.png',
    why:
        'unreachable: the app shows the role reveal only on a phase_change to '
        'night (game_notifier.dart _handlePhaseChange), which the server never '
        'sends (services.py sends phase.change for discussion and voting '
        'only), and GET /me never selects it',
  ),
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
];
