import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config/env.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/websocket/reconnecting_websocket.dart';
import '../../../core/websocket/websocket_channel.dart';
import '../../../design_system/models/game_result.dart';
import '../../../design_system/models/role.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../data/game_service.dart';
import '../domain/game_session_state.dart';
import '../domain/night_state.dart';
import '../domain/voting_state.dart';

part 'game_notifier.g.dart';

/// Core game state machine that handles all WebSocket events and exposes
/// action methods.
///
/// Family provider keyed by game ID. Fetches initial state via REST, then
/// listens to a WebSocket stream for real-time updates. Each WS event type
/// is handled by a discrete method for testability.
///
/// The [NightSubView] state machine is display-only -- it determines which
/// view the [GameContainerScreen] renders during the night phase.
@riverpod
class GameNotifier extends _$GameNotifier {
  StreamSubscription<dynamic>? _wsSubscription;
  StreamSubscription<WebSocketConnectionState>? _connectionSubscription;
  Timer? _resultsTimeout;
  bool _wasDisconnected = false;

  /// WebSocket stream injected for testability.
  /// In production this comes from a ReconnectingWebSocket provider.
  /// In tests it can be overridden via the [webSocketStreamProvider].
  Stream<dynamic>? _wsStream;

  @override
  Future<GameSessionState> build(String gameId) async {
    final service = ref.read(gameServiceProvider);
    final initialState = await service.getGameState(gameId);

    // Listen to WebSocket stream if available.
    _wsStream = ref.read(gameWebSocketStreamProvider(gameId));
    if (_wsStream != null) {
      _wsSubscription = _wsStream!.listen(
        _handleWsMessage,
        onError: (Object error) {
          logger.w('GameNotifier: WebSocket error', error: error);
        },
      );
    }

    // Listen to connection state for reconnection-triggered refresh.
    // When the WebSocket reconnects after a disconnect, re-fetch authoritative
    // state from the server to recover any events missed while disconnected.
    final ws = ref.read(gameWebSocketProvider(gameId));
    if (ws != null) {
      _connectionSubscription = ws.connectionState.listen(
        _handleConnectionStateChange,
      );
    }

    ref.onDispose(() {
      _wsSubscription?.cancel();
      _connectionSubscription?.cancel();
      _resultsTimeout?.cancel();
    });

    // Hydrate frontend-only display state from the server response.
    var hydrated = _hydrateInitialState(initialState);

    // If reconnecting to results phase, fetch results immediately since the
    // game_results WebSocket event was already sent before we connected.
    if (hydrated.phase == 'results') {
      try {
        final data = await service.fetchResults(gameId);
        final gameResult = _parseGameResult(data, hydrated.players);
        hydrated = hydrated.copyWith(results: gameResult);
      } catch (e) {
        logger.e(
          'GameNotifier: Failed to fetch results on reconnect',
          error: e,
        );
      }
    }

    return hydrated;
  }

  /// Hydrates frontend-only display state from the initial REST response.
  ///
  /// Night phase: derives the correct [NightSubView].
  /// Voting phase: populates [VoteProgress] from the server-provided
  /// [GamePlayer.hasVoted] field so reconnecting clients see accurate
  /// vote progress.
  ///
  /// [carriedResult] is a night result the player has been shown but not yet
  /// dismissed. The server does not send it again, so a refresh keeps the one
  /// already on screen.
  GameSessionState _hydrateInitialState(
    GameSessionState state, {
    ActionResult? carriedResult,
  }) {
    var result = state;

    if (carriedResult != null &&
        (result.phase == 'night' || result.phase == 'discussion')) {
      result = result.copyWith(lastActionResult: carriedResult);
    }

    if (result.phase == 'night') {
      if (result.actionPrompt != null) {
        result = result.copyWith(
          nightSubView: result.lastActionResult != null
              ? NightSubView.actionResult
              : _subViewForPrompt(result.actionPrompt!),
        );
      } else {
        // Either nothing to do this window, or already submitted and waiting
        // for the window to close: the server sends no result until then.
        result = result.copyWith(
          nightSubView: result.lastActionResult != null
              ? NightSubView.actionResult
              : NightSubView.waiting,
        );
      }
    }

    if (result.phase == 'voting') {
      final playerVoted = <int, bool>{
        for (final p in result.players) p.playerId: p.hasVoted,
      };
      result = result.copyWith(
        voteProgress: VoteProgress(
          playerVoted: playerVoted,
          currentPlayerVoted: result.hasVoted,
        ),
      );
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // WebSocket event dispatch
  // ---------------------------------------------------------------------------

  void _handleWsMessage(dynamic message) {
    final Map<String, dynamic> event;
    if (message is String) {
      event = jsonDecode(message) as Map<String, dynamic>;
    } else if (message is Map<String, dynamic>) {
      event = message;
    } else {
      logger.w('GameNotifier: Unknown message type: ${message.runtimeType}');
      return;
    }

    final type = event['type'] as String?;
    if (type == null) {
      logger.w('GameNotifier: WS event missing type field');
      return;
    }

    switch (type) {
      case 'wave_start':
        _handleWaveStart(event);
      case 'action_prompt':
        _handleActionPrompt(event);
      case 'action_result':
        _handleActionResult(event);
      case 'wave_complete':
        _handleWaveComplete(event);
      case 'wave_waiting':
        _handleWaveWaiting(event);
      case 'phase_change':
        _handlePhaseChange(event);
      case 'vote_submitted':
        _handleVoteSubmitted(event);
      case 'vote_reveal':
        _handleVoteReveal(event);
      case 'game_results':
        _handleGameResults(event);
      default:
        logger.d('GameNotifier: Unhandled WS event type: $type');
    }
  }

  // ---------------------------------------------------------------------------
  // Event handlers (each is a discrete, testable method)
  // ---------------------------------------------------------------------------

  /// Updates currentWave and deadline when a night window opens.
  ///
  /// The night has two windows (1 = Doppelganger, 2 = everyone else). A result
  /// the player has not dismissed yet (the Doppelganger's look, shown before
  /// window 2 opens) stays on screen: only a prompt or the player replaces it.
  void _handleWaveStart(Map<String, dynamic> data) {
    _updateState((state) {
      final wave = data['wave'] as int;
      final deadlineStr = data['deadline'] as String?;
      final deadline = deadlineStr != null ? DateTime.parse(deadlineStr) : null;
      return state.copyWith(
        currentWave: wave,
        deadline: deadline,
        actionPrompt: null,
      );
    });
  }

  /// Chooses the sub-view for a prompt: the Seer's pick between looking at a
  /// player or at the center when several real actions are offered, else the
  /// action screen. A lone action plus `skip` is not a choice.
  NightSubView _subViewForPrompt(ActionPrompt prompt) =>
      prompt.needsActionChoice
      ? NightSubView.seerChoice
      : NightSubView.actionPrompt;

  /// Stores the prompt and shows it, unless the player is still reading a
  /// result: the Doppelganger's look result arrives immediately followed by her
  /// follow-up prompt in the same window, and must stay readable until she
  /// taps Continue.
  void _handleActionPrompt(Map<String, dynamic> data) {
    _updateState((state) {
      final prompt = ActionPrompt(
        roleActingAs: data['role_acting_as'] as String,
        actionTypes: List<String>.from(data['action_types'] as List),
        validTargets: Map<String, dynamic>.from(data['valid_targets'] as Map),
        wave: data['wave'] as int,
      );

      final readingResult =
          state.lastActionResult != null &&
          state.nightSubView == NightSubView.actionResult;

      return state.copyWith(
        actionPrompt: prompt,
        nightSubView: readingResult
            ? NightSubView.actionResult
            : _subViewForPrompt(prompt),
      );
    });
  }

  /// Stores the action result and transitions to actionResult sub-view.
  ///
  /// Results arrive when a window closes (all players' together), except the
  /// Doppelganger's look, which arrives on submit. Injects `action_type` (and,
  /// for see_team, `role_acting_as`) into [ActionResult.revealedInfo] so
  /// [NightResultView] can determine display logic without needing extra params.
  void _handleActionResult(Map<String, dynamic> data) {
    _updateState((state) {
      final revealedInfo = Map<String, dynamic>.from(
        data['revealed_info'] as Map,
      );
      // Inject action_type from the WS event top-level field.
      if (data['action_type'] is String) {
        revealedInfo['action_type'] = data['action_type'];
      }
      // Inject role_acting_as from current actionPrompt for see_team display
      // (the server includes it; this covers an older payload).
      if (revealedInfo['action_type'] == 'see_team' &&
          state.actionPrompt != null &&
          !revealedInfo.containsKey('role_acting_as')) {
        revealedInfo['role_acting_as'] = state.actionPrompt!.roleActingAs;
      }
      final result = ActionResult(
        wave: data['wave'] as int,
        revealedInfo: revealedInfo,
      );
      return state.copyWith(
        lastActionResult: result,
        nightSubView: NightSubView.actionResult,
      );
    });
  }

  /// A window closed: clear the prompt. The result that arrived just before
  /// stays on screen (it is the player's night information); anyone without one
  /// goes back to waiting.
  void _handleWaveComplete(Map<String, dynamic> data) {
    _updateState((state) {
      return state.copyWith(
        actionPrompt: null,
        nightSubView: state.lastActionResult != null
            ? NightSubView.actionResult
            : NightSubView.waiting,
      );
    });
  }

  /// Player has no action this window -- show waiting view (or keep the result
  /// they are still reading).
  void _handleWaveWaiting(Map<String, dynamic> data) {
    _updateState((state) {
      return state.copyWith(
        nightSubView: state.lastActionResult != null
            ? NightSubView.actionResult
            : NightSubView.waiting,
      );
    });
  }

  /// Updates phase and deadline on phase transition.
  ///
  /// Transitions to [NightSubView.roleReveal] when entering the night phase
  /// for the first time. The role reveal auto-advance timer runs client-side
  /// and transitions via [onRoleRevealComplete].
  ///
  /// Night results all arrive as window 2 closes, immediately followed by the
  /// move to discussion. A result the player has not dismissed survives that one
  /// transition so [GameContainerScreen] can show it before the discussion.
  void _handlePhaseChange(Map<String, dynamic> data) {
    _updateState((state) {
      final phase = data['phase'] as String;
      final deadlineStr = data['deadline'] as String?;
      final deadline = deadlineStr != null ? DateTime.parse(deadlineStr) : null;
      final nightSubView = phase == 'night'
          ? NightSubView.roleReveal
          : NightSubView.waiting;
      final keepResult =
          phase == 'discussion' && state.lastActionResult != null;
      return state.copyWith(
        phase: phase,
        deadline: deadline,
        // Reset night-specific state on phase change.
        actionPrompt: null,
        lastActionResult: keepResult ? state.lastActionResult : null,
        nightSubView: nightSubView,
      );
    });
  }

  /// Marks a player as having voted in VoteProgress.
  void _handleVoteSubmitted(Map<String, dynamic> data) {
    _updateState((state) {
      final playerId = data['player_id'] as int;
      final updatedVoted = Map<int, bool>.from(state.voteProgress.playerVoted);
      updatedVoted[playerId] = true;
      return state.copyWith(
        voteProgress: state.voteProgress.copyWith(playerVoted: updatedVoted),
      );
    });
  }

  /// Stores vote mapping and starts 5s timeout for game_results.
  void _handleVoteReveal(Map<String, dynamic> data) {
    _updateState((state) {
      final votesRaw = data['votes'] as Map<String, dynamic>;
      final votes = votesRaw.map<String, int?>(
        (key, value) => MapEntry(key, value as int?),
      );

      // Compute tally from votes.
      final tally = <String, int>{};
      for (final targetId in votes.values) {
        if (targetId != null) {
          final key = targetId.toString();
          tally[key] = (tally[key] ?? 0) + 1;
        }
      }

      final voteReveal = VoteRevealData(votes: votes, tally: tally);
      return state.copyWith(voteRevealData: voteReveal);
    });

    // Start 5-second timeout -- if game_results doesn't arrive, fetch via REST.
    _resultsTimeout?.cancel();
    _resultsTimeout = Timer(const Duration(seconds: 5), () {
      _fetchResultsFallback();
    });
  }

  /// Cancels timeout and triggers results fetch via REST.
  void _handleGameResults(Map<String, dynamic> data) {
    _resultsTimeout?.cancel();
    _updateState((state) {
      return state.copyWith(phase: 'results');
    });
    _fetchResultsFallback();
  }

  // ---------------------------------------------------------------------------
  // Exposed action methods
  // ---------------------------------------------------------------------------

  /// Called by [RoleRevealView] after the 4-second auto-advance timer fires.
  ///
  /// Transitions to the appropriate night sub-view based on whether an action
  /// prompt is available.
  void onRoleRevealComplete() {
    _updateState((state) {
      if (state.actionPrompt != null) {
        return state.copyWith(
          nightSubView: _subViewForPrompt(state.actionPrompt!),
        );
      }
      return state.copyWith(nightSubView: NightSubView.waiting);
    });
  }

  /// Called by [SeerChoiceView] when the player picks peek_player or peek_center.
  ///
  /// Narrows the action prompt to the selected action type and transitions to
  /// [NightSubView.actionPrompt]. `skip` stays on the prompt when the server
  /// offered it, so the "do nothing" control remains on the next screen.
  void selectSeerChoice(String actionType) {
    _updateState((state) {
      final prompt = state.actionPrompt;
      if (prompt == null) return state;
      return state.copyWith(
        actionPrompt: prompt.copyWith(
          actionTypes: [
            actionType,
            if (prompt.canSkip) ActionPromptChoices.skipType,
          ],
        ),
        nightSubView: NightSubView.actionPrompt,
      );
    });
  }

  /// Called when the player taps Continue on a night result.
  ///
  /// During the night this moves on to a prompt that is waiting for them (the
  /// Doppelganger's follow-up) or back to waiting. After the night it clears the
  /// result so the discussion shows.
  void dismissNightResult() {
    _updateState((state) {
      final prompt = state.actionPrompt;
      if (state.phase == 'night' && prompt != null) {
        return state.copyWith(
          lastActionResult: null,
          nightSubView: _subViewForPrompt(prompt),
        );
      }
      return state.copyWith(
        lastActionResult: null,
        nightSubView: NightSubView.waiting,
      );
    });
  }

  /// Called by [NightResultView] when a lone-werewolf see_team result is shown.
  ///
  /// Transitions to [NightSubView.loneWerewolfPeek] so the player can
  /// optionally peek at one center card.
  void transitionToLoneWerewolfPeek() {
    _updateState((state) {
      return state.copyWith(nightSubView: NightSubView.loneWerewolfPeek);
    });
  }

  /// Submits a night action (`skip` with empty targets is "do nothing").
  ///
  /// The server accepts it and the window stays open until it closes: no result
  /// comes back yet (only the Doppelganger's look does). Once accepted the
  /// player is shown waiting, unless a newer event already replaced the prompt
  /// (her follow-up). If the server rejects it, the error propagates and the
  /// prompt stays so the player can try again.
  Future<void> submitAction(
    String actionType,
    Map<String, dynamic> targets,
  ) async {
    final service = ref.read(gameServiceProvider);
    final submitted = state.value?.actionPrompt;
    await service.submitAction(gameId, actionType, targets);
    if (!ref.mounted || submitted == null) return;
    _updateState((s) {
      if (s.phase == 'night' && s.actionPrompt == submitted) {
        return s.copyWith(
          actionPrompt: null,
          nightSubView: s.lastActionResult != null
              ? NightSubView.actionResult
              : NightSubView.waiting,
        );
      }
      return s;
    });
  }

  /// Submits a vote for a target player.
  Future<void> submitVote(int targetPlayerId) async {
    final service = ref.read(gameServiceProvider);
    await service.submitVote(gameId, targetPlayerId);

    // Optimistically mark current player as voted.
    _updateState((state) {
      return state.copyWith(
        voteProgress: state.voteProgress.copyWith(currentPlayerVoted: true),
      );
    });
  }

  /// Ends the discussion phase (host only).
  Future<void> endDiscussion() async {
    final service = ref.read(gameServiceProvider);
    await service.endDiscussion(gameId);
  }

  // ---------------------------------------------------------------------------
  // Reconnection handling
  // ---------------------------------------------------------------------------

  /// Handles WebSocket connection state transitions.
  ///
  /// When the connection is re-established after a disconnect, triggers
  /// [refreshState] to re-fetch authoritative game state from the server,
  /// recovering any events missed during the disconnection window.
  void _handleConnectionStateChange(WebSocketConnectionState connState) {
    if (connState == WebSocketConnectionState.connected && _wasDisconnected) {
      _wasDisconnected = false;
      logger.d('GameNotifier: Reconnected — refreshing state from server');
      refreshState();
    } else if (connState == WebSocketConnectionState.disconnected ||
        connState == WebSocketConnectionState.reconnecting) {
      _wasDisconnected = true;
    }
  }

  /// Re-fetches authoritative game state from the server and re-hydrates
  /// all frontend-only display state.
  ///
  /// Called automatically on WebSocket reconnection. Can also be called
  /// manually if the caller suspects stale state.
  Future<void> refreshState() async {
    if (!ref.mounted) return;
    try {
      final service = ref.read(gameServiceProvider);
      final freshState = await service.getGameState(gameId);
      if (!ref.mounted) return;

      var hydrated = _hydrateInitialState(
        freshState,
        carriedResult: state.value?.lastActionResult,
      );

      // If we reconnected into results phase, fetch full results.
      if (hydrated.phase == 'results') {
        try {
          final data = await service.fetchResults(gameId);
          if (!ref.mounted) return;
          final gameResult = _parseGameResult(data, hydrated.players);
          hydrated = hydrated.copyWith(results: gameResult);
        } catch (e) {
          logger.e(
            'GameNotifier: Failed to fetch results on refresh',
            error: e,
          );
        }
      }

      if (ref.mounted) {
        state = AsyncData(hydrated);
      }
    } catch (e) {
      logger.e('GameNotifier: Failed to refresh state', error: e);
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Fetches full results from REST as a fallback when the game_results
  /// WS event is missed or as the primary data source.
  Future<void> _fetchResultsFallback() async {
    if (!ref.mounted) return;
    try {
      final service = ref.read(gameServiceProvider);
      final data = await service.fetchResults(gameId);
      if (!ref.mounted) return;

      // Map the raw results JSON to a GameResult model.
      final currentPlayers = state.value?.players ?? [];
      final gameResult = _parseGameResult(data, currentPlayers);

      _updateState((s) {
        return s.copyWith(phase: 'results', results: gameResult);
      });
    } catch (e) {
      logger.e('GameNotifier: Failed to fetch results fallback', error: e);
    }
  }

  /// Maps raw results JSON from the server to a [GameResult] model.
  GameResult _parseGameResult(
    Map<String, dynamic> data,
    List<GamePlayer> players,
  ) {
    // Build a player-ID-to-display-name lookup for vote target names.
    final playerNames = {
      for (final p in players) p.playerId.toString(): p.displayName,
    };

    final winningTeams = (data['winning_teams'] as List<dynamic>? ?? [])
        .map((t) => _parseTeamId(t as String))
        .whereType<TeamId>()
        .toList();

    final centerCards = (data['center_cards'] as List<dynamic>? ?? [])
        .map((r) => _parseRoleId(r as String))
        .whereType<RoleId>()
        .toList();

    final playerResults = (data['players'] as List<dynamic>? ?? []).map((raw) {
      final p = raw as Map<String, dynamic>;
      final playerId = p['player_id'];
      final playerIdStr = playerId?.toString() ?? '';
      final voteTargetId = p['vote_target_id'];
      final voteTargetIdStr = voteTargetId?.toString();
      return PlayerResult(
        id: playerIdStr,
        displayName: p['display_name'] as String? ?? '',
        originalRole:
            _parseRoleId(p['original_role'] as String? ?? '') ??
            RoleId.villager,
        finalRole:
            _parseRoleId(p['final_role'] as String? ?? '') ?? RoleId.villager,
        team: _parseTeamId(p['team'] as String? ?? '') ?? TeamId.village,
        isEliminated: p['is_eliminated'] as bool? ?? false,
        isWinner: (p['outcome'] as String?) == 'win',
        voteTargetId: voteTargetIdStr,
        voteTargetName: voteTargetIdStr != null
            ? playerNames[voteTargetIdStr]
            : null,
        eliminationReason: _parseEliminationReason(
          p['elimination_reason'] as String?,
        ),
      );
    }).toList();

    final voteResults = (data['votes'] as List<dynamic>? ?? []).map((raw) {
      final v = raw as Map<String, dynamic>;
      final targetId = v['target_id'];
      final targetIdStr = targetId?.toString();
      return VoteResult(
        voterId: v['voter_id'].toString(),
        voterName: v['voter_name'] as String? ?? '',
        targetId: targetIdStr,
        targetName: targetIdStr != null
            ? (v['target_name'] as String? ?? playerNames[targetIdStr])
            : null,
      );
    }).toList();

    final reason = data['reason'] as String? ?? '';

    return GameResult(
      winningTeams: winningTeams,
      players: playerResults,
      reason: reason,
      votes: voteResults,
      centerCards: centerCards,
    );
  }

  /// Safely updates the current state if it's in the data state.
  void _updateState(
    GameSessionState Function(GameSessionState current) updater,
  ) {
    final currentState = state;
    if (currentState is AsyncData<GameSessionState>) {
      state = AsyncData(updater(currentState.value));
    }
  }
}

// ---------------------------------------------------------------------------
// Result parsing helpers (module-level for testability)
// ---------------------------------------------------------------------------

RoleId? _parseRoleId(String roleStr) => switch (roleStr.toLowerCase()) {
  'werewolf' => RoleId.werewolf,
  'minion' => RoleId.minion,
  'villager' => RoleId.villager,
  'seer' => RoleId.seer,
  'robber' => RoleId.robber,
  'troublemaker' => RoleId.troublemaker,
  'drunk' => RoleId.drunk,
  'insomniac' => RoleId.insomniac,
  'mason' => RoleId.mason,
  'hunter' => RoleId.hunter,
  'tanner' => RoleId.tanner,
  'doppelganger' => RoleId.doppelganger,
  _ => null,
};

TeamId? _parseTeamId(String teamStr) => switch (teamStr.toLowerCase()) {
  'werewolf' => TeamId.werewolf,
  'village' => TeamId.village,
  'independent' || 'neutral' || 'tanner' => TeamId.independent,
  _ => null,
};

EliminationReason? _parseEliminationReason(String? reason) => switch (reason) {
  'vote' => EliminationReason.vote,
  'hunter_chain' => EliminationReason.hunterChain,
  _ => null,
};

/// Provides the [ReconnectingWebSocket] instance for a given game ID.
///
/// Exposes the full instance so callers can access both [stream] (for game
/// events) and [connectionState] (for reconnection tracking / overlay).
///
/// In tests, override [gameWebSocketStreamProvider] and
/// [gameConnectionStateProvider] instead — those are the consumer-facing
/// providers.
final gameWebSocketProvider = Provider.family<ReconnectingWebSocket?, String>((
  ref,
  gameId,
) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  final url = '${Env.wsBaseUrl}/ws/game/$gameId/';
  final ws = ReconnectingWebSocket(url: url, tokenStorage: tokenStorage);
  unawaited(ws.connect());
  ref.onDispose(ws.dispose);
  return ws;
}, name: 'gameWebSocketProvider');

/// Provides the WebSocket message stream for a given game ID.
///
/// Delegates to [gameWebSocketProvider]. In tests, override this provider
/// with a MockWebSocketChannel.stream.
///
/// Returns null when no WebSocket is available (e.g., in unit tests that
/// test individual event handlers by calling them directly).
final gameWebSocketStreamProvider = Provider.family<Stream<dynamic>?, String>((
  ref,
  gameId,
) {
  return ref.watch(gameWebSocketProvider(gameId))?.stream;
}, name: 'gameWebSocketStreamProvider');

/// Provides the WebSocket connection state stream for a given game ID.
///
/// Used by [GameContainerScreen] to drive the [ReconnectionOverlay].
/// Returns a stream of [WebSocketConnectionState] values.
///
/// In tests, override this provider to inject connection state transitions.
final gameConnectionStateProvider =
    StreamProvider.family<WebSocketConnectionState, String>((ref, gameId) {
      final ws = ref.watch(gameWebSocketProvider(gameId));
      if (ws == null) {
        return Stream.value(WebSocketConnectionState.connected);
      }
      return ws.connectionState;
    }, name: 'gameConnectionStateProvider');
