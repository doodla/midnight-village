@Tags(['e2e'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/api_exception.dart';
import 'package:midnight_village/core/debug/debug_models.dart';

import 'harness/harness_config.dart';
import 'harness/live_table.dart';
import 'harness/scenario_runner.dart';

/// API runner, table lifecycle: play again, dropped phones and host handover,
/// through the real server over real HTTP and real WebSockets.
///
/// Each scenario asserts BOTH what the clients are told (HTTP bodies, socket
/// events) AND the truth in the debug-state oracle. Time is never slept on: the
/// tests wait for the event the server sends. The only real clock is the
/// server's own grace / handover period, set to a few seconds per game.
void main() {
  setUpAll(HarnessConfig.setUp);

  group('API: play again', () {
    test('only the host reopens a finished table; everyone is told; the same '
        'members and settings deal a NEW game and the old one stays '
        'readable', () async {
      final t = await _openTable();
      addTearDown(t.closeAll);
      await _connectEveryone(t, lobby: true);
      final alice = t.player('Alice'), bob = t.player('Bob');

      // Not finished yet: even the host is refused (409), nothing changes.
      await expectLater(
        t.playAgain(alice),
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
      await expectLater(t.playAgain(bob), throwsA(isA<ForbiddenException>()));
      expect((await t.lobby(alice))['status'], 'finished');

      final gameMarks = {
        for (final p in t.table.players) p.userId: t.gameWire(p).mark,
      };
      final lobbyMarks = {
        for (final p in t.table.players) p.userId: t.lobbyWire(p).mark,
      };
      final body = await t.playAgain(alice);

      // Every connected client hears it, on the game socket and the lobby socket.
      for (final p in t.table.players) {
        final again = await t
            .gameWire(p)
            .waitForEvent('play_again', after: gameMarks[p.userId]!);
        expect(again['lobby_code'], t.lobbyCode, reason: p.displayName);
        final update = await t
            .lobbyWire(p)
            .waitForEvent('lobby_update', after: lobbyMarks[p.userId]!);
        expect(update['data'], body, reason: '${p.displayName} lobby_update');
      }

      // The lobby: waiting, the same members (all ready) and the same settings.
      final after = await t.lobby(alice);
      expect(after, body);
      expect(after['status'], 'waiting');
      expect(_memberIds(after), _memberIds(before));
      expect(
        (after['players'] as List).every((m) => (m as Map)['is_ready'] == true),
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
      expect(await t.playAgain(alice), body);
      await expectLater(t.startGame(bob), throwsA(isA<ForbiddenException>()));
      final lobbyMark = t.lobbyWire(bob).mark;
      final started = await t.startGame(alice);
      expect(started['game_id'], isNot(oldGame));
      final startedEvent = await t
          .lobbyWire(bob)
          .waitForEvent('game_started', after: lobbyMark);
      expect(startedEvent['game_id'], started['game_id']);

      final fresh = await t.oracleJson();
      expect(fresh['game_id'], started['game_id']);
      expect(fresh['phase'], 'night');
      expect(fresh['results'], isNull);
      expect(_playerIds(fresh), _playerIds(oldOracle));
      for (final p in t.table.players) {
        expect((await t.currentGame(p))['game_id'], started['game_id']);
      }
      // The old game is untouched by the new one.
      final old = await t.client.get(
        '/onuw/games/$oldGame/debug-state/',
        token: alice.accessToken,
      );
      expect(old['phase'], 'results');
      expect(old['results'], oldOracle['results']);
    });
  });

  group('API: dropped phone', () {
    test('a dropped Drunk: the window holds for the grace period although '
        'everyone else has acted, then closes with the server\'s swap; the '
        'phone that was offline reads its result from /me/', () async {
      const grace = 3;
      final t = await _openTable({'disconnect_grace_seconds': grace});
      addTearDown(t.closeAll);
      await _connectEveryone(t);
      final alice = t.player('Alice'), bob = t.player('Bob');
      final carol = t.player('Carol'), dave = t.player('Dave');
      final aliceWire = t.gameWire(alice);

      final clock = Stopwatch()..start();
      final mark = aliceWire.mark;
      await t.dropGame(carol);

      // What the table is told: presence, on the socket and in the player list.
      await aliceWire.waitForEvent(
        'player_presence',
        where: (e) => e['player_id'] == carol.userId && e['connected'] == false,
        after: mark,
      );
      await t
          .gameWire(bob)
          .waitForEvent(
            'player_presence',
            where: (e) =>
                e['player_id'] == carol.userId && e['connected'] == false,
          );
      final seen = await t.presenceAsSeenBy(alice);
      expect(seen[carol.userId], isFalse);
      expect(
        [
          for (final p in [alice, bob, dave]) seen[p.userId],
        ],
        [true, true, true],
      );
      // The truth: the oracle agrees, and the grace countdown is running.
      final oracle = await t.oracleJson();
      expect(_connected(oracle), {
        alice.userId: true,
        bob.userId: true,
        carol.userId: false,
        dave.userId: true,
      });
      expect(
        await t.pendingTimers(),
        containsAll(['wave:2', 'grace:${carol.userId}']),
      );

      // Everyone else acts (Dave has no action). The Drunk has not.
      await _act(t, alice, 'see_team', {'center_index': 0});
      await _act(t, bob, 'skip');
      final state = await t.oracleJson();
      expect(
        [state['phase'], state['current_wave']],
        ['night', 2],
        reason:
            'the window closed ${clock.elapsed} after the drop, inside '
            'the $grace s grace period',
      );
      for (final p in [alice, bob, dave]) {
        expect(
          t.gameWire(p).ofType('action_result'),
          isEmpty,
          reason: '${p.displayName} was told a result before the window closed',
        );
      }

      // After the grace period it closes without her.
      await aliceWire.waitForEvent(
        'phase_change',
        where: (e) => e['phase'] == 'discussion',
        after: mark,
      );
      expect(
        clock.elapsed,
        greaterThanOrEqualTo(const Duration(seconds: grace)),
        reason: 'the window closed before the grace period was over',
      );

      // The truth: her action was a timeout and the server swapped her card with
      // a seeded center card; it is logged like a chosen swap. She never sent
      // anything.
      final end = await t.oracleJson();
      final swaps = [
        for (final e in (end['night_actions_log'] as List).cast<Map>())
          if (e['player_id'] == carol.userId) e,
      ];
      expect(swaps, hasLength(1));
      expect(swaps.single['action_type'], 'swap_with_center');
      final index = (swaps.single['targets'] as Map)['center_index'] as int;
      expect(index, inInclusiveRange(0, 2));
      expect((end['center_cards'] as List)[index], 'Drunk');
      expect(
        _player(end, carol)['current_role'],
        _center[index],
        reason: 'she took the card that was in that center slot',
      );

      // She was offline when the window closed: /me/ has her result.
      final view = await t.me(carol);
      expect(view['phase'], 'discussion');
      final results = (view['night_results'] as List).cast<Map>();
      expect(results, hasLength(1));
      expect(results.single['action_type'], 'swap_with_center');
      expect(results.single['revealed_info'], {'card_index': index});
      // Nobody else's result is in it.
      for (final p in [bob, dave]) {
        final others = (await t.me(p))['night_results'] as List;
        expect(
          others.where((r) => (r as Map)['action_type'] == 'swap_with_center'),
          isEmpty,
          reason: '${p.displayName} was shown the Drunk\'s result',
        );
      }

      // Coming back after the window closed: told as present again, no timer.
      final back = aliceWire.mark;
      await t.connectGame(carol);
      await aliceWire.waitForEvent(
        'player_presence',
        where: (e) => e['player_id'] == carol.userId && e['connected'] == true,
        after: back,
      );
      expect((await t.presenceAsSeenBy(alice))[carol.userId], isTrue);
      expect(await t.pendingTimers(), isNot(contains('grace:${carol.userId}')));
    });

    test('coming back inside the grace period cancels it: presence is '
        'restored and the window waits for her normally', () async {
      const grace = 30;
      final t = await _openTable({'disconnect_grace_seconds': grace});
      addTearDown(t.closeAll);
      await _connectEveryone(t);
      final alice = t.player('Alice'), bob = t.player('Bob');
      final carol = t.player('Carol');
      final aliceWire = t.gameWire(alice);
      final clock = Stopwatch()..start();

      var mark = aliceWire.mark;
      await t.dropGame(carol);
      await aliceWire.waitForEvent(
        'player_presence',
        where: (e) => e['player_id'] == carol.userId && e['connected'] == false,
        after: mark,
      );
      expect(await t.pendingTimers(), contains('grace:${carol.userId}'));
      await _act(t, alice, 'see_team', {'center_index': 0});
      await _act(t, bob, 'skip');

      mark = aliceWire.mark;
      await t.connectGame(carol);
      await aliceWire.waitForEvent(
        'player_presence',
        where: (e) => e['player_id'] == carol.userId && e['connected'] == true,
        after: mark,
      );
      expect((await t.presenceAsSeenBy(bob))[carol.userId], isTrue);
      expect(_connected(await t.oracleJson())[carol.userId], isTrue);

      // The countdown is gone and the window is still waiting for her answer.
      final timers = await t.pendingTimers();
      expect(timers, isNot(contains('grace:${carol.userId}')));
      expect(timers, contains('wave:2'));
      expect(await t.phase(), 'night');

      // She answers herself: it closes at once, nowhere near the grace period.
      await _act(t, carol, 'swap_with_center', {'center_index': 2});
      await aliceWire.waitForEvent(
        'phase_change',
        where: (e) => e['phase'] == 'discussion',
        after: mark,
      );
      expect(clock.elapsed, lessThan(const Duration(seconds: grace)));
      final end = await t.oracleJson();
      expect(_player(end, carol)['current_role'], _center[2]);
      expect((end['center_cards'] as List)[2], 'Drunk');
      final result = t.gameWire(carol).ofType('action_result').single;
      expect(result['revealed_info'], {'card_index': 2});
    });

    test('the close time does not depend on whether the dropped player had an '
        'action: a dropped Seer and a dropped Villager hold the window for '
        'the same grace period and the table sees the same events', () async {
      const grace = 3;
      final withAction = await _dropThenEveryoneElseActs('Bob', grace);
      final withoutAction = await _dropThenEveryoneElseActs('Dave', grace);

      // Neither window closed early: not when the last other actor acted, and
      // not at any moment inside the grace period.
      expect(
        withAction.closedAfter,
        greaterThanOrEqualTo(const Duration(seconds: grace)),
      );
      expect(
        withoutAction.closedAfter,
        greaterThanOrEqualTo(const Duration(seconds: grace)),
      );
      // What Alice's phone was told while it waited is identical.
      expect(withAction.trace, withoutAction.trace);
    });

    test(
      'a dropped voter: the vote waits for the grace period although '
      'everyone else has voted, then is revealed with her as a non-voter',
      () async {
        const grace = 3;
        final t = await _openTable({'disconnect_grace_seconds': grace});
        addTearDown(t.closeAll);
        await _connectEveryone(t);
        final alice = t.player('Alice'), bob = t.player('Bob');
        final carol = t.player('Carol'), dave = t.player('Dave');
        final aliceWire = t.gameWire(alice);
        await _playNight(t);
        await t.hostAction(alice, 'end-discussion');
        await aliceWire.waitForEvent(
          'phase_change',
          where: (e) => e['phase'] == 'voting',
        );

        final clock = Stopwatch()..start();
        final mark = aliceWire.mark;
        await t.dropGame(dave);
        await aliceWire.waitForEvent(
          'player_presence',
          where: (e) =>
              e['player_id'] == dave.userId && e['connected'] == false,
          after: mark,
        );
        expect((await t.presenceAsSeenBy(alice))[dave.userId], isFalse);
        expect(await t.pendingTimers(), contains('grace:${dave.userId}'));

        await t.controller.driveAs(
          alice,
          DebugAction.vote(voteTargetUserId: bob.userId),
        );
        await t.controller.driveAs(
          bob,
          DebugAction.vote(voteTargetUserId: alice.userId),
        );
        await t.controller.driveAs(
          carol,
          DebugAction.vote(voteTargetUserId: alice.userId),
        );
        final state = await t.oracleJson();
        expect(
          state['phase'],
          'voting',
          reason:
              'revealed ${clock.elapsed} after the drop, inside the $grace s '
              'grace period',
        );
        expect(aliceWire.ofType('vote_reveal'), isEmpty);

        final reveal = await aliceWire.waitForEvent('vote_reveal', after: mark);
        expect(
          clock.elapsed,
          greaterThanOrEqualTo(const Duration(seconds: grace)),
        );
        final cast = {
          '${alice.userId}': bob.userId,
          '${bob.userId}': alice.userId,
          '${carol.userId}': alice.userId,
          '${dave.userId}': null, // the dropped player: a non-voter
        };
        expect(reveal['votes'], cast);

        // The truth: results, with Alice's two votes counted and Dave a non-voter.
        await aliceWire.waitForEvent('game_results', after: mark);
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
          .waitForEvent('host_changed', after: gameMark);
      expect(change, {
        'type': 'host_changed',
        'host_id': carol.userId,
        'host_name': 'Carol',
        'original_host_id': alice.userId,
        'reason': 'handover',
      });
      expect(
        await t.lobbyWire(dave).waitForEvent('host_changed', after: lobbyMark),
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
      final hosts = [
        for (final p in (await t.oracleJson())['players'] as List)
          if ((p as Map)['is_host'] == true) p['user_id'],
      ];
      expect(hosts, [carol.userId]);

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
          .waitForEvent('host_changed', after: backMark);
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
            .waitForEvent('host_changed', after: backLobbyMark),
        returned,
      );
      final lobbyBack = await t.lobby(carol);
      expect((lobbyBack['host'] as Map)['id'], alice.userId);
      expect(lobbyBack['is_acting_host'], isFalse);
      expect((await t.me(alice))['is_host'], isTrue);
      expect((await t.me(carol))['is_host'], isFalse);
      expect(await t.pendingTimers(), isNot(contains('host_handover')));
      await expectLater(
        t.hostAction(carol, 'reveal-votes'),
        throwsA(isA<ForbiddenException>()),
      );
      await t.hostAction(alice, 'reveal-votes');
      expect(await t.phase(), 'results');
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
          .waitForEvent('host_changed', after: mark);
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
}

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
      timerSettings: {...fastTimers, ...extra},
    );

/// Opens every player's game socket (and, with [lobby], lobby socket).
Future<void> _connectEveryone(LiveTable t, {bool lobby = false}) async {
  for (final p in t.table.players) {
    await t.connectGame(p);
    if (lobby) await t.connectLobby(p);
  }
}

Future<void> _act(
  LiveTable t,
  DebugPlayer player,
  String type, [
  Map<String, dynamic> targets = const {},
]) => t.controller.driveAs(
  player,
  DebugAction.nightAction(actionType: type, targets: targets),
);

/// Window 2 with everyone present: the lone Werewolf looks at the center, the
/// Seer skips, the Drunk swaps with the middle card. The window closes when the
/// last of them has answered.
Future<void> _playNight(LiveTable t) async {
  final alice = t.player('Alice');
  final mark = t.gameWire(alice).mark;
  await _act(t, alice, 'see_team', {'center_index': 0});
  await _act(t, t.player('Bob'), 'skip');
  await _act(t, t.player('Carol'), 'swap_with_center', {'center_index': 1});
  await t
      .gameWire(alice)
      .waitForEvent(
        'phase_change',
        where: (e) => e['phase'] == 'discussion',
        after: mark,
      );
}

/// Discussion to results: the host ends the talk, everyone votes, the last vote
/// reveals.
Future<void> _playDay(LiveTable t) async {
  final alice = t.player('Alice'), wire = t.gameWire(alice);
  var mark = wire.mark;
  await t.hostAction(alice, 'end-discussion');
  await wire.waitForEvent(
    'phase_change',
    where: (e) => e['phase'] == 'voting',
    after: mark,
  );
  mark = wire.mark;
  final target = t.player('Bob');
  for (final p in t.table.players) {
    final vote = p == target ? alice : target;
    await t.controller.driveAs(
      p,
      DebugAction.vote(voteTargetUserId: vote.userId),
    );
  }
  await wire.waitForEvent('game_results', after: mark);
}

/// A table where [dropped] loses their phone, then every other player acts
/// (Dave has nothing to do). Returns how long after the drop the window closed
/// and what Alice's phone was told while it waited.
Future<({Duration closedAfter, List<String> trace})> _dropThenEveryoneElseActs(
  String dropped,
  int grace,
) async {
  final t = await _openTable({'disconnect_grace_seconds': grace});
  addTearDown(t.closeAll);
  await _connectEveryone(t);
  final alice = t.player('Alice'), wire = t.gameWire(alice);
  final player = t.player(dropped);

  final clock = Stopwatch()..start();
  final mark = wire.mark;
  await t.dropGame(player);
  await wire.waitForEvent(
    'player_presence',
    where: (e) => e['player_id'] == player.userId && e['connected'] == false,
    after: mark,
  );
  final moves = {
    'Alice': ('see_team', {'center_index': 0}),
    'Bob': ('skip', <String, dynamic>{}),
    'Carol': ('swap_with_center', {'center_index': 1}),
  };
  for (final entry in moves.entries) {
    if (entry.key != dropped) {
      await _act(t, t.player(entry.key), entry.value.$1, entry.value.$2);
    }
  }

  final state = await t.oracleJson();
  expect(
    [state['phase'], state['current_wave']],
    ['night', 2],
    reason:
        'with $dropped dropped, the window closed ${clock.elapsed} after '
        'the drop, inside the $grace s grace period',
  );
  expect(await t.pendingTimers(), contains('grace:${player.userId}'));
  final waiting = List<String>.of(wire.trace);

  await wire.waitForEvent(
    'phase_change',
    where: (e) => e['phase'] == 'discussion',
    after: mark,
  );
  return (closedAfter: clock.elapsed, trace: waiting);
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

List<int> _playerIds(Map<String, dynamic> oracle) => [
  for (final p in (oracle['players'] as List).cast<Map<String, dynamic>>())
    p['user_id'] as int,
]..sort();

List<int> _memberIds(Map<String, dynamic> lobby) => [
  for (final m in (lobby['players'] as List).cast<Map<String, dynamic>>())
    (m['user'] as Map)['id'] as int,
]..sort();
