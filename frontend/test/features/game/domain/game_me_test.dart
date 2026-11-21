import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/domain/stage_progress.dart';

import '../../../helpers/contract/from_sample.dart';
import '../../../helpers/contract/sample_sets.dart';
import '../../../helpers/sheet/sheet_data.dart' show recordedMe;

void main() {
  GameMe me(String name) => FromSample.gameMe(recordedMe(name));

  test('every recorded /me/ parses, the night by the design system', () {
    final names = meSamples();
    expect(names, hasLength(greaterThan(20)));
    for (final name in names) {
      final json = recordedMe(name);
      final parsed = me(name);
      expect(parsed.gameId, json['game_id'], reason: name);
      expect(parsed.lobbyCode, json['lobby_code'], reason: name);
      expect(parsed.window, json['current_wave'], reason: name);
      expect(parsed.isHost, json['is_host'], reason: name);
      expect(parsed.hostId, json['host_id'], reason: name);
      expect(parsed.nightResultCount, (json['night_results'] as List).length);
      expect(parsed.nightResultsSeen, json['night_results_seen']);
      expect(parsed.ready, json['ready'], reason: name);
      // Seats in seat order, tokens read.
      expect(
        [for (final s in parsed.seats) s.seat],
        [for (var i = 0; i < parsed.seats.length; i++) i],
        reason: name,
      );
      expect(parsed.seats.every((s) => s.token != null), isTrue);
      expect(
        parsed.deck.values.fold<int>(0, (a, b) => a + b),
        parsed.seats.length + 3,
        reason: '$name: the deck is players + 3',
      );
    }
  });

  test('a missing always-sent key is a broken payload, never a default', () {
    final json = recordedMe('me_voting_picked');
    for (final key in json.keys.where((k) => k != 'has_voted')) {
      final broken = Map<String, dynamic>.of(json)..remove(key);
      expect(() => GameMe.fromJson(broken), throwsA(anything), reason: key);
    }
  });

  group('the look stage', () {
    test('window 0, ready false, counts of who looked, its own deadline', () {
      final look = me('me_look_stage');
      expect(look.phase, GamePhase.night);
      expect(look.inLook, isTrue);
      expect(look.inWindow, isFalse);
      final recorded = recordedMe('me_look_stage');
      expect(look.stage, recorded['stage']);
      expect(look.stage, startsWith('look.'));
      expect(look.deadline, DateTime.parse(recorded['deadline'] as String));
      expect(look.ready, isFalse);
      expect(look.progress, FromSample.progress('look', done: 0, needed: 5));
      expect(look.prompt, isNull);
      expect(look.dealt, RoleId.seer);
    });

    test('after "Ready" the server has the flag and the count', () {
      final ready = me('me_look_ready');
      expect(ready.ready, isTrue);
      expect(ready.progress!.done, 1);
    });
  });

  group('the night windows', () {
    test('a prompt carries its stage, chosen and max_chooses', () {
      final seer = me('me_choose_prompt_seer');
      expect(seer.inWindow, isTrue);
      expect(seer.prompt!.stage, seer.stage);
      expect(seer.prompt!.chosen, 0);
      expect(seer.prompt!.maxChooses, 1);
      expect(seer.prompt!.maxPicks, 2);
      expect(seer.prompt!.used, isFalse);
      expect(seer.ready, isNull);
      expect(seer.progress, isNull);
    });

    test('a phone that already chose starts at "Chosen"', () {
      expect(me('me_choose_chosen').prompt!.used, isTrue);
    });

    test("the Doppelganger's follow-up is a second turn, not used", () {
      final followUp = me('me_choose_doppelganger_followup');
      expect(followUp.prompt!.turn, 1);
      expect(followUp.prompt!.chosen, 1);
      expect(followUp.prompt!.used, isFalse);
      expect(followUp.nightResultCount, 1, reason: 'her look is listed');
      // Any other phone in window 1 has one turn, whatever max_chooses says.
      final sleeper = me('me_choose_prompt_window1_sleeper');
      expect(sleeper.prompt!.maxChooses, 2);
      expect(sleeper.prompt!.turn, 0);
    });

    test('withChosen shows the turn as sent, once', () {
      final seer = me('me_choose_prompt_seer').withChosen();
      expect(seer.prompt!.used, isTrue);
      expect(seer.withChosen().prompt!.chosen, seer.prompt!.chosen);
      final followUp = me('me_choose_doppelganger_followup').withChosen();
      expect(followUp.prompt!.chosen, 2);
      expect(followUp.prompt!.used, isTrue);
    });
  });

  group('the talk and the vote', () {
    test('the talk: ready to vote, counts only', () {
      final talk = me('me_discussion_choose_villager');
      expect(talk.phase, GamePhase.discussion);
      expect(talk.ready, isFalse);
      expect(talk.progress!.stage, ProgressStage.talk);
      expect(me('me_talk_ready').ready, isTrue);
    });

    test("the vote: this phone's own pick, then locked", () {
      final picked = me('me_voting_picked');
      expect(picked.phase, GamePhase.voting);
      expect(picked.myVote, const MyVote.local(29, locked: false));
      expect(picked.ready, isNull);
      expect(picked.progress!.stage, ProgressStage.vote);
      expect(
        me('me_voting_locked').myVote,
        const MyVote.local(29, locked: true),
      );
    });

    test('progress for another stage does not change the counts', () {
      final talk = me('me_discussion_choose_villager');
      final vote = me('me_voting_locked').progress!;
      expect(talk.withProgress(vote).progress, talk.progress);
      final newer = me('me_talk_ready').progress!;
      expect(talk.withProgress(newer).progress, newer);
    });

    test('the stage start and the vote list are carried as the server sent '
        'them', () {
      for (final name in meSamples()) {
        final json = recordedMe(name);
        final parsed = me(name);
        final started = json['stage_started_at'] as String?;
        expect(
          parsed.stageStartedAt,
          started == null ? null : DateTime.parse(started),
          reason: name,
        );
        // A start only beside a deadline.
        if (parsed.deadline == null) {
          expect(parsed.stageStartedAt, isNull, reason: name);
        }
        expect(parsed.voteTargets, json['vote_targets'], reason: name);
      }
      final ten = me('me_voting_ten');
      expect(ten.voteTargets, hasLength(9));
      expect(ten.voteTargets, isNot(contains(ten.playerId)));
      expect(ten.stageStartedAt!.isBefore(ten.deadline!), isTrue);
      final untimed = me('me_voting_untimed');
      expect((untimed.deadline, untimed.stageStartedAt), (null, null));
      expect(me('me_talk_ten').voteTargets, isNull);
      // Carried through a local change.
      expect(ten.withReady(true).voteTargets, ten.voteTargets);
      expect(ten.withReady(true).stageStartedAt, ten.stageStartedAt);
    });

    test('acknowledged results only go up', () {
      final talk = me('me_talk_ready');
      expect(talk.hasUnseenResults, isTrue);
      expect(talk.withSeen(1).hasUnseenResults, isFalse);
      expect(talk.withSeen(1).withSeen(0).nightResultsSeen, 1);
    });
  });

  test("this phone's own id is /me/'s player_id", () {
    expect(me('me_choose_prompt_seer').playerId, 27);
    expect(me('me_choose_doppelganger_followup').playerId, 32);
  });

  test('the vote before a pick: no vote of mine yet', () {
    final open = me('me_voting_unpicked');
    expect(open.myVote, isNull);
    expect(open.progress!.done, 0);
  });

  test('the results: no stage, no deadline, the card held at the end', () {
    final results = me('me_results');
    expect(results.phase, GamePhase.results);
    expect(results.stage, isNull);
    expect(results.deadline, isNull);
    expect(results.finalRole, RoleId.seer);
    expect(results.progress, isNull);
  });

  test('the turn is the server\'s chooses_left, never inferred', () {
    expect(me('me_choose_prompt_seer').prompt!.choosesLeft, 1);
    expect(me('me_choose_chosen').prompt!.choosesLeft, 0);
    expect(me('me_choose_chosen').prompt!.used, isTrue);
  });

  test('the server-built deck is roles_in_game', () {
    final nine = me('me_auto_deck_9');
    expect(nine.deck[RoleId.doppelganger], 1);
    expect(nine.deck.values.fold<int>(0, (a, b) => a + b), 12);
  });
}
