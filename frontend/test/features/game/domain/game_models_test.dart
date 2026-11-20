import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/game_session_state.dart';
import 'package:midnight_village/features/game/domain/night_state.dart';
import 'package:midnight_village/features/game/domain/voting_state.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/server_json.dart';

void main() {
  group('GamePlayer', () {
    test('fromJson parses snake_case fields', () {
      final json = {'player_id': 1, 'display_name': 'Alice', 'has_voted': true};
      final player = GamePlayer.fromJson(json);
      expect(player.playerId, 1);
      expect(player.displayName, 'Alice');
      expect(player.hasVoted, true);
    });

    test('fromJson defaults hasVoted to false when missing', () {
      final json = {'player_id': 2, 'display_name': 'Bob'};
      final player = GamePlayer.fromJson(json);
      expect(player.hasVoted, false);
    });

    test('toJson produces snake_case keys', () {
      const player = GamePlayer(
        playerId: 1,
        displayName: 'Alice',
        hasVoted: true,
      );
      final json = player.toJson();
      expect(json['player_id'], 1);
      expect(json['display_name'], 'Alice');
      expect(json['has_voted'], true);
    });

    test('roundtrip serialization preserves all fields', () {
      const original = GamePlayer(
        playerId: 5,
        displayName: 'Charlie',
        hasVoted: false,
      );
      final json = original.toJson();
      final restored = GamePlayer.fromJson(json);
      expect(restored, original);
    });
  });

  group('YourRole', () {
    test('fromJson parses snake_case fields', () {
      final json = {
        'original_role': 'seer',
        'has_acted': false,
        'current_role': null,
      };
      final role = YourRole.fromJson(json);
      expect(role.originalRole, 'seer');
      expect(role.hasActed, false);
      expect(role.currentRole, isNull);
    });

    test('fromJson parses current_role in results phase', () {
      final json = {
        'original_role': 'seer',
        'has_acted': true,
        'current_role': 'robber',
      };
      final role = YourRole.fromJson(json);
      expect(role.currentRole, 'robber');
    });

    test('roundtrip serialization preserves all fields', () {
      const original = YourRole(
        originalRole: 'werewolf',
        hasActed: true,
        currentRole: 'villager',
      );
      final json = original.toJson();
      final restored = YourRole.fromJson(json);
      expect(restored, original);
    });
  });

  group('GameSessionState', () {
    test('parses every /me/ the server has sent', () {
      final samples = ContractSamples.index.where(
        (s) =>
            s.isHttp && s.status == 200 && s.matchesPath('/onuw/games/g/me/'),
      );
      expect(samples, isNotEmpty);
      for (final sample in samples) {
        final json = ContractSamples.map(sample.name);
        final state = GameSessionState.fromJson(json);
        expect(state.phase, json['phase'], reason: sample.name);
        expect(state.players, hasLength((json['players'] as List).length));
        expect(state.actionPrompt == null, json['action_prompt'] == null);
      }
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
    test('fromJson parses correctly', () {
      final json = {'role': 'werewolf', 'count': 2};
      final rig = RoleInGame.fromJson(json);
      expect(rig.role, 'werewolf');
      expect(rig.count, 2);
    });

    test('roundtrip serialization preserves all fields', () {
      const original = RoleInGame(role: 'seer', count: 1);
      final json = original.toJson();
      final restored = RoleInGame.fromJson(json);
      expect(restored, original);
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
