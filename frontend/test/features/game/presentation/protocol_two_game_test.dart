import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';
import 'package:midnight_village/features/game/domain/stage_progress.dart';
import 'package:midnight_village/features/game/presentation/protocol_two_game.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/from_sample.dart';
import '../../../helpers/contract/sample_sets.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/protocol_two_setup.dart';

/// What `/me/table/` answers while [me]'s game runs.
TableView tableDuring(GameMe me) => TableView.fromMyTable(
  FromSample.myTable(
    serverMyTable(
      code: me.lobbyCode,
      status: 'in_game',
      gameId: me.gameId,
      phase: me.phase.server,
    ),
  ),
);

/// A recorded game socket event.
Map<String, dynamic> event(String name) => ContractSamples.map('ws/game/$name');

/// What a test compares between two phones: everything on screen.
Object view(ProtocolTwoGame game) {
  final me = game.me;
  return (
    game.screenAt(tableDuring(game.server)),
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
  );
}

void main() {
  Future<ProtocolTwoSetup> phone(
    String meName, {
    DateTime Function()? clock,
  }) async {
    final setup = ProtocolTwoSetup.create(recordedMe(meName), clock: clock);
    addTearDown(setup.dispose);
    await setup.load();
    await setup.settle();
    return setup;
  }

  group('a phone that (re)starts lands from /me/ alone', () {
    test('every recorded protocol-2 /me/: the screen the table says', () async {
      for (final name in protocolTwoMeSamples()) {
        final setup = await phone(name);
        final me = FromSample.gameMe(recordedMe(name));
        expect(
          setup.game.screenAt(tableDuring(me)),
          screenFor(tableDuring(me), me: me),
          reason: name,
        );
        expect(setup.meFetches, 1, reason: '$name: one fetch, no events');
      }
    });

    test('the screen provider reads /me/table/ and /me/', () async {
      final setup = await phone('me_look_stage');
      final me = setup.game.server;
      setup.http.answer(
        'GET',
        '/me/table/',
        serverMyTable(
          code: me.lobbyCode,
          status: 'in_game',
          gameId: me.gameId,
          phase: 'night',
        ),
      );
      setup.container.listen(protocolTwoScreenProvider(me.gameId), (_, _) {});
      await setup.settle();
      expect(
        setup.container.read(protocolTwoScreenProvider(me.gameId)).value,
        AppScreen.yourCard,
      );
    });

    test('an event alone never moves the screen: /me/ does', () async {
      final setup = await phone('me_talk_ready');
      // The vote has not started on the server (the /me/ still says talk).
      setup.ws.addServerEvent(event('phase_change_voting'));
      await setup.settle();
      expect(setup.meFetches, 2, reason: 'the event asked for /me/');
      expect(
        setup.game.screenAt(tableDuring(setup.game.server)),
        AppScreen.talk,
      );
      // Now the server moved: the next fetch shows it.
      setup.answerMe(recordedMe('me_voting_picked'));
      setup.ws.addServerEvent(event('progress_vote_open'));
      await setup.settle();
      expect(
        setup.game.screenAt(tableDuring(setup.game.server)),
        AppScreen.vote,
      );
    });
  });

  group('events in any order, repeated or dropped, then a fetch', () {
    // Window 2 closing into the talk, as every seat heard it
    // (ws_sequence/window_2), one recorded event per type.
    const byType = {
      'progress': 'progress_talk_open',
      'night_window': 'night_window_2',
      'wave_complete': 'wave_complete_v2',
      'phase_change': 'phase_change_discussion',
    };
    final heard = ContractSamples.sequence('ws_sequence/window_2')['Ana']!;

    for (var seed = 0; seed < 12; seed++) {
      test('seed $seed: the same state as a phone that just started', () async {
        final random = Random(seed);
        final live = await phone('me_choose_prompt_seer');
        final serverNow = recordedMe('me_discussion_choose_seer');
        // The server moves on at a random point among the events.
        final events = [
          for (final type in heard)
            for (var copies = random.nextInt(3); copies > 0; copies--)
              byType[type]!,
        ]..shuffle(random);
        final moveAt = random.nextInt(events.length + 1);
        for (final (i, name) in events.indexed) {
          if (i == moveAt) live.answerMe(serverNow);
          live.ws.addServerEvent(event(name));
          if (random.nextBool()) await live.settle();
        }
        live.answerMe(serverNow);
        await live.settle();
        await live.notifier.refresh();

        final cold = await phone('me_discussion_choose_seer');
        expect(view(live.game), view(cold.game));
        expect(
          live.game.screenAt(tableDuring(live.game.server)),
          AppScreen.talk,
        );
      });
    }

    test('progress applies in place, and a fetch has the last word', () async {
      final setup = await phone('me_discussion_choose_villager');
      setup.ws.addServerEvent(withValues(event('progress_talk'), {'done': 3}));
      setup.ws.addServerEvent(withValues(event('progress_talk'), {'done': 3}));
      expect(setup.game.me.progress!.done, 3);
      expect(setup.meFetches, 1, reason: 'same stage: no fetch');
      // A count for another stage: this phone is behind, so it fetches.
      setup.ws.addServerEvent(event('progress_vote_open'));
      await setup.settle();
      expect(setup.meFetches, 2);
      expect(
        setup.game.me.progress,
        FromSample.progress('talk', done: 0, needed: 5),
      );
    });

    test('presence and host changes update what /me/ also holds', () async {
      final setup = await phone('me_discussion_choose_villager');
      setup.ws.addServerEvent(event('player_presence_disconnected'));
      final presence = event('player_presence_disconnected');
      expect(setup.game.presence[presence['player_id']], isFalse);
      setup.ws.addServerEvent(
        withValues(event('host_changed_handover'), {'host_id': 27}),
      );
      expect(setup.game.me.hostId, 27);
      expect(setup.game.me.isHost, isTrue, reason: 'this phone is player 27');
      expect(setup.game.hostNotice, isNotNull);
    });

    test('play again: the table moves on, /me/ is fetched', () async {
      final setup = await phone('me_voting_locked');
      setup.ws.addServerEvent(event('play_again'));
      await setup.settle();
      expect(setup.meFetches, 2);
    });

    test('a game that is gone says so', () async {
      final setup = await phone('me_talk_ready');
      setup.http.answer(
        'GET',
        '/onuw/games/${setup.gameId}/me/',
        ContractSamples.load('http/game/me_not_found'),
        status: 404,
      );
      await setup.notifier.refresh();
      expect(setup.game.tableClosed, isTrue);
    });
  });

  group('deadlines', () {
    test('no answer after the deadline: one fetch, then none', () async {
      final setup = await phone(
        'me_choose_prompt_seer',
        clock: () => DateTime.utc(2024, 3, 7, 21, 30),
      );
      await setup.settle();
      expect(setup.meFetches, 2);
      await setup.settle();
      expect(setup.meFetches, 2, reason: 'once per stage and deadline');
    });

    test('before the deadline nothing is fetched', () async {
      final setup = await phone('me_choose_prompt_seer');
      expect(setup.meFetches, 1);
    });
  });

  group('choose: what the table sees changes on the tap', () {
    const picks = [CenterPick(0), CenterPick(2)];

    test('"Chosen" before the answer, kept after it', () async {
      final setup = await phone('me_choose_prompt_seer');
      setup.answerPost('/action/', 'game/choose_submitted_seer');
      final stage = setup.game.me.stage!;
      final sent = setup.notifier.choose(stage, picks);
      expect(setup.game.me.prompt!.used, isTrue, reason: 'on the tap');
      expect(await sent, ChooseAnswer.taken);
      expect(setup.game.me.prompt!.used, isTrue);
      expect(setup.lastBody('/action/'), {
        'action_type': 'choose',
        'picks': [
          {'center_index': 0},
          {'center_index': 2},
        ],
        'stage': stage,
      });
    });

    test(
      'a fetch that left before the choose landed does not re-arm',
      () async {
        final setup = await phone('me_choose_prompt_seer');
        setup.answerPost('/action/', 'game/choose_submitted_seer');
        await setup.notifier.choose(setup.game.me.stage!, picks);
        // The server's answer to an earlier fetch still says chosen 0.
        await setup.notifier.refresh();
        expect(setup.game.server.prompt!.used, isFalse);
        expect(setup.game.me.prompt!.used, isTrue);
      },
    );

    test('refused (4xx): armed again', () async {
      final setup = await phone('me_choose_prompt_seer');
      setup.answerPost('/action/', 'game/choose_bad_request', status: 400);
      expect(
        await setup.notifier.choose(setup.game.me.stage!, picks),
        ChooseAnswer.refused,
      );
      expect(setup.game.me.prompt!.used, isFalse);
    });

    test('stale (409 wrong_stage): fetch /me/, not an error', () async {
      final setup = await phone('me_choose_prompt_seer');
      setup.answerPost('/action/', 'game/choose_wrong_stage', status: 409);
      setup.answerMe(recordedMe('me_discussion_choose_seer'));
      expect(
        await setup.notifier.choose(setup.game.me.stage!, picks),
        ChooseAnswer.stale,
      );
      await setup.settle();
      expect(setup.game.me.phase, GamePhase.discussion);
    });

    test('not sent: still "Chosen" (the board offers Try again)', () async {
      final setup = await phone('me_choose_prompt_seer');
      setup.failPost('/action/');
      expect(
        await setup.notifier.choose(setup.game.me.stage!, picks),
        ChooseAnswer.notSent,
      );
      expect(setup.game.me.prompt!.used, isTrue);
      // Try again sends the same picks for the same stage.
      setup.answerPost('/action/', 'game/choose_submitted_seer');
      expect(
        await setup.notifier.choose(setup.game.me.stage!, picks),
        ChooseAnswer.taken,
      );
    });

    test('a choose for a stage that is over is not sent', () async {
      final setup = await phone('me_choose_prompt_seer');
      expect(
        await setup.notifier.choose('w1.000000000007', picks),
        ChooseAnswer.stale,
      );
      expect(setup.http.requests.where((r) => r.method == 'POST'), isEmpty);
    });

    test("the Doppelganger's follow-up is her second turn", () async {
      final setup = await phone('me_choose_doppelganger_followup');
      setup.answerPost('/action/', 'game/choose_submitted_window1_second');
      expect(setup.game.me.prompt!.used, isFalse);
      await setup.notifier.choose(setup.game.me.stage!, const [SelfPick()]);
      expect(setup.game.me.prompt!.used, isTrue);
    });
  });

  group('ready', () {
    test('the look: "Ready" on the tap, the stage echoed', () async {
      final setup = await phone('me_look_stage');
      setup.answerPost('/ready/', 'game/ready_look');
      final sent = setup.notifier.setReady(true);
      expect(setup.game.me.ready, isTrue);
      expect(await sent, ChooseAnswer.taken);
      expect(setup.lastBody('/ready/'), {
        'ready': true,
        'stage': setup.game.me.stage,
      });
    });

    test('looking cannot be taken back, so it is not even sent', () async {
      final setup = await phone('me_look_ready');
      expect(await setup.notifier.setReady(false), ChooseAnswer.refused);
      expect(setup.game.me.ready, isTrue);
    });

    test('refused: back to what the server has', () async {
      final setup = await phone('me_look_stage');
      setup.answerPost('/ready/', 'game/ready_bad_body', status: 400);
      await setup.notifier.setReady(true);
      expect(setup.game.me.ready, isFalse);
    });

    test('stale: the stage is over, /me/ is fetched', () async {
      final setup = await phone('me_look_stage');
      setup.answerPost('/ready/', 'game/ready_wrong_stage', status: 409);
      setup.answerMe(recordedMe('me_choose_prompt_seer'));
      await setup.notifier.setReady(true);
      await setup.settle();
      expect(setup.game.me.inWindow, isTrue);
    });

    test('not sent: kept as tapped, "Try again" sends it again', () async {
      final setup = await phone('me_discussion_choose_villager');
      setup.failPost('/ready/');
      expect(await setup.notifier.setReady(true), ChooseAnswer.notSent);
      expect(setup.game.me.ready, isTrue);
      expect(setup.game.unsent, UnsentRequest.ready);
      setup.answerPost('/ready/', 'game/ready_talk');
      await setup.notifier.retry();
      expect(setup.game.unsent, isNull);
      expect(setup.game.me.ready, isTrue);
      expect(
        setup.http.requests.where((r) => r.path.endsWith('/ready/')),
        hasLength(2),
      );
    });

    test('the talk: ready can be taken back', () async {
      final setup = await phone('me_talk_ready');
      setup.answerPost('/ready/', 'game/ready_talk_off');
      final sent = setup.notifier.setReady(false);
      expect(setup.game.me.ready, isFalse);
      await sent;
      expect(setup.game.me.ready, isFalse);
      // Counts are the server's alone: the tap does not invent one.
      expect(setup.game.me.progress!.done, 1);
    });
  });

  group('vote', () {
    test('a pick shows at once; locking shows "Locked" at once', () async {
      final setup = await phone('me_voting_picked');
      setup.answerPost('/vote/', 'game/vote_picked');
      final pick = setup.notifier.pickVote(29);
      expect(setup.game.me.myVote, const MyVote.local(29, locked: false));
      await pick;
      setup.answerPost('/vote/', 'game/vote_locked_v2');
      final lock = setup.notifier.lockVote(29);
      expect(setup.game.me.myVote, const MyVote.local(29, locked: true));
      expect(await lock, ChooseAnswer.taken);
      expect(setup.lastBody('/vote/'), {
        'target_player_id': 29,
        'lock': true,
        'stage': setup.game.me.stage,
      });
    });

    test('refused: back to the pick the server has', () async {
      final setup = await phone('me_voting_picked');
      setup.answerPost('/vote/', 'game/vote_self_v2', status: 400);
      await setup.notifier.pickVote(27);
      expect(setup.game.me.myVote, const MyVote.local(30, locked: false));
    });

    test('already locked (409): fetch /me/', () async {
      final setup = await phone('me_voting_picked');
      setup.answerPost('/vote/', 'game/vote_already_locked', status: 409);
      setup.answerMe(recordedMe('me_voting_locked'));
      expect(await setup.notifier.lockVote(29), ChooseAnswer.stale);
      await setup.settle();
      expect(setup.game.me.myVote, const MyVote.local(30, locked: true));
    });

    test('after locking nothing more is sent', () async {
      final setup = await phone('me_voting_locked');
      expect(await setup.notifier.pickVote(29), ChooseAnswer.stale);
      expect(setup.http.requests.where((r) => r.method == 'POST'), isEmpty);
    });

    test('not sent: the lock stays, "Try again" offered', () async {
      final setup = await phone('me_voting_picked');
      setup.failPost('/vote/');
      await setup.notifier.lockVote(30);
      expect(setup.game.me.myVote!.locked, isTrue);
      expect(setup.game.unsent, UnsentRequest.lock);
    });
  });

  group('the rest', () {
    test('My night held: every result acknowledged, once', () async {
      final setup = await phone('me_talk_ready');
      setup.answerPost('/night-results/seen/', 'game/night_results_seen');
      await setup.notifier.acknowledgeNightResults();
      expect(setup.lastBody('/night-results/seen/'), {'seen': 1});
      expect(setup.game.me.hasUnseenResults, isFalse);
      await setup.notifier.acknowledgeNightResults();
      expect(
        setup.http.requests.where((r) => r.path.endsWith('/seen/')),
        hasLength(1),
      );
    });

    test('a phone with nothing to acknowledge still sends its count', () async {
      final setup = await phone('me_discussion_choose_villager');
      setup.answerPost('/night-results/seen/', 'game/night_results_seen');
      await setup.notifier.acknowledgeNightResults();
      expect(setup.lastBody('/night-results/seen/'), {'seen': 0});
    });

    test('"See who won" is a local step', () async {
      final setup = await phone('me_voting_locked');
      setup.notifier.seeWhoWon();
      expect(setup.game.countSeen, isTrue);
    });

    test('play again asks the server, then where the table is', () async {
      final setup = await phone('me_voting_locked');
      setup.http.answer(
        'POST',
        '/lobbies/${setup.game.server.lobbyCode}/play-again/',
        ContractSamples.load('http/lobby/play_again'),
      );
      await setup.notifier.playAgain();
      expect(setup.http.requests.last.path, endsWith('/play-again/'));
    });

    test('a stage is the server\'s: a new one drops the taps', () async {
      final setup = await phone('me_look_stage');
      setup.answerPost('/ready/', 'game/ready_look');
      await setup.notifier.setReady(true);
      setup.answerMe(recordedMe('me_choose_prompt_seer'));
      await setup.notifier.refresh();
      expect(setup.game.overlay.ready, isNull);
      expect(setup.game.me.ready, isNull);
      expect(setup.game.me.progress, isNull);
      expect(ProgressStage.values, hasLength(3));
    });
  });
}
