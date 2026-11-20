// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'debug_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The §D2 explicit-per-player-token client used by the toolbar.

@ProviderFor(debugApiClient)
const debugApiClientProvider = DebugApiClientProvider._();

/// The §D2 explicit-per-player-token client used by the toolbar.

final class DebugApiClientProvider
    extends $FunctionalProvider<DebugApiClient, DebugApiClient, DebugApiClient>
    with $Provider<DebugApiClient> {
  /// The §D2 explicit-per-player-token client used by the toolbar.
  const DebugApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'debugApiClientProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$debugApiClientHash();

  @$internal
  @override
  $ProviderElement<DebugApiClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DebugApiClient create(Ref ref) {
    return debugApiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DebugApiClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DebugApiClient>(value),
    );
  }
}

String _$debugApiClientHash() => r'b4528bb875e1acdf3a1db4a08b9d57e8223a0a5e';

/// The §D1 table controller, wired to the real auth notifier + the four game
/// providers in `game_notifier.dart`, and the rebuilt screens' state.
///
/// `switchTo` adopts a session (no refresh) and invalidates `gameProvider`,
/// `gameWebSocketProvider`, `gameWebSocketStreamProvider`, and
/// `gameConnectionStateProvider` so the prior player's socket is disposed and
/// the new player's attaches — exactly one live WS. For a protocol-2 table it
/// also drops the previous player's `/me/`, `/me/table/` and local steps.

@ProviderFor(debugTableController)
const debugTableControllerProvider = DebugTableControllerProvider._();

/// The §D1 table controller, wired to the real auth notifier + the four game
/// providers in `game_notifier.dart`, and the rebuilt screens' state.
///
/// `switchTo` adopts a session (no refresh) and invalidates `gameProvider`,
/// `gameWebSocketProvider`, `gameWebSocketStreamProvider`, and
/// `gameConnectionStateProvider` so the prior player's socket is disposed and
/// the new player's attaches — exactly one live WS. For a protocol-2 table it
/// also drops the previous player's `/me/`, `/me/table/` and local steps.

final class DebugTableControllerProvider
    extends
        $FunctionalProvider<
          DebugTableController,
          DebugTableController,
          DebugTableController
        >
    with $Provider<DebugTableController> {
  /// The §D1 table controller, wired to the real auth notifier + the four game
  /// providers in `game_notifier.dart`, and the rebuilt screens' state.
  ///
  /// `switchTo` adopts a session (no refresh) and invalidates `gameProvider`,
  /// `gameWebSocketProvider`, `gameWebSocketStreamProvider`, and
  /// `gameConnectionStateProvider` so the prior player's socket is disposed and
  /// the new player's attaches — exactly one live WS. For a protocol-2 table it
  /// also drops the previous player's `/me/`, `/me/table/` and local steps.
  const DebugTableControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'debugTableControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$debugTableControllerHash();

  @$internal
  @override
  $ProviderElement<DebugTableController> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DebugTableController create(Ref ref) {
    return debugTableController(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DebugTableController value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DebugTableController>(value),
    );
  }
}

String _$debugTableControllerHash() =>
    r'9b6a455929c70ca8e7ae5ba041e8b80b9b883c66';
