import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/logging/app_logger.dart';
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
  Timer? _resultsTimeout;

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

    ref.onDispose(() {
      _wsSubscription?.cancel();
      _resultsTimeout?.cancel();
    });

    // Derive initial nightSubView from the fetched state.
    return _deriveNightSubView(initialState);
  }

  /// Derives the appropriate [NightSubView] from the initial server state.
  GameSessionState _deriveNightSubView(GameSessionState state) {
    if (state.phase != 'night') return state;

    if (state.actionPrompt != null) {
      final prompt = state.actionPrompt!;
      if (prompt.actionTypes.length > 1) {
        return state.copyWith(nightSubView: NightSubView.seerChoice);
      }
      return state.copyWith(nightSubView: NightSubView.actionPrompt);
    }

    return state.copyWith(nightSubView: NightSubView.waiting);
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

  /// Updates currentWave and deadline when a new night wave starts.
  void _handleWaveStart(Map<String, dynamic> data) {
    _updateState((state) {
      final wave = data['wave'] as int;
      final deadlineStr = data['deadline'] as String?;
      final deadline = deadlineStr != null ? DateTime.parse(deadlineStr) : null;
      return state.copyWith(
        currentWave: wave,
        deadline: deadline,
        actionPrompt: null,
        lastActionResult: null,
      );
    });
  }

  /// Sets nightSubView based on the number of action types in the prompt.
  /// If actionTypes.length > 1: seerChoice. If 1: actionPrompt.
  void _handleActionPrompt(Map<String, dynamic> data) {
    _updateState((state) {
      final prompt = ActionPrompt(
        roleActingAs: data['role_acting_as'] as String,
        actionTypes: List<String>.from(data['action_types'] as List),
        validTargets: Map<String, dynamic>.from(data['valid_targets'] as Map),
        wave: data['wave'] as int,
      );

      final subView = prompt.actionTypes.length > 1
          ? NightSubView.seerChoice
          : NightSubView.actionPrompt;

      return state.copyWith(
        actionPrompt: prompt,
        nightSubView: subView,
        lastActionResult: null,
      );
    });
  }

  /// Stores the action result and transitions to actionResult sub-view.
  void _handleActionResult(Map<String, dynamic> data) {
    _updateState((state) {
      final result = ActionResult(
        wave: data['wave'] as int,
        revealedInfo: Map<String, dynamic>.from(data['revealed_info'] as Map),
      );
      return state.copyWith(
        lastActionResult: result,
        nightSubView: NightSubView.actionResult,
      );
    });
  }

  /// Clears action prompt/result and sets nightSubView to waiting.
  void _handleWaveComplete(Map<String, dynamic> data) {
    _updateState((state) {
      return state.copyWith(
        actionPrompt: null,
        lastActionResult: null,
        nightSubView: NightSubView.waiting,
      );
    });
  }

  /// Player has no action this wave -- show waiting view.
  void _handleWaveWaiting(Map<String, dynamic> data) {
    _updateState((state) {
      return state.copyWith(nightSubView: NightSubView.waiting);
    });
  }

  /// Updates phase and deadline on phase transition.
  void _handlePhaseChange(Map<String, dynamic> data) {
    _updateState((state) {
      final phase = data['phase'] as String;
      final deadlineStr = data['deadline'] as String?;
      final deadline = deadlineStr != null ? DateTime.parse(deadlineStr) : null;
      return state.copyWith(
        phase: phase,
        deadline: deadline,
        // Reset night-specific state on phase change.
        actionPrompt: null,
        lastActionResult: null,
        nightSubView: NightSubView.waiting,
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

  /// Submits a night action.
  Future<void> submitAction(
    String actionType,
    Map<String, dynamic> targets,
  ) async {
    final service = ref.read(gameServiceProvider);
    await service.submitAction(gameId, actionType, targets);
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
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Fetches full results from REST as a fallback when the game_results
  /// WS event is missed or as the primary data source.
  Future<void> _fetchResultsFallback() async {
    if (!ref.mounted) return;
    try {
      final service = ref.read(gameServiceProvider);
      await service.fetchResults(gameId);
      if (!ref.mounted) return;
      // Results are stored on the server -- for now, just transition to
      // results phase. The GameContainerScreen will show a results view
      // that fetches the full data.
      _updateState((state) {
        return state.copyWith(phase: 'results');
      });
    } catch (e) {
      logger.e('GameNotifier: Failed to fetch results fallback', error: e);
    }
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

/// Provides the WebSocket stream for a given game ID.
///
/// In production, this will be backed by ReconnectingWebSocket from WP03.
/// In tests, override this provider with a MockWebSocketChannel.stream.
///
/// Returns null when no WebSocket is available (e.g., in unit tests that
/// test individual event handlers by calling them directly).
final gameWebSocketStreamProvider = Provider.family<Stream<dynamic>?, String>((
  ref,
  gameId,
) {
  // Placeholder -- will be wired to ReconnectingWebSocket in WP08.
  return null;
}, name: 'gameWebSocketStreamProvider');
