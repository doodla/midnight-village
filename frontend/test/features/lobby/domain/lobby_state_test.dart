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
      expect(player.joinedAt, DateTime.parse(json['joined_at'] as String));
    });

    test('copyWith and equality', () {
      final json = members('http/lobby/detail_waiting').first;
      final player = LobbyPlayer.fromJson(json);

      expect(player.copyWith(connected: false).connected, isFalse);
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

  group('the table extras', () {
    LobbyState lobby(String name) =>
        LobbyState.fromJson(ContractSamples.map('http/lobby/$name'));

    test('carries who is connected, the deck preview and whether it can be '
        'dealt', () {
      final dropped = lobby('detail_member_dropped');
      expect(
        [for (final p in dropped.players) p.connected],
        [true, true, true, false],
      );
      final chaos = lobby('detail_deck_chaos_4');
      expect(
        chaos.deckPreview,
        (ContractSamples.map('http/lobby/detail_deck_chaos_4')['deck_preview']
                as Map)
            .cast<String, int>(),
      );
      expect(chaos.deal, const DealReadiness(ok: true, need: 7, have: 7));
      final short = lobby('detail_custom_deck_short');
      expect(short.deckPreview, isNull);
      expect(short.deal, const DealReadiness(ok: false, need: 11, have: 10));
    });

    test('a body missing any of them is broken, never a default', () {
      Map<String, dynamic> body() =>
          ContractSamples.map('http/lobby/detail_member_dropped');
      for (final key in ['deck_preview', 'deal']) {
        expect(
          () => LobbyState.fromJson(body()..remove(key)),
          throwsA(anything),
          reason: key,
        );
      }
      final noConnected = body();
      ((noConnected['players'] as List).first as Map).remove('connected');
      expect(() => LobbyState.fromJson(noConnected), throwsA(anything));
      // `deck_preview` is null by design for a custom deck.
      expect(lobby('detail_custom_deck_ok').deckPreview, isNull);
    });

    test('a table made without defaults sends them too', () {
      final plain = LobbyState.fromJson(
        ContractSamples.map('http/lobby/detail_waiting'),
      );
      expect(plain.deal, isNotNull);
      expect(plain.deckPreview, isNull); // a custom deck
      // Recorded with no lobby socket open: nobody is shown at the table.
      expect(plain.players.every((p) => !p.connected), isTrue);
    });
  });

  group('the deal, as the server says', () {
    LobbyState at(String sample) =>
        LobbyState.fromJson(ContractSamples.map('http/lobby/$sample'));

    test('ok: deal to everyone at the table', () {
      expect(
        DealState.of(at('detail_custom_deck_ok')),
        isA<CanDeal>().having((d) => d.players, 'players', 7),
      );
    });

    test('a custom deck short of what the deal needs: add the difference', () {
      expect(
        DealState.of(at('detail_custom_deck_short')),
        isA<AddCards>().having((d) => d.count, 'count', 1),
      );
    });

    test('alone at a new table: three players needed', () {
      expect(DealState.of(at('created_with_defaults')), isA<NeedPlayers>());
    });

    test('a chip\'s cards are the server\'s preview, for that chip only', () {
      final lobby = at('detail_deck_chaos_4');
      expect(lobby.chipCards, isNotNull);
      expect(
        lobby.chipCards!.values.fold(0, (a, b) => a + b),
        lobby.deal!.have,
      );
      // A chip changed here and not answered yet: no cards of another chip.
      final pending = lobby.copyWith(
        table: lobby.table.merged({'deck_chip': 'simple'}),
      );
      expect(pending.chipCards, isNull);
    });

    test('a custom deck has no chip cards', () {
      expect(at('detail_custom_deck_ok').chipCards, isNull);
    });
  });
}
