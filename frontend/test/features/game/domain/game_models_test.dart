import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/domain/game_session_state.dart';
import 'package:midnight_village/features/game/domain/night_state.dart';
import 'package:midnight_village/features/game/domain/voting_state.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/server_json.dart';

void main() {
  /// The recorded `/me/` sample [name].
  Map<String, dynamic> me(String name) =>
      ContractSamples.map('http/game/$name');
  Map<String, dynamic> first(Map<String, dynamic> body, String key) =>
      ((body[key] as List).first as Map).cast<String, dynamic>();

  group('GamePlayer', () {
    test('reads a player as the vote lists them (with has_voted)', () {
      final json = first(me('me_voting_voted'), 'players');
      final player = GamePlayer.fromJson(json);
      expect(player.playerId, json['player_id']);
      expect(player.displayName, json['display_name']);
      expect(player.hasVoted, json['has_voted']);
    });

    test('outside the vote the server sends no has_voted: not voted', () {
      final json = first(me('me_discussion'), 'players');
      expect(json.containsKey('has_voted'), isFalse);
      expect(GamePlayer.fromJson(json).hasVoted, isFalse);
    });

    test('roundtrip serialization preserves all fields', () {
      final original = GamePlayer.fromJson(first(me('me_voting'), 'players'));
      expect(GamePlayer.fromJson(original.toJson()), original);
    });
  });

  group('YourRole', () {
    test('during play the card held now is not sent', () {
      final json = (me('me_night_prompt_seer')['your_role'] as Map)
          .cast<String, dynamic>();
      final role = YourRole.fromJson(json);
      expect(role.originalRole, json['original_role']);
      expect(role.hasActed, json['has_acted']);
      expect(role.currentRole, isNull);
    });

    test('in the results the card held at the end is sent', () {
      final json = (me('me_results')['your_role'] as Map)
          .cast<String, dynamic>();
      expect(YourRole.fromJson(json).currentRole, json['current_role']);
    });

    test('roundtrip serialization preserves all fields', () {
      final original = YourRole.fromJson(
        (me('me_results')['your_role'] as Map).cast<String, dynamic>(),
      );
      expect(YourRole.fromJson(original.toJson()), original);
    });
  });

  group('GameSessionState', () {
    test('parses every /me/ the server has sent, each by its protocol', () {
      // Protocol 1 (the old screens) is GameSessionState; protocol 2 (a
      // `stage` key: the rebuilt screens) is GameMe, whose night is the
      // design system's own parsers. No /me/ is left unparsed.
      final samples = ContractSamples.index.where(
        (s) =>
            s.isHttp && s.status == 200 && s.matchesPath('/onuw/games/g/me/'),
      );
      final byProtocol = <NightProtocol?, List<String>>{};
      for (final sample in samples) {
        final protocol = ContractSamples.protocolOf(sample);
        (byProtocol[protocol] ??= []).add(sample.name);
        final json = ContractSamples.map(sample.name);
        switch (protocol) {
          case NightProtocol.one:
            final state = GameSessionState.fromJson(json);
            expect(state.phase, json['phase'], reason: sample.name);
            expect(state.players, hasLength((json['players'] as List).length));
            expect(state.actionPrompt == null, json['action_prompt'] == null);
            expect(
              () => GameMe.fromJson(json),
              throwsFormatException,
              reason: '${sample.name} is protocol 1',
            );
          case NightProtocol.two:
            final me = GameMe.fromJson(json);
            expect(me.phase.server, json['phase'], reason: sample.name);
            expect(me.stage, json['stage'], reason: sample.name);
            expect(me.seats, hasLength((json['players'] as List).length));
            expect(me.prompt == null, json['action_prompt'] == null);
          case null:
            fail('${sample.name}: a /me/ is protocol 1 or 2');
        }
      }
      expect(byProtocol[NightProtocol.one], isNotEmpty);
      expect(
        byProtocol[NightProtocol.two],
        containsAll([
          'http/game/me_look_stage',
          'http/game/me_choose_prompt_seer',
          'http/game/me_discussion_choose_seer',
          'http/game/me_voting_picked',
        ]),
      );
    });

    test('fromJson reads the night with a prompt', () {
      final state = GameSessionState.fromJson(
        ContractSamples.map('http/game/me_night_prompt_seer'),
      );
      expect(state.phase, 'night');
      expect(state.currentWave, 2);
      expect(state.deadline, DateTime.utc(2024, 3, 7, 20, 57, 30));
      expect(state.yourRole.originalRole, 'Seer');
      expect(state.isHost, isTrue);
      expect(state.hostId, 1);
      expect(state.lobbyCode, 'K7QX4M');
      expect(state.actionPrompt!.roleActingAs, 'Seer');
      expect(state.actionPrompt!.actionTypes, [
        'peek_player',
        'peek_center',
        'skip',
      ]);
      expect(state.rolesInGame, hasLength(7));
    });

    test('fromJson reads an untimed phase (null deadline)', () {
      final state = GameSessionState.fromJson(
        ContractSamples.map('http/game/me_discussion_doppelganger'),
      );
      expect(state.deadline, isNull);
    });

    test('the card held at the end is read only in the results', () {
      final results = GameSessionState.fromJson(
        ContractSamples.map('http/game/me_results'),
      );
      expect(results.yourRole.currentRole, 'Troublemaker');
      final night = GameSessionState.fromJson(
        ContractSamples.map('http/game/me_night_acted'),
      );
      expect(night.yourRole.currentRole, isNull);
    });

    test('frontend-only fields have correct defaults', () {
      final state = GameSessionState.fromJson(
        ContractSamples.map('http/game/me_night_prompt_seer'),
      );
      expect(state.nightSubView, NightSubView.waiting);
      expect(state.voteProgress.playerVoted, isEmpty);
      expect(state.voteProgress.currentPlayerVoted, false);
      expect(state.voteRevealData, isNull);
      expect(state.results, isNull);
      // Presence comes from the player list, not /me/.
      expect(state.players.every((p) => p.connected), isTrue);
    });

    test('copyWith preserves immutability', () {
      final state = GameSessionState.fromJson(
        ContractSamples.map('http/game/me_night_prompt_seer'),
      );
      final updated = state.copyWith(phase: 'discussion');
      expect(state.phase, 'night');
      expect(updated.phase, 'discussion');
    });
  });

  group('ActionPrompt', () {
    test('fromJson reads every prompt the server sends', () {
      for (final kind in promptKinds) {
        final json = serverPrompt(kind);
        final prompt = ActionPrompt.fromJson(json);
        expect(prompt.roleActingAs, json['role_acting_as'], reason: kind);
        expect(prompt.actionTypes, json['action_types'], reason: kind);
        expect(prompt.validTargets, json['valid_targets'], reason: kind);
      }
    });

    test('roundtrip serialization preserves all fields', () {
      final original = ActionPrompt.fromJson(serverPrompt('robber'));
      final restored = ActionPrompt.fromJson(original.toJson());
      expect(restored, original);
    });
  });

  group('ActionResult', () {
    test('actionResultFromServer reads every result the server sends', () {
      for (final kind in nightResultKinds) {
        final json = serverNightResult(kind);
        final result = actionResultFromServer(json);
        expect(result.wave, json['wave'], reason: kind);
        expect(result.revealedInfo['action_type'], json['action_type']);
      }
    });

    test('roundtrip serialization preserves all fields', () {
      final original = actionResultFromServer(
        serverNightResult('see_team_werewolves'),
      );
      final restored = ActionResult.fromJson(original.toJson());
      expect(restored, original);
    });
  });

  group('RoleInGame', () {
    test('reads the deck as /me/ lists it', () {
      final json = first(me('me_discussion'), 'roles_in_game');
      final rig = RoleInGame.fromJson(json);
      expect(rig.role, json['role']);
      expect(rig.count, json['count']);
    });

    test('roundtrip serialization preserves all fields', () {
      final original = RoleInGame.fromJson(
        first(me('me_discussion'), 'roles_in_game'),
      );
      expect(RoleInGame.fromJson(original.toJson()), original);
    });
  });

  group('VoteProgress', () {
    test('default state has no votes', () {
      const progress = VoteProgress();
      expect(progress.playerVoted, isEmpty);
      expect(progress.currentPlayerVoted, false);
    });

    test('copyWith adds voted players', () {
      const progress = VoteProgress();
      final updated = progress.copyWith(
        playerVoted: {1: true, 2: true},
        currentPlayerVoted: true,
      );
      expect(updated.playerVoted[1], true);
      expect(updated.playerVoted[2], true);
      expect(updated.currentPlayerVoted, true);
    });
  });

  group('VoteRevealData', () {
    test('fromJson parses correctly', () {
      final json = {
        'votes': {'1': 3, '2': 3, '4': 1, '5': null},
        'tally': {'3': 2, '1': 1},
      };
      final reveal = VoteRevealData.fromJson(json);
      expect(reveal.votes['1'], 3);
      expect(reveal.votes['5'], isNull);
      expect(reveal.tally['3'], 2);
    });
  });

  group('NightSubView enum', () {
    test('has all expected values', () {
      expect(NightSubView.values, hasLength(5));
      expect(NightSubView.values, contains(NightSubView.waiting));
      expect(NightSubView.values, contains(NightSubView.seerChoice));
      expect(NightSubView.values, contains(NightSubView.actionPrompt));
      expect(NightSubView.values, contains(NightSubView.actionResult));
      expect(NightSubView.values, contains(NightSubView.roleReveal));
    });
  });
}
