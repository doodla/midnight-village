import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/api/authenticated_client.dart';
import '../../../core/logging/app_logger.dart';
import '../../../features/auth/presentation/auth_notifier.dart';
import '../domain/game_me.dart';
import '../domain/game_outcome.dart';
import '../domain/game_session_state.dart';
import 'stage_requests.dart';

export 'stage_requests.dart';

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
      return gameStateFromServer(response.data!);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Fetches who is connected, as `player_id -> connected`.
  ///
  /// `GET /onuw/games/{id}/players/`
  /// Presence is a courtesy: callers treat a failure as "everyone
  /// connected", never as an error.
  Future<Map<int, bool>> fetchPresence(String gameId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/onuw/games/$gameId/players/',
      );
      return {
        for (final p in response.data!['players'] as List)
          (p as Map)['player_id'] as int: p['connected'] as bool,
      };
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

  /// Closes the current night window now (host only).
  ///
  /// `POST /onuw/games/{id}/advance-wave/`
  Future<void> advanceNight(String gameId) async {
    try {
      await _client.post<Map<String, dynamic>>(
        '/onuw/games/$gameId/advance-wave/',
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Reveals the votes now (host only); players who have not voted abstain.
  ///
  /// `POST /onuw/games/{id}/reveal-votes/`
  Future<void> revealVotes(String gameId) async {
    try {
      await _client.post<Map<String, dynamic>>(
        '/onuw/games/$gameId/reveal-votes/',
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
      return response.data!;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  // ---------------------------------------------------------------------------
  // Night protocol 2. Every stage-scoped request echoes `/me/`'s `stage` and
  // answers a [StageAnswer]: a 409 is "fetch /me/ again", never an error.
  // ---------------------------------------------------------------------------

  /// `GET /onuw/games/{id}/me/` of a protocol-2 game.
  Future<GameMe> fetchMe(String gameId) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/onuw/games/$gameId/me/',
      );
      return GameMe.fromJson(response.data!);
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// `GET /onuw/games/{id}/results/`, parsed.
  Future<GameOutcome> fetchOutcome(String gameId) async =>
      GameOutcome.fromJson(await fetchResults(gameId));

  Future<StageAnswer> _stage(String path, Map<String, Object> body) async {
    try {
      await _client.post<Map<String, dynamic>>(path, data: body);
      return StageAnswer.taken;
    } on DioException catch (e) {
      final answer = stageAnswerOf(e);
      logger.d(
        'GameService: $path answered ${e.response?.statusCode} '
        '(${answer.name})',
      );
      return answer;
    }
  }

  /// `POST .../action/` `{"action_type": "choose", "picks", "stage"}`.
  Future<StageAnswer> choose(String gameId, ChooseRequest request) =>
      _stage('/onuw/games/$gameId/action/', request.toJson());

  /// `POST .../ready/` `{"ready", "stage"}`: "I've looked at my card" at the
  /// look (true only), "ready to vote" in the talk (true or false).
  Future<StageAnswer> setReady(
    String gameId, {
    required String stage,
    required bool ready,
  }) => _stage('/onuw/games/$gameId/ready/', {'ready': ready, 'stage': stage});

  /// `POST .../vote/` `{"target_player_id", "lock", "stage"}`: a pick
  /// (`lock: false`, may change) or locking in (final; it carries the target,
  /// so a lost pick can never lock the wrong name).
  Future<StageAnswer> vote(
    String gameId, {
    required String stage,
    required int targetId,
    required bool lock,
  }) => _stage('/onuw/games/$gameId/vote/', {
    'target_player_id': targetId,
    'lock': lock,
    'stage': stage,
  });

  /// `POST .../night-results/seen/` `{"seen": n}`: this phone has shown the
  /// first [seen] night results. Answers the stored (monotonic) count.
  Future<int> acknowledgeNightResults(String gameId, int seen) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/onuw/games/$gameId/night-results/seen/',
        data: {'seen': seen},
      );
      return response.data!['night_results_seen'] as int;
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Host: open the night now (look) or close the window now, for [stage].
  Future<StageAnswer> advanceStage(String gameId, {required String stage}) =>
      _stage('/onuw/games/$gameId/advance-wave/', {'stage': stage});

  /// Host: end the talk now, for [stage].
  Future<StageAnswer> endTalk(String gameId, {required String stage}) =>
      _stage('/onuw/games/$gameId/end-discussion/', {'stage': stage});

  /// Host: reveal the votes now, for [stage].
  Future<StageAnswer> revealVotesAt(String gameId, {required String stage}) =>
      _stage('/onuw/games/$gameId/reveal-votes/', {'stage': stage});
}

/// Provides the game service with an authenticated client.
@riverpod
GameService gameService(Ref ref) {
  return GameService(client: ref.watch(authenticatedClientProvider));
}
