import 'package:flutter/widgets.dart' show AppLifecycleListener;

import 'reconnecting_websocket.dart';

/// While the app is hidden, [ws] does not watch its silence
/// ([ReconnectingWebSocket.pause]): no timer runs for it in the background,
/// and a browser that holds frames while timers still run cannot make it
/// reconnect again and again. Coming back, the screen's resume calls
/// [ReconnectingWebSocket.verify], which decides by the clock. Held for the
/// socket's life (it is let go when the socket is disposed).
void pauseWhileHidden(ReconnectingWebSocket ws) {
  final listener = AppLifecycleListener(onHide: ws.pause);
  ws.whenDisposed(listener.dispose);
}
