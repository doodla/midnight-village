@Tags(['e2e'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/debug/debug_models.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/features/lobby/presentation/at_table_screen.dart';
import 'package:midnight_village/features/lobby/presentation/where_am_i_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/test_fonts.dart';
import 'harness/end_of_game.dart' as end_of_game;
import 'harness/failure_report.dart';
import 'harness/harness_config.dart';
import 'harness/live_table.dart';
import 'harness/time_budget.dart';
import 'harness/ui_harness.dart';

/// UI runner, the end of the game: the whole table plays a
/// game through the API (the look, the night, the talk, the vote; the
/// server's oracle says what happened), then one phone opens the rebuilt
/// shell at the results and goes through the REAL widget tree: 10 The count,
/// "See who won", 11 Results and, for the host, "Play again" back to the
/// table. Kept apart from `ui_game_test.dart` (the phone's own night and
/// talk) so each starts where its screens are reachable.
///
/// Each game is one outcome the server can produce, with no recording in
/// `contract_samples/` for some of them: the Hunter's chain (the village
/// wins), nobody dies with a card moved (the Werewolves win), the Tanner
/// alone. Filmstrips go to `integration_test/screenshots/<game>/`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await HarnessConfig.setUp();
    HarnessConfig.stubSecureStorage();
    // Test code; the analyzer only counts test/ and *_test.dart as tests.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await loadAppFonts();
  });

  group('UI, from the count', () {
    testWidgets('the Hunter is voted out and takes a Werewolf: the village '
        'wins; the host plays again: a guest\'s phone goes to 02 by itself and '
        'every phone is told the table waits', (tester) async {
      await _run(tester, 'p2-end-hunter', (r) async {
        await r.play(
          roles: {
            'Alice': 'Seer',
            'Bob': 'Hunter',
            'Cara': 'Werewolf',
            'Dan': 'Villager',
            'Eve': 'Villager',
          },
          center: ['Werewolf', 'Villager', 'Troublemaker'],
          votes: {
            'Alice': 'Bob',
            'Bob': 'Cara',
            'Cara': 'Bob',
            'Dan': 'Bob',
            'Eve': 'Dan',
          },
        );
        // A guest's phone (the Hunter's own), left at 11.
        await r.endAsTheOracleSays('Bob');
        // The host plays again from her phone: this one goes to 02 by
        // itself (the table's event, or its poll), and the server has every
        // phone at the waiting table.
        await r.api(() => r.table.playAgain(r.table.player('Alice')));
        await r.ui.pumpUntil(
          r.shows<AtTableScreen>,
          reason: "Bob's phone at 02 after the host's play again",
        );
        await r.shoot('table');
        for (final p in r.table.table.players) {
          final where = await r.api(
            () => r.table.client.get('/me/table/', token: p.accessToken),
          );
          expect(
            (where['table'] as Map)['status'],
            'waiting',
            reason: "${p.displayName}'s phone is told the table waits (02)",
          );
        }
      });
    });

    testWidgets('a tie: both die; the village wins; the host plays again from '
        'her phone', (tester) async {
      await _run(tester, 'p2-end-tie', (r) async {
        await r.play(
          roles: {
            'Alice': 'Seer',
            'Bob': 'Villager',
            'Cara': 'Werewolf',
            'Dan': 'Villager',
            'Eve': 'Robber',
          },
          center: ['Werewolf', 'Villager', 'Troublemaker'],
          votes: {
            'Alice': 'Bob',
            'Bob': 'Cara',
            'Cara': 'Bob',
            'Dan': 'Cara',
            'Eve': 'Alice',
          },
        );
        // The host's phone: "Play again" takes it to 02.
        await r.endAsTheOracleSays('Alice');
        await r.ui.tapAndSubmit(
          find.text(ResultsCopy.playAgain),
          until: r.shows<AtTableScreen>,
        );
        await r.shoot('table');
        final lobby = await r.api(() => r.table.lobby(r.table.player('Alice')));
        expect(lobby['status'], 'waiting');
      });
    });

    testWidgets('nobody dies and the Robber took the Werewolf: the '
        'Werewolves win; his row shows the card he ended with', (tester) async {
      await _run(tester, 'p2-end-nobody', (r) async {
        await r.play(
          roles: {
            'Alice': 'Seer',
            'Bob': 'Robber',
            'Cara': 'Werewolf',
            'Dan': 'Villager',
            'Eve': 'Villager',
          },
          center: ['Werewolf', 'Villager', 'Troublemaker'],
          picks: {
            'Bob': (t) => [
              {'player_id': t.player('Cara').userId},
            ],
          },
          votes: {
            'Alice': 'Bob',
            'Bob': 'Cara',
            'Cara': 'Dan',
            'Dan': 'Eve',
            'Eve': 'Alice',
          },
        );
        await r.endAsTheOracleSays('Alice');
        // The red line: the Werewolf card went from Cara to Bob.
        expect(r.text('Cara'), isTrue);
        expect(r.text('Robber'), isTrue, reason: "Bob's dealt card");
      });
    });

    testWidgets('the Tanner is voted out and wins alone, on his own phone '
        '(a guest): who deals next', (tester) async {
      await _run(tester, 'p2-end-tanner', (r) async {
        await r.play(
          roles: {
            'Alice': 'Seer',
            'Bob': 'Tanner',
            'Cara': 'Werewolf',
            'Dan': 'Villager',
            'Eve': 'Villager',
          },
          center: ['Werewolf', 'Villager', 'Troublemaker'],
          votes: {
            'Alice': 'Bob',
            'Bob': 'Cara',
            'Cara': 'Bob',
            'Dan': 'Bob',
            'Eve': 'Dan',
          },
        );
        await r.endAsTheOracleSays('Bob');
        expect(r.text('Alice deals next.'), isTrue);
      });
    });
  });
}

/// Runs [script] on a fresh app at a phone's size, recording a failure with
/// its filmstrip folder, and tears the app down whatever happens.
Future<void> _run(
  WidgetTester tester,
  String name,
  Future<void> Function(_End r) script,
) async {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final ui = UiHarness(tester);
  final end = _End(tester, ui, name);
  try {
    await ui.pumpApp();
    await script(end);
  } catch (e) {
    FailureReport.record(
      scenario: name,
      checkpoint: 'ui-end',
      message: e.toString(),
      pngPath: 'integration_test/screenshots/$name/',
    );
    rethrow;
  } finally {
    await end.close();
    await ui.tearDownHarness();
  }
}

/// What [p] picks at night (none: they keep their card).
typedef _Picks = List<Map<String, Object>> Function(LiveTable t);

/// A table of five played to the end through the API, then one phone.
class _End {
  _End(this.tester, this.ui, this.name);

  final WidgetTester tester;
  final UiHarness ui;
  final String name;
  late LiveTable table;
  var _frame = 0;

  /// Real network, in the real zone.
  Future<T> api<T>(Future<T> Function() call) async =>
      (await tester.runAsync(() => call().timeout(eventTimeout))) as T;

  /// Opens a table forced to [roles] and [center] and plays it
  /// through: everyone looks, chooses [picks] (else keeps their card), is
  /// ready to vote and locks in [votes] (voter -> target, by name).
  Future<LiveTable> play({
    required Map<String, String> roles,
    required List<String> center,
    required Map<String, String> votes,
    Map<String, _Picks> picks = const {},
  }) async {
    final counts = <String, int>{};
    for (final role in [...roles.values, ...center]) {
      counts[role] = (counts[role] ?? 0) + 1;
    }
    table = (await tester.runAsync(
      () => LiveTable.open(
        playerNames: roles.keys.toList(),
        roleCounts: counts,
        playerRolesByName: roles,
        centerCards: center,
        // Every stage ends because everyone acted, never by a clock.
        timerSettings: {
          'card_look_seconds': 120,
          'night_wave_seconds': 600,
          'night_min_window_seconds': 0,
          'night_doppelganger_window_seconds': 600,
          'discussion_seconds': 600,
          'voting_seconds': 600,
        },
      ),
    ))!;
    final players = table.table.players;
    // Each wait below is bounded on its own.
    await tester.runAsync(() async {
      for (final p in players) {
        await _staged(p, 'ready', {'ready': true});
      }
      await _phase('night', window: 2);
      for (final p in players) {
        await _staged(p, 'action', {
          'action_type': 'choose',
          'picks': picks[p.displayName]?.call(table) ?? const [],
        });
      }
      await _phase('discussion');
      for (final p in players) {
        await _staged(p, 'ready', {'ready': true});
      }
      await _phase('voting');
      for (final p in players) {
        await _staged(p, 'vote', {
          'target_player_id': table.player(votes[p.displayName]!).userId,
          'lock': true,
        });
      }
      await _phase('results');
    });
    return table;
  }

  /// Waits until the server's oracle is at [phase] (and, at night, the
  /// choose window [window]).
  Future<void> _phase(String phase, {int? window}) => pollUntil(
    () async {
      final me = await table.me(table.table.players.first);
      return me['phase'] == phase &&
          (window == null || me['action_prompt'] != null);
    },
    reason: 'the table to reach $phase',
    timeout: eventTimeout,
  );

  /// A stage-scoped request as [p], naming the stage `/me/` has now.
  Future<void> _staged(
    DebugPlayer p,
    String tail,
    Map<String, dynamic> data,
  ) async {
    final me = await table.me(p);
    final prompt = me['action_prompt'] as Map<String, dynamic>?;
    await table.client.post(
      '/onuw/games/${table.gameId}/$tail/',
      token: p.accessToken,
      data: {
        ...data,
        'stage': me['stage'] as String,
        if (data['action_type'] == 'choose')
          'chosen': prompt == null ? 0 : prompt['chosen'] as int,
      },
    );
  }

  /// [name]'s phone, opened on the game's shell.
  Future<void> openAs(String name) async {
    final p = table.player(name);
    await ui.switchTo(
      userId: p.userId,
      displayName: p.displayName,
      accessToken: p.accessToken,
      refreshToken: p.refreshToken,
      gameId: table.gameId,
    );
    // Another phone: where it is is fetched afresh, in the real zone (the
    // last phone's slow poll of `/me/table/` was armed in the fake one).
    await tester.runAsync(() async => ui.container.invalidate(myTableProvider));
    await ui.openShell(table.gameId);
  }

  Future<void> close() async {
    try {
      await tester.runAsync(table.closeAll);
    } catch (_) {
      // Not opened.
    }
  }

  bool shows<T extends Widget>() => find.byType(T).evaluate().isNotEmpty;
  bool text(String t) => find.text(t).evaluate().isNotEmpty;

  /// [name]'s phone, opened at the end and checked against the oracle
  /// (`harness/end_of_game.dart`).
  Future<void> endAsTheOracleSays(String name) async {
    await openAs(name);
    await end_of_game.endAsTheOracleSays(
      tester: tester,
      ui: ui,
      table: table,
      name: name,
      shoot: shoot,
    );
  }

  /// A local step (no network).
  Future<void> tapText(String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await ui.settle();
  }

  /// The next filmstrip frame.
  Future<void> shoot(String state) =>
      ui.captureFrame(name, '${(++_frame).toString().padLeft(2, '0')}-$state');
}
