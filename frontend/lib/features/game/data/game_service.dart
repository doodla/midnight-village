import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/authenticated_client.dart';
import '../../../core/logging/app_logger.dart';
import '../../../features/auth/presentation/auth_notifier.dart';
import '../domain/game_session_state.dart';

part 'game_service.g.dart';

/// HTTP service for all game-related API calls.
///
/// Uses [AuthenticatedClient] for JWT-authenticated requests. Handles 409
/// responses on action/vote submission as success (idempotent -- player
/// already acted).
class GameService {
  GameService({required AuthenticatedClient client}) : _client = client;

  final AuthenticatedClient _client;

  /// Fetches the current player's view of the game state.
  ///
  /// `GET /onuw/games/{id}/me/`
  Future<GameSessionState> getGameState(String gameId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/onuw/games/$gameId/me/',
      );
      final data = response.data;
      if (data == null) {
        throw const MalformedResponseException('Response body is null');
      }
      return GameSessionState.fromJson(data);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Submits a night action for the current player.
  ///
  /// `POST /onuw/games/{id}/action/`
  /// 409 is treated as success (player already acted this wave).
  /// 400 means invalid action for current state -- surfaces to caller.
  Future<void> submitAction(
    String gameId,
    String actionType,
    Map<String, dynamic> targets,
  ) async {
    try {
      await _client.post<Map<String, dynamic>>(
        '/onuw/games/$gameId/action/',
        data: {'action_type': actionType, 'targets': targets},
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        logger.d(
          'GameService.submitAction: 409 -- already acted, treating as success',
        );
        return;
      }
      throw mapDioException(e);
    }
  }

  /// Submits a vote for the current player.
  ///
  /// `POST /onuw/games/{id}/vote/`
  /// 409 is treated as success (player already voted).
  Future<void> submitVote(String gameId, int targetPlayerId) async {
    try {
      await _client.post<Map<String, dynamic>>(
        '/onuw/games/$gameId/vote/',
        data: {'target_player_id': targetPlayerId},
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        logger.d(
          'GameService.submitVote: 409 -- already voted, treating as success',
        );
        return;
      }
      throw mapDioException(e);
    }
  }

  /// Ends the discussion phase (host only).
  ///
  /// `POST /onuw/games/{id}/end-discussion/`
  Future<void> endDiscussion(String gameId) async {
    try {
      await _client.post<Map<String, dynamic>>(
        '/onuw/games/$gameId/end-discussion/',
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Fetches full game results.
  ///
  /// `GET /onuw/games/{id}/results/`
  /// Returns the raw results map for the caller to parse.
  Future<Map<String, dynamic>> fetchResults(String gameId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/onuw/games/$gameId/results/',
      );
      final data = response.data;
      if (data == null) {
        throw const MalformedResponseException('Results response body is null');
      }
      return data;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}

/// Provides the game service with an authenticated client.
@riverpod
GameService gameService(Ref ref) {
  return GameService(client: ref.watch(authenticatedClientProvider));
}
