import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/config/env.dart';
import '../../../core/host/host_change.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/websocket/reconnecting_websocket.dart';
import '../../../core/websocket/websocket_channel.dart';
import '../../../design_system/models/game_result.dart';
import '../../../design_system/models/role.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../lobby/domain/lobby_state.dart';
import '../../lobby/presentation/lobby_notifier.dart';
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
  Timer? _hostNoticeTimer;
  bool _wasDisconnected = false;

  /// True while a state fetch (the first load or a refresh) is in flight.
  /// Socket events arriving meanwhile are held in [_buffered] and replayed, in
  /// order, on top of the fetched snapshot, so none is dropped (the first
  /// load has no state to apply them to) or overwritten by an older snapshot.
  bool _buffering = false;
  final List<dynamic> _buffered = [];

  /// While replaying, the state the replayed events are applied to.
  GameSessionState? _working;

  Future<void>? _refreshing;
  bool _refreshAgain = false;

  /// Lobby code the screen knew when it opened (from the route), used when the
  /// server's state does not carry one.
  String? lobbyCodeHint;

  /// The table this game belongs to: the server's, else the route's hint.
  String? get lobbyCode => state.value?.lobbyCode ?? lobbyCodeHint;

  /// WebSocket stream injected for testability.
  /// In production this comes from a ReconnectingWebSocket provider.
  /// In tests it can be overridden via the [webSocketStreamProvider].
  Stream<dynamic>? _wsStream;

  @override
  Future<GameSessionState> build(String gameId) async {
    final service = ref.read(gameServiceProvider);

    ref.onDispose(() {
      _wsSubscription?.cancel();
      _connectionSubscription?.cancel();
      _resultsTimeout?.cancel();
      _hostNoticeTimer?.cancel();
    });

    // Listen to the socket BEFORE fetching, so no event between the server
    // reading its state and this phone hearing about it is lost: events are
    // held until the snapshot is in, then replayed on top of it.
    _buffering = true;
    _buffered.clear();
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

    final initialState = await service.getGameState(gameId);

    // Hydrate frontend-only display state from the server response.
    var hydrated = _hydrateInitialState(await _withPresence(initialState));

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
      unawaited(_checkTableMovedOn());
    }

    return _replayBuffered(hydrated);
  }

  /// Ends buffering and applies the held events, in order, on top of [base].
  /// Returns the resulting state. An event that cannot be handled is logged
  /// and skipped, never allowed to break the load.
  GameSessionState _replayBuffered(GameSessionState base) {
    _buffering = false;
    final held = List<dynamic>.of(_buffered);
    _buffered.clear();
    if (held.isEmpty) return base;
    _working = base;
    try {
      for (final message in held) {
        try {
          _handleWsMessage(message);
        } catch (e) {
          logger.w('GameNotifier: skipped a held event', error: e);
        }
      }
      return _working!;
    } finally {
      _working = null;
    }
  }

  /// Hydrates frontend-only display state from the initial REST response.
  ///
  /// Night phase: derives the correct [NightSubView].
  /// Voting phase: populates [VoteProgress] from the server-provided
  /// [GamePlayer.hasVoted] field so reconnecting clients see accurate
  /// vote progress.
  ///
  /// [previous] is the state this refresh replaces. The server does not send a
  /// result the player has already been shown again, so a refresh keeps the one
  /// already on screen (and the queue behind it), and remembers which results
  /// were shown so a closed window's result is surfaced exactly once.
  GameSessionState _hydrateInitialState(
    GameSessionState state, {
    GameSessionState? previous,
  }) {
    var result = state;

    if (previous != null) {
      result = result.copyWith(
        shownNightResults: previous.shownNightResults,
        pendingNightResults: previous.pendingNightResults,
        playAgainLobbyCode: previous.playAgainLobbyCode,
        hostNotice: previous.hostNotice,
        hostActionNotice: previous.hostActionNotice,
      );
    }

    result = _followEffectiveHost(result);

    final carriedResult = previous?.lastActionResult;
    if (carriedResult != null && _showsNightResults(result.phase)) {
      result = result.copyWith(lastActionResult: carriedResult);
    }

    result = _surfaceMissedNightResults(result);

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

  /// The player id of the signed-in player, or null when not known.
  int? _viewerId() {
    try {
      final auth = ref.read(authProvider);
      return auth is AuthAuthenticated ? auth.user.id : null;
    } catch (_) {
      return null;
    }
  }

  /// When the server names the effective host (`host_id`), "am I the host"
  /// follows it, on every fetch, so a missed `host_changed` heals. Without a
  /// `host_id` the server's own `is_host` stands. A "hosting while ... is
  /// away" line is dropped once the server shows the role back with its
  /// original host.
  GameSessionState _followEffectiveHost(GameSessionState state) {
    var result = state;
    final hostId = result.hostId;
    final me = hostId != null ? _viewerId() : null;
    if (hostId != null && me != null) {
      result = result.copyWith(isHost: hostId == me);
    }
    final notice = result.hostNotice;
    if (hostId != null &&
        notice != null &&
        notice.reason == HostChangeReason.handover &&
        hostId == notice.originalHostId) {
      result = result.copyWith(hostNotice: null);
    }
    return result;
  }

  /// Phases in which a night result may be put in front of the player.
  static bool _showsNightResults(String phase) =>
      phase == 'night' || phase == 'discussion' || phase == 'voting';

  /// Puts results of closed night windows the player has not been shown in
  /// front of them, the same way the `action_result` event does.
  ///
  /// The server lists only windows that already closed; as a second check, a
  /// result for a window this state still has open (`wave >= currentWave`
  /// during the night) is never shown from here. Results already shown are
  /// skipped. When a result is on screen the rest queue up behind it.
  GameSessionState _surfaceMissedNightResults(GameSessionState state) {
    if (!_showsNightResults(state.phase) || state.nightResults.isEmpty) {
      return state;
    }
    final closed = state.nightResults
        .where((r) => state.phase != 'night' || r.wave < state.currentWave)
        .toList();
    final unseen = _unseenResults(closed, state.shownNightResults);
    if (unseen.isEmpty) return state;

    final shown = [...state.shownNightResults, ...unseen];
    if (state.lastActionResult != null) {
      return state.copyWith(
        shownNightResults: shown,
        pendingNightResults: [...state.pendingNightResults, ...unseen],
      );
    }
    return state.copyWith(
      shownNightResults: shown,
      lastActionResult: unseen.first,
      pendingNightResults: [...state.pendingNightResults, ...unseen.skip(1)],
    );
  }

  /// [closed] without the results already in [shown] (each shown result
  /// accounts for one equal entry).
  List<ActionResult> _unseenResults(
    List<ActionResult> closed,
    List<ActionResult> shown,
  ) {
    final remaining = [...shown];
    final unseen = <ActionResult>[];
    for (final result in closed) {
      final i = remaining.indexWhere((s) => _sameResult(s, result));
      if (i >= 0) {
        remaining.removeAt(i);
      } else {
        unseen.add(result);
      }
    }
    return unseen;
  }

  /// Whether two results are the same night information. `role_acting_as` is
  /// ignored: the socket path may add it from the prompt, a state fetch may not.
  bool _sameResult(ActionResult a, ActionResult b) {
    if (a.wave != b.wave) return false;
    ActionResult core(ActionResult r) => ActionResult(
      wave: r.wave,
      revealedInfo: Map<String, dynamic>.of(r.revealedInfo)
        ..remove('role_acting_as'),
    );
    // Generated equality compares the info map deeply.
    return core(a) == core(b);
  }

  /// Merges the public `connected` flags from the player list into [state].
  /// Presence is a courtesy: when the call fails everyone stays connected.
  Future<GameSessionState> _withPresence(GameSessionState state) async {
    try {
      final presence = await ref
          .read(gameServiceProvider)
          .fetchPresence(gameId);
      if (presence.isEmpty) return state;
      return state.copyWith(
        players: [
          for (final p in state.players)
            presence.containsKey(p.playerId)
                ? p.copyWith(connected: presence[p.playerId]!)
                : p,
        ],
      );
    } catch (e) {
      logger.d('GameNotifier: presence unavailable ($e)');
      return state;
    }
  }

  // ---------------------------------------------------------------------------
  // WebSocket event dispatch
  // ---------------------------------------------------------------------------

  void _handleWsMessage(dynamic message) {
    if (_buffering) {
      _buffered.add(message);
      return;
    }
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
      case 'player_presence':
        _handlePlayerPresence(event);
      case 'play_again':
        _handlePlayAgain(event);
      case 'host_changed':
        _handleHostChanged(event);
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
      final ActionResult result;
      try {
        result = actionResultFromServer(
          data,
          // The server includes it; this covers an older payload.
          fallbackRoleActingAs: state.actionPrompt?.roleActingAs,
        );
      } on FormatException catch (e) {
        logger.w('GameNotifier: Malformed action_result: $e');
        return state;
      }
      // Already put in front of the player (surfaced from a state fetch that
      // got there first): do not show it a second time.
      if (state.shownNightResults.any((s) => _sameResult(s, result))) {
        return state;
      }
      return state.copyWith(
        lastActionResult: result,
        shownNightResults: [...state.shownNightResults, result],
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
        pendingNightResults: keepResult ? state.pendingNightResults : const [],
        nightSubView: nightSubView,
        // "Hosting again" and "no longer the host" are for the moment; a
        // handover line stays until the role returns.
        hostNotice: state.hostNotice?.reason == HostChangeReason.handover
            ? state.hostNotice
            : null,
        hostActionNotice: null,
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

  /// Updates one player's `connected` flag. Public to the whole table, so it
  /// says nothing about roles or who has acted.
  void _handlePlayerPresence(Map<String, dynamic> data) {
    final playerId = data['player_id'];
    final connected = data['connected'];
    if (playerId is! int || connected is! bool) return;
    _updateState((state) {
      if (!state.players.any((p) => p.playerId == playerId)) return state;
      return state.copyWith(
        players: [
          for (final p in state.players)
            p.playerId == playerId ? p.copyWith(connected: connected) : p,
        ],
      );
    });
  }

  /// The host role moved (the original host's phone dropped, or came back).
  /// Updates who the host is straight away, so host-only controls appear for
  /// the new host and disappear for the old one without a refetch.
  void _handleHostChanged(Map<String, dynamic> data) {
    final change = HostChange.fromEvent(data);
    if (change == null) return;
    final me = _viewerId();
    _updateState(
      (state) => state.copyWith(
        hostId: change.hostId,
        isHost: me != null ? change.hostId == me : state.isHost,
        hostNotice: change,
        hostActionNotice: null,
      ),
    );
    _hostNoticeTimer?.cancel();
    if (change.reason != HostChangeReason.handover) {
      _hostNoticeTimer = Timer(kHostNoticeDuration, () {
        if (!ref.mounted) return;
        _updateState(
          (s) => s.hostNotice == change ? s.copyWith(hostNotice: null) : s,
        );
      });
    }
  }

  /// Runs a host-only call. When the server refuses because the role has just
  /// moved (403), state is re-read from the server, a plain line says so, and
  /// [NoLongerHostException] is thrown (instead of an error dump).
  Future<void> _hostAction(Future<void> Function() call) async {
    try {
      await call();
    } on ForbiddenException {
      await refreshState();
      if (ref.mounted) {
        _updateState((s) => s.copyWith(hostActionNotice: kNoLongerHostMessage));
        _hostNoticeTimer?.cancel();
        _hostNoticeTimer = Timer(kHostNoticeDuration, () {
          if (!ref.mounted) return;
          _updateState((s) => s.copyWith(hostActionNotice: null));
        });
      }
      throw const NoLongerHostException();
    }
  }

  /// The host started another game at this table: the screen leaves for the
  /// lobby. Nothing of the finished game is kept (this provider is disposed
  /// with the screen), so the next `game_started` opens a fresh game.
  void _handlePlayAgain(Map<String, dynamic> data) {
    final code = data['lobby_code'];
    if (code is! String || code.isEmpty) return;
    _updateState((state) => state.copyWith(playAgainLobbyCode: code));
  }

  /// Opens the table's lobby on this screen when the table has already gone
  /// back to waiting (a `play_again` this phone missed, or an old results link
  /// reopened). A table still "in game" is left alone.
  Future<void> _checkTableMovedOn() async {
    // Let the state settle first: this runs from build.
    await Future<void>.delayed(Duration.zero);
    if (!ref.mounted) return;
    final code = lobbyCode;
    if (code == null) return;
    try {
      final lobby = await ref.read(lobbyServiceProvider).fetchLobby(code);
      if (!ref.mounted || lobby.status != 'waiting') return;
      _updateState((s) => s.copyWith(playAgainLobbyCode: lobby.code));
    } on NotFoundException {
      // The table is gone: say so and go home.
      if (ref.mounted) _updateState((s) => s.copyWith(tableClosed: true));
    } catch (e) {
      logger.d('GameNotifier: could not check the table ($e)');
    }
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
      // Missed results queued behind this one come first, one at a time.
      final pending = state.pendingNightResults;
      if (pending.isNotEmpty) {
        return state.copyWith(
          lastActionResult: pending.first,
          pendingNightResults: pending.sublist(1),
        );
      }
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
    await _hostAction(() => service.endDiscussion(gameId));
  }

  /// Closes the current night window now (host only): "Continue without them".
  Future<void> advanceNight() async {
    await _hostAction(() => ref.read(gameServiceProvider).advanceNight(gameId));
  }

  /// Reveals the votes now (host only); anyone who has not voted abstains.
  Future<void> revealVotesNow() async {
    await _hostAction(() => ref.read(gameServiceProvider).revealVotes(gameId));
  }

  /// Takes the table back to the lobby for another game (host only).
  ///
  /// On success the screen is told to leave for the lobby, the same as when the
  /// `play_again` event arrives. Errors propagate so the screen can say so.
  Future<void> playAgain() async {
    final code = lobbyCode;
    if (code == null) {
      throw StateError('The table for this game is not known');
    }
    late final LobbyState lobby;
    await _hostAction(() async {
      lobby = await ref.read(lobbyServiceProvider).playAgain(code);
    });
    if (!ref.mounted) return;
    _updateState((state) => state.copyWith(playAgainLobbyCode: lobby.code));
  }

  /// Leaves the table (the lobby this game was played at).
  ///
  /// Without a known table there is nothing to leave on the server.
  Future<void> leaveTable() async {
    final code = lobbyCode;
    if (code == null) return;
    await ref.read(lobbyServiceProvider).leaveLobby(code);
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
  Future<void> refreshState() {
    // Not before the first load has finished: that load is the fetch.
    if (!ref.mounted || state.value == null) return Future.value();
    final running = _refreshing;
    if (running != null) {
      // Run once more after the current fetch, which may predate the reason
      // for asking.
      _refreshAgain = true;
      return running;
    }
    return _refreshing = _refreshLoop().whenComplete(() => _refreshing = null);
  }

  Future<void> _refreshLoop() async {
    do {
      _refreshAgain = false;
      await _refreshOnce();
    } while (_refreshAgain && ref.mounted);
  }

  Future<void> _refreshOnce() async {
    if (!ref.mounted) return;
    // Hold socket events while the snapshot is in flight; they are replayed on
    // top of it so a fresher event is never overwritten by the older snapshot.
    _buffering = true;
    _buffered.clear();
    try {
      final service = ref.read(gameServiceProvider);
      final freshState = await _withPresence(
        await service.getGameState(gameId),
      );
      if (!ref.mounted) return;

      var hydrated = _hydrateInitialState(freshState, previous: state.value);

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
        state = AsyncData(_replayBuffered(hydrated));
        if (hydrated.phase == 'results') unawaited(_checkTableMovedOn());
      }
    } on NotFoundException {
      // The table is gone (its last member left): the screen says so and
      // returns home.
      logger.w('GameNotifier: the game is gone');
      _applyHeldToCurrent();
      _updateState((s) => s.copyWith(tableClosed: true));
    } catch (e) {
      logger.e('GameNotifier: Failed to refresh state', error: e);
      // Nothing fetched: the held events still belong to the current state.
      _applyHeldToCurrent();
    } finally {
      _buffering = false;
    }
  }

  /// A fetch failed: apply the events held meanwhile to the state we have.
  void _applyHeldToCurrent() {
    if (!ref.mounted) return;
    final current = state.value;
    if (current == null) {
      _buffering = false;
      _buffered.clear();
      return;
    }
    state = AsyncData(_replayBuffered(current));
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
    // While held events are being replayed they build on the fetched snapshot.
    final working = _working;
    if (working != null) {
      _working = updater(working);
      return;
    }
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
