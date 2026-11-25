// A game state that did not change tells nobody (the owner, 24 November
// 2026: "it felt like I was watching a ppt"; measured, every poll of an
// unchanged `/me/` past a deadline drew the whole screen again). The state is
// set only when it differs (`LiveGameNotifier._set`, `LiveGame.==`,
// `GameMe.==`), so a poll, a heal, a failed retry or a known presence asks
// for no frame.
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/game_event.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/presentation/live_game.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/from_sample.dart';
import '../../../helpers/live_game_setup.dart';

void main() {
  /// How often [setup]'s game told its listeners, from now on.
  int Function() told(LiveGameSetup setup) {
    var count = 0;
    final sub = setup.container.listen(
      liveGameProvider(setup.gameId),
      (_, _) => count++,
    );
    addTearDown(sub.close);
    return () => count;
  }

  group('the same /me/ is the same state', () {
    test('two reads of one body are equal; a tap or a count on it is not', () {
      final body = recordedMe('me_talk_ready');
      final a = FromSample.gameMe(body);
      final b = FromSample.gameMe(recordedMe('me_talk_ready'));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.withReady(!(a.ready ?? false)), isNot(a));
      final other = FromSample.gameMe(recordedMe('me_look_stage'));
      expect(other, isNot(a));
    });

    test('a turn chosen on the board is not the turn unchosen', () {
      final me = FromSample.gameMe(recordedMe('me_choose_prompt_seer'));
      expect(me.withChosen(), isNot(me));
      expect(me.withChosen(), me.withChosen());
    });
  });

  group('nothing new tells nobody', () {
    // Window 2's deadline in the seer's recorded /me/.
    final deadline = DateTime.parse(
      recordedMe('me_choose_prompt_seer')['deadline'] as String,
    );

    test('the poll past a deadline, answered the same /me/ three times and '
        'more, tells nobody', () async {
      final me = recordedMe('me_choose_prompt_seer');
      final setup = LiveGameSetup.create(me, clock: () => DateTime.utc(2030));
      addTearDown(setup.dispose);
      setup.answerMe(me, serverDate: deadline);
      await setup.load();
      await setup.settle();
      final count = told(setup);
      final fetches = setup.meFetches;
      await setup.wait(const Duration(milliseconds: 200));
      expect(setup.meFetches, greaterThan(fetches + 2), reason: 'polling');
      expect(count(), 0, reason: 'the same /me/ each time');
      // A /me/ that differs is told at once.
      setup.answerMe(
        recordedMe('me_discussion_choose_seer'),
        serverDate: deadline.subtract(const Duration(hours: 1)),
      );
      await setup.wait(const Duration(milliseconds: 60));
      expect(count(), greaterThan(0));
      expect(setup.game.me.phase, GamePhase.discussion);
    });

    test('a fetch that keeps failing tells once, not at every retry', () async {
      final me = recordedMe('me_talk_ready');
      final setup = LiveGameSetup.create(me);
      addTearDown(setup.dispose);
      await setup.load();
      await setup.settle();
      final count = told(setup);
      setup.failGet('/onuw/games/${setup.gameId}/me/');
      await setup.notifier.refresh();
      await setup.wait(const Duration(milliseconds: 200));
      expect(setup.meFetches, greaterThan(3), reason: 'retried');
      expect(setup.game.fetchFailing, isTrue);
      expect(count(), 1, reason: 'failing once is news; again is not');
    });

    test('a presence already known tells nobody', () async {
      final setup = LiveGameSetup.create(recordedMe('me_talk_ready'));
      addTearDown(setup.dispose);
      await setup.load();
      await setup.settle();
      final presence = GameEvent.parse(
        ContractSamples.map('ws/game/player_presence_disconnected'),
      );
      setup.notifier.apply(presence);
      final count = told(setup);
      setup.notifier
        ..apply(presence)
        ..apply(presence);
      expect(count(), 0);
    });
  });
}
