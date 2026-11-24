import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';

export 'read_on_drop.dart';

part 'websocket_channel.freezed.dart';
part 'websocket_channel.g.dart';

/// Canonical WebSocket channel interface.
///
/// Both the production [ReconnectingWebSocket] and test [MockWebSocketChannel]
/// implement this interface, ensuring interchangeability.
abstract interface class WebSocketChannelInterface {
  /// The stream of messages received from the server.
  Stream<dynamic> get stream;

  /// Completes when the connection is open: the server has accepted it (and,
  /// on this server, has already put the socket in its groups). Completes with
  /// an error when it could not be opened (a channel that tries again by
  /// itself never does: it completes when one of its tries opens). Making a
  /// channel only starts the connection; nothing is "connected" until this
  /// completes.
  Future<void> get ready;

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
