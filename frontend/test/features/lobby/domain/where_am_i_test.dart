import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';
import 'package:midnight_village/features/lobby/domain/where_am_i.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/contract_shape.dart';
import '../../../helpers/contract/from_sample.dart';
import '../../../helpers/contract/sample_sets.dart';

void main() {
  group('lobby bodies', () {
    test('every one parses, every seat with its token', () {
      final bodies = lobbyBodies();
      expect(bodies.length, greaterThan(8));
      for (final (name, body) in bodies) {
        final lobby = LobbyState.fromJson(body);
        expect(
          lobby.players.every((p) => p.token != null),
          isTrue,
          reason: name,
        );
      }
    });

    test('a v2 table with a chip: the deck automatic', () {
      final lobby = FromSample.lobby(
        ContractSamples.map('http/lobby/detail_auto_deck_5'),
      );
      expect(lobby.table.autoDeck, isTrue);
      expect(lobby.table.deckChip, DeckChip.classic);
      expect(lobby.table.cardLookSeconds, 30);
      expect(lobby.players, hasLength(5));
    });

    test('a v2 table whose cards were edited: custom, the cards are read', () {
      final lobby = FromSample.lobby(
        ContractSamples.map('http/lobby/detail_custom_deck'),
      );
      expect(lobby.table.autoDeck, isFalse);
      expect(lobby.roleConfig['Doppelganger'], 1);
      // The update the table hears is the same body.
      final update = ContractSamples.map('ws/lobby/lobby_update_custom_deck');
      expect(
        LobbyState.fromJson(
          (update['data'] as Map).cast<String, dynamic>(),
        ).table,
        lobby.table,
      );
    });

    test('a table opened with defaults v2: the Simple chip, the look on', () {
      final body = ContractSamples.map('http/lobby/created_with_defaults');
      checkHttpBody('POST', '/lobbies/', 201, body);
      final lobby = LobbyState.fromJson(body);
      expect(lobby.table.deckChip, DeckChip.simple);
      expect(lobby.players.single.token, TokenId.moth);
    });

    test('a table that says nothing has a custom deck and no look', () {
      final lobby = FromSample.lobby(
        ContractSamples.map('http/lobby/detail_waiting'),
      );
      expect(lobby.table, TableSettings.none);
      expect(lobby.roleConfig, isNotEmpty);
    });

    test('a deck chip the app does not know is a broken payload', () {
      final body = ContractSamples.map('http/lobby/settings_deck_chip');
      (body['settings'] as Map)['deck_chip'] = 'wild';
      expect(() => LobbyState.fromJson(body), throwsFormatException);
    });
  });

  group('where am I', () {
    test('every recorded answer is read', () {
      expect(
        FromSample.myTable(ContractSamples.map('http/lobby/my_table_none')),
        isNull,
      );
      final waiting = FromSample.myTable(
        ContractSamples.map('http/lobby/my_table_waiting'),
      )!;
      expect(waiting.status, TableStatus.waiting);
      expect(waiting.gameId, isNull);
      expect(waiting.token, TokenId.thorn);
      final again = FromSample.myTable(
        ContractSamples.map('http/lobby/my_table_after_play_again'),
      )!;
      expect(again.status, TableStatus.waiting);
      expect(again.gamePhase, GamePhase.results);
      for (final (name, phase) in [
        ('night', GamePhase.night),
        ('discussion', GamePhase.discussion),
        ('voting', GamePhase.voting),
        ('results', GamePhase.results),
      ]) {
        final table = FromSample.myTable(
          ContractSamples.map('http/lobby/my_table_$name'),
        )!;
        expect(table.gamePhase, phase, reason: name);
        expect(table.lobbyCode, 'K7QX4M');
      }
    });
  });

  group('home', () {
    test('players at tables', () {
      final stats = OnlineStats.fromJson(
        ContractSamples.map('http/core/online_stats'),
      );
      expect((stats.players, stats.tables), (6, 1));
    });

    test('recent games: only what the table was told', () {
      final games = RecentGame.listFrom(
        ContractSamples.map('http/game/recent_games'),
      );
      expect(games.single.youWon, isTrue);
      expect(games.single.winningTeams, [TeamId.village]);
      expect(games.single.token, TokenId.antler);
      expect(games.single.endedAt, DateTime.utc(2024, 3, 7, 20, 59, 8));
      expect(
        RecentGame.listFrom(ContractSamples.map('http/game/recent_games_none')),
        isEmpty,
      );
    });
  });
}
