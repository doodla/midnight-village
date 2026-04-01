import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';

void main() {
  group('LobbyPlayer', () {
    test('fromJson parses backend nested player format', () {
      final json = {
        'user': {'id': 1, 'username': 'player1', 'display_name': 'Alice'},
        'is_ready': true,
        'joined_at': '2026-03-31T06:00:00Z',
      };

      final player = LobbyPlayer.fromJson(json);

      expect(player.id, 1);
      expect(player.displayName, 'Alice');
      expect(player.isReady, isTrue);
      expect(player.joinedAt, DateTime.utc(2026, 3, 31, 6, 0, 0));
    });

    test('fromJson handles is_ready false', () {
      final json = {
        'user': {'id': 2, 'username': 'player2', 'display_name': 'Bob'},
        'is_ready': false,
        'joined_at': '2026-03-31T06:01:00Z',
      };

      final player = LobbyPlayer.fromJson(json);

      expect(player.id, 2);
      expect(player.displayName, 'Bob');
      expect(player.isReady, isFalse);
    });

    test('copyWith creates modified copy', () {
      final player = LobbyPlayer(
        id: 1,
        displayName: 'Alice',
        isReady: false,
        joinedAt: DateTime.utc(2026, 3, 31),
      );

      final ready = player.copyWith(isReady: true);

      expect(ready.isReady, isTrue);
      expect(ready.id, 1);
      expect(ready.displayName, 'Alice');
    });

    test('equality works correctly', () {
      final a = LobbyPlayer(
        id: 1,
        displayName: 'Alice',
        isReady: true,
        joinedAt: DateTime.utc(2026, 3, 31),
      );
      final b = LobbyPlayer(
        id: 1,
        displayName: 'Alice',
        isReady: true,
        joinedAt: DateTime.utc(2026, 3, 31),
      );

      expect(a, equals(b));
    });
  });

  group('LobbyState', () {
    final sampleJson = {
      'code': 'ABC123',
      'host': {'id': 1, 'username': 'player1', 'display_name': 'Alice'},
      'game_type': 'onuw',
      'status': 'waiting',
      'max_players': 10,
      'settings': {
        'roles': {
          'werewolf': 2,
          'seer': 1,
          'robber': 1,
          'troublemaker': 1,
          'villager': 3,
        },
      },
      'players': [
        {
          'user': {'id': 1, 'username': 'player1', 'display_name': 'Alice'},
          'is_ready': true,
          'joined_at': '2026-03-31T06:00:00Z',
        },
        {
          'user': {'id': 2, 'username': 'player2', 'display_name': 'Bob'},
          'is_ready': false,
          'joined_at': '2026-03-31T06:01:00Z',
        },
      ],
      'created_at': '2026-03-31T05:55:00Z',
    };

    test('fromJson parses full backend LobbyResponse', () {
      final lobby = LobbyState.fromJson(sampleJson);

      expect(lobby.code, 'ABC123');
      expect(lobby.hostId, 1);
      expect(lobby.status, 'waiting');
      expect(lobby.maxPlayers, 10);
      expect(lobby.players, hasLength(2));
      expect(lobby.players[0].displayName, 'Alice');
      expect(lobby.players[0].isReady, isTrue);
      expect(lobby.players[1].displayName, 'Bob');
      expect(lobby.players[1].isReady, isFalse);
    });

    test('fromJson extracts role config from nested settings', () {
      final lobby = LobbyState.fromJson(sampleJson);

      expect(lobby.roleConfig, {
        'werewolf': 2,
        'seer': 1,
        'robber': 1,
        'troublemaker': 1,
        'villager': 3,
      });
    });

    test('fromJson handles missing settings gracefully', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json['settings'] = null;

      final lobby = LobbyState.fromJson(json);

      expect(lobby.roleConfig, isEmpty);
    });

    test('fromJson handles empty roles in settings', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json['settings'] = <String, dynamic>{'roles': null};

      final lobby = LobbyState.fromJson(json);

      expect(lobby.roleConfig, isEmpty);
    });

    test('fromJson handles empty player list', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json['players'] = <dynamic>[];

      final lobby = LobbyState.fromJson(json);

      expect(lobby.players, isEmpty);
    });

    test('copyWith creates modified copy', () {
      final lobby = LobbyState.fromJson(sampleJson);
      final updated = lobby.copyWith(status: 'in_game');

      expect(updated.status, 'in_game');
      expect(updated.code, 'ABC123');
      expect(updated.players, hasLength(2));
    });

    test('equality works correctly', () {
      final a = LobbyState.fromJson(sampleJson);
      final b = LobbyState.fromJson(sampleJson);

      expect(a, equals(b));
    });
  });
}
