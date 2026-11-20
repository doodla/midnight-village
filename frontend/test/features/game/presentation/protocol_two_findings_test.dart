// The paths a model of the phone found (docs/dev/models/), each replayed
// against the real notifier from recorded payloads. Each test states the
// rule it holds the app to.
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';
import 'package:midnight_village/features/game/presentation/protocol_two_game.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/from_sample.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/protocol_two_setup.dart';

/// [me] with its prompt's values changed: a state the recorder has no
/// sample of, reached by changing values only.
Map<String, dynamic> withPrompt(
  Map<String, dynamic> me,
  Map<String, dynamic> values,
) => withValues(me, {
  'action_prompt': withValues(
    (me['action_prompt'] as Map).cast<String, dynamic>(),
    values,
  ),
});

void main() {
  Future<ProtocolTwoSetup> phone(Map<String, dynamic> body) async {
    final setup = ProtocolTwoSetup.create(body);
    addTearDown(setup.dispose);
    await setup.load();
    await setup.settle();
    return setup;
  }

  String mePath(ProtocolTwoSetup setup) => '/onuw/games/${setup.gameId}/me/';

  group('a fetch the screen depends on is made again until it succeeds', () {
    test('F1: the fetch after a taken choose fails: it is retried, and her '
        'follow-up arms while window 1 is open', () async {
      final look = recordedMe('me_choose_prompt_doppelganger_look');
      final setup = await phone(look);
      setup.answerPost('/action/', 'game/choose_submitted_doppelganger_look');
      setup.failGet(mePath(setup)); // the fetch after the 200: no answer
      final stage = setup.game.me.stage!;
      final answer = await setup.notifier.choose(stage, const [PlayerPick(33)]);
      expect(answer.forBoard, ChooseAnswer.taken);
      await setup.settle();
      expect(setup.meFetches, 2, reason: 'the one fetch after a taken choose');
      // The network is back. No event comes, the deadline is far away.
      setup.answerMe(recordedMe('me_choose_doppelganger_followup'));
      await setup.wait(const Duration(milliseconds: 150));
      expect(setup.game.me.prompt!.turn, 1, reason: 'her follow-up turn');
      expect(setup.game.me.prompt!.used, isFalse);
    });

    test('F3: Riverpod does not rebuild the game behind its back: a tap in '
        'flight survives a first /me/ that failed', () async {
      final look = recordedMe('me_choose_prompt_doppelganger_look');
      final setup = ProtocolTwoSetup.create(look);
      addTearDown(setup.dispose);
      setup.failGet(mePath(setup));
      setup.container.listen(protocolTwoGameProvider(setup.gameId), (_, _) {});
      await setup.settle();
      setup.answerMe(look); // the notifier's own retry loads it
      await setup.wait(const Duration(milliseconds: 40));
      expect(
        setup.container.read(protocolTwoGameProvider(setup.gameId)).value !=
            null,
        isTrue,
      );
      setup.answerPost('/action/', 'game/choose_submitted_doppelganger_look');
      final posts = setup.http.hold(
        method: 'POST',
        path: '/onuw/games/${setup.gameId}/action/',
      );
      final first = setup.notifier.choose(setup.game.me.stage!, const [
        PlayerPick(33),
      ]);
      // Long past when Riverpod's default retry of the failed build fires.
      await setup.wait(const Duration(milliseconds: 300));
      expect(setup.game.outbox.current(OutboxLane.choose), isNotNull);
      setup.answerMe(recordedMe('me_choose_doppelganger_followup'));
      posts.releaseAll();
      expect((await first).forBoard, ChooseAnswer.taken);
      await setup.wait(const Duration(milliseconds: 50));
      expect(setup.game.me.prompt!.turn, 1, reason: 'follow-up armed');
      expect(setup.posts('/action/'), 1);
    });

    test('F5: at the results a failed GET results/ is fetched again, with no '
        'deadline and no event', () async {
      final setup = ProtocolTwoSetup.create(recordedMe('me_results_v2'));
      addTearDown(setup.dispose);
      setup.failGet('/onuw/games/${setup.gameId}/results/');
      await setup.load();
      await setup.settle();
      expect(setup.game.outcome, isNull);
      setup.answerResults();
      await setup.wait(const Duration(milliseconds: 150));
      expect(setup.game.outcome, isNotNull);
    });

    test('F6: at the results, a play again whose event was lost: the slow '
        'poll of /me/table/ reaches 02', () async {
      final me = recordedMe('me_results_v2');
      final setup = await phone(me);
      expect(setup.screen!.screen, AppScreen.count);
      // The host plays again: the table waits. The event never arrives.
      setup.answerTable(
        serverMyTable(
          code: me['lobby_code'] as String,
          status: 'waiting',
          gameId: me['game_id'] as String,
          phase: 'results',
        ),
      );
      await setup.wait(const Duration(milliseconds: 200));
      expect(setup.screen!.screen, AppScreen.table);
    });

    test('a cold start with no network: /me/table/ is fetched until it '
        'answers', () async {
      final setup = ProtocolTwoSetup.create(recordedMe('me_talk_ready'));
      addTearDown(setup.dispose);
      setup.failGet('/me/table/');
      expect(setup.screen, isNull, reason: 'nothing to show yet');
      await setup.wait(const Duration(milliseconds: 700));
      setup.answerTable(tableOf(recordedMe('me_talk_ready')));
      await setup.wait(const Duration(seconds: 2));
      expect(setup.screen!.screen, AppScreen.talk);
    });
  });

  group('the turn is what the server says, not what kind suggests', () {
    test('F2: a Doppelganger who copied the Minion has a follow-up turn '
        '(chooses_left 1): not "Chosen"', () {
      final minion = withPrompt(recordedMe('me_choose_doppelganger_followup'), {
        'kind': 'none',
        'shapes': [
          {'any': 1},
        ],
        'role_acting_as': 'Minion',
      });
      final prompt = FromSample.gameMe(minion).prompt!;
      expect(prompt.chosen, 1);
      expect(prompt.choosesLeft, 1);
      expect(prompt.used, isFalse);
      expect(prompt.turn, 1, reason: 'a new turn: the board arms again');
    });

    test(
      'after a taken choose, /me/ decides: still one left is armed again',
      () async {
        // A choose from a stale prompt is answered 200 and stored nowhere:
        // only /me/ (chooses_left still 1) shows it was not taken.
        final seer = recordedMe('me_choose_prompt_seer');
        final setup = await phone(seer);
        setup.answerPost('/action/', 'game/choose_resent');
        setup.answerMe(seer); // the server still has chosen 0, one left
        await setup.notifier.choose(setup.game.me.stage!, const [SelfPick()]);
        await setup.settle();
        expect(setup.game.me.prompt!.used, isFalse);
      },
    );

    test('F4: every choose carries the prompt\'s chosen', () async {
      final setup = await phone(recordedMe('me_choose_doppelganger_followup'));
      setup.answerPost('/action/', 'game/choose_submitted_window1_second');
      await setup.notifier.choose(setup.game.me.stage!, const [
        CenterPick(0),
        CenterPick(2),
      ]);
      expect(setup.lastBody('/action/'), {
        'action_type': 'choose',
        'picks': [
          {'center_index': 0},
          {'center_index': 2},
        ],
        'stage': setup.game.me.stage,
        'chosen': 1,
      });
    });
  });

  group('the results ack', () {
    test('a lost ack is sent again by itself, without "Try again"', () async {
      final setup = await phone(recordedMe('me_talk_ready'));
      setup.failPost('/night-results/seen/');
      await setup.notifier.acknowledgeNightResults();
      expect(setup.game.unsent, isEmpty, reason: 'nothing for the player');
      // The server never got it (its /me/ still says 0 seen): sent again.
      setup.answerPost('/night-results/seen/', 'game/night_results_seen');
      await setup.wait(const Duration(milliseconds: 100));
      expect(setup.posts('/night-results/seen/'), greaterThanOrEqualTo(2));
      expect(setup.lastBody('/night-results/seen/'), {'seen': 1});
    });

    test('after a restart, /me/ says it was sent: not sent again', () async {
      final setup = await phone(
        withValues(recordedMe('me_talk_ready'), {'night_results_seen': 1}),
      );
      expect(await setup.notifier.acknowledgeNightResults(), isA<Declined>());
      expect(setup.posts('/night-results/seen/'), 0);
    });
  });

  test('a game answered 404 then found again is no longer closed', () async {
    final setup = await phone(recordedMe('me_talk_ready'));
    setup.http.answer(
      'GET',
      mePath(setup),
      ContractSamples.load('http/game/me_not_found'),
      status: 404,
    );
    await setup.notifier.refresh();
    expect(setup.game.tableClosed, isTrue);
    setup.answerMe(recordedMe('me_talk_ready'));
    await setup.notifier.refresh();
    expect(setup.game.tableClosed, isFalse);
  });
}
