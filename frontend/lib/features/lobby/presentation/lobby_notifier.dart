import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/config/env.dart';
import '../../../core/host/host_change.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/websocket/reconnecting_websocket.dart';
import '../../../core/websocket/websocket_channel.dart';
import '../../../features/auth/presentation/auth_notifier.dart';
import '../data/lobby_service.dart';
import '../domain/lobby_state.dart';

part 'lobby_notifier.g.dart';

/// Provides the [LobbyService] for HTTP lobby operations.
@riverpod
LobbyService lobbyService(Ref ref) {
  return LobbyService(client: ref.watch(authenticatedClientProvider));
}

/// Factory for creating WebSocket connections to a lobby.
///
/// This provider exists to decouple WebSocket creation from the notifier,
/// making it easy to inject [MockWebSocketChannel] in tests. In production,
/// this will be overridden to use [ReconnectingWebSocket] (from WP03).
///
/// Returns a function that creates a [WebSocketChannelInterface] for a
/// given lobby code.
typedef LobbyWebSocketFactory =
    WebSocketChannelInterface Function(String lobbyCode);

/// Provider for the WebSocket factory. Override in tests with a mock.
@riverpod
LobbyWebSocketFactory lobbyWebSocketFactory(Ref ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return (String lobbyCode) {
    final url = '${Env.wsBaseUrl}/ws/lobby/$lobbyCode/';
    final ws = ReconnectingWebSocket(url: url, tokenStorage: tokenStorage);
    unawaited(ws.connect());
    return ws;
  };
}

/// Manages lobby state for a given lobby code.
///
/// Coordinates HTTP state fetches with real-time WebSocket events.
/// This is a family provider keyed by lobby code -- one instance per lobby.
///
/// Lifecycle:
/// 1. [build] fetches initial lobby state via HTTP and connects the WebSocket.
/// 2. WebSocket events update state in real-time.
/// 3. [ref.onDispose] closes the WebSocket connection.
///
/// WebSocket event handling per the API contract:
/// - `player_joined` / `player_left` -> re-fetch full lobby state (events lack complete data)
/// - `player_ready` -> update player's isReady flag in-place (event has complete data)
/// - `lobby_update` -> update settings (role configuration changed by host)
/// - `game_started` -> extract game_id for navigation (WS provider auto-disposes)
///
/// A table runs several games one after another: every start sets a new
/// [LobbyState.startedGameId], and a lobby opened while a game is already
/// running (the start event came before the socket was up) looks the game up.
@riverpod
class LobbyNotifier extends _$LobbyNotifier {
  StreamSubscription<dynamic>? _wsSubscription;
  StreamSubscription<WebSocketConnectionState>? _connectionSubscription;
  Timer? _noticeTimer;
  WebSocketChannelInterface? _webSocket;

  /// True while a lobby fetch (the first load or a refetch) is in flight.
  /// Socket events arriving meanwhile are held and replayed, in order, on top
  /// of the fetched snapshot, so none is lost (the first load has no state to
  /// apply them to) or overwritten by an older snapshot.
  bool _buffering = false;
  final List<dynamic> _buffered = [];

  /// While replaying, the state the replayed events are applied to.
  LobbyState? _working;

  Future<void>? _refreshing;
  bool _refreshAgain = false;

  /// The lobby state events act on: the snapshot being replayed on, else the
  /// current state.
  LobbyState? get _current => _working ?? state.value;

  void _set(LobbyState next) {
    if (_working != null) {
      _working = next;
    } else {
      _show(next);
    }
  }

  /// Settings changes sent and not answered yet, oldest first. What the
  /// screen shows is the server's lobby with these merged over it as the
  /// server merges them, so a tap shows at once and an event or a refetch
  /// meanwhile never takes it back.
  final List<Map<String, Object>> _pending = [];
  Future<void> _settingsQueue = Future.value();

  /// The last change that did not reach the server ("Try again").
  Future<void> Function()? _retry;

  void _show(LobbyState server) => state = AsyncData(_withPending(server));

  LobbyState _withPending(LobbyState lobby) =>
      _pending.fold(lobby, _mergeSettings);

  static LobbyState _mergeSettings(LobbyState lobby, Map<String, Object> p) =>
      lobby.copyWith(
        table: lobby.table.merged(p),
        roleConfig: p['roles'] is Map<String, int>
            ? p['roles']! as Map<String, int>
            : lobby.roleConfig,
      );

  /// The game ID from a `game_started` event. Consumers watch this to navigate.
  String? gameId;

  @override
  Future<LobbyState> build(String code) async {
    final service = ref.read(lobbyServiceProvider);

    // Clean up on dispose
    ref.onDispose(_dispose);

    // Connect the socket BEFORE fetching, so no event between the server
    // reading the lobby and this phone hearing about it is lost.
    _buffering = true;
    _buffered.clear();
    _connectWebSocket(code);

    // Fetch initial lobby state
    final lobbyState = await service.fetchLobby(code);

    if (lobbyState.status == 'in_game') unawaited(_findRunningGame());

    return _replayBuffered(lobbyState);
  }

  /// Ends buffering and applies the held events, in order, on top of [base].
  LobbyState _replayBuffered(LobbyState base) {
    _buffering = false;
    final held = List<dynamic>.of(_buffered);
    _buffered.clear();
    if (held.isEmpty) return base;
    _working = base;
    try {
      for (final message in held) {
        _handleWebSocketEvent(message);
      }
      return _working!;
    } finally {
      _working = null;
    }
  }

  void _connectWebSocket(String code) {
    try {
      final factory = ref.read(lobbyWebSocketFactoryProvider);
      _webSocket = factory(code);
      _wsSubscription = _webSocket!.stream.listen(
        _handleWebSocketEvent,
        onError: (Object error) {
          logger.w('Lobby WebSocket error', error: error);
        },
      );
      // After a dropped connection comes back, read the lobby again: events
      // (including a host change) may have been missed meanwhile.
      final ws = _webSocket;
      if (ws is ReconnectingWebSocket) {
        var wasDown = false;
        _connectionSubscription = ws.connectionState.listen((s) {
          if (s == WebSocketConnectionState.connected && wasDown) {
            wasDown = false;
            unawaited(refreshLobby());
          } else if (s == WebSocketConnectionState.disconnected ||
              s == WebSocketConnectionState.reconnecting) {
            wasDown = true;
          }
        });
      }
    } catch (e) {
      logger.w('Failed to connect lobby WebSocket', error: e);
      // Non-fatal: lobby still works via HTTP, just without real-time updates.
    }
  }

  void _handleWebSocketEvent(dynamic rawMessage) {
    if (_buffering) {
      _buffered.add(rawMessage);
      return;
    }
    try {
      final Map<String, dynamic> message;
      if (rawMessage is String) {
        message = json.decode(rawMessage) as Map<String, dynamic>;
      } else if (rawMessage is Map<String, dynamic>) {
        message = rawMessage;
      } else {
        logger.w(
          'Unexpected WebSocket message type: ${rawMessage.runtimeType}',
        );
        return;
      }

      final type = message['type'] as String?;
      if (type == null) {
        logger.w('WebSocket message missing type field');
        return;
      }

      switch (type) {
        case 'player_joined':
        case 'player_left':
          _onPlayerListChanged();
        case 'player_ready':
          _onPlayerReady(message);
        case 'lobby_update':
          _onLobbyUpdate(message);
        case 'game_started':
          _onGameStarted(message);
        case 'host_changed':
          _onHostChanged(message);
        default:
          logger.d('Unhandled lobby WS event type: $type');
      }
    } catch (e, stack) {
      logger.e('Error handling lobby WS event', error: e, stackTrace: stack);
    }
  }

  /// Re-fetch full lobby state when player list changes.
  ///
  /// The `player_joined` and `player_left` events carry only a username,
  /// which is insufficient to construct the full player list. Re-fetching
  /// keeps us consistent with the server (spec US3 AS7).
  Future<void> _onPlayerListChanged() => refreshLobby();

  /// Reads the lobby again from the server. The host (the effective host) is
  /// whatever the server says, so a missed `host_changed` heals here. Calls
  /// made while a fetch is in flight share it, then run once more.
  Future<void> refreshLobby() {
    if (!ref.mounted || state.value == null) return Future.value();
    final running = _refreshing;
    if (running != null) {
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
    // Hold socket events while the snapshot is in flight; they are replayed
    // on top of it.
    _buffering = true;
    _buffered.clear();
    try {
      final newState = await ref.read(lobbyServiceProvider).fetchLobby(code);
      if (!ref.mounted) return;
      _show(_replayBuffered(_adopt(newState)));
    } on NotFoundException {
      // The table is gone (its last member left).
      if (ref.mounted) _applyHeld(closed: true);
    } catch (e, stack) {
      logger.e(
        'Error re-fetching lobby after player change',
        error: e,
        stackTrace: stack,
      );
      if (ref.mounted) _applyHeld();
    } finally {
      _buffering = false;
    }
  }

  /// A fetch failed: apply the events held meanwhile to the state we have.
  void _applyHeld({bool closed = false}) {
    final current = state.value;
    if (current == null) {
      _buffering = false;
      _buffered.clear();
      return;
    }
    final next = _replayBuffered(current);
    _show(closed ? next.copyWith(tableClosed: true) : next);
  }

  /// A freshly fetched lobby, keeping what only this phone knows: the game it
  /// has been told to open and the host lines.
  LobbyState _adopt(LobbyState fresh) {
    final current = state.value;
    if (current == null) return fresh;
    final brief = current.briefHostNotice;
    return fresh.copyWith(
      startedGameId: current.startedGameId,
      notSent: current.notSent,
      // The "hosting again" / "is the host now" line outlives a refetch only
      // while the server agrees that person is the host.
      briefHostNotice: brief != null && fresh.hostId == brief.hostId
          ? brief
          : null,
      hostActionNotice: current.hostActionNotice,
    );
  }

  /// The host role moved. The new host is known straight away, so host-only
  /// controls (deal, deck) follow it without a refetch.
  void _onHostChanged(Map<String, dynamic> message) {
    final change = HostChange.fromEvent(message);
    final current = _current;
    if (current == null) return;
    final brief = change.reason != HostChangeReason.handover;
    _set(
      current.copyWith(
        hostId: change.hostId,
        hostName: change.hostName,
        originalHostId: change.originalHostId,
        isActingHost: change.reason == HostChangeReason.handover,
        briefHostNotice: brief ? change : null,
        hostActionNotice: null,
      ),
    );
    _noticeTimer?.cancel();
    if (brief) {
      _noticeTimer = Timer(kHostNoticeDuration, () {
        if (!ref.mounted) return;
        final s = state.value;
        if (s != null && s.briefHostNotice == change) {
          state = AsyncData(s.copyWith(briefHostNotice: null));
        }
      });
    }
  }

  /// Runs a host-only call. A 403 means the role has just moved: the lobby is
  /// read again, a plain line says so, and [NoLongerHostException] is thrown
  /// (instead of an error dump).
  Future<T> _hostAction<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ForbiddenException {
      await refreshLobby();
      final s = state.value;
      if (ref.mounted && s != null) {
        state = AsyncData(s.copyWith(hostActionNotice: kNoLongerHostMessage));
        _noticeTimer?.cancel();
        _noticeTimer = Timer(kHostNoticeDuration, () {
          if (!ref.mounted) return;
          final c = state.value;
          if (c != null) state = AsyncData(c.copyWith(hostActionNotice: null));
        });
      }
      throw const NoLongerHostException();
    }
  }

  /// Update a player's ready state in-place.
  ///
  /// The `player_ready` event has complete data (`user_id`, `is_ready`),
  /// so we can update locally without re-fetching.
  void _onPlayerReady(Map<String, dynamic> message) {
    final userId = message['user_id'];
    final isReady = message['is_ready'] as bool?;
    if (userId == null || isReady == null) return;

    final current = _current;
    if (current == null) return;

    final targetId = userId is int ? userId : int.tryParse(userId.toString());

    final updatedPlayers = current.players.map((player) {
      if (player.id == targetId) {
        return player.copyWith(isReady: isReady);
      }
      return player;
    }).toList();

    _set(current.copyWith(players: updatedPlayers));
  }

  /// `lobby_update` carries the whole lobby body (a settings change, play
  /// again): it is the server's lobby now, kept with what only this phone
  /// knows and with its own changes still on their way merged over it.
  void _onLobbyUpdate(Map<String, dynamic> message) {
    final current = _current;
    if (current == null) return;
    final data = message['data'] as Map<String, dynamic>?;
    if (data == null) return;
    final fresh = LobbyState.fromJson(data);
    _set(
      fresh.copyWith(
        startedGameId: current.startedGameId,
        notSent: current.notSent,
        briefHostNotice: current.briefHostNotice,
        hostActionNotice: current.hostActionNotice,
      ),
    );
  }

  /// Handle game_started event by extracting the game ID.
  ///
  /// The consumer (lobby screen) watches [gameId] and navigates to
  /// `/game/<gameId>` when it becomes non-null. The provider is then
  /// invalidated by navigation, triggering dispose and WS cleanup.
  void _onGameStarted(Map<String, dynamic> message) {
    final id = message['game_id'] as String?;
    if (id != null) _applyStartedGame(id);
  }

  /// Records the started game and flips the table to in-game so listeners
  /// (the lobby screen) open it.
  void _applyStartedGame(String id) {
    gameId = id;
    final current = _current;
    if (current != null) {
      _set(current.copyWith(status: 'in_game', startedGameId: id));
    }
  }

  /// A lobby opened while its game is already running missed `game_started`.
  Future<void> _findRunningGame() async {
    // Let build finish first.
    await Future<void>.delayed(Duration.zero);
    if (!ref.mounted) return;
    try {
      final id = await ref.read(lobbyServiceProvider).activeGameIdAt(code);
      if (id != null && ref.mounted && gameId == null) _applyStartedGame(id);
    } catch (e) {
      logger.d('Could not look up the running game ($e)');
    }
  }

  // --- Public methods for user actions ---

  bool _readying = false;

  /// This phone sits down ready: the server deals only when every member is
  /// ready, and there is no ready button. Sent once while [playerId] is not
  /// ready at a waiting table; the lobby the answer brings (an event or the
  /// next read) shows the flag, and a failed send is tried again on the next
  /// call (the screen calls this on every lobby it shows).
  Future<void> sitDown(int playerId) async {
    final lobby = state.value;
    if (_readying || lobby == null || lobby.status != 'waiting') return;
    final me = lobby.players.where((p) => p.id == playerId).firstOrNull;
    if (me == null || me.isReady) return;
    _readying = true;
    try {
      await ref.read(lobbyServiceProvider).setReady(code, ready: true);
      if (!ref.mounted) return;
      final now = state.value;
      if (now != null) {
        _show(
          now.copyWith(
            players: [
              for (final p in now.players)
                p.id == playerId ? p.copyWith(isReady: true) : p,
            ],
          ),
        );
      }
    } catch (e) {
      logger.d('Could not set ready ($e)');
    } finally {
      _readying = false;
    }
  }

  /// The host picks a deck chip: the server builds that deck at the deal.
  Future<void> chooseChip(DeckChip chip) =>
      _changeSettings(LobbyService.deckChip(chip));

  /// The host's own card list (it must hold players + 3 cards: the server
  /// refuses any other).
  Future<void> useCustomDeck(Map<String, int> roles) =>
      _changeSettings(LobbyService.customDeck(roles));

  /// The host picks a pace preset.
  Future<void> choosePace(Pace pace) => _changeSettings(pace.settings);

  /// Sends [patch] (one at a time, in order) and shows it at once, merged
  /// as the server merges it. The answer is the server's lobby; a refusal
  /// or no answer takes the change back (the lobby is read again) and the
  /// screen says "Not sent." with "Try again".
  Future<void> _changeSettings(Map<String, Object> patch) {
    final lobby = state.value;
    if (lobby == null) return Future.value();
    _pending.add(patch);
    _show(lobby.copyWith(notSent: false));
    return _settingsQueue = _settingsQueue.then((_) => _send(patch));
  }

  Future<void> _send(Map<String, Object> patch) async {
    try {
      final answer = await _hostAction(
        () => ref.read(lobbyServiceProvider).patchSettings(code, patch),
      );
      if (!ref.mounted) return;
      _pending.remove(patch);
      _show(_adopt(answer));
    } on NoLongerHostException {
      // The role moved: the lobby was read again and this phone is a guest
      // now, which its screen shows with no words.
      _pending.remove(patch);
      if (ref.mounted) await refreshLobby();
    } catch (e) {
      logger.d('Settings change not sent ($e)');
      if (!ref.mounted) return;
      _pending.remove(patch);
      _retry = () => _changeSettings(patch);
      final now = state.value;
      if (now != null) state = AsyncData(now.copyWith(notSent: true));
      await refreshLobby();
    }
  }

  /// "Try again" after "Not sent.": the change (or the deal) that failed.
  Future<void> retry() async {
    final again = _retry;
    _retry = null;
    final now = state.value;
    if (now != null) state = AsyncData(now.copyWith(notSent: false));
    if (again != null) await again();
  }

  /// Deals (host only): the game id, or null when the deal did not happen
  /// (then the screen says "Not sent." with "Try again"; a host role that
  /// moved meanwhile says nothing: the screen is a guest's now).
  Future<String?> deal() async {
    try {
      final id = await startGame();
      _retry = null;
      return id;
    } on NoLongerHostException {
      return null;
    } catch (e) {
      if (!ref.mounted) return null;
      _retry = deal;
      final now = state.value;
      if (now != null) state = AsyncData(now.copyWith(notSent: true));
      return null;
    }
  }

  /// Starts the game (host only).
  ///
  /// Returns the game ID on success.
  Future<String> startGame() async {
    try {
      final service = ref.read(lobbyServiceProvider);
      final id = await _hostAction(() => service.startGame(code));
      // The host does not have to wait for the lobby event to open the game.
      if (ref.mounted) _applyStartedGame(id);
      return id;
    } catch (e, stack) {
      logger.e('Error starting game', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Leaves the lobby.
  Future<void> leave() async {
    try {
      final service = ref.read(lobbyServiceProvider);
      await service.leaveLobby(code);
    } catch (e, stack) {
      logger.e('Error leaving lobby', error: e, stackTrace: stack);
      rethrow;
    }
  }

  void _dispose() {
    _noticeTimer?.cancel();
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    _wsSubscription?.cancel();
    _webSocket?.close();
    _wsSubscription = null;
    _webSocket = null;
  }
}
