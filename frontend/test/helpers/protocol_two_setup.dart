import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/auth/domain/user.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/game/data/game_service.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';
import 'package:midnight_village/features/game/presentation/protocol_two_game.dart';
import 'package:midnight_village/features/lobby/data/lobby_service.dart';
import 'package:midnight_village/features/lobby/presentation/lobby_notifier.dart';
import 'package:midnight_village/features/lobby/presentation/where_am_i_provider.dart';

import 'contract/contract_samples.dart';
import 'mock_http_client.dart';
import 'mock_websocket.dart';

export 'sheet/sheet_data.dart' show recordedMe;

/// Before every recorded deadline (the samples' games ran on 7 March 2024
/// from 21:13): no deadline fetch fires during a test unless it moves the
/// clock.
final sampleClockStart = DateTime.utc(2024, 3, 7, 21, 13);

/// A [ProtocolTwoGameNotifier] wired to the strict HTTP mock and a fake game
/// socket, with every answer a recorded server payload.
class ProtocolTwoSetup {
  ProtocolTwoSetup._(this.container, this.http, this.ws, this.gameId);

  /// A phone whose `/me/` answers [me] (a recorded protocol-2 `/me/`).
  factory ProtocolTwoSetup.create(
    Map<String, dynamic> me, {
    int userId = 27,
    DateTime Function()? clock,
  }) {
    final http = MockHttpClient();
    final ws = MockWebSocketChannel();
    final client = AuthenticatedClient.forTesting(dio: http.dio);
    final gameId = me['game_id'] as String;
    final setup = ProtocolTwoSetup._(
      ProviderContainer(
        overrides: [
          authProvider.overrideWithValue(
            AuthState.authenticated(User(id: userId, displayName: 'P$userId')),
          ),
          authenticatedClientProvider.overrideWithValue(client),
          gameServiceProvider.overrideWithValue(GameService(client: client)),
          lobbyServiceProvider.overrideWithValue(LobbyService(client: client)),
          gameWebSocketProvider.overrideWith((ref, id) => null),
          gameWebSocketStreamProvider.overrideWith((ref, id) => ws.stream),
          clockProvider.overrideWithValue(clock ?? () => sampleClockStart),
        ],
      ),
      http,
      ws,
      gameId,
    );
    setup.answerMe(me);
    return setup;
  }

  final ProviderContainer container;
  final MockHttpClient http;
  final MockWebSocketChannel ws;
  final String gameId;

  String get _base => '/onuw/games/$gameId';

  /// What the next `GET /me/` answers.
  void answerMe(Map<String, dynamic> me) =>
      http.answer('GET', '$_base/me/', me);

  /// `POST <base><endpoint>` answers the recorded sample [sample] with
  /// [status].
  void answerPost(String endpoint, String sample, {int status = 200}) =>
      http.answer(
        'POST',
        '$_base$endpoint',
        ContractSamples.load('http/$sample'),
        status: status,
      );

  /// `POST <base><endpoint>` fails without a body the app can read (a 5xx).
  void failPost(String endpoint) =>
      http.answer('POST', '$_base$endpoint', 'Server Error', status: 503);

  ProtocolTwoGameNotifier get notifier =>
      container.read(protocolTwoGameProvider(gameId).notifier);

  ProtocolTwoGame get game =>
      container.read(protocolTwoGameProvider(gameId)).requireValue;

  /// Loads the game (the first `/me/`) and keeps the provider alive.
  Future<ProtocolTwoGame> load() async {
    container.listen(protocolTwoGameProvider(gameId), (_, _) {});
    return container.read(protocolTwoGameProvider(gameId).future);
  }

  /// Every `GET /me/` made so far.
  int get meFetches => http.requests
      .where((r) => r.method == 'GET' && r.path == '$_base/me/')
      .length;

  /// The body of the last request to [endpoint].
  dynamic lastBody(String endpoint) =>
      http.requests.lastWhere((r) => r.path == '$_base$endpoint').data;

  /// Lets every queued answer and fetch finish.
  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  void dispose() => container.dispose();
}
