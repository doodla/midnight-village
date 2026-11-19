import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/game_session_state.dart';

import 'contract/server_json.dart';
import 'game_state_factory.dart';

void main() {
  group('GameMeJsonBuilder', () {
    test('defaults are a server /me/ at night, window 2, nothing to do', () {
      final json = GameMeJsonBuilder().build();

      expect(json['game_id'], 'test-game-id');
      expect(json['phase'], 'night');
      expect(json['current_wave'], 2);
      expect(json['deadline'], isNull);
      expect(json['your_role'], {'original_role': 'Seer', 'has_acted': false});
      expect(json['action_prompt'], isNull);
      expect(json['has_voted'], false);
      expect(json['night_results'], isEmpty);
      expect(json['lobby_code'], 'ABC123');
      expect(json['is_host'], false);
      expect(json['host_id'], 2);
      expect(json['night_results_seen'], 0);
      expect(json['players'], [
        {'player_id': 1, 'display_name': 'Alice', 'token': 'crow', 'seat': 0},
        {'player_id': 2, 'display_name': 'Bob', 'token': 'key', 'seat': 1},
        {'player_id': 3, 'display_name': 'Charlie', 'token': 'moth', 'seat': 2},
      ]);
    });

    test('the app parses every phase it builds', () {
      for (final phase in ['night', 'discussion', 'voting', 'results']) {
        final state = GameSessionState.fromJson(
          GameMeJsonBuilder().inPhase(phase).build(),
        );
        expect(state.phase, phase);
      }
    });

    test('withPrompt is the server prompt aimed at the other players', () {
      final json = GameMeJsonBuilder().withPrompt('seer').build();
      expect(json['action_prompt'], {
        'role_acting_as': 'Seer',
        'action_types': ['peek_player', 'peek_center', 'skip'],
        'valid_targets': {
          'player_ids': [2, 3],
          'center_indices': [0, 1, 2],
        },
        'wave': 2,
      });
    });

    test('a team prompt has no player targets, only the team', () {
      final json = GameMeJsonBuilder()
          .withRole('Werewolf')
          .withPrompt('werewolf_pack', seeTeam: [3])
          .build();
      expect(json['action_prompt']['valid_targets'], {
        'see_team': [3],
      });
    });

    test('window 1 needs a Doppelganger in the deck', () {
      expect(
        () => GameMeJsonBuilder().withWave(1).build(),
        throwsA(isA<StateError>()),
      );
      final json = GameMeJsonBuilder().withWave(1).withDeck({
        'Doppelganger': 1,
        'Werewolf': 2,
        'Seer': 1,
        'Villager': 2,
      }).build();
      expect(json['current_wave'], 1);
    });

    test('role names must be the server casing', () {
      expect(
        () => GameMeJsonBuilder().withRole('seer'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('outside the night the window is 0', () {
      expect(GameMeJsonBuilder().inPhase('voting').build()['current_wave'], 0);
    });

    test('the vote: has_voted for the viewer and each player', () {
      final json = GameMeJsonBuilder()
          .inPhase('voting')
          .hasVoted(true)
          .withPlayersHavingVoted({3: true})
          .build();
      expect(json['has_voted'], true);
      expect(
        [for (final p in json['players'] as List) p['has_voted']],
        [true, false, true],
      );
    });

    test('asHost makes the viewer the effective host', () {
      final json = GameMeJsonBuilder().forViewer(3).asHost().build();
      expect(json['is_host'], true);
      expect(json['host_id'], 3);
    });

    test('results carry the card held at the end', () {
      final json = GameMeJsonBuilder()
          .inPhase('results')
          .withRole('Robber', currentRole: 'Werewolf')
          .build();
      expect(json['your_role']['current_role'], 'Werewolf');
    });

    test('night results are entries from the server samples', () {
      final json = GameMeJsonBuilder().inPhase('discussion').withNightResults([
        serverNightResult('peek_player', info: {'target_name': 'Bob'}),
      ]).build();
      expect(json['night_results'], [
        {
          'wave': 2,
          'action_type': 'peek_player',
          'revealed_info': {'target_name': 'Bob', 'role': 'werewolf'},
        },
      ]);
    });

    test('night_results_seen counts acknowledged entries, at most all', () {
      final results = [serverNightResult('peek_player')];
      final json = GameMeJsonBuilder()
          .inPhase('discussion')
          .withNightResults(results)
          .withNightResultsSeen(1)
          .build();
      expect(json['night_results_seen'], 1);

      expect(
        () => GameMeJsonBuilder()
            .inPhase('discussion')
            .withNightResults(results)
            .withNightResultsSeen(2)
            .build(),
        throwsStateError,
      );
    });
  });
}
