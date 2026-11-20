import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'game_events.dart';

void main() {
  Map<String, dynamic> decode(String event) =>
      jsonDecode(event) as Map<String, dynamic>;

  group('GameEvents', () {
    test('waveStart carries the window and its deadline', () {
      expect(decode(GameEvents.waveStart(wave: 2)), {
        'type': 'wave_start',
        'wave': 2,
        'deadline': null,
      });
      expect(
        decode(
          GameEvents.waveStart(wave: 1, deadline: '2026-11-19T21:00:10+00:00'),
        )['deadline'],
        '2026-11-19T21:00:10+00:00',
      );
    });

    test('actionPrompt is the server prompt with flat targets and skip', () {
      expect(decode(GameEvents.actionPrompt('robber', playerIds: [2, 3])), {
        'type': 'action_prompt',
        'wave': 2,
        'role_acting_as': 'Robber',
        'action_types': ['swap_with_player', 'skip'],
        'valid_targets': {
          'player_ids': [2, 3],
        },
      });
    });

    test('actionResult takes values for the keys the server sends', () {
      final event = decode(
        GameEvents.actionResult(
          'swap_with_player',
          info: {'target_name': 'Bob', 'new_role': 'werewolf'},
        ),
      );
      expect(event, {
        'type': 'action_result',
        'wave': 2,
        'action_type': 'swap_with_player',
        'revealed_info': {'target_name': 'Bob', 'new_role': 'werewolf'},
      });
      expect(
        () => GameEvents.actionResult('peek_player', info: {'player_id': 3}),
        throwsArgumentError,
      );
    });

    test('phaseChange exists only for the talk and the vote', () {
      expect(
        decode(GameEvents.phaseChange(phase: 'voting'))['phase'],
        'voting',
      );
      for (final phase in ['night', 'results']) {
        expect(
          () => GameEvents.phaseChange(phase: phase),
          throwsArgumentError,
          reason: 'the server never sends phase_change $phase',
        );
      }
    });

    test('gameResults carries eliminated player ids', () {
      expect(decode(GameEvents.gameResults(eliminatedPlayers: [2]))['data'], {
        'winning_teams': ['village'],
        'reason': 'A Werewolf was eliminated.',
        'eliminated_players': [2],
      });
    });

    test('lobby joins and leaves carry only a username', () {
      expect(decode(GameEvents.playerJoined()).keys, {'type', 'username'});
      expect(decode(GameEvents.playerLeft()).keys, {'type', 'username'});
    });

    test('playerReady carries the id and the flag', () {
      final event = decode(GameEvents.playerReady(playerId: 2, isReady: true));
      expect(event['user_id'], 2);
      expect(event['is_ready'], true);
    });

    test('lobbyUpdate carries the whole lobby with the new deck', () {
      final event = decode(GameEvents.lobbyUpdate(roleConfig: {'Seer': 1}));
      expect(event['data']['settings'], {
        'roles': {'Seer': 1},
      });
      expect(event['data']['code'], 'ABC123');
    });
  });
}
