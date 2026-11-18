import 'dart:convert';

/// Static factory for WebSocket event JSON strings.
///
/// Each method produces a JSON-encoded string matching the exact format
/// the server sends. Use with [MockWebSocketChannel.addServerEvent].
///
/// Event formats are derived from the real server contract as used in
/// [GameNotifier._handleWsMessage] and [LobbyNotifier._handleWsMessage].
abstract final class GameEvents {
  // ---------------------------------------------------------------------------
  // Night phase events
  // ---------------------------------------------------------------------------

  /// Wave starts, clearing previous action state.
  static String waveStart({required int wave, String? deadline}) {
    return jsonEncode({
      'type': 'wave_start',
      'wave': wave,
      'deadline': deadline,
    });
  }

  /// Server prompts player for a night action.
  static String actionPrompt({
    required String role,
    required List<String> actionTypes,
    Map<String, dynamic> validTargets = const {},
    int wave = 1,
  }) {
    return jsonEncode({
      'type': 'action_prompt',
      'role_acting_as': role,
      'action_types': actionTypes,
      'valid_targets': validTargets,
      'wave': wave,
    });
  }

  /// Result of a submitted night action.
  static String actionResult({
    required int wave,
    required Map<String, dynamic> revealedInfo,
    String? actionType,
  }) {
    final map = <String, dynamic>{
      'type': 'action_result',
      'wave': wave,
      'revealed_info': revealedInfo,
    };
    if (actionType != null) {
      map['action_type'] = actionType;
    }
    return jsonEncode(map);
  }

  /// Wave completed, transition to waiting.
  static String waveComplete({int wave = 1}) {
    return jsonEncode({'type': 'wave_complete', 'wave': wave});
  }

  /// Player has no action this wave.
  static String waveWaiting({int wave = 1}) {
    return jsonEncode({'type': 'wave_waiting', 'wave': wave});
  }

  // ---------------------------------------------------------------------------
  // Phase transitions
  // ---------------------------------------------------------------------------

  /// Game phase changes (night -> discussion -> voting -> results).
  static String phaseChange({required String phase, String? deadline}) {
    return jsonEncode({
      'type': 'phase_change',
      'phase': phase,
      'deadline': deadline,
    });
  }

  // ---------------------------------------------------------------------------
  // Voting events
  // ---------------------------------------------------------------------------

  /// A player submitted their vote (progress tracking, no target revealed).
  static String voteSubmitted({required int playerId}) {
    return jsonEncode({'type': 'vote_submitted', 'player_id': playerId});
  }

  /// All votes revealed. Tally is computed client-side by GameNotifier.
  static String voteReveal({required Map<String, int?> votes}) {
    return jsonEncode({'type': 'vote_reveal', 'votes': votes});
  }

  /// Game results ready, triggers REST fetch.
  static String gameResults() {
    return jsonEncode({'type': 'game_results'});
  }

  /// A player's phone connected or dropped (public to the whole table).
  static String playerPresence({
    required int playerId,
    required bool connected,
  }) {
    return jsonEncode({
      'type': 'player_presence',
      'player_id': playerId,
      'connected': connected,
    });
  }

  /// The host took the table back to the lobby for another game.
  static String playAgain({required String lobbyCode}) {
    return jsonEncode({'type': 'play_again', 'lobby_code': lobbyCode});
  }

  // ---------------------------------------------------------------------------
  // Lobby events
  // ---------------------------------------------------------------------------

  /// Player joined the lobby.
  static String playerJoined({
    required int playerId,
    required String displayName,
  }) {
    return jsonEncode({
      'type': 'player_joined',
      'user_id': playerId,
      'username': displayName,
    });
  }

  /// Player left the lobby.
  static String playerLeft({required int playerId}) {
    return jsonEncode({'type': 'player_left', 'user_id': playerId});
  }

  /// Player toggled ready state.
  static String playerReady({
    required int playerId,
    required String displayName,
    required bool isReady,
  }) {
    return jsonEncode({
      'type': 'player_ready',
      'user_id': playerId,
      'username': displayName,
      'is_ready': isReady,
    });
  }

  /// Lobby config updated.
  static String lobbyUpdate({required Map<String, int> roleConfig}) {
    return jsonEncode({
      'type': 'lobby_update',
      'data': {
        'settings': {'roles': roleConfig},
      },
    });
  }

  /// Game started from lobby.
  static String gameStarted({required String gameId}) {
    return jsonEncode({'type': 'game_started', 'game_id': gameId});
  }
}
