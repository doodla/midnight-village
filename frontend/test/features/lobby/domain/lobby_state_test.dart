import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';

import '../../../helpers/contract/contract_samples.dart';

void main() {
  group('LobbyPlayer', () {
    /// The members of a recorded lobby body.
    List<Map<String, dynamic>> members(String sample) => [
      for (final m in ContractSamples.map(sample)['players'] as List)
        (m as Map).cast<String, dynamic>(),
    ];

    test('fromJson reads the member the server nests under user', () {
      final json = members('http/lobby/detail_waiting').first;
      final user = (json['user'] as Map).cast<String, dynamic>();

      final player = LobbyPlayer.fromJson(json);

      expect(player.id, user['id']);
      expect(player.displayName, user['display_name']);
      expect(player.isReady, json['is_ready']);
      expect(player.joinedAt, DateTime.parse(json['joined_at'] as String));
    });

    test('fromJson reads a member who is not ready', () {
      final json = members(
        'http/lobby/joined',
      ).firstWhere((m) => m['is_ready'] == false);

      expect(LobbyPlayer.fromJson(json).isReady, isFalse);
    });

    test('copyWith and equality', () {
      final json = members('http/lobby/detail_waiting').first;
      final player = LobbyPlayer.fromJson(json);

      expect(player.copyWith(isReady: false).isReady, isFalse);
      expect(LobbyPlayer.fromJson(json), equals(player));
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

  group('a protocol-2 table', () {
    LobbyState lobby(String name) =>
        LobbyState.fromJson(ContractSamples.map('http/lobby/$name'));

    test('carries who is connected, the deck preview and whether it can be '
        'dealt', () {
      final dropped = lobby('detail_v2_member_dropped');
      expect(
        [for (final p in dropped.players) p.connected],
        [true, true, true, false],
      );
      final chaos = lobby('detail_v2_deck_chaos_4');
      expect(
        chaos.deckPreview,
        (ContractSamples.map(
                  'http/lobby/detail_v2_deck_chaos_4',
                )['deck_preview']
                as Map)
            .cast<String, int>(),
      );
      expect(chaos.deal, const DealReadiness(ok: true, need: 7, have: 7));
      final short = lobby('detail_v2_custom_deck_short');
      expect(short.deckPreview, isNull);
      expect(short.deal, const DealReadiness(ok: false, need: 11, have: 10));
    });

    test('an original table sends none of it', () {
      final original = LobbyState.fromJson(
        ContractSamples.map('http/lobby/detail_waiting'),
      );
      expect(original.deal, isNull);
      expect(original.deckPreview, isNull);
      expect(original.players.every((p) => p.connected == null), isTrue);
    });
  });
}
