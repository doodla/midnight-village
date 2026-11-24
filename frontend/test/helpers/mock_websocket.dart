import 'dart:async';

import 'package:midnight_village/core/websocket/websocket_channel.dart';

import 'contract/contract_shape.dart';

export 'package:midnight_village/core/websocket/websocket_channel.dart'
    show WebSocketChannelInterface;

/// Fake WebSocket channel for use in tests.
///
/// Lets tests control the full WebSocket lifecycle without a real network
/// connection:
///
/// - **Inject server events** — call [addServerEvent] to push messages that
///   listeners will receive on [stream]. Each must be an event the server
///   sends (checked against `contract_samples/`, see [checkSocketEvent]);
///   [addOffContractEvent] is for tests about malformed input.
/// - **Simulate errors** — call [addServerError] to push an error event.
/// - **No client messages** — the server's consumers refuse anything a
///   client sends (game and lobby actions go through HTTP), so [send] fails
///   the test, unless the mock was made with `acceptsSends: true` for a test
///   of socket plumbing; [sentMessages] then records what was sent.
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
/// ws.addServerEvent(GameEvents.gameStarted(gameId: 'g1'));
/// // -> received: {"type":"game_started","game_id":"g1"}
///
/// await ws.close();
/// expect(ws.isClosed, isTrue);
/// ```
class MockWebSocketChannel implements WebSocketChannelInterface {
  MockWebSocketChannel({this.acceptsSends = false, Future<void>? opens})
    // sync: true ensures addServerEvent() delivers events synchronously to
    // listeners, making test assertions deterministic without extra awaits.
    : _opens = opens,
      _controller = StreamController<dynamic>.broadcast(sync: true);

  final StreamController<dynamic> _controller;

  /// When the connection opens: at once, unless the test gives the moment
  /// (a slow, failed or never-finished opening).
  final Future<void>? _opens;

  @override
  Future<void> get ready => _opens ?? Future<void>.value();

  /// Whether [send] is allowed (socket plumbing tests only).
  final bool acceptsSends;

  /// All messages that the code-under-test sent via [send], in order.
  final List<dynamic> sentMessages = [];

  bool _isClosed = false;

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  bool get isClosed => _isClosed;

  /// Pushes [data] as a server-sent event to all current stream listeners.
  /// Throws [OffContractPayload] unless the server sends events of that shape.
  ///
  /// Silently ignored if the channel is already [closed][isClosed].
  void addServerEvent(dynamic data) {
    checkSocketEvent(data);
    addOffContractEvent(data);
  }

  /// [addServerEvent] without the check, for a test about a message the
  /// server would never send (malformed, unknown type).
  void addOffContractEvent(dynamic data) {
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
    if (!acceptsSends) {
      throw StateError(
        'The app sent $data on a socket: the server answers every client '
        'message with an error (actions go through the HTTP API).',
      );
    }
    sentMessages.add(data);
  }

  @override
  Future<void> close([int? code, String? reason]) async {
    _isClosed = true;
    await _controller.close();
  }
}
