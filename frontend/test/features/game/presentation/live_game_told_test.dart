import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/presentation/live_game.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/game_events.dart';
import '../../../helpers/live_game_setup.dart';
import '../../../helpers/mock_http_client.dart';

// What the phone is told without asking: its own view on its socket, the count
// on a tap's answer, the results on the table's `game_results`. Each is taken
// only when it is the newest the phone has; an older server that tells less
// still leaves the screen true.

void main() {
  Future<LiveGameSetup> phone(String meName) async {
    final setup = LiveGameSetup.create(recordedMe(meName));
    addTearDown(setup.dispose);
    await setup.load();
    await setup.settle();
    return setup;
  }

  test("a tap's count is not taken over a /me/ applied while it was out "
      '(that read may be newer)', () async {
    final me = recordedMe('me_discussion_choose_villager');
    final setup = await phone('me_discussion_choose_villager');
    setup.answerPost('/ready/', 'game/ready_talk'); // done 1 of 5
    final posts = setup.http.hold(
      method: 'POST',
      path: '/onuw/games/${setup.gameId}/ready/',
    );
    final tap = setup.notifier.setReady(true);
    await setup.settle();
    // While it is out, a read in the same stage: three are ready now.
    setup.answerMe(
      withValues(me, {
        'ready': true,
        'progress': {'stage': 'talk', 'done': 3, 'needed': 5},
      }),
    );
    await setup.notifier.refresh();
    await setup.settle();
    posts.releaseAll();
    await tap;
    await setup.settle();
    expect(setup.game.server.progress?.done, 3, reason: 'the read is newer');
    expect(setup.game.me.ready, isTrue);
  });

  test("a tap's count is taken when nothing newer came: no read", () async {
    final setup = await phone('me_discussion_choose_villager');
    setup.answerPost('/ready/', 'game/ready_talk');
    await setup.notifier.setReady(true);
    await setup.settle();
    expect(setup.game.server.progress?.done, 1);
    expect(setup.meFetches, 1);
  });

  test(
    'a view answers a read that was failing: nothing more is tried',
    () async {
      final setup = await phone('me_talk_ready');
      setup.failGet('/onuw/games/${setup.gameId}/me/');
      await setup.notifier.refresh();
      await setup.settle();
      expect(setup.game.fetchFailing, isTrue);
      setup.ws.addServerEvent(
        GameEvents.ownView(recordedMe('me_voting_picked')),
      );
      await setup.settle();
      expect(setup.game.fetchFailing, isFalse);
      expect(setup.game.me.phase, GamePhase.voting);
      final reads = setup.meFetches;
      await setup.wait(const Duration(milliseconds: 300));
      expect(setup.meFetches, reads, reason: 'its retry was answered');
    },
  );

  test('the end: the view, then game_results with the results; nothing '
      'read (no /results/ is answered here: one would fail)', () async {
    final setup = await phone('me_voting_picked');
    setup.ws.addServerEvent(GameEvents.ownView(recordedMe('me_results')));
    await setup.settle();
    expect(setup.game.me.phase, GamePhase.results);
    setup.ws.addServerEvent(GameEvents.gameResults());
    await setup.settle();
    expect(setup.game.outcome, isNotNull);
    expect(setup.meFetches, 1);
  });

  group('a frame lost on a socket that stays alive: the beat reads once', () {
    int results(LiveGameSetup setup) =>
        setup.http.requests.where((r) => r.path.endsWith('/results/')).length;

    test('a beat at the stage it holds reads nothing', () async {
      final setup = await phone('me_voting_picked');
      for (var i = 0; i < 3; i++) {
        setup.ws.addServerEvent(GameEvents.beat(phase: 'voting'));
        await setup.settle();
      }
      expect(setup.meFetches, 1);
    });

    test('the vote opened and its frames were lost: the beat says voting, '
        'and /me/ is read once, however many beats follow', () async {
      final setup = await phone('me_talk_ready');
      setup.answerMe(recordedMe('me_voting_picked'));
      for (var i = 0; i < 3; i++) {
        setup.ws.addServerEvent(GameEvents.beat(phase: 'voting'));
        await setup.settle();
      }
      expect(setup.meFetches, 2);
      expect(setup.game.me.phase, GamePhase.voting);
    });

    test('the end board waits on a game_results that was lost: the beat at '
        'the results reads them once (no wait screen for good)', () async {
      final setup = await phone('me_voting_picked');
      setup.ws.addServerEvent(GameEvents.ownView(recordedMe('me_results')));
      await setup.settle();
      expect(setup.game.outcome, isNull, reason: 'its game_results was lost');
      setup.answerResults();
      for (var i = 0; i < 3; i++) {
        setup.ws.addServerEvent(GameEvents.beat(phase: 'results'));
        await setup.settle();
      }
      expect(setup.game.outcome, isNotNull);
      expect(results(setup), 1);
      expect(setup.meFetches, 1);
    });

    test('play again was lost at the end board: the beat says the table '
        'moved on, and where it sits is read once', () async {
      final setup = await phone('me_voting_picked');
      setup.ws.addServerEvent(GameEvents.ownView(recordedMe('me_results')));
      setup.ws.addServerEvent(GameEvents.gameResults());
      await setup.settle();
      final tables = setup.tableFetches;
      for (var i = 0; i < 3; i++) {
        setup.ws.addServerEvent(
          GameEvents.beat(phase: 'results', movedOn: true),
        );
        await setup.settle();
      }
      expect(setup.tableFetches, tables + 1);
      expect(setup.meFetches, 1);
    });
  });

  test('an older server: game_results with no results, at the results, '
      'reads them', () async {
    final setup = await phone('me_voting_picked');
    setup.ws.addServerEvent(GameEvents.ownView(recordedMe('me_results')));
    await setup.settle();
    setup.answerResults();
    final told = ContractSamples.map('ws/game/game_results');
    final data = Map<String, dynamic>.of(
      (told['data'] as Map).cast<String, dynamic>(),
    )..remove('results');
    setup.ws.addOffContractEvent({...told, 'data': data});
    await setup.settle();
    expect(setup.game.outcome, isNotNull);
    expect(
      setup.http.requests.where((r) => r.path.endsWith('/results/')),
      hasLength(1),
    );
  });

  test("an older server's lock answer (its status alone): the vote stays "
      'locked; the first count it cannot place is read once, and the '
      'server says locked', () async {
    final setup = await phone('me_voting_picked');
    setup.http.answer('POST', '/onuw/games/${setup.gameId}/vote/', {
      'status': 'submitted',
    }, offContract: true);
    await setup.notifier.lockVote(29);
    await setup.settle();
    expect(setup.game.me.myVote, const MyVote.local(29, locked: true));
    expect(setup.meFetches, 1, reason: 'the answer alone: nothing read');
    expect(await setup.notifier.pickVote(30), isA<Declined>());
    // Another locks: the server counts two (this phone's lock among them).
    const two = {'stage': 'vote', 'done': 2, 'needed': 5};
    setup.answerMe(
      withValues(recordedMe('me_voting_locked'), {'progress': two}),
    );
    setup.ws.addServerEvent(
      withValues(ContractSamples.map('ws/game/progress_vote_open'), two),
    );
    await setup.settle();
    expect(setup.meFetches, 2);
    expect(setup.game.me.myVote, const MyVote.local(29, locked: true));
    expect(setup.game.me.progress?.done, 2);
  });
}
