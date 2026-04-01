import '../../../core/api/authenticated_client.dart';

/// Full game state response from `GET /onuw/games/<id>/me/`.
///
/// Contains the complete player-scoped game state needed to restore the
/// correct view after a WebSocket reconnection. The server response is
/// authoritative — this is re-fetched rather than reconstructed from
/// cached WebSocket events (T053, SC-003).
class GameStateResponse {
  const GameStateResponse({
    required this.phase,
    this.currentWave,
    this.deadline,
    this.yourRole,
    this.actionPrompt,
    required this.players,
    required this.hasVoted,
    required this.hasActed,
  });

  factory GameStateResponse.fromJson(Map<String, dynamic> json) {
    return GameStateResponse(
      phase: json['phase']?.toString() ?? '',
      currentWave: json['current_wave']?.toString(),
      deadline: json['deadline']?.toString(),
      yourRole: json['your_role']?.toString(),
      actionPrompt: json['action_prompt'] as Map<String, dynamic>?,
      players:
          (json['players'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [],
      hasVoted: json['has_voted'] == true,
      hasActed: json['has_acted'] == true,
    );
  }

  /// Current game phase (e.g. 'night', 'discussion', 'voting', 'results').
  final String phase;

  /// Current night wave identifier, or null when not in night phase.
  final String? currentWave;

  /// Server-authoritative deadline for the current phase (ISO 8601), or null.
  final String? deadline;

  /// The authenticated player's role name, or null if not yet revealed.
  final String? yourRole;

  /// The pending action prompt for the player, or null if no action is needed.
  ///
  /// When present during the night phase, the player still needs to act.
  /// When absent with [hasActed] true, the player is in the waiting sub-view.
  final Map<String, dynamic>? actionPrompt;

  /// All players in the game (display names and vote state, no hidden info).
  final List<Map<String, dynamic>> players;

  /// Whether the player has already submitted a vote in the voting phase.
  final bool hasVoted;

  /// Whether the player has completed their night action.
  final bool hasActed;
}

/// Response from the current-game endpoint.
///
/// When the player has an active game, [gameId], [phase], and [lobbyCode]
/// are populated. When there is no active game, all fields are null.
class CurrentGameResponse {
  const CurrentGameResponse({this.gameId, this.phase, this.lobbyCode});

  factory CurrentGameResponse.fromJson(Map<String, dynamic> json) {
    // The API returns either:
    //   {"game_id": "...", "phase": "...", "lobby_code": "..."}  (active game)
    //   {"game": null}                                           (no game)
    //   {"game": {"game_id": "...", ...}}                        (nested form)

    // Check for explicit no-game signal.
    if (json.containsKey('game') && json['game'] == null) {
      return const CurrentGameResponse();
    }

    // If nested under 'game' key, unwrap.
    final data = json['game'] is Map<String, dynamic>
        ? json['game'] as Map<String, dynamic>
        : json;

    final gameId = data['game_id']?.toString();
    if (gameId == null) {
      return const CurrentGameResponse();
    }

    return CurrentGameResponse(
      gameId: gameId,
      phase: data['phase']?.toString(),
      lobbyCode: data['lobby_code']?.toString(),
    );
  }

  /// The active game's ID, or null if no active game.
  final String? gameId;

  /// The current phase of the active game, or null.
  final String? phase;

  /// The lobby code for the active game, or null.
  final String? lobbyCode;

  /// Whether the player has an active game.
  bool get hasActiveGame => gameId != null;
}

/// Service for checking whether the current player has an active game.
///
/// Used on app startup to detect in-progress games and redirect to the
/// game screen. The result is cached to avoid repeated API calls.
class GameResumeService {
  GameResumeService({required AuthenticatedClient apiClient})
    : _apiClient = apiClient;

  final AuthenticatedClient _apiClient;

  /// Cached result from the last check.
  CurrentGameResponse? _cachedResult;

  /// Whether a check has already been performed.
  bool get hasChecked => _cachedResult != null;

  /// Returns the cached result without making a network call.
  ///
  /// Returns null if [checkCurrentGame] has not been called yet.
  CurrentGameResponse? get cachedResult => _cachedResult;

  /// Checks if the player has an active game.
  ///
  /// Calls `GET /onuw/me/current-game/` and caches the result.
  /// Subsequent calls return the cached result unless [force] is true.
  Future<CurrentGameResponse> checkCurrentGame({bool force = false}) async {
    if (_cachedResult != null && !force) {
      return _cachedResult!;
    }

    final response = await _apiClient.get<Map<String, dynamic>>(
      '/onuw/me/current-game/',
    );

    final result = CurrentGameResponse.fromJson(
      response.data ?? {'game': null},
    );
    _cachedResult = result;
    return result;
  }

  /// Clears the cached result so the next check hits the network.
  void clearCache() {
    _cachedResult = null;
  }

  /// Re-fetches full game state from the server after a WebSocket reconnection.
  ///
  /// Calls `GET /onuw/games/<id>/me/` and returns the complete player-scoped
  /// game state. The response is authoritative — re-fetching is more reliable
  /// than reconstructing state from missed WebSocket events.
  ///
  /// The [GameStateResponse] contains everything needed to restore the correct
  /// phase view: [GameStateResponse.phase], [GameStateResponse.hasActed],
  /// [GameStateResponse.actionPrompt], [GameStateResponse.hasVoted], etc.
  ///
  /// Integration with [GameNotifier] (WP07): when WP07 lands on this branch,
  /// the caller should pass the response to `GameNotifier.rebuildFromState()`.
  Future<GameStateResponse> getGameState(String gameId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/onuw/games/$gameId/me/',
    );
    return GameStateResponse.fromJson(response.data ?? {});
  }
}
