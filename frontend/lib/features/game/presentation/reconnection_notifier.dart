import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/websocket/reconnecting_websocket.dart';
import '../../../core/websocket/websocket_channel.dart';

part 'reconnection_notifier.g.dart';

/// Tracks whether the WebSocket connection requires a state refresh.
///
/// Listens to the [ReconnectingWebSocket.connectionState] stream and
/// determines when a reconnection has occurred (transition from
/// disconnected/reconnecting to connected). When that happens, the
/// [needsStateRefresh] flag is set to true so the game notifier can
/// re-fetch state from the server.
///
/// This is a focused concern -- it does not fetch game state itself.
/// The game container or game notifier reads [needsStateRefresh] and
/// calls the appropriate API to restore state.
@riverpod
class ReconnectionNotifier extends _$ReconnectionNotifier {
  StreamSubscription<WebSocketConnectionState>? _subscription;

  @override
  ReconnectionState build(ReconnectingWebSocket webSocket) {
    _subscription?.cancel();
    _subscription = webSocket.connectionState.listen(_onStateChange);

    ref.onDispose(() {
      _subscription?.cancel();
      _subscription = null;
    });

    return const ReconnectionState(
      connectionState: WebSocketConnectionState.connecting,
      needsStateRefresh: false,
      wasDisconnected: false,
    );
  }

  void _onStateChange(WebSocketConnectionState connectionState) {
    final wasDisconnected =
        state.wasDisconnected ||
        state.connectionState == WebSocketConnectionState.disconnected ||
        state.connectionState == WebSocketConnectionState.reconnecting;

    if (connectionState == WebSocketConnectionState.connected &&
        wasDisconnected) {
      // Reconnected after a disconnect -- signal that state needs refresh.
      state = ReconnectionState(
        connectionState: connectionState,
        needsStateRefresh: true,
        wasDisconnected: false,
      );
    } else {
      final isDisconnected =
          connectionState == WebSocketConnectionState.disconnected ||
          connectionState == WebSocketConnectionState.reconnecting;

      state = ReconnectionState(
        connectionState: connectionState,
        needsStateRefresh: false,
        wasDisconnected: wasDisconnected || isDisconnected,
      );
    }
  }

  /// Acknowledges that the state refresh has been handled.
  ///
  /// Call this after re-fetching game state from the server so that
  /// the [needsStateRefresh] flag is cleared.
  void acknowledgeRefresh() {
    state = state.copyWith(needsStateRefresh: false);
  }
}

/// Immutable state for the reconnection tracker.
class ReconnectionState {
  const ReconnectionState({
    required this.connectionState,
    required this.needsStateRefresh,
    required this.wasDisconnected,
  });

  /// Current WebSocket connection state.
  final WebSocketConnectionState connectionState;

  /// Whether the game state needs to be re-fetched from the server.
  ///
  /// Set to true when the connection transitions from disconnected/reconnecting
  /// to connected. Cleared when [ReconnectionNotifier.acknowledgeRefresh] is
  /// called.
  final bool needsStateRefresh;

  /// Internal tracking: whether we have been disconnected since last connected.
  final bool wasDisconnected;

  /// Whether the overlay should be shown (disconnected or reconnecting).
  bool get showOverlay =>
      connectionState == WebSocketConnectionState.disconnected ||
      connectionState == WebSocketConnectionState.reconnecting;

  ReconnectionState copyWith({
    WebSocketConnectionState? connectionState,
    bool? needsStateRefresh,
    bool? wasDisconnected,
  }) {
    return ReconnectionState(
      connectionState: connectionState ?? this.connectionState,
      needsStateRefresh: needsStateRefresh ?? this.needsStateRefresh,
      wasDisconnected: wasDisconnected ?? this.wasDisconnected,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReconnectionState &&
          runtimeType == other.runtimeType &&
          connectionState == other.connectionState &&
          needsStateRefresh == other.needsStateRefresh &&
          wasDisconnected == other.wasDisconnected;

  @override
  int get hashCode =>
      connectionState.hashCode ^
      needsStateRefresh.hashCode ^
      wasDisconnected.hashCode;
}
