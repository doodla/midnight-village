import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';

import '../../../helpers/contract/contract_samples.dart';

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
    final sampleJson = ContractSamples.map('http/lobby/detail_waiting');

    test('fromJson parses the lobby the server sends', () {
      final lobby = LobbyState.fromJson(sampleJson);

      expect(lobby.code, 'K7QX4M');
      expect(lobby.hostId, 1);
      expect(lobby.hostName, 'Ana');
      expect(lobby.originalHostId, 1);
      expect(lobby.isActingHost, isFalse);
      expect(lobby.status, 'waiting');
      expect(lobby.maxPlayers, 10);
      expect(lobby.players, hasLength(6));
      expect(lobby.players[0].displayName, 'Ana');
      expect(lobby.players[0].isReady, isTrue);
      expect(lobby.players[0].joinedAt, DateTime.utc(2024, 3, 7, 20, 51));
    });

    test('fromJson extracts role config from nested settings', () {
      final lobby = LobbyState.fromJson(sampleJson);

      expect(lobby.roleConfig, {
        'Werewolf': 2,
        'Seer': 1,
        'Robber': 1,
        'Troublemaker': 1,
        'Insomniac': 1,
        'Villager': 2,
        'Hunter': 1,
      });
    });

    test('a new table has no deck yet', () {
      final lobby = LobbyState.fromJson(
        ContractSamples.map('http/lobby/created'),
      );

      expect(lobby.roleConfig, isEmpty);
      expect(lobby.players, hasLength(1));
    });

    test('fromJson reads an acting host', () {
      final lobby = LobbyState.fromJson(
        ContractSamples.map('http/lobby/detail_acting_host'),
      );

      expect(lobby.hostId, 8);
      expect(lobby.hostName, 'Ben');
      expect(lobby.originalHostId, 7);
      expect(lobby.isActingHost, isTrue);
    });

    test('copyWith creates modified copy', () {
      final lobby = LobbyState.fromJson(sampleJson);
      final updated = lobby.copyWith(status: 'in_game');

      expect(updated.status, 'in_game');
      expect(updated.code, 'K7QX4M');
      expect(updated.players, hasLength(6));
    });

    test('equality works correctly', () {
      final a = LobbyState.fromJson(sampleJson);
      final b = LobbyState.fromJson(sampleJson);

      expect(a, equals(b));
    });
  });
}
