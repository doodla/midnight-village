import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/websocket/reconnecting_websocket.dart';
import '../../../core/websocket/websocket_channel.dart';
import '../../auth/presentation/auth_notifier.dart';

/// The game's socket (`/ws/game/<id>/`), open while a game listens to it
/// (autoDispose: a game no longer shown closes its socket).
///
/// In tests, override [gameWebSocketStreamProvider] and
/// [gameConnectionStateProvider] instead: those are what the game reads.
final gameWebSocketProvider = Provider.autoDispose
    .family<ReconnectingWebSocket?, String>((ref, gameId) {
      final tokenStorage = ref.watch(tokenStorageProvider);
      final url = '${Env.wsBaseUrl}/ws/game/$gameId/';
      final ws = ReconnectingWebSocket(url: url, tokenStorage: tokenStorage);
      unawaited(ws.connect());
      ref.onDispose(ws.dispose);
      return ws;
    }, name: 'gameWebSocketProvider');

/// The game's socket events (null: no socket, as in a unit test that calls
/// the handlers itself).
final gameWebSocketStreamProvider = Provider.autoDispose
    .family<Stream<dynamic>?, String>((ref, gameId) {
      return ref.watch(gameWebSocketProvider(gameId))?.stream;
    }, name: 'gameWebSocketStreamProvider');

/// The game socket's connection state: the shell's "One moment" and the
/// game's fetch on reconnect read it.
final gameConnectionStateProvider = StreamProvider.autoDispose
    .family<WebSocketConnectionState, String>((ref, gameId) {
      final ws = ref.watch(gameWebSocketProvider(gameId));
      if (ws == null) {
        return Stream.value(WebSocketConnectionState.connected);
      }
      return ws.connectionState;
    }, name: 'gameConnectionStateProvider');
