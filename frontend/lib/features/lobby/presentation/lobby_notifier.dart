import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/logging/app_logger.dart';
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
  // Default implementation throws -- must be overridden in production
  // (with ReconnectingWebSocket from WP03) or in tests (with MockWebSocketChannel).
  throw UnimplementedError(
    'lobbyWebSocketFactory must be overridden. '
    'In production, override with ReconnectingWebSocket factory. '
    'In tests, override with MockWebSocketChannel factory.',
  );
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
@riverpod
class LobbyNotifier extends _$LobbyNotifier {
  StreamSubscription<dynamic>? _wsSubscription;
  WebSocketChannelInterface? _webSocket;

  /// The game ID from a `game_started` event. Consumers watch this to navigate.
  String? gameId;

  @override
  Future<LobbyState> build(String code) async {
    final service = ref.read(lobbyServiceProvider);

    // Fetch initial lobby state
    final lobbyState = await service.fetchLobby(code);

    // Connect WebSocket
    _connectWebSocket(code);

    // Clean up on dispose
    ref.onDispose(_dispose);

    return lobbyState;
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
    } catch (e) {
      logger.w('Failed to connect lobby WebSocket', error: e);
      // Non-fatal: lobby still works via HTTP, just without real-time updates.
    }
  }

  void _handleWebSocketEvent(dynamic rawMessage) {
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
  Future<void> _onPlayerListChanged() async {
    try {
      final service = ref.read(lobbyServiceProvider);
      final newState = await service.fetchLobby(code);
      state = AsyncData(newState);
    } catch (e, stack) {
      logger.e(
        'Error re-fetching lobby after player change',
        error: e,
        stackTrace: stack,
      );
    }
  }

  /// Update a player's ready state in-place.
  ///
  /// The `player_ready` event has complete data (`username`, `is_ready`),
  /// so we can update locally without re-fetching.
  void _onPlayerReady(Map<String, dynamic> message) {
    final username = message['username'] as String?;
    final isReady = message['is_ready'] as bool?;
    if (username == null || isReady == null) return;

    final current = state.value;
    if (current == null) return;

    final updatedPlayers = current.players.map((player) {
      if (player.displayName == username) {
        return player.copyWith(isReady: isReady);
      }
      return player;
    }).toList();

    state = AsyncData(current.copyWith(players: updatedPlayers));
  }

  /// Update lobby settings when the host changes role configuration.
  void _onLobbyUpdate(Map<String, dynamic> message) {
    final current = state.value;
    if (current == null) return;

    final data = message['data'] as Map<String, dynamic>?;
    final settings = data?['settings'] as Map<String, dynamic>?;
    final roles = settings?['roles'] as Map<String, dynamic>?;

    if (roles != null) {
      final roleConfig = roles.map((k, v) => MapEntry(k, v as int));
      state = AsyncData(current.copyWith(roleConfig: roleConfig));
    }
  }

  /// Handle game_started event by extracting the game ID.
  ///
  /// The consumer (lobby screen) watches [gameId] and navigates to
  /// `/game/<gameId>` when it becomes non-null. The provider is then
  /// invalidated by navigation, triggering dispose and WS cleanup.
  void _onGameStarted(Map<String, dynamic> message) {
    final id = message['game_id'] as String?;
    if (id != null) {
      gameId = id;
      // Trigger a state update so listeners re-evaluate
      final current = state.value;
      if (current != null) {
        state = AsyncData(current.copyWith(status: 'in_game'));
      }
    }
  }

  // --- Public methods for user actions ---

  /// Toggles the current player's ready state.
  Future<void> toggleReady() async {
    try {
      final service = ref.read(lobbyServiceProvider);
      await service.toggleReady(code);
    } catch (e, stack) {
      logger.e('Error toggling ready', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Starts the game (host only).
  ///
  /// Returns the game ID on success.
  Future<String> startGame() async {
    try {
      final service = ref.read(lobbyServiceProvider);
      return await service.startGame(code);
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

  /// Updates the role configuration (host only).
  Future<void> updateRoleConfig(Map<String, int> roles) async {
    try {
      final service = ref.read(lobbyServiceProvider);
      final newState = await service.updateRoleConfig(code, roles);
      state = AsyncData(newState);
    } catch (e, stack) {
      logger.e('Error updating role config', error: e, stackTrace: stack);
      rethrow;
    }
  }

  void _dispose() {
    _wsSubscription?.cancel();
    _webSocket?.close();
    _wsSubscription = null;
    _webSocket = null;
  }
}
