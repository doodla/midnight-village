import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/config/env.dart';
import '../../../core/healing/healing.dart';
import '../../../core/host/host_change.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/requests/player_request.dart';
import '../../../core/websocket/reconnecting_websocket.dart';
import '../../../core/websocket/websocket_channel.dart';
import '../../../design_system/copy/copy.dart';
import '../../../design_system/primitives/pending.dart' show RequestRefused;
import '../../../features/auth/presentation/auth_notifier.dart';
import '../data/lobby_service.dart';
import '../domain/lobby_state.dart';
import '../domain/settings_lane.dart';
import 'where_am_i_provider.dart';

part 'lobby_notifier.g.dart';
part 'lobby_taps.dart';

/// A leave the server refused, with the words to show ([why]): never "Not
/// sent.", which is only for a leave that did not reach the server.
class LeaveRefused extends RequestRefused {
  const LeaveRefused(super.why);

  @override
  String toString() => 'LeaveRefused: $why';
}

/// Provides the [LobbyService] for HTTP lobby operations.
@riverpod
LobbyService lobbyService(Ref ref) {
  return LobbyService(client: ref.watch(authenticatedClientProvider));
}

/// The lobby the server just answered a start or a join with, so the
/// table's first read uses it instead of asking again (one slot: the table
/// this phone just sat down at). [settled]: nobody else can have changed it
/// since (a table just opened: only its host knows the code); otherwise it
/// is read once more as soon as its socket is up, for anything said before
/// the socket listened.
class LobbySeed {
  ({LobbyState lobby, bool settled})? _seed;

  void put(LobbyState lobby, {required bool settled}) =>
      _seed = (lobby: lobby, settled: settled);

  /// The seed for table [code], once.
  ({LobbyState lobby, bool settled})? take(String code) {
    final seed = _seed;
    if (seed == null || seed.lobby.code != code) return null;
    _seed = null;
    return seed;
  }

  void clear() => _seed = null;
}

@Riverpod(keepAlive: true)
LobbySeed lobbySeed(Ref ref) => LobbySeed();

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
/// - `lobby_update` -> update settings (role configuration changed by host)
/// - `game_started` -> extract game_id for navigation (WS provider auto-disposes)
///
/// A table runs several games one after another: every start sets a new
/// [LobbyState.startedGameId], and a lobby opened while a game is already
/// running (the start event came before the socket was up) looks the game up.
/// Its first read heals like every fetch a screen depends on: retried until
/// it answers ([retryForever]); 02 and 03 say "One moment" meanwhile.
@Riverpod(retry: retryForever)
class LobbyNotifier extends _$LobbyNotifier with _LobbyTaps {
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

  /// Shown from a join's answer ([LobbySeed], not settled): read once more
  /// when the socket is first up.
  bool _readWhenUp = false;

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

  /// The host's changes on the settings lane (settings and practice): what
  /// is asked and not answered, the one out, the changes that got no answer
  /// and the one "Try again" slot ([SettingsLane]; sent by [_LobbyTaps]).
  /// What the screen shows is the server's lobby with ALL pending changes
  /// over it ([SettingsLane.over]), as the server will apply them, so a tap
  /// shows at once, an event or a refetch meanwhile never takes it back, and
  /// nothing judged from the server's numbers (Deal, the seats, the practice
  /// limit) goes around one ([LobbyState.pendingKeys]: `settling`).
  @override
  SettingsLane _lane = SettingsLane.empty;

  @override
  void _show(LobbyState server) => state = AsyncData(_lane.over(server));

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
    final seed = ref.read(lobbySeedProvider).take(code);
    _readWhenUp = seed != null && !seed.settled;
    _connectWebSocket(code);

    // The start's or the join's answer is the lobby: no read before 02.
    if (seed != null) return _replayBuffered(seed.lobby);

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
          if (s == WebSocketConnectionState.connected &&
              (wasDown || _readWhenUp)) {
            wasDown = false;
            _readWhenUp = false;
            unawaited(refreshLobby());
          } else if (s == WebSocketConnectionState.disconnected ||
              s == WebSocketConnectionState.reconnecting) {
            wasDown = readOnDrop(s, refreshLobby);
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
  /// The `player_joined` and `player_left` events carry only their type:
  /// who is at the table is in the lobby body, read again here. Re-fetching
  /// keeps us consistent with the server (spec US3 AS7).
  Future<void> _onPlayerListChanged() => refreshLobby();

  /// Reads the lobby again from the server. The host (the effective host) is
  /// whatever the server says, so a missed `host_changed` heals here. Calls
  /// made while a fetch is in flight share it, then run once more.
  @override
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
  @override
  LobbyState _adopt(LobbyState fresh) {
    final current = state.value;
    if (current == null) return fresh;
    final brief = current.briefHostNotice;
    return fresh.copyWith(
      startedGameId: current.startedGameId,
      notSent: current.notSent,
      dealRefused: current.dealRefused,
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
  @override
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
  @override
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

  /// What a refused deal means to the host, from the server's answer
  /// (`apps/onuw/deal.py`'s `deal_refusal`: the table is not waiting, or the
  /// settings' errors for this many players). Not [answered]: the phone could
  /// not reach the server ("Not sent."). Answered with no [why]: the server
  /// gave no reason worth saying, so nothing is said; the button showed
  /// `deal.ok`, so a refusal means the table changed under the tap, and the
  /// lobby read again sets the button.
  static ({bool answered, String? why}) dealRefusal(Object error) {
    final (int? status, List<String> details) = switch (error) {
      ValidationException(:final errors) => (
        400,
        [...errors.values.expand((e) => e)],
      ),
      UnhandledHttpException(:final statusCode, :final message) => (
        statusCode,
        [message],
      ),
      NotFoundException() => (404, const <String>[]),
      _ => (null, const <String>[]),
    };
    if (status == null || !serverAnswered(error)) {
      return (answered: false, why: null);
    }
    final why = status == 404
        ? BannerCopy.tableClosed
        : details.contains(_notWaiting)
        ? BannerCopy.lobbyClosed
        : details.any((d) => d.startsWith(_tooFew))
        ? TableCopy.needPlayers
        // Not everyone the table is set for is here: the seats say so.
        : details.any((d) => d.startsWith(_setFor))
        ? null
        : details.any(_deckError.hasMatch)
        ? BannerCopy.deckDoesNotFit
        : null;
    return (answered: true, why: why);
  }

  /// The server's refusal words (`deal.py`, `validate_onuw_settings`).
  static const _notWaiting = 'Lobby is not in waiting state.';
  static const _tooFew = 'At least 3 players required';
  static const _setFor = 'The table is set for';
  static final _deckError = RegExp(
    r'^(Total role count|Masons must|Unknown role|Count for|.* requires at least|.* allows at most)',
  );

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
