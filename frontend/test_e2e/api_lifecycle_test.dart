@Tags(['e2e'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/api_exception.dart';
import 'package:midnight_village/core/debug/debug_models.dart';

import 'harness/harness_config.dart';
import 'harness/live_table.dart';
import 'harness/night_wire.dart';
import 'harness/scenario_runner.dart';
import 'harness/time_budget.dart';

/// API runner, table lifecycle: play again, dropped phones and host handover,
/// through the real server over real HTTP and real WebSockets. Every phone
/// plays as the app does: one `choose` per night window, lock-in votes, every
/// stage-scoped request naming the stage its `/me/` carries.
///
/// Each scenario asserts BOTH what the clients are told (HTTP bodies, socket
/// events) AND the truth in the debug-state oracle. Nothing is slept on: the
/// tests wait for the event the server sends. The only real clocks are the
/// server's own grace and handover periods, set per game; every "has not
/// happened yet" check inside one goes through a [TimeBox], so a slow machine
/// reports itself as inconclusive instead of blaming the server.
void main() {
  setUpAll(HarnessConfig.setUp);

  group('API: play again', () {
    for (final alias in [false, true]) {
      final path = alias
          ? '/onuw/lobbies/<code>/play-again/'
          : '/lobbies/<code>/play-again/';
      test('$path: only the host reopens a finished table; everyone is told; '
          'the same members and settings deal a NEW game, the controller '
          'follows it, and the old one stays readable', () async {
        final t = await _openTable();
        addTearDown(t.closeAll);
        await _connectEveryone(t, lobby: true);
        final alice = t.player('Alice'), bob = t.player('Bob');

        // Not finished yet: even the host is refused (409), nothing changes.
        await expectLater(
          t.playAgain(alice, alias: alias),
          throwsA(
            isA<UnhandledHttpException>().having(
              (e) => e.statusCode,
              'status',
              409,
            ),
          ),
        );

        await _playNight(t);
        await _playDay(t);
        final oldGame = t.gameId;
        final oldOracle = await t.oracleJson();
        expect(oldOracle['phase'], 'results');
        final before = await t.lobby(alice);
        expect(before['status'], 'finished');

        // A normal player is refused and nothing changes.
        await expectLater(
          t.playAgain(bob, alias: alias),
          throwsA(isA<ForbiddenException>()),
        );
        expect((await t.lobby(alice))['status'], 'finished');

        final gameMarks = {
          for (final p in t.table.players) p.userId: t.gameWire(p).mark,
        };
        final lobbyMarks = {
          for (final p in t.table.players) p.userId: t.lobbyWire(p).mark,
        };
        final body = await t.playAgain(alice, alias: alias);

        // Every connected client hears it, on the game socket and the lobby socket.
        for (final p in t.table.players) {
          final again = await t
              .gameWire(p)
              .waitForEvent(
                'play_again',
                after: gameMarks[p.userId]!,
                timeout: eventTimeout,
              );
          expect(again['lobby_code'], t.lobbyCode, reason: p.displayName);
          final update = await t
              .lobbyWire(p)
              .waitForEvent(
                'lobby_update',
                after: lobbyMarks[p.userId]!,
                timeout: eventTimeout,
              );
          expect(update['data'], body, reason: '${p.displayName} lobby_update');
        }

        // The lobby: waiting, the same members (all ready) and the same settings.
        final after = await t.lobby(alice);
        expect(after, body);
        expect(after['status'], 'waiting');
        expect(_memberIds(after), _memberIds(before));
        expect(
          (after['players'] as List).every(
            (m) => (m as Map)['is_ready'] == true,
          ),
          isTrue,
        );
        expect(after['settings'], before['settings']);

        // Nobody is sent back into the finished game; it is still readable.
        for (final p in t.table.players) {
          expect(await t.currentGame(p), {'game': null}, reason: p.displayName);
          final old = await t.me(p, game: oldGame);
          expect(old['phase'], 'results');
        }
        expect((await t.oracleJson())['results'], oldOracle['results']);

        // A repeat is harmless; only the host deals; the deal is a NEW game.
        expect(await t.playAgain(alice, alias: alias), body);
        await expectLater(t.startGame(bob), throwsA(isA<ForbiddenException>()));
        final lobbyMark = t.lobbyWire(bob).mark;
        final started = await t.startGame(
          alice,
          dealtByName: _dealt,
          centerCards: _center,
        );
        expect(started['game_id'], isNot(oldGame));
        final startedEvent = await t
            .lobbyWire(bob)
            .waitForEvent(
              'game_started',
              after: lobbyMark,
              timeout: eventTimeout,
            );
        expect(startedEvent['game_id'], started['game_id']);

        final fresh = await t.oracleJson();
        expect(fresh['game_id'], started['game_id']);
        expect(fresh['phase'], 'night');
        expect(fresh['results'], isNull);
        expect(_playerIds(fresh), _playerIds(oldOracle));
        for (final p in t.table.players) {
          expect((await t.currentGame(p))['game_id'], started['game_id']);
        }

        // The controller follows the new game: a move driven through it lands
        // there, not in the old one.
        expect(t.controller.table!.gameId, started['game_id']);
        expect((await t.me(alice))['action_prompt']['chosen'], 0);
        await _choose(t, alice, [_center0]);
        expect((await t.me(alice))['action_prompt']['chosen'], 1);
        expect(
          (await t.controller.playerView(alice))['game_id'],
          started['game_id'],
        );
        expect((await t.controller.oracle()).gameId, started['game_id']);

        // The old game is untouched by the new one.
        final old = await t.oracleJson(game: oldGame);
        expect(old['phase'], 'results');
        expect(old['results'], oldOracle['results']);
        expect(old['night_actions_log'], oldOracle['night_actions_log']);
      });
    }

    test('a double tap on Start (two concurrent requests) deals exactly one '
        'game', () async {
      final t = await _openTable();
      addTearDown(t.closeAll);
      await _connectEveryone(t);
      final alice = t.player('Alice');
      await _playNight(t);
      await _playDay(t);
      await t.playAgain(alice);

      Future<String?> tap() async {
        try {
          return (await t.startRequest(alice))['game_id'] as String;
        } on ApiException {
          return null;
        }
      }

      final dealt = (await Future.wait([tap(), tap()])).nonNulls.toList();
      expect(dealt, hasLength(1), reason: 'both taps dealt a game: $dealt');
      expect(await t.lobby(alice), containsPair('status', 'in_game'));
      t.adoptGame(dealt.single);
      for (final p in t.table.players) {
        expect((await t.currentGame(p))['game_id'], dealt.single);
      }
      expect((await t.oracleJson())['phase'], 'night');
    });
  });

  group('API: dropped phone', () {
    test('a dropped Drunk: the window holds for the grace period although '
        'everyone else has acted, then closes with the server\'s swap; the '
        'phone that was offline reads its result from /me/', () async {
      final t = await _openTable({'disconnect_grace_seconds': _graceSeconds});
      addTearDown(t.closeAll);
      await _connectEveryone(t);
      final alice = t.player('Alice'), bob = t.player('Bob');
      final carol = t.player('Carol'), dave = t.player('Dave');
      final aliceWire = t.gameWire(alice);

      final grace = TimeBox('the grace period', _grace);
      final mark = aliceWire.mark;
      await t.dropGame(carol);

      // What the table is told: presence, on the socket and in the player list.
      await _presence(aliceWire, carol, false, after: mark);
      await _presence(t.gameWire(bob), carol, false);
      final seen = await t.presenceAsSeenBy(alice);
      expect(seen[carol.userId], isFalse);
      expect(
        [
          for (final p in [alice, bob, dave]) seen[p.userId],
        ],
        [true, true, true],
      );
      // The truth: the oracle agrees, and the grace countdown is running.
      expect(_connected(await t.oracleJson()), {
        alice.userId: true,
        bob.userId: true,
        carol.userId: false,
        dave.userId: true,
      });
      expect(
        await grace.readInside(t.pendingTimers),
        containsAll(['wave:2', 'grace:${carol.userId}']),
      );

      // Every other phone chooses (Dave has nothing to choose). The Drunk has
      // not.
      await _choose(t, alice, [_center0]);
      await _choose(t, bob);
      await _choose(t, dave);
      final state = await grace.readInside(t.oracleJson);
      expect([state['phase'], state['current_wave']], ['night', 2]);
      final results = await grace.readInside(
        () async => [
          for (final p in [alice, bob, dave])
            ((await t.me(p))['night_results'] as List).length,
        ],
      );
      expect(results, [
        0,
        0,
        0,
      ], reason: 'someone was told a result before the window closed');

      // After the grace period it closes without her.
      await _phaseChange(
        aliceWire,
        'discussion',
        after: mark,
        timeout: grace.timeout,
      );
      grace.expectOver('the window closed before it was over');

      // The truth: her action was a timeout and the SERVER swapped her card with
      // a seeded center card; it is logged like a chosen swap, marked as the
      // server's. She never sent anything.
      final end = await t.oracleJson();
      final swaps = [
        for (final e in (end['night_actions_log'] as List).cast<Map>())
          if (e['player_id'] == carol.userId) e,
      ];
      expect(swaps, hasLength(1));
      expect(swaps.single['action_type'], 'swap_with_center');
      expect(swaps.single['made_by_server'], isTrue);
      final index = (swaps.single['targets'] as Map)['center_index'] as int;
      expect(index, inInclusiveRange(0, 2));
      expect((end['center_cards'] as List)[index], 'Drunk');
      expect(
        _player(end, carol)['current_role'],
        _center[index],
        reason: 'she took the card that was in that center slot',
      );
      for (final e in (end['night_actions_log'] as List).cast<Map>()) {
        if (e['player_id'] != carol.userId) {
          expect(e['made_by_server'], isFalse, reason: 'only hers was');
        }
      }

      // She was offline when the window closed: /me/ has her result.
      final view = await t.me(carol);
      expect(view['phase'], 'discussion');
      final mine = (view['night_results'] as List).cast<Map>();
      expect(mine, hasLength(1));
      expect(mine.single['action_type'], 'swap_with_center');
      expect(mine.single['revealed_info'], {
        'card_index': index,
        'nothing_chosen': true,
      });
      // Nobody else's /me/ carries her card index.
      for (final p in [alice, bob, dave]) {
        final others = ((await t.me(p))['night_results'] as List).cast<Map>();
        expect(
          [
            for (final r in others)
              if ((r['revealed_info'] as Map).containsKey('card_index')) r,
          ],
          isEmpty,
          reason: '${p.displayName} was shown the Drunk\'s result',
        );
      }

      // Coming back after the window closed: told as present again, no timer.
      final back = aliceWire.mark;
      await t.connectGame(carol);
      await _presence(aliceWire, carol, true, after: back);
      expect((await t.presenceAsSeenBy(alice))[carol.userId], isTrue);
      expect(await t.pendingTimers(), isNot(contains('grace:${carol.userId}')));
    });

    test('coming back inside the grace period cancels it: presence is '
        'restored and the window waits for her normally', () async {
      final t = await _openTable({'disconnect_grace_seconds': _longGrace});
      addTearDown(t.closeAll);
      await _connectEveryone(t);
      final alice = t.player('Alice'), bob = t.player('Bob');
      final carol = t.player('Carol');
      final aliceWire = t.gameWire(alice);
      final grace = TimeBox('the grace period', _longGraceDuration);

      var mark = aliceWire.mark;
      await t.dropGame(carol);
      await _presence(aliceWire, carol, false, after: mark);
      expect(await t.pendingTimers(), contains('grace:${carol.userId}'));
      await _choose(t, alice, [_center0]);
      await _choose(t, bob);
      await _choose(t, t.player('Dave'));

      mark = aliceWire.mark;
      await t.connectGame(carol);
      await _presence(aliceWire, carol, true, after: mark);
      expect((await t.presenceAsSeenBy(bob))[carol.userId], isTrue);
      expect(_connected(await t.oracleJson())[carol.userId], isTrue);

      // The countdown is gone and the window is still waiting for her answer.
      final timers = await grace.readInside(t.pendingTimers);
      expect(timers, isNot(contains('grace:${carol.userId}')));
      expect(timers, contains('wave:2'));
      expect(await grace.readInside(t.phase), 'night');

      // She chooses herself: it closes at once, nowhere near the grace period.
      await _choose(t, carol, [
        {'center_index': 2},
      ]);
      await _phaseChange(aliceWire, 'discussion', after: mark);
      await grace.readInside(() async {});
      final end = await t.oracleJson();
      expect(_player(end, carol)['current_role'], _center[2]);
      expect((end['center_cards'] as List)[2], 'Drunk');
      final result = ((await t.me(carol))['night_results'] as List).single;
      expect(result['revealed_info'], {'card_index': 2});
    });

    test('a dropped Seer (an actor) and a dropped Villager (no action) close '
        'the window after the same grace period: neither before it, within '
        '${_closeSpread.inSeconds} s of each other, and Alice\'s phone gets '
        'the same events up to the discussion', () async {
      final both = await Future.wait([
        _dropThenEveryoneElseActs('Bob'),
        _dropThenEveryoneElseActs('Dave'),
      ]);
      final seer = both[0], villager = both[1];

      // (Each run already asserted its own window was not closed early.)
      expect(
        (seer.closedAfter - villager.closedAfter).abs(),
        lessThan(_closeSpread),
        reason:
            'closed ${seer.closedAfter} after the Seer dropped, '
            '${villager.closedAfter} after the Villager did',
      );
      expect(seer.trace, villager.trace);
      expect(seer.trace, contains('phase_change:discussion'));
    });

    test(
      'a dropped voter: the vote waits for the grace period although '
      'everyone else has voted, then is revealed with her as a non-voter',
      () async {
        final t = await _openTable({'disconnect_grace_seconds': _graceSeconds});
        addTearDown(t.closeAll);
        await _connectEveryone(t);
        final alice = t.player('Alice'), bob = t.player('Bob');
        final carol = t.player('Carol'), dave = t.player('Dave');
        final aliceWire = t.gameWire(alice);
        await _playNight(t);
        await t.hostAction(alice, 'end-discussion');
        await _phaseChange(aliceWire, 'voting');

        final grace = TimeBox('the grace period', _grace);
        final mark = aliceWire.mark;
        await t.dropGame(dave);
        await _presence(aliceWire, dave, false, after: mark);
        expect((await t.presenceAsSeenBy(alice))[dave.userId], isFalse);
        expect(
          await grace.readInside(t.pendingTimers),
          contains('grace:${dave.userId}'),
        );

        await _vote(t, alice, bob);
        await _vote(t, bob, alice);
        await _vote(t, carol, alice);
        expect(await grace.readInside(t.phase), 'voting');
        expect(
          await grace.readInside(
            () async => aliceWire.ofType('vote_reveal').length,
          ),
          0,
        );

        final reveal = await aliceWire.waitForEvent(
          'vote_reveal',
          after: mark,
          timeout: grace.timeout,
        );
        grace.expectOver('the vote was revealed before it was over');
        final cast = {
          '${alice.userId}': bob.userId,
          '${bob.userId}': alice.userId,
          '${carol.userId}': alice.userId,
          '${dave.userId}': null, // the dropped player: a non-voter
        };
        expect(reveal['votes'], cast);

        // The truth: results, with the three votes counted and Dave a non-voter.
        await aliceWire.waitForEvent(
          'game_results',
          after: mark,
          timeout: eventTimeout,
        );
        final end = await t.oracleJson();
        expect(end['phase'], 'results');
        expect(end['votes'], cast);
        expect(_player(end, alice)['current_role'], 'Werewolf');
        expect(
          ((end['results'] as Map)['eliminated_players'] as List),
          [alice.userId],
          reason: 'Alice has two votes; the dropped Dave voted for nobody',
        );
      },
    );

    test('a voter who comes back inside the grace period is waited for and '
        'their vote counts', () async {
      final t = await _openTable({'disconnect_grace_seconds': _longGrace});
      addTearDown(t.closeAll);
      await _connectEveryone(t);
      final alice = t.player('Alice'), bob = t.player('Bob');
      final carol = t.player('Carol'), dave = t.player('Dave');
      final aliceWire = t.gameWire(alice);
      await _playNight(t);
      await t.hostAction(alice, 'end-discussion');
      await _phaseChange(aliceWire, 'voting');

      final grace = TimeBox('the grace period', _longGraceDuration);
      var mark = aliceWire.mark;
      await t.dropGame(dave);
      await _presence(aliceWire, dave, false, after: mark);
      await _vote(t, alice, bob);
      await _vote(t, bob, alice);
      await _vote(t, carol, alice);

      mark = aliceWire.mark;
      await t.connectGame(dave);
      await _presence(aliceWire, dave, true, after: mark);
      // Back inside the period: the vote waits for him, and his countdown is gone.
      expect(await grace.readInside(t.phase), 'voting');
      expect(
        await grace.readInside(t.pendingTimers),
        isNot(contains('grace:${dave.userId}')),
      );
      expect(aliceWire.ofType('vote_reveal').length, 0);

      // His vote is the last one: it reveals at once, and it counts.
      await _vote(t, dave, alice);
      final reveal = await aliceWire.waitForEvent(
        'vote_reveal',
        after: mark,
        timeout: eventTimeout,
      );
      await grace.readInside(() async {});
      expect(reveal['votes'], containsPair('${dave.userId}', alice.userId));
      final end = await t.oracleJson();
      expect(end['votes'], containsPair('${dave.userId}', alice.userId));
      expect(((end['results'] as Map)['eliminated_players'] as List), [
        alice.userId,
      ]);
    });

    test('one player with two game sockets: closing one is not a drop (no '
        'presence event); closing the last one is', () async {
      final t = await _openTable();
      addTearDown(t.closeAll);
      await _connectEveryone(t);
      final alice = t.player('Alice'), carol = t.player('Carol');
      final aliceWire = t.gameWire(alice);
      final extra = await t.connectExtraGame(carol);
      final mark = aliceWire.mark;

      await extra.close();
      await t.dropGame(carol);
      await _presence(aliceWire, carol, false, after: mark);
      // The returning phone is the barrier: the server handled both closes
      // before it handled this connect, so a presence event for the first close
      // (the bug) would already be in Alice's events.
      await t.connectGame(carol);
      await _presence(aliceWire, carol, true, after: mark);
      expect(
        [
          for (final e in aliceWire.events.skip(mark))
            if (e['type'] == 'player_presence' &&
                e['player_id'] == carol.userId)
              e['connected'],
        ],
        [false, true],
        reason: 'one drop (the LAST socket) and one return',
      );
    });
  });

  group('API: host handover', () {
    test('the owner\'s phone goes away: the first connected member in join '
        'order takes the host role, may do host things, and the owner '
        'getting back reclaims it at once', () async {
      final t = await _openTable({
        'host_handover_seconds': 1,
        'disconnect_grace_seconds': 0,
      });
      addTearDown(t.closeAll);
      final alice = t.player('Alice'), bob = t.player('Bob');
      final carol = t.player('Carol'), dave = t.player('Dave');
      // Bob (second in join order) never connects: he cannot take over.
      for (final p in [alice, carol, dave]) {
        await t.connectGame(p);
        await t.connectLobby(p);
      }
      final gameMark = t.gameWire(dave).mark;
      final lobbyMark = t.lobbyWire(dave).mark;

      await t.dropGame(alice);
      await t.dropLobby(alice);

      // Everyone connected is told, on both sockets; the first connected member
      // in join order (Carol) is the acting host.
      final change = await t
          .gameWire(dave)
          .waitForEvent(
            'host_changed',
            after: gameMark,
            timeout: _handoverTimeout,
          );
      expect(change, {
        'type': 'host_changed',
        'host_id': carol.userId,
        'host_name': 'Carol',
        'original_host_id': alice.userId,
        'reason': 'handover',
      });
      expect(
        await t
            .lobbyWire(dave)
            .waitForEvent(
              'host_changed',
              after: lobbyMark,
              timeout: eventTimeout,
            ),
        change,
      );

      // HTTP and the oracle agree with the event.
      final lobby = await t.lobby(dave);
      expect((lobby['host'] as Map)['id'], carol.userId);
      expect(lobby['original_host_id'], alice.userId);
      expect(lobby['is_acting_host'], isTrue);
      for (final p in [alice, bob, carol, dave]) {
        final view = await t.me(p);
        expect(view['host_id'], carol.userId, reason: p.displayName);
        expect(view['is_host'], p == carol, reason: p.displayName);
      }
      expect(_hosts(await t.oracleJson()), [carol.userId]);

      // The acting host can do host things; a normal player still cannot.
      await expectLater(
        t.hostAction(dave, 'advance-wave'),
        throwsA(isA<ForbiddenException>()),
      );
      expect(await t.phase(), 'night');
      await t.hostAction(carol, 'advance-wave');
      expect(await t.phase(), 'discussion');
      await expectLater(
        t.hostAction(dave, 'end-discussion'),
        throwsA(isA<ForbiddenException>()),
      );
      await t.hostAction(carol, 'end-discussion');
      expect(await t.phase(), 'voting');

      // The owner is back: the role returns at once, to her and nobody else.
      final backMark = t.gameWire(carol).mark;
      final backLobbyMark = t.lobbyWire(carol).mark;
      await t.connectGame(alice);
      final returned = await t
          .gameWire(carol)
          .waitForEvent('host_changed', after: backMark, timeout: eventTimeout);
      expect(returned, {
        'type': 'host_changed',
        'host_id': alice.userId,
        'host_name': 'Alice',
        'original_host_id': alice.userId,
        'reason': 'returned',
      });
      expect(
        await t
            .lobbyWire(carol)
            .waitForEvent(
              'host_changed',
              after: backLobbyMark,
              timeout: eventTimeout,
            ),
        returned,
      );
      final lobbyBack = await t.lobby(carol);
      expect((lobbyBack['host'] as Map)['id'], alice.userId);
      expect(lobbyBack['is_acting_host'], isFalse);
      expect((await t.me(alice))['is_host'], isTrue);
      expect((await t.me(carol))['is_host'], isFalse);
      await expectLater(
        t.hostAction(carol, 'reveal-votes'),
        throwsA(isA<ForbiddenException>()),
      );
      await t.hostAction(alice, 'reveal-votes');
      expect(await t.phase(), 'results');
    });

    test('the handover timer is armed only while the owner has NO socket '
        '(a lobby socket alone keeps it off), and the owner coming back '
        'cancels it before it fires: nobody is told anything', () async {
      final t = await _openTable({
        'host_handover_seconds': _longGrace,
        'disconnect_grace_seconds': 0,
      });
      addTearDown(t.closeAll);
      final alice = t.player('Alice'), carol = t.player('Carol');
      final dave = t.player('Dave');
      for (final p in [alice, carol, dave]) {
        await t.connectGame(p);
        await t.connectLobby(p);
      }
      final box = TimeBox('the handover period', _longGraceDuration);
      final marks = {
        for (final p in [carol, dave]) p: t.gameWire(p).mark,
      };

      // Her game socket goes, her lobby socket stays: she is still reachable.
      await t.dropGame(alice);
      await _presence(t.gameWire(carol), alice, false);
      expect((await t.presenceAsSeenBy(carol))[alice.userId], isFalse);
      expect(
        await box.readInside(t.pendingTimers),
        isNot(contains('host_handover')),
      );

      // The lobby socket goes too: now the countdown starts.
      await t.dropLobby(alice);
      await pollUntil(
        () async => (await t.pendingTimers()).contains('host_handover'),
        reason: 'the handover timer to be armed',
        timeout: eventTimeout,
      );

      // She comes back inside the period: the timer is gone, nothing was said.
      final back = t.gameWire(carol).mark;
      await t.connectGame(alice);
      await _presence(t.gameWire(carol), alice, true, after: back);
      await pollUntil(
        () async => !(await t.pendingTimers()).contains('host_handover'),
        reason: 'the handover timer to be cancelled',
        timeout: eventTimeout,
      );
      await box.readInside(() async {});
      for (final p in [carol, dave]) {
        expect(
          [
            for (final e in t.gameWire(p).events.skip(marks[p]!))
              if (e['type'] == 'host_changed') e,
          ],
          isEmpty,
          reason: '${p.displayName} was told the host changed',
        );
        expect(t.lobbyWire(p).ofType('host_changed'), isEmpty);
      }
      expect((await t.lobby(carol))['is_acting_host'], isFalse);
      expect((await t.me(alice))['is_host'], isTrue);
    });

    test('an acting host who drops hands the role on to the next connected '
        'member, never back to the absent owner', () async {
      final t = await _openTable({
        'host_handover_seconds': 1,
        'disconnect_grace_seconds': 0,
      });
      addTearDown(t.closeAll);
      final alice = t.player('Alice'), carol = t.player('Carol');
      final dave = t.player('Dave');
      for (final p in [alice, carol, dave]) {
        await t.connectGame(p);
        await t.connectLobby(p);
      }
      var mark = t.gameWire(dave).mark;
      await t.dropGame(alice);
      await t.dropLobby(alice);
      final first = await t
          .gameWire(dave)
          .waitForEvent('host_changed', after: mark, timeout: _handoverTimeout);
      expect(first['host_id'], carol.userId);

      mark = t.gameWire(dave).mark;
      await t.dropGame(carol);
      await t.dropLobby(carol);
      final second = await t
          .gameWire(dave)
          .waitForEvent('host_changed', after: mark, timeout: _handoverTimeout);
      expect(second, {
        'type': 'host_changed',
        'host_id': dave.userId,
        'host_name': 'Dave',
        'original_host_id': alice.userId,
        'reason': 'handover',
      });
      final lobby = await t.lobby(dave);
      expect((lobby['host'] as Map)['id'], dave.userId);
      expect(lobby['is_acting_host'], isTrue);
      expect(_hosts(await t.oracleJson()), [dave.userId]);
      await t.hostAction(dave, 'advance-wave');
      expect(await t.phase(), 'discussion');
    });

    test('an acting host reopens the finished table and deals the next game; '
        'a normal player cannot', () async {
      final t = await _openTable({
        'host_handover_seconds': 1,
        'disconnect_grace_seconds': 0,
      });
      addTearDown(t.closeAll);
      await _connectEveryone(t);
      final alice = t.player('Alice'), bob = t.player('Bob');
      final carol = t.player('Carol');
      await _playNight(t);
      await _playDay(t);

      final mark = t.gameWire(carol).mark;
      await t.dropGame(alice);
      // Bob is the first connected member after the owner in join order.
      final change = await t
          .gameWire(carol)
          .waitForEvent('host_changed', after: mark, timeout: _handoverTimeout);
      expect(change['host_id'], bob.userId);
      expect(change['reason'], 'handover');
      expect((await t.lobby(carol))['is_acting_host'], isTrue);

      await expectLater(t.playAgain(carol), throwsA(isA<ForbiddenException>()));
      final oldGame = t.gameId;
      final body = await t.playAgain(bob);
      expect(body['status'], 'waiting');
      await expectLater(t.startGame(carol), throwsA(isA<ForbiddenException>()));
      final started = await t.startGame(bob);
      expect(started['game_id'], isNot(oldGame));
      expect((await t.oracleJson())['phase'], 'night');
      expect((await t.lobby(carol))['status'], 'in_game');
    });
  });

  group('API: missed night results', () {
    test('a Doppelganger offline when window 1 closes gets BOTH her window 1 '
        'results from /me/ and nothing for the window still open', () async {
      final t = await LiveTable.open(
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
        protocolTwo: true,
        // Window 1 has a real timer for the hook to fire; grace is off.
        timerSettings: {
          ...fastTimers,
          'card_look_seconds': 0,
          'night_doppelganger_window_seconds': 600,
          'disconnect_grace_seconds': 0,
        },
      );
      addTearDown(t.closeAll);
      final alice = t.player('Alice'), bob = t.player('Bob');
      final carol = t.player('Carol');
      await t.connectGame(alice);
      await t.connectGame(bob);

      // Her look (copying the Seer), then her follow-up (looking at Carol).
      await _choose(t, alice, [
        {'player_id': bob.userId},
      ]);
      await _choose(t, alice, [
        {'player_id': carol.userId},
      ]);
      // Window 1 is still open: her /me/ has her look (she needed it to
      // choose), not the follow-up, which resolves when the window closes.
      final open = (await t.me(alice))['night_results'] as List;
      expect(open.single['revealed_info']['copied_role'], 'Seer');

      final mark = t.gameWire(bob).mark;
      await t.dropGame(alice);
      await _presence(t.gameWire(bob), alice, false, after: mark);
      expect(_connected(await t.oracleJson())[alice.userId], isFalse);
      expect(await t.controller.fireTimer(TimerKey.wave(1)), isTrue);

      // Window 2 is open and she is offline: her two window 1 results are
      // there, in order, and nothing else; Bob (a window 2 actor) has none yet.
      final view = await t.me(alice);
      expect(view['current_wave'], 2);
      final results = (view['night_results'] as List).cast<Map>();
      expect(results, hasLength(2));
      expect(results[0]['action_type'], 'peek_player');
      expect((results[0]['revealed_info'] as Map)['copied_role'], 'Seer');
      expect(results[1]['action_type'], 'peek_player');
      expect((results[1]['revealed_info'] as Map)['role'], 'Werewolf');
      expect(results[0]['wave'], results[1]['wave']);
      expect((await t.me(bob))['night_results'], isEmpty);
    });
  });
}

// -----------------------------------------------------------------------------
// Times
// -----------------------------------------------------------------------------

/// The grace period of the scenarios that wait it out. Long enough that the few
/// HTTP calls made inside it are a small fraction (a [TimeBox] fails as
/// inconclusive otherwise).
const _graceSeconds = 8;
const _grace = Duration(seconds: _graceSeconds);

/// For scenarios that must NOT reach the end of the period: it never does.
const _longGrace = 30;
const _longGraceDuration = Duration(seconds: _longGrace);

/// The handover scenarios set 1 s; the wait covers it and a slow server.
const _handoverTimeout = Duration(seconds: 15);

/// How far apart the two close times of the hidden-information test may be
/// (both are the grace period plus the server's scheduling).
const _closeSpread = Duration(seconds: 2);

// -----------------------------------------------------------------------------
// The table every lifecycle scenario plays at
// -----------------------------------------------------------------------------

const _names = ['Alice', 'Bob', 'Carol', 'Dave'];

/// 4 players + 3 center cards. Alice (the owner and host) is the only dealt
/// Werewolf, so she is alone and may look at a center card.
const _roleCounts = {
  'Werewolf': 2,
  'Seer': 1,
  'Drunk': 1,
  'Villager': 2,
  'Troublemaker': 1,
};
const _dealt = {
  'Alice': 'Werewolf',
  'Bob': 'Seer',
  'Carol': 'Drunk',
  'Dave': 'Villager',
};
const _center = ['Werewolf', 'Villager', 'Troublemaker'];

/// A started table. [extra] timer settings go on top of [fastTimers].
Future<LiveTable> _openTable([Map<String, int> extra = const {}]) =>
    LiveTable.open(
      playerNames: _names,
      roleCounts: _roleCounts,
      playerRolesByName: _dealt,
      centerCards: _center,
      // No look stage: the deal opens window 2 at once (the timing scenarios
      // count from the deal).
      timerSettings: {...fastTimers, 'card_look_seconds': 0, ...extra},
      protocolTwo: true,
    );

/// Opens every player's game socket (and, with [lobby], lobby socket).
Future<void> _connectEveryone(LiveTable t, {bool lobby = false}) async {
  for (final p in t.table.players) {
    await t.connectGame(p);
    if (lobby) await t.connectLobby(p);
  }
}

/// [player]'s one `choose` for the open window (naming the stage and the
/// prompt's `chosen` their `/me/` shows).
Future<void> _choose(
  LiveTable t,
  DebugPlayer player, [
  List<Map<String, Object>> picks = const [],
]) => t.controller.stagedAs(player, 'action', {
  'action_type': 'choose',
  'picks': picks,
});

/// The lone Werewolf's look at the first centre card.
const _center0 = {'center_index': 0};

/// [voter] picks [target] and locks in one request.
Future<void> _vote(LiveTable t, DebugPlayer voter, DebugPlayer target) => t
    .controller
    .stagedAs(voter, 'vote', {'target_player_id': target.userId, 'lock': true});

/// Waits for [about]'s `player_presence` (connected or not) on [wire].
Future<Map<String, dynamic>> _presence(
  PlayerWire wire,
  DebugPlayer about,
  bool connected, {
  int after = 0,
}) => wire.waitForEvent(
  'player_presence',
  where: (e) => e['player_id'] == about.userId && e['connected'] == connected,
  after: after,
  timeout: eventTimeout,
);

Future<Map<String, dynamic>> _phaseChange(
  PlayerWire wire,
  String phase, {
  int after = 0,
  Duration timeout = eventTimeout,
}) => wire.waitForEvent(
  'phase_change',
  where: (e) => e['phase'] == phase,
  after: after,
  timeout: timeout,
);

/// Window 2 with everyone present: the lone Werewolf looks at the center, the
/// Seer picks nothing, the Drunk swaps with the middle card, the Villager has
/// nothing to choose. The window closes when the last phone has chosen.
Future<void> _playNight(LiveTable t) async {
  final alice = t.player('Alice');
  final mark = t.gameWire(alice).mark;
  await _choose(t, alice, [_center0]);
  await _choose(t, t.player('Bob'));
  await _choose(t, t.player('Carol'), [
    {'center_index': 1},
  ]);
  await _choose(t, t.player('Dave'));
  await _phaseChange(t.gameWire(alice), 'discussion', after: mark);
}

/// Discussion to results: the host ends the talk, everyone votes, the last vote
/// reveals.
Future<void> _playDay(LiveTable t) async {
  final alice = t.player('Alice'), wire = t.gameWire(alice);
  var mark = wire.mark;
  await t.hostAction(alice, 'end-discussion');
  await _phaseChange(wire, 'voting', after: mark);
  mark = wire.mark;
  final target = t.player('Bob');
  for (final p in t.table.players) {
    await _vote(t, p, p == target ? alice : target);
  }
  await wire.waitForEvent('game_results', after: mark, timeout: eventTimeout);
}

/// A table where [dropped] loses their phone, then every other phone chooses
/// (Dave has nothing to choose). The window must still be open when they have, for
/// the whole grace period. Returns how long after the drop it closed and what
/// Alice's phone was told up to and including the discussion.
Future<({Duration closedAfter, List<String> trace})> _dropThenEveryoneElseActs(
  String dropped,
) async {
  final t = await _openTable({'disconnect_grace_seconds': _graceSeconds});
  addTearDown(t.closeAll);
  await _connectEveryone(t);
  final alice = t.player('Alice'), wire = t.gameWire(alice);
  final player = t.player(dropped);

  final grace = TimeBox('the grace period', _grace);
  final mark = wire.mark;
  await t.dropGame(player);
  await _presence(wire, player, false, after: mark);
  final picks = <String, List<Map<String, Object>>>{
    'Alice': [_center0],
    'Bob': [],
    'Carol': [
      {'center_index': 1},
    ],
    'Dave': [],
  };
  for (final entry in picks.entries) {
    if (entry.key != dropped) {
      await _choose(t, t.player(entry.key), entry.value);
    }
  }

  final state = await grace.readInside(t.oracleJson);
  expect(
    [state['phase'], state['current_wave']],
    ['night', 2],
    reason: 'with $dropped dropped, the window must wait for the grace period',
  );
  expect(
    await grace.readInside(t.pendingTimers),
    contains('grace:${player.userId}'),
  );

  await _phaseChange(wire, 'discussion', after: mark, timeout: grace.timeout);
  final closedAfter = grace.elapsed;
  grace.expectOver('the window with $dropped dropped closed early');
  final trace = wire.trace;
  return (
    closedAfter: closedAfter,
    trace: trace.sublist(0, trace.indexOf('phase_change:discussion') + 1),
  );
}

// -----------------------------------------------------------------------------
// Reading the oracle
// -----------------------------------------------------------------------------

Map<String, dynamic> _player(Map<String, dynamic> oracle, DebugPlayer p) =>
    ((oracle['players'] as List).cast<Map<String, dynamic>>()).firstWhere(
      (e) => e['user_id'] == p.userId,
    );

Map<int, bool> _connected(Map<String, dynamic> oracle) => {
  for (final p in (oracle['players'] as List).cast<Map<String, dynamic>>())
    p['user_id'] as int: p['connected'] as bool,
};

List<int> _hosts(Map<String, dynamic> oracle) => [
  for (final p in (oracle['players'] as List).cast<Map<String, dynamic>>())
    if (p['is_host'] == true) p['user_id'] as int,
];

List<int> _playerIds(Map<String, dynamic> oracle) => [
  for (final p in (oracle['players'] as List).cast<Map<String, dynamic>>())
    p['user_id'] as int,
]..sort();

List<int> _memberIds(Map<String, dynamic> lobby) => [
  for (final m in (lobby['players'] as List).cast<Map<String, dynamic>>())
    (m['user'] as Map)['id'] as int,
]..sort();
