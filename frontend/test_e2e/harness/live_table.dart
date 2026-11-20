import 'package:midnight_village/core/debug/debug_api_client.dart';
import 'package:midnight_village/core/debug/debug_models.dart';
import 'package:midnight_village/core/debug/debug_table_controller.dart';

import 'harness_config.dart';
import 'night_wire.dart';

/// A [DebugApiClient] and a [DebugTableController] aimed at the harness backend.
/// The controller's session hooks do nothing: the API runners never change the
/// visible perspective.
({DebugApiClient client, DebugTableController controller}) harnessClients() {
  final client = DebugApiClient(
    baseUrl: HarnessConfig.apiBaseUrl,
    origin: HarnessConfig.origin,
  );
  final controller = DebugTableController(
    client: client,
    adoptSession: (_, {required accessToken, required refreshToken}) async {},
    invalidateGameProviders: (_) {},
  );
  return (client: client, controller: controller);
}

/// A started table plus everything the lifecycle scenarios do to it: open and
/// close each player's game and lobby sockets (their events are recorded), and
/// read what the server tells a player over HTTP next to the debug-state oracle.
///
/// The CURRENT game is whatever the [controller] is attached to: starting
/// another game (a play again) re-attaches it, so [controller] (`driveAs`,
/// `playerView`, `oracle`, `fireTimer`) and every helper here always act on the
/// same, newest game.
class LiveTable {
  LiveTable._(this.client, this.controller);

  /// Creates the guests, the lobby and the started game (see
  /// [DebugTableController.createTable]; [protocolTwo]: a table made as the
  /// `/debug` toolbar makes one for the rebuilt screens).
  static Future<LiveTable> open({
    required List<String> playerNames,
    required Map<String, int> roleCounts,
    required Map<String, String> playerRolesByName,
    required List<String> centerCards,
    required Map<String, int> timerSettings,
    bool protocolTwo = false,
  }) async {
    final clients = harnessClients();
    await clients.controller.createTable(
      playerNames: playerNames,
      roleCounts: roleCounts,
      playerRolesByName: playerRolesByName,
      centerCards: centerCards,
      timerSettings: timerSettings,
      protocolTwo: protocolTwo,
    );
    return LiveTable._(clients.client, clients.controller);
  }

  /// A table opened some other way (a phone's own 01 and 02) and dealt:
  /// [table]'s players and game adopted, so every helper here acts on it.
  static LiveTable adopt(DebugTable table) {
    final clients = harnessClients();
    clients.controller.attachTable(table);
    return LiveTable._(clients.client, clients.controller);
  }

  final DebugApiClient client;
  final DebugTableController controller;

  final Map<int, PlayerWire> _gameWires = {};
  final Map<int, PlayerWire> _lobbyWires = {};
  final List<PlayerWire> _extraWires = [];

  DebugTable get table => controller.table!;
  String get gameId => table.gameId;
  String get lobbyCode => table.lobbyCode;

  DebugPlayer player(String name) =>
      table.players.firstWhere((p) => p.displayName == name);

  // ---------------------------------------------------------------------------
  // Sockets
  // ---------------------------------------------------------------------------

  /// Opens [player]'s game socket (for the current game) and records it.
  Future<PlayerWire> connectGame(DebugPlayer player) async {
    final wire = await PlayerWire.connectToGame(client, gameId, player);
    _gameWires[player.userId] = wire;
    return wire;
  }

  /// Opens a SECOND game socket for [player] (another tab or phone). Not the
  /// one [gameWire] returns.
  Future<PlayerWire> connectExtraGame(DebugPlayer player) async {
    final wire = await PlayerWire.connectToGame(client, gameId, player);
    _extraWires.add(wire);
    return wire;
  }

  Future<PlayerWire> connectLobby(DebugPlayer player) async {
    final wire = await PlayerWire.connectLobby(client, table, player);
    _lobbyWires[player.userId] = wire;
    return wire;
  }

  /// The recorded game socket of [player] (open, or the last one closed).
  PlayerWire gameWire(DebugPlayer player) => _gameWires[player.userId]!;
  PlayerWire lobbyWire(DebugPlayer player) => _lobbyWires[player.userId]!;

  /// Closes [player]'s game socket from the client side, as a phone going away.
  /// Its recorded events stay readable through [gameWire].
  Future<void> dropGame(DebugPlayer player) => gameWire(player).close();

  Future<void> dropLobby(DebugPlayer player) => lobbyWire(player).close();

  /// Closes every socket still open (test teardown).
  Future<void> closeAll() async {
    for (final wire in [
      ..._gameWires.values,
      ..._lobbyWires.values,
      ..._extraWires,
    ]) {
      await wire.close();
    }
  }

  // ---------------------------------------------------------------------------
  // What the server says (HTTP) and what is true (oracle)
  // ---------------------------------------------------------------------------

  /// `GET /onuw/games/<id>/me/` as [player] (the current game unless [game]).
  Future<Map<String, dynamic>> me(DebugPlayer player, {String? game}) => client
      .get('/onuw/games/${game ?? gameId}/me/', token: player.accessToken);

  /// `GET /lobbies/<code>/` as [player].
  Future<Map<String, dynamic>> lobby(DebugPlayer player) =>
      client.get('/lobbies/$lobbyCode/', token: player.accessToken);

  /// The player list of the current game, as [player] sees it:
  /// user id -> `connected`.
  Future<Map<int, bool>> presenceAsSeenBy(DebugPlayer player) async {
    final body = await client.get(
      '/onuw/games/$gameId/players/',
      token: player.accessToken,
    );
    return {
      for (final p in (body['players'] as List).cast<Map<String, dynamic>>())
        (p['player_id'] as num).toInt(): p['connected'] as bool,
    };
  }

  /// `GET /onuw/me/current-game/` as [player].
  Future<Map<String, dynamic>> currentGame(DebugPlayer player) =>
      client.get('/onuw/me/current-game/', token: player.accessToken);

  /// The raw debug-state body of the current game (all of it, including
  /// `pending_timers` and each player's `connected`).
  Future<Map<String, dynamic>> oracleJson({String? game}) => client.get(
    '/onuw/games/${game ?? gameId}/debug-state/',
    token: table.host.accessToken,
  );

  /// The oracle's `pending_timers`: `wave:2`, `grace:<user id>`,
  /// `host_handover`, ...
  Future<List<String>> pendingTimers() async =>
      ((await oracleJson())['pending_timers'] as List).cast<String>();

  Future<String> phase() async => (await oracleJson())['phase'] as String;

  /// `POST /lobbies/<code>/play-again/` as [player]; with [alias] the same
  /// action under the ONUW prefix (`/onuw/lobbies/<code>/play-again/`).
  Future<Map<String, dynamic>> playAgain(
    DebugPlayer player, {
    bool alias = false,
  }) => client.post(
    alias
        ? '/onuw/lobbies/$lobbyCode/play-again/'
        : '/lobbies/$lobbyCode/play-again/',
    token: player.accessToken,
  );

  /// One `POST /onuw/lobbies/<code>/start/` as [player], not yet adopted: for a
  /// double tap, where only one of two requests may deal a game. The body is
  /// the response (`game_id`).
  Future<Map<String, dynamic>> startRequest(
    DebugPlayer player, {
    Map<String, String>? dealtByName,
    List<String>? centerCards,
  }) => client.post(
    '/onuw/lobbies/$lobbyCode/start/',
    token: player.accessToken,
    data: dealtByName == null
        ? null
        : {
            'debug': {
              'forced_assignment': ForcedAssignment(
                playerRoles: {
                  for (final p in table.players)
                    p.userId: dealtByName[p.displayName]!,
                },
                center: centerCards!,
              ).toJson(),
            },
          },
  );

  /// Starts the next game as [player] and attaches the controller to it. With
  /// [dealtByName] and [centerCards] the deal is forced.
  Future<Map<String, dynamic>> startGame(
    DebugPlayer player, {
    Map<String, String>? dealtByName,
    List<String>? centerCards,
  }) async {
    final body = await startRequest(
      player,
      dealtByName: dealtByName,
      centerCards: centerCards,
    );
    adoptGame(body['game_id'] as String);
    return body;
  }

  /// Makes [gameId] the current game (the controller acts on it from now on).
  void adoptGame(String gameId) => controller.attachTable(
    DebugTable(gameId: gameId, lobbyCode: lobbyCode, players: table.players),
  );

  /// `POST` one of the game's host-only endpoints as [player].
  Future<void> hostAction(DebugPlayer player, String endpoint) async {
    await client.post(
      '/onuw/games/$gameId/$endpoint/',
      token: player.accessToken,
    );
  }
}
