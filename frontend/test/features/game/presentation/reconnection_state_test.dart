import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/websocket/websocket_channel.dart';
import 'package:midnight_village/features/game/presentation/reconnection_notifier.dart';

void main() {
  group('ReconnectionState', () {
    test('showOverlay is true when disconnected', () {
      const state = ReconnectionState(
        connectionState: WebSocketConnectionState.disconnected,
        needsStateRefresh: false,
        wasDisconnected: true,
      );

      expect(state.showOverlay, isTrue);
    });

    test('showOverlay is true when reconnecting', () {
      const state = ReconnectionState(
        connectionState: WebSocketConnectionState.reconnecting,
        needsStateRefresh: false,
        wasDisconnected: true,
      );

      expect(state.showOverlay, isTrue);
    });

    test('showOverlay is false when connected', () {
      const state = ReconnectionState(
        connectionState: WebSocketConnectionState.connected,
        needsStateRefresh: false,
        wasDisconnected: false,
      );

      expect(state.showOverlay, isFalse);
    });

    test('showOverlay is false when connecting', () {
      const state = ReconnectionState(
        connectionState: WebSocketConnectionState.connecting,
        needsStateRefresh: false,
        wasDisconnected: false,
      );

      expect(state.showOverlay, isFalse);
    });

    test('copyWith preserves unmodified fields', () {
      const original = ReconnectionState(
        connectionState: WebSocketConnectionState.connected,
        needsStateRefresh: true,
        wasDisconnected: false,
      );

      final copied = original.copyWith(needsStateRefresh: false);

      expect(copied.connectionState, WebSocketConnectionState.connected);
      expect(copied.needsStateRefresh, isFalse);
      expect(copied.wasDisconnected, isFalse);
    });

    test('equality works correctly', () {
      const a = ReconnectionState(
        connectionState: WebSocketConnectionState.connected,
        needsStateRefresh: false,
        wasDisconnected: false,
      );

      const b = ReconnectionState(
        connectionState: WebSocketConnectionState.connected,
        needsStateRefresh: false,
        wasDisconnected: false,
      );

      const c = ReconnectionState(
        connectionState: WebSocketConnectionState.disconnected,
        needsStateRefresh: false,
        wasDisconnected: false,
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  group('ReconnectionNotifier (unit logic)', () {
    // Test the state machine logic that the notifier implements.
    // Uses a pure function that mirrors the notifier's _onStateChange.

    test('connected after disconnected sets needsStateRefresh', () {
      // connecting -> connected -> disconnected -> connected
      var state = const ReconnectionState(
        connectionState: WebSocketConnectionState.connecting,
        needsStateRefresh: false,
        wasDisconnected: false,
      );

      // Initial connect -- no refresh needed
      state = _applyTransition(state, WebSocketConnectionState.connected);
      expect(state.needsStateRefresh, isFalse);
      expect(state.showOverlay, isFalse);

      // Disconnect
      state = _applyTransition(state, WebSocketConnectionState.disconnected);
      expect(state.showOverlay, isTrue);
      expect(state.wasDisconnected, isTrue);

      // Reconnecting
      state = _applyTransition(state, WebSocketConnectionState.reconnecting);
      expect(state.showOverlay, isTrue);

      // Reconnected -- should flag for refresh
      state = _applyTransition(state, WebSocketConnectionState.connected);
      expect(state.needsStateRefresh, isTrue);
      expect(state.showOverlay, isFalse);
    });

    test('initial connection does not set needsStateRefresh', () {
      var state = const ReconnectionState(
        connectionState: WebSocketConnectionState.connecting,
        needsStateRefresh: false,
        wasDisconnected: false,
      );

      state = _applyTransition(state, WebSocketConnectionState.connected);
      expect(state.needsStateRefresh, isFalse);
    });

    test('acknowledgeRefresh clears the flag', () {
      const state = ReconnectionState(
        connectionState: WebSocketConnectionState.connected,
        needsStateRefresh: true,
        wasDisconnected: false,
      );

      final acknowledged = state.copyWith(needsStateRefresh: false);
      expect(acknowledged.needsStateRefresh, isFalse);
      expect(acknowledged.connectionState, WebSocketConnectionState.connected);
    });

    test('multiple disconnects only trigger one refresh on reconnect', () {
      var state = const ReconnectionState(
        connectionState: WebSocketConnectionState.connected,
        needsStateRefresh: false,
        wasDisconnected: false,
      );

      // Several disconnect/reconnecting cycles
      state = _applyTransition(state, WebSocketConnectionState.disconnected);
      state = _applyTransition(state, WebSocketConnectionState.reconnecting);
      state = _applyTransition(state, WebSocketConnectionState.disconnected);
      state = _applyTransition(state, WebSocketConnectionState.reconnecting);

      // Finally reconnect
      state = _applyTransition(state, WebSocketConnectionState.connected);
      expect(state.needsStateRefresh, isTrue);
      expect(state.wasDisconnected, isFalse);
    });

    test('reconnect after initial failure triggers refresh', () {
      // connecting -> disconnected -> reconnecting -> connected
      var state = const ReconnectionState(
        connectionState: WebSocketConnectionState.connecting,
        needsStateRefresh: false,
        wasDisconnected: false,
      );

      // Initial connection fails
      state = _applyTransition(state, WebSocketConnectionState.disconnected);
      expect(state.wasDisconnected, isTrue);

      // Attempting reconnect
      state = _applyTransition(state, WebSocketConnectionState.reconnecting);

      // Successfully connects (this is technically a "reconnect" since we
      // were disconnected)
      state = _applyTransition(state, WebSocketConnectionState.connected);
      expect(state.needsStateRefresh, isTrue);
    });
  });
}

/// Applies the same state transition logic that ReconnectionNotifier uses.
///
/// Mirrors the _onStateChange method for unit testing the state machine
/// without needing a Riverpod container.
ReconnectionState _applyTransition(
  ReconnectionState current,
  WebSocketConnectionState newConnectionState,
) {
  final wasDisconnected =
      current.wasDisconnected ||
      current.connectionState == WebSocketConnectionState.disconnected ||
      current.connectionState == WebSocketConnectionState.reconnecting;

  if (newConnectionState == WebSocketConnectionState.connected &&
      wasDisconnected) {
    return ReconnectionState(
      connectionState: newConnectionState,
      needsStateRefresh: true,
      wasDisconnected: false,
    );
  } else {
    final isDisconnected =
        newConnectionState == WebSocketConnectionState.disconnected ||
        newConnectionState == WebSocketConnectionState.reconnecting;

    return ReconnectionState(
      connectionState: newConnectionState,
      needsStateRefresh: false,
      wasDisconnected: wasDisconnected || isDisconnected,
    );
  }
}
