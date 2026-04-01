// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reconnection_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Tracks whether the WebSocket connection requires a state refresh.
///
/// Listens to the [ReconnectingWebSocket.connectionState] stream and
/// determines when a reconnection has occurred (transition from
/// disconnected/reconnecting to connected). When that happens, the
/// [needsStateRefresh] flag is set to true so the game notifier can
/// re-fetch state from the server.
///
/// This is a focused concern -- it does not fetch game state itself.
/// The game container or game notifier reads [needsStateRefresh] and
/// calls the appropriate API to restore state.

@ProviderFor(ReconnectionNotifier)
const reconnectionProvider = ReconnectionNotifierFamily._();

/// Tracks whether the WebSocket connection requires a state refresh.
///
/// Listens to the [ReconnectingWebSocket.connectionState] stream and
/// determines when a reconnection has occurred (transition from
/// disconnected/reconnecting to connected). When that happens, the
/// [needsStateRefresh] flag is set to true so the game notifier can
/// re-fetch state from the server.
///
/// This is a focused concern -- it does not fetch game state itself.
/// The game container or game notifier reads [needsStateRefresh] and
/// calls the appropriate API to restore state.
final class ReconnectionNotifierProvider
    extends $NotifierProvider<ReconnectionNotifier, ReconnectionState> {
  /// Tracks whether the WebSocket connection requires a state refresh.
  ///
  /// Listens to the [ReconnectingWebSocket.connectionState] stream and
  /// determines when a reconnection has occurred (transition from
  /// disconnected/reconnecting to connected). When that happens, the
  /// [needsStateRefresh] flag is set to true so the game notifier can
  /// re-fetch state from the server.
  ///
  /// This is a focused concern -- it does not fetch game state itself.
  /// The game container or game notifier reads [needsStateRefresh] and
  /// calls the appropriate API to restore state.
  const ReconnectionNotifierProvider._({
    required ReconnectionNotifierFamily super.from,
    required ReconnectingWebSocket super.argument,
  }) : super(
         retry: null,
         name: r'reconnectionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reconnectionNotifierHash();

  @override
  String toString() {
    return r'reconnectionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ReconnectionNotifier create() => ReconnectionNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReconnectionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReconnectionState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ReconnectionNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reconnectionNotifierHash() =>
    r'05e85bd9035f45121a532e384dc11f471d5fb9f3';

/// Tracks whether the WebSocket connection requires a state refresh.
///
/// Listens to the [ReconnectingWebSocket.connectionState] stream and
/// determines when a reconnection has occurred (transition from
/// disconnected/reconnecting to connected). When that happens, the
/// [needsStateRefresh] flag is set to true so the game notifier can
/// re-fetch state from the server.
///
/// This is a focused concern -- it does not fetch game state itself.
/// The game container or game notifier reads [needsStateRefresh] and
/// calls the appropriate API to restore state.

final class ReconnectionNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          ReconnectionNotifier,
          ReconnectionState,
          ReconnectionState,
          ReconnectionState,
          ReconnectingWebSocket
        > {
  const ReconnectionNotifierFamily._()
    : super(
        retry: null,
        name: r'reconnectionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Tracks whether the WebSocket connection requires a state refresh.
  ///
  /// Listens to the [ReconnectingWebSocket.connectionState] stream and
  /// determines when a reconnection has occurred (transition from
  /// disconnected/reconnecting to connected). When that happens, the
  /// [needsStateRefresh] flag is set to true so the game notifier can
  /// re-fetch state from the server.
  ///
  /// This is a focused concern -- it does not fetch game state itself.
  /// The game container or game notifier reads [needsStateRefresh] and
  /// calls the appropriate API to restore state.

  ReconnectionNotifierProvider call(ReconnectingWebSocket webSocket) =>
      ReconnectionNotifierProvider._(argument: webSocket, from: this);

  @override
  String toString() => r'reconnectionProvider';
}

/// Tracks whether the WebSocket connection requires a state refresh.
///
/// Listens to the [ReconnectingWebSocket.connectionState] stream and
/// determines when a reconnection has occurred (transition from
/// disconnected/reconnecting to connected). When that happens, the
/// [needsStateRefresh] flag is set to true so the game notifier can
/// re-fetch state from the server.
///
/// This is a focused concern -- it does not fetch game state itself.
/// The game container or game notifier reads [needsStateRefresh] and
/// calls the appropriate API to restore state.

abstract class _$ReconnectionNotifier extends $Notifier<ReconnectionState> {
  late final _$args = ref.$arg as ReconnectingWebSocket;
  ReconnectingWebSocket get webSocket => _$args;

  ReconnectionState build(ReconnectingWebSocket webSocket);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<ReconnectionState, ReconnectionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReconnectionState, ReconnectionState>,
              ReconnectionState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
