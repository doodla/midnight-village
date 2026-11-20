@Tags(['e2e'])
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/api_exception.dart';
import 'package:midnight_village/core/debug/debug_api_client.dart';
import 'package:midnight_village/core/debug/debug_models.dart';

import 'harness/harness_config.dart';
import 'harness/live_table.dart';
import 'harness/night_wire.dart';
import 'harness/time_budget.dart';

/// API runner, night protocol 2: the look stage, the choose night (a plain table
/// and a Doppelganger table), lock-in voting, ready to vote and the automatic
/// deck, through the real server over real HTTP and real WebSockets.
///
/// Every scenario asserts what the clients are told (HTTP bodies, the events on
/// each socket) AND the truth in the oracle. Nothing is slept on: a test waits
/// for the event or the oracle state the server produces, bounded by
/// [eventTimeout]. The server's own windows are set to 600 s and closed by the
/// all-tap rule or the fire-timer hook, so no real clock decides a result.
void main() {
  setUpAll(HarnessConfig.setUp);

  const eventsOfTheOriginalNight = {
    'action_prompt',
    'action_result',
    'wave_waiting',
    'wave_start',
  };

  group('API: night protocol 2', () {
    test('look stage, one choose from every phone, ready to vote and a '
        'lock-in vote', () async {
      final t = await LiveTable.open(
        playerNames: ['Alice', 'Bob', 'Cara', 'Dan', 'Eve'],
        roleCounts: {
          'Werewolf': 2,
          'Seer': 1,
          'Robber': 1,
          'Troublemaker': 1,
          'Villager': 3,
        },
        playerRolesByName: {
          'Alice': 'Seer',
          'Bob': 'Robber',
          'Cara': 'Werewolf',
          'Dan': 'Troublemaker',
          'Eve': 'Villager',
        },
        centerCards: ['Werewolf', 'Villager', 'Villager'],
        timerSettings: {
          'night_protocol': 2,
          'card_look_seconds': 100,
          'night_wave_seconds': 600,
          'night_min_window_seconds': 0,
          'night_doppelganger_window_seconds': 0,
          'discussion_seconds': 0,
          'voting_seconds': 0,
        },
      );
      addTearDown(t.closeAll);
      final players = t.table.players;
      for (final p in players) {
        await t.connectGame(p);
      }
      final alice = t.player('Alice'), bob = t.player('Bob');
      final cara = t.player('Cara'), dan = t.player('Dan');
      final eve = t.player('Eve');
      String game(String tail) => '/onuw/games/${t.gameId}/$tail/';

      // -- the look stage: nothing opened, everyone is counted ------------
      final stage = await t.me(alice);
      expect(stage['phase'], 'night');
      expect(stage['current_wave'], 0);
      expect(stage['progress'], {'stage': 'look', 'done': 0, 'needed': 5});
      expect(stage['action_prompt'], isNull);
      await expectLater(
        t.client.post(
          game('ready'),
          token: alice.accessToken,
          data: {'ready': false},
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.code,
            'code',
            'bad_request',
          ),
        ),
      );
      final marks = {for (final p in players) p.userId: t.gameWire(p).mark};
      for (final p in [alice, bob, cara, dan]) {
        final body = await t.client.post(
          game('ready'),
          token: p.accessToken,
          data: {'ready': true},
        );
        expect(body, {'status': 'ok', 'ready': true});
      }
      expect((await t.me(alice))['current_wave'], 0);
      await t.client.post(
        game('ready'),
        token: eve.accessToken,
        data: {'ready': true},
      );

      // -- window 2 opens with ONE group event, the same for every phone -----
      final opened = <Map<String, dynamic>>[];
      for (final p in players) {
        opened.add(
          await t
              .gameWire(p)
              .waitForEvent(
                'night_window',
                after: marks[p.userId]!,
                timeout: eventTimeout,
              ),
        );
      }
      expect(opened.map(jsonEncode).toSet().length, 1, reason: 'one event, the same bytes');
      expect(opened.first['window'], 2);

      // Every phone reads its own prompt from /me/; none got a prompt event.
      final kinds = {
        for (final p in players)
          p.displayName: (await t.me(p))['action_prompt']['kind'],
      };
      expect(kinds, {
        'Alice': 'seer',
        'Bob': 'robber',
        'Cara': 'lone_werewolf',
        'Dan': 'troublemaker',
        'Eve': 'none',
      });

      Future<Map<String, dynamic>> choose(
        DebugPlayer p,
        List<Map<String, Object>> picks,
      ) => t.client.post(
        game('action'),
        token: p.accessToken,
        data: {'action_type': 'choose', 'picks': picks},
      );
      Map<String, Object> other(DebugPlayer p) => {'player_id': p.userId};

      final answers = [
        await choose(alice, [other(cara)]),
        await choose(eve, [
          {'self': true},
        ]),
        await choose(bob, [
          {'center_index': 0},
        ]),
        await choose(cara, [
          {'center_index': 0},
        ]),
      ];
      expect(
        answers.every((a) => a.length == 1 && a['status'] == 'submitted'),
        isTrue,
        reason: 'the same answer for every role',
      );
      await expectLater(
        choose(alice, []),
        throwsA(
          isA<UnhandledHttpException>().having((e) => e.statusCode, 's', 409),
        ),
      );
      expect((await t.me(alice))['action_prompt']['chosen'], 1);
      expect(await t.phase(), 'night', reason: 'Dan has not chosen');
      await choose(dan, [other(alice), other(bob)]);

      // The last choose closed it; the table reads the results from /me/.
      await pollUntil(
        () async => await t.phase() == 'discussion',
        reason: 'the window to close when every phone has chosen',
        timeout: eventTimeout,
      );
      final seen = (await t.me(alice))['night_results'] as List;
      expect(seen.single['revealed_info']['role'], 'Werewolf');
      expect(
        ((await t.me(cara))['night_results'] as List)
            .single['revealed_info']['center_card'],
        {'index': 0, 'role': 'Werewolf'},
      );
      expect((await t.me(eve))['night_results'], isEmpty);
      for (final p in players) {
        final heard = t.gameWire(p).events.map((e) => e['type']).toSet();
        expect(
          heard.intersection(eventsOfTheOriginalNight),
          isEmpty,
          reason: '${p.displayName} must hear no per-player night event',
        );
      }

      // -- the talk: ready to vote ends it when every phone has tapped --------
      expect((await t.me(alice))['progress'], {
        'stage': 'talk',
        'done': 0,
        'needed': 5,
      });
      for (final p in [alice, bob, cara, dan]) {
        await t.client.post(
          game('ready'),
          token: p.accessToken,
          data: {'ready': true},
        );
      }
      await t.client.post(
        game('ready'),
        token: dan.accessToken,
        data: {'ready': false},
      );
      expect(await t.phase(), 'discussion');
      await t.client.post(
        game('ready'),
        token: dan.accessToken,
        data: {'ready': true},
      );
      expect(await t.phase(), 'discussion', reason: 'Eve is not ready');
      await t.client.post(
        game('ready'),
        token: eve.accessToken,
        data: {'ready': true},
      );
      expect(await t.phase(), 'voting');

      // -- the vote: pick, re-pick, lock ---------------------------------
      Future<Map<String, dynamic>> vote(
        DebugPlayer p,
        DebugPlayer target, {
        bool? lock,
      }) => t.client.post(
        game('vote'),
        token: p.accessToken,
        data: {
          'target_player_id': target.userId,
          ...?(lock == null ? null : {'lock': lock}),
        },
      );
      final bobMark = t.gameWire(bob).mark;
      expect(await vote(alice, cara, lock: false), {
        'status': 'picked',
        'target_player_id': cara.userId,
      });
      expect(await vote(alice, dan, lock: false), {
        'status': 'picked',
        'target_player_id': dan.userId,
      });
      expect((await t.me(alice))['my_vote'], {
        'target_player_id': dan.userId,
        'locked': false,
      });
      expect((await t.me(bob))['my_vote'], isNull);
      expect(
        t
            .gameWire(bob)
            .events
            .skip(bobMark)
            .where((e) => e['type'] == 'progress'),
        isEmpty,
        reason: 'a pick sends nothing to anyone',
      );
      expect(await vote(alice, dan), {'status': 'submitted'});
      final progress = await t
          .gameWire(bob)
          .waitForEvent(
            'progress',
            after: bobMark,
            where: (e) => e['stage'] == 'vote',
            timeout: eventTimeout,
          );
      expect(progress, {
        'type': 'progress',
        'stage': 'vote',
        'done': 1,
        'needed': 5,
      });
      await expectLater(
        vote(alice, cara),
        throwsA(
          isA<UnhandledHttpException>().having((e) => e.statusCode, 's', 409),
        ),
      );
      for (final p in [bob, dan, eve, cara]) {
        await vote(p, p == cara ? dan : cara);
      }
      expect(await t.phase(), 'results');
      final oracle = await t.oracleJson();
      expect((oracle['votes'] as Map)['${alice.userId}'], dan.userId);
      expect(
        (oracle['vote_locked'] as Map).values.every((v) => v == true),
        isTrue,
      );
    });

    test('a Doppelganger table: window 1 takes two chooses from every phone, '
        'her look is read at once, nobody hears a per-player event', () async {
      final t = await LiveTable.open(
        playerNames: ['Alice', 'Bob', 'Cara', 'Dan', 'Eve'],
        roleCounts: {
          'Doppelganger': 1,
          'Seer': 1,
          'Werewolf': 2,
          'Villager': 2,
          'Drunk': 1,
          'Tanner': 1,
        },
        playerRolesByName: {
          'Alice': 'Doppelganger',
          'Bob': 'Seer',
          'Cara': 'Werewolf',
          'Dan': 'Villager',
          'Eve': 'Drunk',
        },
        centerCards: ['Werewolf', 'Villager', 'Tanner'],
        timerSettings: {
          'night_protocol': 2,
          'card_look_seconds': 0,
          'night_wave_seconds': 600,
          'night_min_window_seconds': 0,
          'night_doppelganger_window_seconds': 600,
          'discussion_seconds': 0,
          'voting_seconds': 0,
        },
      );
      addTearDown(t.closeAll);
      final players = t.table.players;
      for (final p in players) {
        await t.connectGame(p);
      }
      final alice = t.player('Alice'), bob = t.player('Bob');
      String game(String tail) => '/onuw/games/${t.gameId}/$tail/';
      Future<Map<String, dynamic>> choose(
        DebugPlayer p,
        List<Map<String, Object>> picks,
      ) => t.client.post(
        game('action'),
        token: p.accessToken,
        data: {'action_type': 'choose', 'picks': picks},
      );

      var me = await t.me(alice);
      expect(me['current_wave'], 1);
      expect(me['action_prompt']['kind'], 'doppelganger_look');
      expect((await t.me(bob))['action_prompt']['kind'], 'none');

      // Her first choose is the look: resolved at once, in /me/, not by event.
      await choose(alice, [
        {'player_id': bob.userId},
      ]);
      me = await t.me(alice);
      expect(me['night_results'].single['revealed_info'], {
        'target_name': 'Bob',
        'role': 'Seer',
        'copied_role': 'Seer',
      });
      expect(me['action_prompt']['kind'], 'seer');
      expect(me['action_prompt']['chosen'], 1);
      await choose(alice, [
        {'center_index': 0},
        {'center_index': 1},
      ]);

      // Every other phone also sends two, and a third is refused for all.
      for (final p in players.where((p) => p != alice)) {
        await choose(p, []);
        await choose(p, [
          {'self': true},
        ]);
      }
      await expectLater(
        choose(bob, []),
        throwsA(
          isA<UnhandledHttpException>().having((e) => e.statusCode, 's', 409),
        ),
      );
      expect((await t.me(alice))['current_wave'], 1, reason: 'a fixed window');

      expect(await t.controller.fireTimer(TimerKey.wave(1)), isTrue);
      await pollUntil(
        () async => (await t.me(alice))['current_wave'] == 2,
        reason: 'window 2 to open',
        timeout: eventTimeout,
      );
      final results = (await t.me(alice))['night_results'] as List;
      expect(results.map((r) => r['action_type']), [
        'peek_player',
        'peek_center',
      ]);
      expect(results.last['revealed_info']['roles'], ['Werewolf', 'Villager']);

      for (final p in players) {
        await choose(p, []);
      }
      await pollUntil(
        () async => await t.phase() == 'discussion',
        reason: 'window 2 to close when every phone has chosen',
        timeout: eventTimeout,
      );
      for (final p in players) {
        final heard = t.gameWire(p).events.map((e) => e['type']).toSet();
        expect(heard.intersection(eventsOfTheOriginalNight), isEmpty);
      }
      final windows = t
          .gameWire(alice)
          .events
          .where((e) => e['type'] == 'night_window')
          .map((e) => e['window']);
      expect(windows, containsAllInOrder([2]));
    });

    for (final (players, chip, expected) in [
      (
        5,
        'classic',
        {
          'Werewolf': 2,
          'Seer': 1,
          'Robber': 1,
          'Troublemaker': 1,
          'Drunk': 1,
          'Insomniac': 1,
          'Villager': 1,
        },
      ),
      (
        9,
        'chaos',
        {
          'Doppelganger': 1,
          'Werewolf': 2,
          'Minion': 1,
          'Seer': 1,
          'Robber': 1,
          'Troublemaker': 1,
          'Mason': 2,
          'Drunk': 1,
          'Insomniac': 1,
          'Tanner': 1,
        },
      ),
    ]) {
      test('the server builds the $chip deck for $players players at the deal '
          '(lobby defaults v2)', () async {
        final clients = harnessClients();
        final client = clients.client;
        final guests = <Map<String, dynamic>>[];
        for (var i = 0; i < players; i++) {
          guests.add(
            await client.post(
              '/auth/guest/',
              token: '',
              data: {'display_name': 'Guest${i + 1}'},
            ),
          );
        }
        String token(int i) => guests[i]['access'] as String;
        final lobby = await client.post(
          '/lobbies/',
          token: token(0),
          data: {'game_type': 'onuw', 'defaults': 'v2'},
        );
        final code = lobby['code'] as String;
        expect(lobby['settings']['deck'], 'auto');
        expect(lobby['settings']['night_protocol'], 2);
        for (var i = 1; i < players; i++) {
          await client.post('/lobbies/$code/join/', token: token(i));
        }
        for (var i = 0; i < players; i++) {
          await client.post('/lobbies/$code/ready/', token: token(i));
        }
        await client.patch(
          '/lobbies/$code/',
          token: token(0),
          data: {
            'settings': {'deck_chip': chip},
          },
        );

        final started = await client.post(
          '/onuw/lobbies/$code/start/',
          token: token(0),
          data: {
            'debug': {'seed': 7},
          },
        );
        final me = await client.get(
          '/onuw/games/${started['game_id']}/me/',
          token: token(1),
        );

        expect({
          for (final r in (me['roles_in_game'] as List))
            (r as Map)['role'] as String: r['count'] as int,
        }, expected);
        expect(me['phase'], 'night');
        expect(me['current_wave'], 0, reason: 'the look stage');
      });
    }
  });
}
