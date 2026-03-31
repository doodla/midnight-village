import 'dart:async';

import 'package:midnight_village/core/websocket/websocket_channel.dart';

export 'package:midnight_village/core/websocket/websocket_channel.dart'
    show WebSocketChannelInterface;

/// Fake WebSocket channel for use in tests.
///
/// Lets tests control the full WebSocket lifecycle without a real network
/// connection:
///
/// - **Inject server events** — call [addServerEvent] to push messages that
///   listeners will receive on [stream].
/// - **Simulate errors** — call [addServerError] to push an error event.
/// - **Capture client messages** — after the code-under-test calls [send],
///   inspect [sentMessages] to assert on what was sent.
/// - **Test close lifecycle** — call [close] and assert [isClosed].
///
/// The underlying [StreamController] uses a broadcast strategy so multiple
/// listeners (e.g. Riverpod providers and test assertions) can subscribe
/// simultaneously.
///
/// Example:
/// ```dart
/// final ws = MockWebSocketChannel();
/// ws.stream.listen((event) => print('received: $event'));
///
/// ws.addServerEvent({'type': 'game_started'});
/// // -> received: {type: game_started}
///
/// ws.send({'type': 'player_action'});
/// expect(ws.sentMessages, [{'type': 'player_action'}]);
///
/// await ws.close();
/// expect(ws.isClosed, isTrue);
/// ```
class MockWebSocketChannel implements WebSocketChannelInterface {
  MockWebSocketChannel()
    // sync: true ensures addServerEvent() delivers events synchronously to
    // listeners, making test assertions deterministic without extra awaits.
    : _controller = StreamController<dynamic>.broadcast(sync: true);

  final StreamController<dynamic> _controller;

  /// All messages that the code-under-test sent via [send], in order.
  final List<dynamic> sentMessages = [];

  bool _isClosed = false;

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  bool get isClosed => _isClosed;

  /// Pushes [data] as a server-sent event to all current stream listeners.
  ///
  /// Silently ignored if the channel is already [closed][isClosed].
  void addServerEvent(dynamic data) {
    if (!_isClosed) _controller.add(data);
  }

  /// Pushes [error] as a server error to all current stream listeners.
  ///
  /// Silently ignored if the channel is already [closed][isClosed].
  void addServerError(Object error) {
    if (!_isClosed) _controller.addError(error);
  }

  @override
  void send(dynamic data) {
    sentMessages.add(data);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    _isClosed = true;
    await _controller.close();
  }
}
