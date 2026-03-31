import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/game_session_state.dart';
import 'package:midnight_village/features/game/domain/night_state.dart';
import 'package:midnight_village/features/game/domain/voting_state.dart';

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
    Map<String, dynamic> _validGameMeResponse() => {
      'game_id': '550e8400-e29b-41d4-a716-446655440000',
      'phase': 'night',
      'current_wave': 2,
      'deadline': '2026-03-31T06:05:30.000Z',
      'your_role': {
        'original_role': 'seer',
        'has_acted': false,
        'current_role': null,
      },
      'players': [
        {'player_id': 1, 'display_name': 'Alice', 'has_voted': false},
        {'player_id': 2, 'display_name': 'Bob', 'has_voted': false},
      ],
      'action_prompt': {
        'role_acting_as': 'Seer',
        'action_types': ['peek_player', 'peek_center'],
        'valid_targets': {
          'peek_player': {
            'players': [2, 3, 4, 5],
          },
          'peek_center': {
            'card_indices': [0, 1, 2],
          },
        },
        'wave': 2,
      },
      'roles_in_game': [
        {'role': 'werewolf', 'count': 2},
        {'role': 'seer', 'count': 1},
      ],
    };

    test('fromJson parses full GameMeResponse format', () {
      final state = GameSessionState.fromJson(_validGameMeResponse());
      expect(state.gameId, '550e8400-e29b-41d4-a716-446655440000');
      expect(state.phase, 'night');
      expect(state.currentWave, 2);
      expect(state.deadline, isNotNull);
      expect(state.yourRole.originalRole, 'seer');
      expect(state.players.length, 2);
      expect(state.players[0].displayName, 'Alice');
      expect(state.actionPrompt, isNotNull);
      expect(state.actionPrompt!.roleActingAs, 'Seer');
      expect(state.actionPrompt!.actionTypes, ['peek_player', 'peek_center']);
      expect(state.rolesInGame.length, 2);
    });

    test('fromJson handles null action_prompt', () {
      final json = _validGameMeResponse();
      json.remove('action_prompt');
      final state = GameSessionState.fromJson(json);
      expect(state.actionPrompt, isNull);
    });

    test('fromJson handles null deadline', () {
      final json = _validGameMeResponse();
      json['deadline'] = null;
      final state = GameSessionState.fromJson(json);
      expect(state.deadline, isNull);
    });

    test('fromJson defaults currentWave to 0 when missing', () {
      final json = _validGameMeResponse();
      json.remove('current_wave');
      final state = GameSessionState.fromJson(json);
      expect(state.currentWave, 0);
    });

    test('fromJson defaults rolesInGame to empty list when missing', () {
      final json = _validGameMeResponse();
      json.remove('roles_in_game');
      final state = GameSessionState.fromJson(json);
      expect(state.rolesInGame, isEmpty);
    });

    test('frontend-only fields have correct defaults', () {
      final state = GameSessionState.fromJson(_validGameMeResponse());
      // These fields are not in the JSON -- they default correctly.
      expect(state.nightSubView, NightSubView.waiting);
      expect(state.voteProgress.playerVoted, isEmpty);
      expect(state.voteProgress.currentPlayerVoted, false);
      expect(state.voteRevealData, isNull);
      expect(state.results, isNull);
    });

    test('copyWith preserves immutability', () {
      final state = GameSessionState.fromJson(_validGameMeResponse());
      final updated = state.copyWith(phase: 'discussion');
      expect(state.phase, 'night');
      expect(updated.phase, 'discussion');
    });
  });

  group('ActionPrompt', () {
    test('fromJson parses snake_case fields', () {
      final json = {
        'role_acting_as': 'Seer',
        'action_types': ['peek_player', 'peek_center'],
        'valid_targets': {
          'peek_player': {
            'players': [2, 3],
          },
        },
        'wave': 2,
      };
      final prompt = ActionPrompt.fromJson(json);
      expect(prompt.roleActingAs, 'Seer');
      expect(prompt.actionTypes, hasLength(2));
      expect(prompt.wave, 2);
    });

    test('roundtrip serialization preserves all fields', () {
      const original = ActionPrompt(
        roleActingAs: 'Robber',
        actionTypes: ['swap_with_player'],
        validTargets: {
          'swap_with_player': {
            'players': [1, 2],
          },
        },
        wave: 3,
      );
      final json = original.toJson();
      final restored = ActionPrompt.fromJson(json);
      expect(restored, original);
    });
  });

  group('ActionResult', () {
    test('fromJson parses snake_case fields', () {
      final json = {
        'wave': 2,
        'revealed_info': {
          'action_type': 'peek_player',
          'target_player_id': 3,
          'role': 'werewolf',
        },
      };
      final result = ActionResult.fromJson(json);
      expect(result.wave, 2);
      expect(result.revealedInfo['action_type'], 'peek_player');
      expect(result.revealedInfo['role'], 'werewolf');
    });

    test('roundtrip serialization preserves all fields', () {
      const original = ActionResult(
        wave: 1,
        revealedInfo: {'action_type': 'see_team', 'teammates': []},
      );
      final json = original.toJson();
      final restored = ActionResult.fromJson(json);
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
      expect(NightSubView.values, contains(NightSubView.loneWerewolfPeek));
    });
  });
}
