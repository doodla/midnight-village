import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'websocket_channel.freezed.dart';
part 'websocket_channel.g.dart';

/// Canonical WebSocket channel interface.
///
/// Both the production [ReconnectingWebSocket] and test [MockWebSocketChannel]
/// implement this interface, ensuring interchangeability.
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

/// Connection lifecycle states for a [WebSocketChannelInterface].
enum WebSocketConnectionState {
  /// Attempting initial connection.
  connecting,

  /// Connection established and ready.
  connected,

  /// Connection lost; not yet attempting to reconnect.
  disconnected,

  /// Waiting for backoff delay before next reconnection attempt.
  reconnecting,
}

/// Typed WebSocket event received from the server.
///
/// All server-sent WebSocket messages are decoded into this structure.
/// The [type] field identifies the event kind; [data] holds the payload.
@freezed
abstract class WebSocketEvent with _$WebSocketEvent {
  const factory WebSocketEvent({
    required String type,
    required Map<String, dynamic> data,
  }) = _WebSocketEvent;

  factory WebSocketEvent.fromJson(Map<String, dynamic> json) =>
      _$WebSocketEventFromJson(json);
}
