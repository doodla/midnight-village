@Tags(['e2e'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/debug/debug_models.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';
import 'package:midnight_village/features/game/presentation/shell/count_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/not_built_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/results_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/test_fonts.dart';
import 'harness/failure_report.dart';
import 'harness/harness_config.dart';
import 'harness/live_table.dart';
import 'harness/time_budget.dart';
import 'harness/ui_harness.dart';

/// UI runner, night protocol 2, the end of the game: the whole table plays a
/// game through the API (the look, the night, the talk, the vote; the
/// server's oracle says what happened), then one phone opens the rebuilt
/// shell at the results and goes through the REAL widget tree: 10 The count,
/// "See who won", 11 Results and, for the host, "Play again" back to the
/// table. Kept apart from `ui_protocol2_test.dart` (the phone's own night and
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

  group('UI, protocol 2, from the count', () {
    testWidgets('the Hunter is voted out and takes a Werewolf: the village '
        'wins; the host plays again and the phone goes to 02', (tester) async {
      await _run(tester, 'p2-end-hunter', (r) async {
        final t = await r.play(
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
        final oracle = await r.api(t.oracleJson);
        expect(oracle['phase'], 'results');

        await r.openAs('Alice');
        await r.ui.pumpUntil(r.shows<CountView>, reason: '10 The count');
        await r.shoot('count-opening');
        await r.finishMotion();
        expect(r.text('Bob dies.'), isTrue);
        expect(r.text('Cara dies too.'), isTrue);
        expect(r.text('Alice, Cara, Dan'), isTrue, reason: "Bob's voters");
        await r.shoot('count');

        await r.tapText(CountCopy.seeWhoWon);
        await r.ui.pumpUntil(r.shows<ResultsView>, reason: '11 Results');
        expect(r.text(ResultsCopy.villageWins), isTrue);
        expect(r.text(ResultsCopy.youWon), isTrue);
        await r.shoot('results');

        await r.ui.tapAndSubmit(
          find.text(ResultsCopy.playAgain),
          until: () => r.placeholder == AppScreen.table,
        );
        await r.shoot('table');
        final lobby = await r.api(() => t.lobby(t.player('Alice')));
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
        await r.openAs('Alice');
        await r.ui.pumpUntil(r.shows<CountView>, reason: '10 The count');
        await r.finishMotion();
        expect(r.text(CountCopy.nobodyDies), isTrue);
        expect(r.text(CountCopy.nobodyGotTwo), isTrue);
        await r.shoot('count');

        await r.tapText(CountCopy.seeWhoWon);
        await r.ui.pumpUntil(r.shows<ResultsView>, reason: '11 Results');
        expect(r.text(ResultsCopy.werewolvesWin), isTrue);
        expect(r.text(ResultsCopy.youLost), isTrue);
        expect(r.text('Robber'), isTrue, reason: "Bob's dealt card");
        await r.shoot('results');
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
        await r.openAs('Bob');
        await r.ui.pumpUntil(r.shows<CountView>, reason: '10 The count');
        await r.finishMotion();
        expect(r.text('Bob dies.'), isTrue);
        await r.tapText(CountCopy.seeWhoWon);
        await r.ui.pumpUntil(r.shows<ResultsView>, reason: '11 Results');
        expect(r.text(ResultsCopy.tannerWins), isTrue);
        expect(r.text(ResultsCopy.youWon), isTrue);
        expect(r.text('Alice deals next.'), isTrue);
        await r.shoot('results-guest');
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
      checkpoint: 'ui-protocol2-end',
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

  /// Opens a protocol-2 table forced to [roles] and [center] and plays it
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
        protocolTwo: true,
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

  AppScreen? get placeholder => shows<NotBuiltScreen>()
      ? tester.widget<NotBuiltScreen>(find.byType(NotBuiltScreen)).screen
      : null;

  /// The count's rows land and its cards turn (a tap finishes them).
  Future<void> finishMotion() async {
    await tester.tap(find.byType(CountView), warnIfMissed: false);
    await tester.pump();
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton).last).phase,
      isNot(ButtonPhase.locked),
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
