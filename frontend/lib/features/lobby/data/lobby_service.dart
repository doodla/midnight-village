import 'package:dio/dio.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/authenticated_client.dart';
import '../domain/lobby_state.dart';

/// HTTP service for lobby CRUD operations.
///
/// Each method maps to one REST endpoint. Responses are parsed into
/// [LobbyState] via [LobbyState.fromJson]. Dio exceptions are mapped
/// to typed [ApiException]s. The [AuthInterceptor] handles 401s
/// automatically.
class LobbyService {
  LobbyService({required AuthenticatedClient client}) : _client = client;

  final AuthenticatedClient _client;

  /// Creates a new lobby for ONUW.
  ///
  /// POST /lobbies/ with {"game_type": "onuw"}
  Future<LobbyState> createLobby() async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/lobbies/',
        data: {'game_type': 'onuw'},
      );
      return _parseLobbyResponse(response);
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

  /// Leaves a lobby.
  ///
  /// POST /lobbies/<code>/leave/
  Future<void> leaveLobby(String code) async {
    try {
      await _client.post<Map<String, dynamic>>('/lobbies/$code/leave/');
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Toggles the current player's ready state.
  ///
  /// POST /lobbies/<code>/ready/
  Future<void> toggleReady(String code) async {
    try {
      await _client.post<Map<String, dynamic>>('/lobbies/$code/ready/');
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Updates the role configuration (host only).
  ///
  /// PATCH /lobbies/<code>/ with {"settings": {"roles": {...}}}
  Future<LobbyState> updateRoleConfig(
    String code,
    Map<String, int> roles,
  ) async {
    try {
      final response = await _client.patch<Map<String, dynamic>>(
        '/lobbies/$code/',
        data: {
          'settings': {'roles': roles},
        },
      );
      return _parseLobbyResponse(response);
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
      final data = response.data;
      if (data == null) {
        throw const MalformedResponseException('Response body is null');
      }
      final gameId = data['game_id'];
      if (gameId is! String) {
        throw const MalformedResponseException(
          'Missing or invalid game_id in start response',
        );
      }
      return gameId;
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

  LobbyState _parseLobbyResponse(Response<Map<String, dynamic>> response) {
    final data = response.data;
    if (data == null) {
      throw const MalformedResponseException('Response body is null');
    }
    return LobbyState.fromJson(data);
  }
}
