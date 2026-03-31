/// Interface for a WebSocket channel.
///
/// Defines the contract that both the production [ReconnectingWebSocket]
/// (WP03) and the test [MockWebSocketChannel] implement. Promoted from
/// test helpers to lib so that production code can depend on it.
abstract interface class WebSocketChannelInterface {
  /// The stream of messages received from the server.
  Stream<dynamic> get stream;

  /// Sends [data] to the server.
  void send(dynamic data);

  /// Closes the channel with an optional [code] and [reason].
  Future<void> close([int? code, String? reason]);

  /// Whether the channel has been closed.
  bool get isClosed;
}
