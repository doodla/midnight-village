// frontend/test/helpers/game_events_test.dart

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'game_events.dart';

void main() {
  /// Helper to decode a GameEvents result and verify it's valid JSON.
  Map<String, dynamic> decode(String event) =>
      jsonDecode(event) as Map<String, dynamic>;

  group('GameEvents — night phase', () {
    test('waveStart encodes wave and optional deadline', () {
      final event = decode(GameEvents.waveStart(wave: 3));
      expect(event['type'], 'wave_start');
      expect(event['wave'], 3);
      expect(event['deadline'], isNull);

      final withDeadline = decode(
        GameEvents.waveStart(wave: 2, deadline: '2026-03-31T06:10:00.000Z'),
      );
      expect(withDeadline['deadline'], '2026-03-31T06:10:00.000Z');
    });

    test('actionPrompt encodes role, action types, and valid targets', () {
      final event = decode(
        GameEvents.actionPrompt(
          role: 'Seer',
          actionTypes: ['peek_player', 'peek_center'],
          validTargets: {
            'peek_player': {
              'players': [2, 3],
            },
            'peek_center': {
              'card_indices': [0, 1, 2],
            },
          },
          wave: 2,
        ),
      );
      expect(event['type'], 'action_prompt');
      expect(event['role_acting_as'], 'Seer');
      expect(event['action_types'], ['peek_player', 'peek_center']);
      expect(event['valid_targets']['peek_player']['players'], [2, 3]);
      expect(event['wave'], 2);
    });

    test(
      'actionResult encodes wave, revealed info, and optional action type',
      () {
        final event = decode(
          GameEvents.actionResult(
            wave: 2,
            revealedInfo: {'role': 'werewolf', 'target_player_id': 3},
            actionType: 'peek_player',
          ),
        );
        expect(event['type'], 'action_result');
        expect(event['wave'], 2);
        expect(event['revealed_info']['role'], 'werewolf');
        expect(event['action_type'], 'peek_player');
      },
    );

    test('actionResult omits action_type when null', () {
      final event = decode(
        GameEvents.actionResult(wave: 1, revealedInfo: {'role': 'seer'}),
      );
      expect(event.containsKey('action_type'), false);
    });

    test('waveComplete encodes wave', () {
      final event = decode(GameEvents.waveComplete(wave: 2));
      expect(event['type'], 'wave_complete');
      expect(event['wave'], 2);
    });

    test('waveWaiting encodes wave', () {
      final event = decode(GameEvents.waveWaiting(wave: 3));
      expect(event['type'], 'wave_waiting');
      expect(event['wave'], 3);
    });
  });

  group('GameEvents — phase transitions', () {
    test('phaseChange encodes phase and optional deadline', () {
      final event = decode(GameEvents.phaseChange(phase: 'discussion'));
      expect(event['type'], 'phase_change');
      expect(event['phase'], 'discussion');
      expect(event['deadline'], isNull);

      final withDeadline = decode(
        GameEvents.phaseChange(
          phase: 'voting',
          deadline: '2026-03-31T06:15:00.000Z',
        ),
      );
      expect(withDeadline['deadline'], '2026-03-31T06:15:00.000Z');
    });
  });

  group('GameEvents — voting', () {
    test('voteSubmitted encodes player_id', () {
      final event = decode(GameEvents.voteSubmitted(playerId: 2));
      expect(event['type'], 'vote_submitted');
      expect(event['player_id'], 2);
    });

    test('voteReveal encodes votes map', () {
      final event = decode(
        GameEvents.voteReveal(votes: {'1': 3, '2': 3, '3': 1}),
      );
      expect(event['type'], 'vote_reveal');
      expect(event['votes']['1'], 3);
      expect(event['votes']['2'], 3);
      expect(event['votes']['3'], 1);
    });

    test('voteReveal handles null (abstain) votes', () {
      final event = decode(GameEvents.voteReveal(votes: {'1': 3, '2': null}));
      expect(event['votes']['2'], isNull);
    });

    test('gameResults encodes type', () {
      final event = decode(GameEvents.gameResults());
      expect(event['type'], 'game_results');
    });
  });

  group('GameEvents — lobby', () {
    test('playerJoined encodes player info', () {
      final event = decode(
        GameEvents.playerJoined(playerId: 3, displayName: 'Charlie'),
      );
      expect(event['type'], 'player_joined');
      expect(event['user_id'], 3);
      expect(event['username'], 'Charlie');
    });

    test('playerLeft encodes player id', () {
      final event = decode(GameEvents.playerLeft(playerId: 2));
      expect(event['type'], 'player_left');
      expect(event['user_id'], 2);
    });

    test('playerReady encodes player id and ready state', () {
      final event = decode(
        GameEvents.playerReady(playerId: 2, displayName: 'Bob', isReady: true),
      );
      expect(event['type'], 'player_ready');
      expect(event['user_id'], 2);
      expect(event['username'], 'Bob');
      expect(event['is_ready'], true);
    });

    test('lobbyUpdate encodes role config', () {
      final event = decode(
        GameEvents.lobbyUpdate(roleConfig: {'werewolf': 2, 'seer': 1}),
      );
      expect(event['type'], 'lobby_update');
      expect(event['data']['settings']['roles'], {'werewolf': 2, 'seer': 1});
    });

    test('gameStarted encodes game_id', () {
      final event = decode(
        GameEvents.gameStarted(gameId: '550e8400-e29b-41d4-a716-446655440000'),
      );
      expect(event['type'], 'game_started');
      expect(event['game_id'], '550e8400-e29b-41d4-a716-446655440000');
    });
  });
}
