import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'game_events.dart';

void main() {
  Map<String, dynamic> decode(String event) =>
      jsonDecode(event) as Map<String, dynamic>;

  group('GameEvents', () {
    test('waveComplete carries the window that closed', () {
      expect(decode(GameEvents.waveComplete(wave: 1))['wave'], 1);
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
