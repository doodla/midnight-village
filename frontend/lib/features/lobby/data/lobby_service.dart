import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/authenticated_client.dart';
import '../domain/lobby_state.dart';
import '../domain/where_am_i.dart';

/// HTTP service for lobby CRUD operations.
///
/// Each method maps to one REST endpoint. Responses are parsed into
/// [LobbyState] via [LobbyState.fromJson]. Dio exceptions are mapped
/// to typed [ApiException]s. The [AuthInterceptor] handles 401s
/// automatically.
class LobbyService {
  LobbyService({required AuthenticatedClient client}) : _client = client;

  final AuthenticatedClient _client;

  /// Opens a table: POST /lobbies/ with
  /// `{"game_type": "onuw", "defaults": "v2"}`, always (the app's starting
  /// set). The server writes the table's defaults (the look stage, the
  /// automatic Simple deck) and no timer length.
  Future<LobbyState> createTable() async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/lobbies/',
        data: {'game_type': 'onuw', 'defaults': 'v2'},
      );
      return _parseLobbyResponse(response);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// The host picks a deck chip: the deck goes back to automatic and the
  /// server builds it at the deal for the players then at the table.
  ///
  /// PATCH /lobbies/<code>/ with
  /// `{"settings": {"deck": "auto", "deck_chip": <chip>}}` (merged into the
  /// stored settings; refused 409 while a game runs).
  Future<LobbyState> setDeckChip(String code, DeckChip chip) =>
      _patchSettings(code, deckChip(chip));

  /// The host edits the cards: the deck is custom from now on.
  ///
  /// PATCH /lobbies/<code>/ with `{"settings": {"deck": "custom", "roles"}}`.
  Future<LobbyState> setCustomDeck(String code, Map<String, int> roles) =>
      _patchSettings(code, customDeck(roles));

  /// The settings a deck chip writes ([setDeckChip]).
  static Map<String, Object> deckChip(DeckChip chip) => {
    'deck': 'auto',
    'deck_chip': chip.server,
  };

  /// The settings a custom deck writes ([setCustomDeck]).
  static Map<String, Object> customDeck(Map<String, int> roles) => {
    'deck': 'custom',
    'roles': roles,
  };

  /// PATCH /lobbies/<code>/ with `{"settings": settings}`: the server merges
  /// them over the stored ones (shallow) and answers the whole lobby.
  Future<LobbyState> patchSettings(
    String code,
    Map<String, Object?> settings,
  ) => _patchSettings(code, settings);

  Future<LobbyState> _patchSettings(
    String code,
    Map<String, Object?> settings,
  ) async {
    try {
      final response = await _client.patch<Map<String, dynamic>>(
        '/lobbies/$code/',
        data: {'settings': settings},
      );
      return _parseLobbyResponse(response);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Practice players (host, waiting table): POST /lobbies/<code>/practice/
  /// with `{"on": bool}` (switched on or off for the table: off takes every
  /// one away) and/or `{"count": n}` (how many sit at it; a target, safe to
  /// send twice). Answers the whole lobby.
  Future<LobbyState> setPractice(String code, {bool? on, int? count}) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/lobbies/$code/practice/',
        data: {'on': ?on, 'count': ?count},
      );
      return _parseLobbyResponse(response);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Where am I: GET /me/table/. Null when at no table.
  Future<MyTable?> fetchMyTable() async {
    try {
      final response = await _client.get<Map<String, dynamic>>('/me/table/');
      return MyTable.parse(response.data!);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// This player's finished games, newest first:
  /// GET /onuw/me/recent-games/ (the server's default of five).
  Future<List<RecentGame>> fetchRecentGames() async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/onuw/me/recent-games/',
      );
      return RecentGame.listFrom(response.data!);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Joins an existing lobby by code.
  ///
  /// POST /lobbies/<code>/join/
  Future<LobbyState> joinLobby(String code) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/lobbies/$code/join/',
      );
      return _parseLobbyResponse(response);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Leaves a lobby: POST /lobbies/<code>/leave/.
  Future<void> leaveLobby(String code) async {
    try {
      await _client.post<Map<String, dynamic>>('/lobbies/$code/leave/');
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Starts the game from the lobby (host only).
  ///
  /// POST /onuw/lobbies/<code>/start/
  /// Returns the game ID.
  Future<String> startGame(String code) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/onuw/lobbies/$code/start/',
      );
      return response.data!['game_id'] as String;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Takes the table back to waiting after a finished game (host only).
  ///
  /// POST /lobbies/<code>/play-again/
  /// 403 for a non-host, 409 when the game is not in results. Returns the
  /// lobby (same players, same deck, waiting).
  Future<LobbyState> playAgain(String code) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/lobbies/$code/play-again/',
      );
      return _parseLobbyResponse(response);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// The id of the game this player is in at table [code], if one is running.
  ///
  /// GET /onuw/me/current-game/ -- null when there is none or it belongs to
  /// another table. Lets a lobby that missed `game_started` find the game.
  Future<String?> activeGameIdAt(String code) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/onuw/me/current-game/',
      );
      // The server answers {"game_id", "phase", "lobby_code"}, or
      // {"game": null} when there is no running game.
      final data = response.data!;
      return data['lobby_code'] == code ? data['game_id'] as String : null;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Fetches the current lobby state.
  ///
  /// GET /lobbies/<code>/
  Future<LobbyState> fetchLobby(String code) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/lobbies/$code/',
      );
      return _parseLobbyResponse(response);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  LobbyState _parseLobbyResponse(Response<Map<String, dynamic>> response) =>
      LobbyState.fromJson(response.data!);
}
