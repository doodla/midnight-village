import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/auth_notifier.dart';
import 'reconnecting_websocket.dart';

part 'websocket_provider.g.dart';

/// Manages a [ReconnectingWebSocket] connection for the given [url].
///
/// Starts the connection on creation and disposes it when all listeners
/// are removed (e.g., on navigation away from the lobby or game screen).
///
/// Consumed by `LobbyNotifier` (WP05) and `GameNotifier` (WP07).
@riverpod
ReconnectingWebSocket webSocketConnection(Ref ref, String url) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  final ws = ReconnectingWebSocket(url: url, tokenStorage: tokenStorage);

  ref.onDispose(ws.dispose);

  unawaited(ws.connect());

  return ws;
}
