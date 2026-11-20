import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';
import 'package:midnight_village/features/game/presentation/protocol_two_game.dart';
import 'package:midnight_village/features/game/presentation/table_screen.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/from_sample.dart';
import '../../../helpers/contract/sample_sets.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/protocol_two_setup.dart';
import 'package:midnight_village/features/lobby/presentation/where_am_i_provider.dart';

/// What `/me/table/` answers while [me]'s game runs.
TableView tableDuring(GameMe me) => TableView.fromMyTable(
  FromSample.myTable(
    serverMyTable(
      code: me.lobbyCode,
      status: me.phase == GamePhase.results ? 'finished' : 'in_game',
      isHost: me.isHost,
      gameId: me.gameId,
      phase: me.phase.server,
    ),
  ),
);

/// A recorded game socket event.
Map<String, dynamic> event(String name) => ContractSamples.map('ws/game/$name');

/// [me] with its prompt's values changed (a state the recorder has no
/// sample of yet, reached by changing values only).
Map<String, dynamic> withPrompt(
  Map<String, dynamic> me,
  Map<String, dynamic> values,
) => withValues(me, {
  'action_prompt': withValues(
    (me['action_prompt'] as Map).cast<String, dynamic>(),
    values,
  ),
});

/// Everything on screen, to compare two phones.
Object view(ProtocolTwoGame game) {
  final me = game.me;
  return (
    screenFor(tableDuring(game.server), me: me),
    me.phase,
    me.window,
    me.stage,
    me.deadline,
    me.progress,
    me.ready,
    me.myVote,
    me.prompt?.stage,
    me.prompt?.used,
    me.nightResultCount,
    me.isHost,
    [for (final lane in game.unsent) lane.name].join(','),
  );
}

void main() {
  Future<ProtocolTwoSetup> phone(
    String meName, {
    int userId = 27,
    DateTime Function()? clock,
    Map<String, dynamic>? body,
  }) async {
    final setup = ProtocolTwoSetup.create(
      body ?? recordedMe(meName),
      userId: userId,
      clock: clock,
    );
    addTearDown(setup.dispose);
    await setup.load();
    await setup.settle();
    return setup;
  }

  group('a phone that (re)starts lands from /me/ and /me/table/ alone', () {
    test('every recorded protocol-2 /me/: the screen the table says', () async {
      for (final name in protocolTwoMeSamples()) {
        final setup = await phone(name);
        final me = FromSample.gameMe(recordedMe(name));
        expect(
          setup.screen,
          TableScreen(screenFor(tableDuring(me), me: me), gameId: me.gameId),
          reason: name,
        );
        expect(setup.meFetches, 1, reason: '$name: one fetch, no events');
      }
    });

    test('an event alone never moves the screen: /me/ does', () async {
      final setup = await phone('me_talk_ready');
      setup.answerMe(recordedMe('me_talk_ready'));
      setup.ws.addServerEvent(event('phase_change_voting'));
      await setup.settle();
      expect(setup.meFetches, 2, reason: 'the event asked for /me/');
      expect(setup.screen!.screen, AppScreen.talk);
      setup.answerMe(recordedMe('me_voting_picked'));
      setup.ws.addServerEvent(event('progress_vote_open'));
      await setup.settle();
      expect(setup.screen!.screen, AppScreen.vote);
    });
  });

  group('events in any order, repeated or dropped; replies late', () {
    // Window 2 closing into the talk, as every seat heard it
    // (ws_sequence/window_2), one recorded event per type.
    const byType = {
      'progress': 'progress_talk_open',
      'night_window': 'night_window_2',
      'wave_complete': 'wave_complete_v2',
      'phase_change': 'phase_change_discussion',
    };
    const fetching = {
      'night_window_2',
      'wave_complete_v2',
      'phase_change_discussion',
    };
    final heard = ContractSamples.sequence('ws_sequence/window_2')['Ana']!;

    for (var seed = 0; seed < 16; seed++) {
      test('seed $seed: the state of a phone that just started', () async {
        final random = Random(seed);
        final live = await phone('me_choose_prompt_seer');
        final held = live.http.hold(
          method: 'GET',
          path: '/onuw/games/${live.gameId}/me/',
        );
        final events = [
          for (final type in heard)
            for (var copies = random.nextInt(3); copies > 0; copies--)
              byType[type]!,
        ]..shuffle(random);
        // The server moves on just before one event that announces it (the
        // events before it may be dropped, repeated or out of order).
        events.add(byType[heard[random.nextInt(heard.length)]]!);
        final announce = [
          for (final (i, e) in events.indexed)
            if (fetching.contains(e)) i,
        ];
        final moveAt = announce.isEmpty
            ? events.length
            : announce[random.nextInt(announce.length)];
        if (announce.isEmpty) events.add('phase_change_discussion');
        for (final (i, name) in events.indexed) {
          if (i == moveAt) {
            live.answerMe(recordedMe('me_discussion_choose_seer'));
          }
          live.ws.addServerEvent(event(name));
          // Replies cross the network late, in their own time.
          if (random.nextBool()) {
            await live.settle();
            if (held.length > 0) held.release();
          }
          if (random.nextBool()) await live.settle();
        }
        // Every reply still on its way arrives (each may bring the next).
        for (var i = 0; i < 10; i++) {
          await live.settle();
          held.releaseAll();
        }
        await live.settle();
        final cold = await phone('me_discussion_choose_seer');
        expect(view(live.game), view(cold.game));
        expect(live.screen!.screen, AppScreen.talk);
      });
    }

    test('a reply of an earlier stage, arriving late, does not win', () async {
      final setup = await phone('me_discussion_choose_seer');
      // An old answer (window 2) reaches the phone after the talk's.
      setup.answerMe(recordedMe('me_choose_prompt_seer'), table: false);
      await setup.notifier.refresh();
      expect(setup.game.server.phase, GamePhase.discussion);
    });

    test('progress applies in place; a fetch has the last word', () async {
      final setup = await phone('me_discussion_choose_villager');
      setup.ws.addServerEvent(withValues(event('progress_talk'), {'done': 3}));
      setup.ws.addServerEvent(withValues(event('progress_talk'), {'done': 3}));
      expect(setup.game.me.progress!.done, 3);
      expect(setup.meFetches, 1, reason: 'same stage: no fetch');
      setup.ws.addServerEvent(event('progress_vote_open'));
      await setup.settle();
      expect(setup.meFetches, 2, reason: 'another stage: behind, fetch');
      expect(
        setup.game.me.progress,
        FromSample.progress('talk', done: 0, needed: 5),
      );
    });

    test('presence, and a host change also asks for the table', () async {
      final setup = await phone('me_discussion_choose_villager');
      setup.ws.addServerEvent(event('player_presence_disconnected'));
      final presence = event('player_presence_disconnected');
      expect(setup.game.presence[presence['player_id']], isFalse);
      final tables = setup.tableFetches;
      setup.ws.addServerEvent(
        withValues(event('host_changed_handover'), {'host_id': 27}),
      );
      await setup.settle();
      expect(setup.game.me.hostId, 27);
      expect(setup.game.me.isHost, isTrue, reason: 'this phone is player 27');
      expect(setup.game.hostNotice, isNotNull);
      expect(setup.tableFetches, greaterThan(tables));
      setup.notifier.clearHostNotice();
      expect(setup.game.hostNotice, isNull);
    });
  });

  group('the Doppelganger: look, fetch, follow-up', () {
    test('after her look every phone fetches; her board arms again', () async {
      final look = recordedMe('me_choose_prompt_doppelganger_look');
      final followUp = recordedMe('me_choose_doppelganger_followup');
      final setup = await phone('', userId: 32, body: look);
      setup
        ..answerPost('/action/', 'game/choose_submitted_doppelganger_look')
        ..answerMe(followUp);
      final stage = setup.game.me.stage!;
      final first = setup.notifier.choose(stage, const [PlayerPick(33)]);
      expect(setup.game.me.prompt!.used, isTrue, reason: 'Chosen on the tap');
      expect((await first).forBoard, ChooseAnswer.taken);
      await setup.settle();
      expect(setup.meFetches, 2, reason: 'one fetch after a taken choose');
      // Her follow-up: the same stage, a new turn, not chosen.
      expect(setup.game.me.prompt!.turn, 1);
      expect(setup.game.me.prompt!.used, isFalse);
      // Her second choose goes out, and is shown chosen at once.
      setup.answerMe(withPrompt(followUp, {'chosen': 2}));
      setup.answerPost('/action/', 'game/choose_submitted_window1_second');
      final second = setup.notifier.choose(stage, const [
        CenterPick(0),
        CenterPick(2),
      ]);
      expect(setup.game.me.prompt!.used, isTrue);
      expect((await second).forBoard, ChooseAnswer.taken);
      await setup.settle();
      expect(setup.posts('/action/'), 2);
      expect(setup.game.server.prompt!.used, isTrue);
    });

    test('any other phone in window 1 fetches once and stays chosen', () async {
      final sleeper = recordedMe('me_choose_prompt_window1_sleeper');
      final setup = await phone('', userId: 34, body: sleeper);
      setup
        ..answerPost('/action/', 'game/choose_submitted_villager')
        ..answerMe(withPrompt(sleeper, {'chosen': 1}));
      await setup.notifier.choose(setup.game.me.stage!, const [SelfPick()]);
      await setup.settle();
      expect(setup.meFetches, 2, reason: 'the same on the wire for all');
      expect(setup.game.me.prompt!.used, isTrue);
    });
  });

  group('a choose is never sent twice for one turn', () {
    const picks = [CenterPick(0), CenterPick(2)];

    test('a double tap while it is out is declined, locally', () async {
      final setup = await phone('me_choose_prompt_seer');
      setup.answerPost('/action/', 'game/choose_submitted_seer');
      final posts = setup.http.hold(
        method: 'POST',
        path: '/onuw/games/${setup.gameId}/action/',
      );
      final stage = setup.game.me.stage!;
      final first = setup.notifier.choose(stage, picks);
      final second = await setup.notifier.choose(stage, picks);
      expect(second, isA<Declined>());
      expect((second as Declined).reason, DeclineReason.alreadyChosen);
      await setup.settle();
      posts.releaseAll();
      await first;
      final third = await setup.notifier.choose(stage, picks);
      expect(third, isA<Declined>(), reason: 'chosen: never again');
      expect(setup.posts('/action/'), 1);
    });

    test('Try again after no answer: it had landed, nothing resent', () async {
      final setup = await phone('me_choose_prompt_seer');
      setup.failPost('/action/');
      final stage = setup.game.me.stage!;
      expect(
        (await setup.notifier.choose(stage, picks)).forBoard,
        ChooseAnswer.notSent,
      );
      expect(setup.game.me.prompt!.used, isTrue, reason: 'still Chosen');
      // It did arrive: /me/ says chosen 1 (> the request's 0).
      setup.answerMe(recordedMe('me_choose_chosen'));
      final again = await setup.notifier.choose(stage, picks);
      expect(again, isA<Landed>());
      expect(setup.posts('/action/'), 1);
      expect(setup.game.me.prompt!.used, isTrue);
    });

    test(
      'Try again after no answer: not landed, the original resent',
      () async {
        final setup = await phone('me_choose_prompt_seer');
        setup.failPost('/action/');
        final stage = setup.game.me.stage!;
        await setup.notifier.choose(stage, picks);
        final firstBody = setup.lastBody('/action/');
        setup.answerPost('/action/', 'game/choose_submitted_seer');
        // The board's Try again may carry other picks: the original goes.
        final again = await setup.notifier.choose(stage, const [SelfPick()]);
        expect(again.forBoard, ChooseAnswer.taken);
        expect(setup.posts('/action/'), 2);
        expect(setup.lastBody('/action/'), firstBody);
        expect(setup.meFetches, greaterThanOrEqualTo(2), reason: 'fetch first');
      },
    );

    test('refused (4xx): armed again', () async {
      final setup = await phone('me_choose_prompt_seer');
      setup.answerPost('/action/', 'game/choose_bad_request', status: 400);
      final answer = await setup.notifier.choose(setup.game.me.stage!, picks);
      expect(answer.forBoard, ChooseAnswer.refused);
      expect(setup.game.me.prompt!.used, isFalse);
    });

    test('stale (409): stays Chosen until the fetch lands', () async {
      final setup = await phone('me_choose_prompt_seer');
      setup.answerPost('/action/', 'game/choose_wrong_stage', status: 409);
      setup.answerMe(recordedMe('me_discussion_choose_seer'));
      final fetches = setup.http.hold(
        method: 'GET',
        path: '/onuw/games/${setup.gameId}/me/',
      );
      final answer = await setup.notifier.choose(setup.game.me.stage!, picks);
      expect(answer.forBoard, ChooseAnswer.stale);
      expect(setup.game.me.prompt!.used, isTrue, reason: 'no flicker');
      await setup.settle();
      fetches.releaseAll();
      await setup.settle();
      expect(setup.game.me.phase, GamePhase.discussion);
    });

    test('an older /me/ landing after the answer does not re-arm', () async {
      final setup = await phone('me_choose_prompt_seer');
      final fetches = setup.http.hold(
        method: 'GET',
        path: '/onuw/games/${setup.gameId}/me/',
      );
      // A fetch leaves before the choose (it will say chosen 0).
      setup.ws.addServerEvent(event('night_window_2'));
      await setup.settle();
      expect(fetches.length, 1);
      setup.answerPost('/action/', 'game/choose_submitted_seer');
      await setup.notifier.choose(setup.game.me.stage!, picks);
      setup.answerMe(recordedMe('me_choose_chosen'));
      await setup.settle();
      fetches.release(); // the old reply: chosen 0
      await setup.settle();
      expect(setup.game.server.prompt!.used, isFalse);
      expect(setup.game.me.prompt!.used, isTrue);
      await setup.settle();
      fetches.releaseAll(); // the fetch after the answer: chosen 1
      await setup.settle();
      expect(setup.game.server.prompt!.used, isTrue);
    });

    test('a choose for a stage that is over is declined, not sent', () async {
      final setup = await phone('me_choose_prompt_seer');
      final answer = await setup.notifier.choose('w1.000000000007', picks);
      expect(answer, isA<Declined>());
      expect(setup.posts('/action/'), 0);
    });
  });

  group('ready and vote go out in tap order', () {
    test('ready toggled three times: one request, the latest shown', () async {
      final setup = await phone('me_discussion_choose_villager');
      setup.answerPost('/ready/', 'game/ready_talk');
      final posts = setup.http.hold(
        method: 'POST',
        path: '/onuw/games/${setup.gameId}/ready/',
      );
      final first = setup.notifier.setReady(true);
      expect(setup.game.me.ready, isTrue);
      expect(await setup.notifier.setReady(false), isA<Queued>());
      expect(setup.game.me.ready, isFalse);
      expect(await setup.notifier.setReady(true), isA<Queued>());
      await setup.settle();
      posts.releaseAll();
      await first;
      await setup.settle();
      expect(setup.posts('/ready/'), 1, reason: 'the latest is what was sent');
      expect(setup.game.me.ready, isTrue);
    });

    test('ready, then not: both go, in that order', () async {
      final setup = await phone('me_discussion_choose_villager');
      setup.answerPost('/ready/', 'game/ready_talk');
      final posts = setup.http.hold(
        method: 'POST',
        path: '/onuw/games/${setup.gameId}/ready/',
      );
      final first = setup.notifier.setReady(true);
      await setup.notifier.setReady(false);
      await setup.settle();
      expect(posts.length, 1, reason: 'one in flight at a time');
      setup.answerPost('/ready/', 'game/ready_talk_off');
      await setup.settle();
      posts.release();
      await first;
      await setup.settle();
      await setup.settle();
      posts.releaseAll();
      await setup.settle();
      final sent = [
        for (final r in setup.http.requests)
          if (r.path.endsWith('/ready/')) (r.data as Map)['ready'],
      ];
      expect(sent, [true, false]);
      expect(setup.game.me.ready, isFalse);
    });

    test('an echo that differs from the tap fetches /me/', () async {
      final setup = await phone('me_discussion_choose_villager');
      setup.answerPost('/ready/', 'game/ready_talk_off'); // echoes false
      await setup.notifier.setReady(true);
      await setup.settle();
      expect(setup.meFetches, 2);
    });

    test('a pick then a lock: the lock goes after the pick', () async {
      final setup = await phone('me_voting_picked');
      setup.answerPost('/vote/', 'game/vote_picked'); // echoes 29
      final posts = setup.http.hold(
        method: 'POST',
        path: '/onuw/games/${setup.gameId}/vote/',
      );
      final pick = setup.notifier.pickVote(29);
      expect(setup.game.me.myVote, const MyVote.local(29, locked: false));
      expect(await setup.notifier.lockVote(29), isA<Queued>());
      expect(setup.game.me.myVote, const MyVote.local(29, locked: true));
      setup.answerPost('/vote/', 'game/vote_locked_v2');
      await setup.settle();
      posts.release();
      await pick;
      await setup.settle();
      await setup.settle();
      posts.releaseAll();
      await setup.settle();
      final sent = [
        for (final r in setup.http.requests)
          if (r.path.endsWith('/vote/')) (r.data as Map)['lock'],
      ];
      expect(sent, [false, true]);
      expect(setup.lastBody('/vote/'), {
        'target_player_id': 29,
        'lock': true,
        'stage': setup.game.me.stage,
      });
    });

    test('a pick echoed for another target fetches /me/', () async {
      final setup = await phone('me_voting_picked');
      setup.answerPost('/vote/', 'game/vote_picked'); // echoes 29
      await setup.notifier.pickVote(31);
      await setup.settle();
      expect(setup.meFetches, 2);
    });

    test('refused: back to the pick the server has', () async {
      final setup = await phone('me_voting_picked');
      setup.answerPost('/vote/', 'game/vote_self_v2', status: 400);
      await setup.notifier.pickVote(27);
      expect(setup.game.me.myVote, const MyVote.local(30, locked: false));
    });

    test('locked: nothing more is sent', () async {
      final setup = await phone('me_voting_locked');
      expect(await setup.notifier.pickVote(29), isA<Declined>());
      expect(setup.posts('/vote/'), 0);
    });

    test(
      'looking cannot be taken back; looking twice is one request',
      () async {
        final setup = await phone('me_look_stage');
        expect(await setup.notifier.setReady(false), isA<Declined>());
        setup.answerPost('/ready/', 'game/ready_look');
        await setup.notifier.setReady(true);
        expect(await setup.notifier.setReady(true), isA<Declined>());
        expect(setup.posts('/ready/'), 1);
        expect(setup.lastBody('/ready/'), {
          'ready': true,
          'stage': setup.game.me.stage,
        });
      },
    );
  });

  group('"Try again" belongs to its stage', () {
    test('kept as tapped, sent again unchanged', () async {
      final setup = await phone('me_discussion_choose_villager');
      setup.failPost('/ready/');
      await setup.notifier.setReady(true);
      expect(setup.game.me.ready, isTrue);
      expect(setup.game.unsent, {OutboxLane.ready});
      setup.answerPost('/ready/', 'game/ready_talk');
      expect(
        (await setup.notifier.retry(OutboxLane.ready)).forBoard,
        ChooseAnswer.taken,
      );
      expect(setup.game.unsent, isEmpty);
      expect(setup.posts('/ready/'), 2);
    });

    test('an unsent tap dies with its stage', () async {
      final setup = await phone('me_look_stage');
      setup.failPost('/ready/');
      await setup.notifier.setReady(true);
      expect(setup.game.unsent, {OutboxLane.ready});
      setup.answerMe(recordedMe('me_choose_prompt_seer'));
      setup.ws.addServerEvent(event('night_window_2'));
      await setup.settle();
      expect(setup.game.unsent, isEmpty);
      expect(setup.game.me.ready, isNull);
      expect(await setup.notifier.retry(OutboxLane.ready), isA<Declined>());
      expect(setup.posts('/ready/'), 1);
    });
  });

  group('healing a missed close, by the server clock', () {
    final deadline = DateTime.utc(2024, 3, 7, 21, 19, 8); // w2's

    test('past the deadline: fetch, then poll until the stage moves', () async {
      final me = recordedMe('me_choose_prompt_seer');
      final setup = ProtocolTwoSetup.create(
        me,
        // The phone's clock is far off; the server's Date decides.
        clock: () => DateTime.utc(2030),
      );
      addTearDown(setup.dispose);
      setup.answerMe(me, serverDate: deadline);
      await setup.load();
      await setup.wait(const Duration(milliseconds: 100));
      expect(setup.meFetches, greaterThan(2), reason: 'polling');
      setup.answerMe(
        recordedMe('me_discussion_choose_seer'),
        serverDate: deadline.subtract(const Duration(hours: 1)),
      );
      await setup.wait(const Duration(milliseconds: 60));
      final moved = setup.meFetches;
      await setup.wait(const Duration(milliseconds: 100));
      expect(setup.meFetches, moved, reason: 'a new stage: no polling');
      expect(setup.game.me.phase, GamePhase.discussion);
    });

    test("before the deadline by the server's clock: nothing", () async {
      final me = recordedMe('me_choose_prompt_seer');
      final setup = ProtocolTwoSetup.create(
        me,
        clock: () => DateTime.utc(2030),
      );
      addTearDown(setup.dispose);
      setup.answerMe(
        me,
        serverDate: deadline.subtract(const Duration(minutes: 1)),
      );
      await setup.load();
      await setup.wait(const Duration(milliseconds: 100));
      expect(setup.meFetches, 1);
    });

    test('reconnect and resume fetch /me/ and the table', () async {
      final setup = await phone('me_talk_ready');
      final tables = setup.tableFetches;
      setup.reconnect();
      await setup.settle();
      expect(setup.meFetches, 2);
      setup.resume();
      await setup.settle();
      expect(setup.meFetches, 3);
      expect(setup.tableFetches, greaterThanOrEqualTo(tables + 2));
    });
  });

  group('the screen never sticks, never flickers', () {
    test('a first /me/ that failed is fetched again', () async {
      final me = recordedMe('me_talk_ready');
      final setup = ProtocolTwoSetup.create(me);
      addTearDown(setup.dispose);
      setup.http.answer(
        'GET',
        '/onuw/games/${setup.gameId}/me/',
        'Bad Gateway',
        status: 502,
      );
      await expectLater(setup.load(), throwsA(anything));
      setup.answerMe(me);
      await setup.wait(const Duration(milliseconds: 60));
      expect(setup.game.me.phase, GamePhase.discussion);
    });

    test(
      'while /me/ and the table are fetched again, the screen holds',
      () async {
        final setup = await phone('me_talk_ready');
        expect(setup.screen!.screen, AppScreen.talk);
        final fetches = setup.http.hold(
          method: 'GET',
          path: '/onuw/games/${setup.gameId}/me/',
        );
        final tables = setup.http.hold(method: 'GET', path: '/me/table/');
        setup.reconnect();
        await setup.settle();
        expect(fetches.length + tables.length, greaterThan(0));
        expect(setup.screen!.screen, AppScreen.talk);
        await setup.settle();
        fetches.releaseAll();
        await setup.settle();
        tables.releaseAll();
        await setup.settle();
        expect(setup.screen!.screen, AppScreen.talk);
      },
    );

    test('a /me/ ahead of the table asks for the table; once', () async {
      final setup = await phone('me_talk_ready');
      final tables = setup.tableFetches;
      // The server moved to the vote; the table answer lags behind.
      setup.answerMe(recordedMe('me_voting_picked'), table: false);
      await setup.notifier.refresh();
      await setup.settle();
      expect(setup.tableFetches, tables + 1);
      expect(setup.screen!.screen, AppScreen.vote, reason: '/me/ is ahead');
    });

    test('a table ahead of /me/ asks for /me/', () async {
      final setup = await phone('me_talk_ready');
      setup.answerMe(recordedMe('me_voting_picked'));
      // Only the table hears of it (a lobby event).
      setup.container.invalidate(myTableProvider);
      await setup.wait(const Duration(milliseconds: 20));
      expect(setup.game.me.phase, GamePhase.voting);
    });

    test(
      'a new deal: the table names the new game, which replaces it',
      () async {
        final setup = await phone('me_talk_ready');
        final next = recordedMe('me_choose_prompt_window1_sleeper');
        setup.http.answer('GET', '/onuw/games/${next['game_id']}/me/', next);
        setup.answerTable(tableOf(next));
        setup.ws.addServerEvent(event('play_again'));
        await setup.settle();
        await setup.settle();
        expect(
          setup.screen,
          TableScreen(AppScreen.nightBoard, gameId: next['game_id'] as String),
        );
      },
    );

    test('a game that is gone: 01, the table says so too', () async {
      final setup = await phone('me_talk_ready');
      setup.http.answer(
        'GET',
        '/onuw/games/${setup.gameId}/me/',
        ContractSamples.load('http/game/me_not_found'),
        status: 404,
      );
      setup.answerTable(ContractSamples.map('http/lobby/my_table_none'));
      await setup.notifier.refresh();
      await setup.settle();
      expect(setup.game.tableClosed, isTrue);
      expect(setup.screen!.screen, AppScreen.join);
    });
  });

  group('local steps cannot strand a phone', () {
    test('the deck: open at the table; a deal or play again ends it', () async {
      final setup = await phone('me_talk_ready');
      final waiting = ContractSamples.map('http/lobby/my_table_waiting');
      (waiting['table'] as Map)['is_host'] = true;
      setup.answerTable(waiting);
      setup.container.invalidate(myTableProvider);
      await setup.settle();
      expect(setup.screen!.screen, AppScreen.table);
      setup.container
          .read(localStepsProvider.notifier)
          .openDeck(FromSample.myTable(waiting)!);
      expect(setup.screen!.screen, AppScreen.deck);
      // The deal: the table plays this game now.
      setup.answerTable(tableOf(recordedMe('me_talk_ready')));
      setup.container.invalidate(myTableProvider);
      await setup.settle();
      expect(setup.screen!.screen, AppScreen.talk);
      // Play again: waiting again, after another game: the table, not 03.
      final again = ContractSamples.map('http/lobby/my_table_after_play_again');
      (again['table'] as Map)['is_host'] = true;
      setup.answerTable(again);
      setup.container.invalidate(myTableProvider);
      await setup.settle();
      expect(setup.screen!.screen, AppScreen.table);
    });

    test('who won: only for the finished game it was tapped in', () {
      final results = FromSample.myTable(
        ContractSamples.map('http/lobby/my_table_results'),
      )!;
      final record = StepRecord(wonIn: results.gameId);
      expect(localStepsFor(record, results).countSeen, isTrue);
      final again = FromSample.myTable(
        ContractSamples.map('http/lobby/my_table_after_play_again'),
      );
      expect(localStepsFor(record, again).countSeen, isFalse);
      final next = FromSample.myTable(
        serverMyTable(
          code: results.lobbyCode,
          status: 'finished',
          gameId: 'the-next-game',
          phase: 'results',
        ),
      );
      expect(localStepsFor(record, next).countSeen, isFalse);
    });
  });

  group('the rest', () {
    test('My night held: every result acknowledged, once', () async {
      final setup = await phone('me_talk_ready');
      setup.answerPost('/night-results/seen/', 'game/night_results_seen');
      await setup.notifier.acknowledgeNightResults();
      expect(setup.lastBody('/night-results/seen/'), {'seen': 1});
      expect(setup.game.me.hasUnseenResults, isFalse);
      expect(await setup.notifier.acknowledgeNightResults(), isA<Declined>());
      expect(setup.posts('/night-results/seen/'), 1);
    });

    test('a phone with nothing to acknowledge still sends its count', () async {
      final setup = await phone('me_discussion_choose_villager');
      setup.answerPost('/night-results/seen/', 'game/night_results_seen');
      await setup.notifier.acknowledgeNightResults();
      expect(setup.lastBody('/night-results/seen/'), {'seen': 0});
    });

    test('play again asks the server, then where the table is', () async {
      final setup = await phone('me_voting_locked');
      setup.http.answer(
        'POST',
        '/lobbies/${setup.game.server.lobbyCode}/play-again/',
        ContractSamples.load('http/lobby/play_again'),
      );
      final tables = setup.tableFetches;
      await setup.notifier.playAgain();
      await setup.settle();
      expect(setup.tableFetches, tables + 1);
    });
  });
}
