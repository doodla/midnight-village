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
/// For each game: spin a fresh table with the recorded deal, play the two-window
/// night by answering each player's own prompt, then (full games) discussion,
/// the recorded votes and the reveal. Assert, via the debug-state oracle, every
/// player's final card, the center, teams, the copied role, what each player
/// learned during the night, and (full games) votes, who was voted out, who died,
/// the winners, who won, and the stated reason.
///
/// This targets the BOOTED HARNESS BACKEND on 127.0.0.1:8001 and mocks nothing.
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

  group('API: two-window night protocol', () {
    late DebugApiClient client;
    late DebugTableController controller;

    setUp(() {
      final clients = harnessClients();
      client = clients.client;
      controller = clients.controller;
    });

    /// Alice Doppelganger, Bob Seer, Carol Werewolf, Dave Insomniac.
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
      timerSettings: timers,
    );

    DebugAction act(String type, [Map<String, dynamic> targets = const {}]) =>
        DebugAction.nightAction(actionType: type, targets: targets);

    test('window 1 look arrives at once with a follow-up; window 2 delivers '
        'nothing until it closes, then all results, wave_complete, '
        'discussion', () async {
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

      // Window 1 is open (its events went out before the sockets connected, so
      // read the prompts from each player's own view): only Alice has one.
      final alicePrompt = (await controller.playerView(alice))['action_prompt'];
      expect(alicePrompt['role_acting_as'], 'Doppelganger');
      expect(alicePrompt['wave'], 1);
      for (final p in [bob, carol, dave]) {
        expect((await controller.playerView(p))['action_prompt'], isNull);
      }

      // Her look: the result comes back at once, then her follow-up prompt, in
      // the same window. Nobody else hears anything.
      await controller.driveAs(
        alice,
        act('peek_player', {'player_id': bob.userId}),
      );
      await wires['Alice']!.waitFor(
        () => wires['Alice']!.ofType('action_prompt').isNotEmpty,
        reason: 'the follow-up prompt',
        timeout: eventTimeout,
      );
      final aliceTrace = wires['Alice']!.trace;
      expect(aliceTrace.sublist(aliceTrace.length - 2), [
        'action_result:1',
        'action_prompt:1',
      ]);
      final look = wires['Alice']!.ofType('action_result').single;
      expect(look['action_type'], 'peek_player');
      expect((look['revealed_info'] as Map)['copied_role'], 'Seer');
      final followUp = wires['Alice']!.ofType('action_prompt').last;
      expect(followUp['role_acting_as'], 'Seer');
      expect(followUp['wave'], 1);
      expect(followUp['action_types'], contains('skip'));
      expect(wires['Bob']!.ofType('action_result'), isEmpty);

      // Her follow-up result arrives when window 1 closes, then window 2 opens.
      await controller.driveAs(alice, act('skip'));
      await wires['Alice']!.waitFor(
        () => wires['Alice']!.ofType('wave_start').any((e) => e['wave'] == 2),
        reason: 'window 2 to open',
        timeout: eventTimeout,
      );
      expect(
        wires['Alice']!.trace.skipWhile((e) => e != 'action_result:1').skip(1),
        containsAllInOrder(['wave_complete:1', 'wave_start:2']),
      );
      expect(
        wires['Alice']!.ofType('action_result').last['action_type'],
        'skip',
      );

      // Window 2: Bob, Carol and Dave are all prompted at once (the Werewolf
      // is alone - her center is a Werewolf - and the Insomniac is prompted).
      for (final name in ['Bob', 'Carol', 'Dave']) {
        await wires[name]!.waitFor(
          () => wires[name]!.ofType('action_prompt').any((e) => e['wave'] == 2),
          reason: 'the window 2 prompt',
          timeout: eventTimeout,
        );
      }
      expect(
        (wires['Bob']!.ofType('action_prompt').last['action_types'] as List),
        containsAll(['peek_player', 'peek_center', 'skip']),
      );
      // Alice copied the Seer and has nothing to do in window 2.
      expect(wires['Alice']!.trace.last, 'wave_waiting:2');

      // Bob and Carol answer; Dave has not. NO result is sent to anyone yet.
      await controller.driveAs(
        bob,
        act('peek_player', {'player_id': carol.userId}),
      );
      await controller.driveAs(carol, act('see_team', {'center_index': 0}));
      // Positive synchronisation instead of a sleep: Alice's phone drops and
      // comes back. The presence events go out to the table AFTER anything the
      // server sent before, and each socket delivers in order, so once the
      // others have seen them, an early result would already be in their
      // recorded events.
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
      for (final w in wires.values) {
        expect(
          w.ofType('action_result').where((e) => e['wave'] == 2),
          isEmpty,
          reason: '${w.player.displayName} got a window 2 result early',
        );
      }
      expect((await controller.oracle()).currentWave, 2);

      // Dave answers: the window closes. Everyone's result, then wave_complete,
      // then the discussion.
      await controller.driveAs(dave, act('none'));
      for (final name in ['Bob', 'Carol', 'Dave']) {
        await wires[name]!.waitFor(
          () => wires[name]!.ofType('phase_change').isNotEmpty,
          reason: 'the discussion',
          timeout: eventTimeout,
        );
        final w2 = wires[name]!.trace
            .skipWhile((e) => e != 'wave_start:2')
            .toList();
        expect(
          w2
              .where((e) => !e.startsWith('wave_') || e == 'wave_complete:2')
              .toList(),
          containsAllInOrder([
            'action_result:2',
            'wave_complete:2',
            'phase_change:discussion',
          ]),
          reason: '$name window 2 delivery order',
        );
      }
      final bobResult = wires['Bob']!.ofType('action_result').single;
      expect(bobResult['action_type'], 'peek_player');
      expect((bobResult['revealed_info'] as Map)['role'], 'werewolf');
      final carolResult = wires['Carol']!.ofType('action_result').single;
      expect((carolResult['revealed_info'] as Map)['center_card'], {
        'index': 0,
        'role': 'werewolf',
      });
      final daveResult = wires['Dave']!.ofType('action_result').single;
      expect(daveResult['wave'], 2);
      expect(daveResult['action_type'], 'insomniac');
      expect((daveResult['revealed_info'] as Map)['current_role'], 'insomniac');
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

      // The Doppelganger answers at once (no follow-up: she copies the Werewolf
      // card, whose action is in window 2). Window 1 must STILL run its length.
      await controller.driveAs(
        alice,
        act('peek_player', {'player_id': carol.userId}),
      );
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

      // Everyone answers straight away; window 2 still waits out its minimum.
      await controller.driveAs(bob, act('skip'));
      await controller.driveAs(carol, act('see_team'));
      await controller.driveAs(dave, act('none'));
      await controller.driveAs(alice, act('see_team'));
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
      final bob = t.players[1];
      final carol = t.players[2], dave = t.players[3];

      // Window 1 is fixed at 600s and the Doppelganger never answers. Fire it:
      // she copied nothing, so window 2 opens without her.
      expect((await controller.oracle()).currentWave, 1);
      expect(await controller.fireTimer(TimerKey.wave(1)), isTrue);
      expect((await controller.oracle()).currentWave, 2);
      expect(await controller.fireTimer(TimerKey.wave(1)), isFalse);

      // Window 2: everyone answers but the 600s minimum holds it open ...
      await controller.driveAs(bob, act('skip'));
      await controller.driveAs(carol, act('see_team'));
      await controller.driveAs(dave, act('none'));
      expect((await controller.oracle()).phase, 'night');

      // ... until the hook closes it.
      expect(await controller.fireTimer(TimerKey.current), isTrue);
      expect((await controller.oracle()).phase, 'discussion');
      expect(await controller.fireTimer(TimerKey.wave(2)), isFalse);
      expect((await controller.oracle()).phase, 'discussion');
    });
  });
}
