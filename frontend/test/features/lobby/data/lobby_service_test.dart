import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/api_exception.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/features/lobby/data/lobby_service.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/mock_http_client.dart';

/// The server's lobby body: Alice (1) alone at the table [code], with a deck
/// chosen or ([deck] false) not yet.
Map<String, dynamic> _lobby({String code = 'ABC123', bool deck = true}) =>
    serverLobby(code: code, seats: const [(id: 1, name: 'Alice')], deck: deck);

void main() {
  late MockHttpClient http;
  late LobbyService service;

  setUp(() {
    http = MockHttpClient();
    service = LobbyService(
      client: AuthenticatedClient.forTesting(dio: http.dio, gated: false),
    );
  });

  /// What the app sent last: method, path and body.
  (String, String, dynamic) sent() {
    final last = http.requests.last;
    return (last.method, last.path, last.data);
  }

  group('LobbyService', () {
    test(
      'createTable opens a table with defaults v2 and reads it back',
      () async {
        http.answer(
          'POST',
          '/lobbies/',
          ContractSamples.load('http/lobby/created_with_defaults'),
          status: 201,
        );

        final lobby = await service.createTable();

        expect(sent().$2, '/lobbies/');
        expect(sent().$3, {'game_type': 'onuw', 'defaults': 'v2'});
        expect(lobby.table.deckChip, DeckChip.simple);
      },
    );

    test('joinLobby joins the table and reads it back', () async {
      http.answer(
        'POST',
        '/lobbies/XYZ789/join/',
        _lobby(code: 'XYZ789', deck: false),
      );

      final lobby = await service.joinLobby('XYZ789');

      expect(sent().$2, '/lobbies/XYZ789/join/');
      expect(lobby.code, 'XYZ789');
    });

    test('a refused join carries the server\'s message and code', () async {
      http.answer(
        'POST',
        '/lobbies/ABC123/join/',
        ContractSamples.load('http/lobby/join_full'),
        status: 400,
      );

      await expectLater(
        service.joinLobby('ABC123'),
        throwsA(
          isA<ValidationException>()
              .having((e) => e.code, 'code', 'lobby_full')
              .having((e) => e.firstErrorFor('detail'), 'detail', isNotNull),
        ),
      );
    });

    test('leaveLobby posts to the table\'s leave', () async {
      http.answer(
        'POST',
        '/lobbies/ABC123/leave/',
        ContractSamples.load('http/lobby/left'),
      );

      await service.leaveLobby('ABC123');

      expect(sent().$2, '/lobbies/ABC123/leave/');
    });

    test('setCustomDeck sends the cards as the custom deck', () async {
      final roles = {'Werewolf': 2, 'Seer': 1};
      http.answer('PATCH', '/lobbies/ABC123/', _lobby());

      final lobby = await service.setCustomDeck('ABC123', roles);

      expect(sent().$1, 'PATCH');
      expect(sent().$3, {
        'settings': {'deck': 'custom', 'roles': roles},
      });
      expect(lobby.code, 'ABC123');
    });

    test('a deck change during a game is a conflict with its code', () async {
      http.answer(
        'PATCH',
        '/lobbies/ABC123/',
        ContractSamples.load('http/lobby/settings_in_game'),
        status: 409,
      );

      await expectLater(
        service.setCustomDeck('ABC123', {'Werewolf': 2}),
        throwsA(
          isA<UnhandledHttpException>()
              .having((e) => e.statusCode, 'status', 409)
              .having((e) => e.code, 'code', 'lobby_in_game')
              .having(
                (e) => e.message,
                'message',
                'Settings cannot change while a game is in progress.',
              ),
        ),
      );
    });

    test('startGame returns the dealt game\'s id', () async {
      final started = ContractSamples.map('http/game/started');
      http.answer('POST', '/onuw/lobbies/ABC123/start/', started, status: 201);

      expect(await service.startGame('ABC123'), started['game_id']);
    });

    test('playAgain returns the reopened table', () async {
      http.answer(
        'POST',
        '/lobbies/ABC123/play-again/',
        ContractSamples.load('http/lobby/play_again'),
      );

      final lobby = await service.playAgain('ABC123');

      expect(lobby.status, 'waiting');
    });

    test('playAgain by someone else is forbidden', () async {
      http.answer(
        'POST',
        '/lobbies/ABC123/play-again/',
        ContractSamples.load('http/lobby/play_again_not_host'),
        status: 403,
      );

      await expectLater(
        service.playAgain('ABC123'),
        throwsA(isA<ForbiddenException>()),
      );
    });

    group('activeGameIdAt', () {
      final running = ContractSamples.map('http/game/current_game_active');

      Future<String?> lookUp(Map<String, dynamic> body) {
        http.answer('GET', '/onuw/me/current-game/', body);
        return service.activeGameIdAt('ABC123');
      }

      test('returns the game running at this table', () async {
        expect(
          await lookUp({...running, 'lobby_code': 'ABC123'}),
          running['game_id'],
        );
      });

      test('is null for another table or no game', () async {
        expect(await lookUp(running), isNull);
        expect(
          await lookUp(ContractSamples.map('http/game/current_game_none')),
          isNull,
        );
      });
    });

    test('fetchLobby reads the table', () async {
      http.answer('GET', '/lobbies/ABC123/', _lobby());

      final lobby = await service.fetchLobby('ABC123');

      expect(lobby.code, 'ABC123');
      expect(lobby.players, hasLength(1));
    });

    test('fetchLobby of a table that is gone is not found', () async {
      http.answer(
        'GET',
        '/lobbies/NOPE/',
        ContractSamples.load('http/lobby/not_found'),
        status: 404,
      );

      await expectLater(
        service.fetchLobby('NOPE'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });
}
