// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'websocket_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Manages a [ReconnectingWebSocket] connection for the given [url].
///
/// Starts the connection on creation and disposes it when all listeners
/// are removed (e.g., on navigation away from the lobby or game screen).
///
/// Consumed by `LobbyNotifier` (WP05) and `GameNotifier` (WP07).

@ProviderFor(webSocketConnection)
const webSocketConnectionProvider = WebSocketConnectionFamily._();

/// Manages a [ReconnectingWebSocket] connection for the given [url].
///
/// Starts the connection on creation and disposes it when all listeners
/// are removed (e.g., on navigation away from the lobby or game screen).
///
/// Consumed by `LobbyNotifier` (WP05) and `GameNotifier` (WP07).

final class WebSocketConnectionProvider
    extends
        $FunctionalProvider<
          ReconnectingWebSocket,
          ReconnectingWebSocket,
          ReconnectingWebSocket
        >
    with $Provider<ReconnectingWebSocket> {
  /// Manages a [ReconnectingWebSocket] connection for the given [url].
  ///
  /// Starts the connection on creation and disposes it when all listeners
  /// are removed (e.g., on navigation away from the lobby or game screen).
  ///
  /// Consumed by `LobbyNotifier` (WP05) and `GameNotifier` (WP07).
  const WebSocketConnectionProvider._({
    required WebSocketConnectionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'webSocketConnectionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$webSocketConnectionHash();

  @override
  String toString() {
    return r'webSocketConnectionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<ReconnectingWebSocket> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ReconnectingWebSocket create(Ref ref) {
    final argument = this.argument as String;
    return webSocketConnection(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReconnectingWebSocket value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReconnectingWebSocket>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is WebSocketConnectionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$webSocketConnectionHash() =>
    r'7842d256f3f722d5e9df48ad9819bd5b0276552a';

/// Manages a [ReconnectingWebSocket] connection for the given [url].
///
/// Starts the connection on creation and disposes it when all listeners
/// are removed (e.g., on navigation away from the lobby or game screen).
///
/// Consumed by `LobbyNotifier` (WP05) and `GameNotifier` (WP07).

final class WebSocketConnectionFamily extends $Family
    with $FunctionalFamilyOverride<ReconnectingWebSocket, String> {
  const WebSocketConnectionFamily._()
    : super(
        retry: null,
        name: r'webSocketConnectionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Manages a [ReconnectingWebSocket] connection for the given [url].
  ///
  /// Starts the connection on creation and disposes it when all listeners
  /// are removed (e.g., on navigation away from the lobby or game screen).
  ///
  /// Consumed by `LobbyNotifier` (WP05) and `GameNotifier` (WP07).

  WebSocketConnectionProvider call(String url) =>
      WebSocketConnectionProvider._(argument: url, from: this);

  @override
  String toString() => r'webSocketConnectionProvider';
}
