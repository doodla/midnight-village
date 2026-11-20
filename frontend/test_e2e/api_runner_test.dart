@Tags(['e2e'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/debug/debug_api_client.dart';
import 'package:midnight_village/core/debug/debug_models.dart';
import 'package:midnight_village/core/debug/debug_table_controller.dart';

import 'harness/failure_report.dart';
import 'harness/harness_config.dart';
import 'harness/live_table.dart';
import 'harness/night_wire.dart';
import 'harness/scenario_runner.dart';
import 'harness/scenarios.dart';
import 'harness/time_budget.dart';

/// API runner: replays EVERY reference game (23 full games + 6 night-only
/// Doppelganger games) from `backend/tests/onuw/data/reference_games.json`.
///
/// For each game: spin a fresh table with the recorded deal, play the look stage
/// and the two-window night the way phones do (every phone sends one `choose`
/// per window, see `harness/scenario_runner.dart`), then (full games) the talk,
/// the recorded lock-in votes and the reveal. Assert, via the debug-state oracle, every
/// player's final card, the center, teams, the copied role, what each player
/// learned during the night, and (full games) votes, who was voted out, who died,
/// the winners, who won, and the stated reason.
///
/// This targets the BOOTED HARNESS BACKEND (127.0.0.1, the run's port:
/// [HarnessConfig.port]) and mocks nothing.
/// It runs headless on the host VM under `flutter test`; real Dio/WS work because
/// [HarnessConfig.setUp] clears `HttpOverrides.global`.
void main() {
  setUpAll(() async {
    await HarnessConfig.setUp();
    FailureReport.reset();
  });

  group('API: reference games', () {
    for (final game in allScenarios) {
      test('API: ${game.name}', () async {
        final runner = ReferenceGameRunner(game);
        try {
          await runner.setUp();
          await runner.runToEnd();
          if (game.hasVotes) await runner.assertResults();
        } on TestFailure {
          rethrow; // already recorded with its diff
        } catch (e) {
          FailureReport.record(
            scenario: game.name,
            checkpoint: 'run',
            message: e.toString(),
          );
          rethrow;
        }
      });
    }
  });

  group('API: the two-window night', () {
    late DebugApiClient client;
    late DebugTableController controller;

    setUp(() {
      final clients = harnessClients();
      client = clients.client;
      controller = clients.controller;
    });

    /// Alice Doppelganger, Bob Seer, Carol Werewolf, Dave Insomniac. No look
    /// stage: the deal opens window 1 at once, so the clocks below start then.
    Future<DebugTable> table(Map<String, int> timers) => controller.createTable(
      playerNames: ['Alice', 'Bob', 'Carol', 'Dave'],
      roleCounts: {
        'Doppelganger': 1,
        'Seer': 1,
        'Werewolf': 2,
        'Insomniac': 1,
        'Robber': 1,
        'Drunk': 1,
      },
      playerRolesByName: {
        'Alice': 'Doppelganger',
        'Bob': 'Seer',
        'Carol': 'Werewolf',
        'Dave': 'Insomniac',
      },
      centerCards: ['Werewolf', 'Robber', 'Drunk'],
      timerSettings: {...timers, 'card_look_seconds': 0},
    );

    Future<void> choose(
      DebugPlayer p, [
      List<Map<String, Object>> picks = const [],
    ]) => controller.stagedAs(p, 'action', {
      'action_type': 'choose',
      'picks': picks,
    });
    Future<Map<String, dynamic>> me(DebugPlayer p) => controller.playerView(p);
    Future<List<dynamic>> results(DebugPlayer p) async =>
        (await me(p))['night_results'] as List;

    /// Per-player night events: the night sends none.
    const perPlayerEvents = {
      'action_prompt',
      'action_result',
      'wave_waiting',
      'wave_start',
    };

    test('window 1: her look is read at once and arms her follow-up; window 2 '
        'holds every result until the last phone has chosen; nothing is sent '
        'to one player', () async {
      final t = await table(fastTimers);
      final wires = {
        for (final p in t.players)
          p.displayName: await PlayerWire.connect(client, t, p),
      };
      addTearDown(() async {
        for (final w in wires.values) {
          await w.close();
        }
      });
      final alice = t.players[0], bob = t.players[1];
      final carol = t.players[2], dave = t.players[3];

      // Window 1 is open: every phone has a prompt, only Alice's does something.
      expect((await me(alice))['action_prompt']['kind'], 'doppelganger_look');
      for (final p in [bob, carol, dave]) {
        expect((await me(p))['action_prompt']['kind'], 'none');
      }

      // Her look: in her own /me/ at once, and her follow-up is armed in the
      // SAME window. Nobody else learns anything.
      await choose(alice, [
        {'player_id': bob.userId},
      ]);
      final aliceMe = await me(alice);
      final look = (aliceMe['night_results'] as List).single;
      expect(look['action_type'], 'peek_player');
      expect(look['revealed_info']['copied_role'], 'Seer');
      expect(aliceMe['action_prompt']['kind'], 'seer');
      expect(aliceMe['action_prompt']['chooses_left'], 1);
      expect(await results(bob), isEmpty);

      // Everyone chooses once and she sends her follow-up (nothing): window 1
      // closes, one `night_window` for window 2 reaches every phone.
      final marks = {for (final w in wires.values) w.player.userId: w.mark};
      for (final p in [bob, carol, dave]) {
        await choose(p);
      }
      await choose(alice);
      for (final w in wires.values) {
        final opened = await w.waitForEvent(
          'night_window',
          where: (e) => e['window'] == 2,
          after: marks[w.player.userId]!,
          timeout: eventTimeout,
        );
        expect(opened.keys.toSet(), {'type', 'window', 'deadline'});
      }
      final followUp = (await results(alice)).last;
      expect(followUp['action_type'], 'skip');
      expect(followUp['revealed_info'], {'nothing_chosen': true});

      // Window 2: Bob is the Seer, Carol a lone Werewolf (her centre is a
      // Werewolf), Dave the Insomniac and Alice (a Seer now) have no choice.
      expect((await me(bob))['action_prompt']['kind'], 'seer');
      expect((await me(carol))['action_prompt']['kind'], 'lone_werewolf');
      expect((await me(dave))['action_prompt']['kind'], 'none');
      expect((await me(alice))['action_prompt']['kind'], 'none');

      // Bob, Carol and Alice choose; Dave has not. Nobody has a result yet.
      await choose(bob, [
        {'player_id': carol.userId},
      ]);
      await choose(carol, [
        {'center_index': 0},
      ]);
      await choose(alice);
      // Positive synchronisation instead of a sleep: Alice's phone drops and
      // comes back; the others hear both presence events, so anything sent
      // before them is already recorded.
      final seenBefore = {
        for (final name in ['Bob', 'Carol', 'Dave']) name: wires[name]!.mark,
      };
      await wires['Alice']!.close();
      for (final name in ['Bob', 'Carol', 'Dave']) {
        await wires[name]!.waitForEvent(
          'player_presence',
          where: (e) =>
              e['player_id'] == alice.userId && e['connected'] == false,
          after: seenBefore[name]!,
          timeout: eventTimeout,
        );
      }
      wires['Alice'] = await PlayerWire.connect(client, t, alice);
      for (final name in ['Bob', 'Carol', 'Dave']) {
        await wires[name]!.waitForEvent(
          'player_presence',
          where: (e) =>
              e['player_id'] == alice.userId && e['connected'] == true,
          after: seenBefore[name]!,
          timeout: eventTimeout,
        );
      }
      for (final p in [bob, carol, dave]) {
        expect(await results(p), isEmpty, reason: '${p.displayName} early');
      }
      expect((await controller.oracle()).currentWave, 2);

      // Dave chooses: the window closes and the talk opens.
      await choose(dave);
      for (final name in ['Bob', 'Carol', 'Dave']) {
        await wires[name]!.waitForEvent(
          'phase_change',
          where: (e) => e['phase'] == 'discussion',
          timeout: eventTimeout,
        );
      }
      final bobResult = (await results(bob)).single;
      expect(bobResult['action_type'], 'peek_player');
      expect(bobResult['revealed_info']['role'], 'Werewolf');
      expect((await results(carol)).single['revealed_info']['center_card'], {
        'index': 0,
        'role': 'Werewolf',
      });
      final daveResult = (await results(dave)).single;
      expect(daveResult['wave'], 2);
      expect(daveResult['action_type'], 'insomniac');
      expect(daveResult['revealed_info']['current_role'], 'Insomniac');
      for (final w in wires.values) {
        expect(
          w.events.map((e) => e['type']).toSet().intersection(perPlayerEvents),
          isEmpty,
          reason: '${w.player.displayName} heard a per-player night event',
        );
      }
    });

    test('window 1 lasts exactly its fixed length and window 2 never closes '
        'sooner than its minimum', () async {
      // Both boxes start before the table is dealt, so the server's windows
      // (which open after) can never be shorter than the client measures.
      final window1 = TimeBox(
        'the Doppelganger window',
        const Duration(seconds: 3),
      );
      final both = TimeBox(
        'the Doppelganger window plus the minimum of window 2',
        const Duration(seconds: 6),
      );
      final t = await table({
        ...fastTimers,
        'night_doppelganger_window_seconds': 3,
        'night_min_window_seconds': 3,
      });
      final alice = t.players[0], bob = t.players[1];
      final carol = t.players[2], dave = t.players[3];

      // Every phone chooses at once (she copies the Werewolf card, whose action
      // is in window 2: no follow-up). Window 1 must STILL run its length.
      await choose(alice, [
        {'player_id': carol.userId},
      ]);
      for (final p in [bob, carol, dave]) {
        await choose(p);
      }
      final wave = await window1.readInside(
        () async => (await controller.oracle()).currentWave,
      );
      expect(wave, 1);

      // ... then closes on its own.
      await pollUntil(
        () async => (await controller.oracle()).currentWave == 2,
        reason: 'window 1 to close by itself',
        timeout: window1.timeout,
      );
      window1.expectOver('window 1 closed early');

      // Everyone chooses straight away; window 2 still waits out its minimum.
      for (final p in [bob, carol, dave, alice]) {
        await choose(p);
      }
      final phase = await both.readInside(
        () async => (await controller.oracle()).phase,
      );
      expect(phase, 'night');
      await pollUntil(
        () async => (await controller.oracle()).phase == 'discussion',
        reason: 'window 2 to close after its minimum',
        timeout: both.timeout,
      );
      both.expectOver('window 2 closed before its minimum');
    });

    test('debug-fire-timer closes the open window now, whatever its minimum, '
        'and a second fire is a no-op', () async {
      final t = await table({
        ...fastTimers,
        'night_doppelganger_window_seconds': 600,
        'night_min_window_seconds': 600,
      });
      final players = t.players;

      // Window 1 is fixed at 600s and the Doppelganger never chooses. Fire it:
      // she copied nothing, so window 2 opens without her.
      expect((await controller.oracle()).currentWave, 1);
      expect(await controller.fireTimer(TimerKey.wave(1)), isTrue);
      expect((await controller.oracle()).currentWave, 2);
      expect(await controller.fireTimer(TimerKey.wave(1)), isFalse);

      // Window 2: every phone chooses but the 600s minimum holds it open ...
      for (final p in players) {
        await choose(p);
      }
      expect((await controller.oracle()).phase, 'night');

      // ... until the hook closes it.
      expect(await controller.fireTimer(TimerKey.current), isTrue);
      expect((await controller.oracle()).phase, 'discussion');
      expect(await controller.fireTimer(TimerKey.wave(2)), isFalse);
      expect((await controller.oracle()).phase, 'discussion');
    });
  });
}
