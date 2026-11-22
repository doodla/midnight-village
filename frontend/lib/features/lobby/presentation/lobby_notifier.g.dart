// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lobby_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the [LobbyService] for HTTP lobby operations.

@ProviderFor(lobbyService)
const lobbyServiceProvider = LobbyServiceProvider._();

/// Provides the [LobbyService] for HTTP lobby operations.

final class LobbyServiceProvider
    extends $FunctionalProvider<LobbyService, LobbyService, LobbyService>
    with $Provider<LobbyService> {
  /// Provides the [LobbyService] for HTTP lobby operations.
  const LobbyServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lobbyServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lobbyServiceHash();

  @$internal
  @override
  $ProviderElement<LobbyService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LobbyService create(Ref ref) {
    return lobbyService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LobbyService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LobbyService>(value),
    );
  }
}

String _$lobbyServiceHash() => r'307575c4fc9b15e2c921330c7fc21ef299e7cd8a';

/// Provider for the WebSocket factory. Override in tests with a mock.

@ProviderFor(lobbyWebSocketFactory)
const lobbyWebSocketFactoryProvider = LobbyWebSocketFactoryProvider._();

/// Provider for the WebSocket factory. Override in tests with a mock.

final class LobbyWebSocketFactoryProvider
    extends
        $FunctionalProvider<
          LobbyWebSocketFactory,
          LobbyWebSocketFactory,
          LobbyWebSocketFactory
        >
    with $Provider<LobbyWebSocketFactory> {
  /// Provider for the WebSocket factory. Override in tests with a mock.
  const LobbyWebSocketFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'lobbyWebSocketFactoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$lobbyWebSocketFactoryHash();

  @$internal
  @override
  $ProviderElement<LobbyWebSocketFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LobbyWebSocketFactory create(Ref ref) {
    return lobbyWebSocketFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LobbyWebSocketFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LobbyWebSocketFactory>(value),
    );
  }
}

String _$lobbyWebSocketFactoryHash() =>
    r'f1af3ee144b21f66c266c979c159d664df5adbbe';

/// Manages lobby state for a given lobby code.
///
/// Coordinates HTTP state fetches with real-time WebSocket events.
/// This is a family provider keyed by lobby code -- one instance per lobby.
///
/// Lifecycle:
/// 1. [build] fetches initial lobby state via HTTP and connects the WebSocket.
/// 2. WebSocket events update state in real-time.
/// 3. [ref.onDispose] closes the WebSocket connection.
///
/// WebSocket event handling per the API contract:
/// - `player_joined` / `player_left` -> re-fetch full lobby state (events lack complete data)
/// - `lobby_update` -> update settings (role configuration changed by host)
/// - `game_started` -> extract game_id for navigation (WS provider auto-disposes)
///
/// A table runs several games one after another: every start sets a new
/// [LobbyState.startedGameId], and a lobby opened while a game is already
/// running (the start event came before the socket was up) looks the game up.
/// Its first read heals like every fetch a screen depends on: retried until
/// it answers ([retryForever]); 02 and 03 say "One moment" meanwhile.

@ProviderFor(LobbyNotifier)
const lobbyProvider = LobbyNotifierFamily._();

/// Manages lobby state for a given lobby code.
///
/// Coordinates HTTP state fetches with real-time WebSocket events.
/// This is a family provider keyed by lobby code -- one instance per lobby.
///
/// Lifecycle:
/// 1. [build] fetches initial lobby state via HTTP and connects the WebSocket.
/// 2. WebSocket events update state in real-time.
/// 3. [ref.onDispose] closes the WebSocket connection.
///
/// WebSocket event handling per the API contract:
/// - `player_joined` / `player_left` -> re-fetch full lobby state (events lack complete data)
/// - `lobby_update` -> update settings (role configuration changed by host)
/// - `game_started` -> extract game_id for navigation (WS provider auto-disposes)
///
/// A table runs several games one after another: every start sets a new
/// [LobbyState.startedGameId], and a lobby opened while a game is already
/// running (the start event came before the socket was up) looks the game up.
/// Its first read heals like every fetch a screen depends on: retried until
/// it answers ([retryForever]); 02 and 03 say "One moment" meanwhile.
final class LobbyNotifierProvider
    extends $AsyncNotifierProvider<LobbyNotifier, LobbyState> {
  /// Manages lobby state for a given lobby code.
  ///
  /// Coordinates HTTP state fetches with real-time WebSocket events.
  /// This is a family provider keyed by lobby code -- one instance per lobby.
  ///
  /// Lifecycle:
  /// 1. [build] fetches initial lobby state via HTTP and connects the WebSocket.
  /// 2. WebSocket events update state in real-time.
  /// 3. [ref.onDispose] closes the WebSocket connection.
  ///
  /// WebSocket event handling per the API contract:
  /// - `player_joined` / `player_left` -> re-fetch full lobby state (events lack complete data)
  /// - `lobby_update` -> update settings (role configuration changed by host)
  /// - `game_started` -> extract game_id for navigation (WS provider auto-disposes)
  ///
  /// A table runs several games one after another: every start sets a new
  /// [LobbyState.startedGameId], and a lobby opened while a game is already
  /// running (the start event came before the socket was up) looks the game up.
  /// Its first read heals like every fetch a screen depends on: retried until
  /// it answers ([retryForever]); 02 and 03 say "One moment" meanwhile.
  const LobbyNotifierProvider._({
    required LobbyNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: retryForever,
         name: r'lobbyProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$lobbyNotifierHash();

  @override
  String toString() {
    return r'lobbyProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  LobbyNotifier create() => LobbyNotifier();

  @override
  bool operator ==(Object other) {
    return other is LobbyNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$lobbyNotifierHash() => r'77e8d8040a1058deacca9d37beeb42f90be8871f';

/// Manages lobby state for a given lobby code.
///
/// Coordinates HTTP state fetches with real-time WebSocket events.
/// This is a family provider keyed by lobby code -- one instance per lobby.
///
/// Lifecycle:
/// 1. [build] fetches initial lobby state via HTTP and connects the WebSocket.
/// 2. WebSocket events update state in real-time.
/// 3. [ref.onDispose] closes the WebSocket connection.
///
/// WebSocket event handling per the API contract:
/// - `player_joined` / `player_left` -> re-fetch full lobby state (events lack complete data)
/// - `lobby_update` -> update settings (role configuration changed by host)
/// - `game_started` -> extract game_id for navigation (WS provider auto-disposes)
///
/// A table runs several games one after another: every start sets a new
/// [LobbyState.startedGameId], and a lobby opened while a game is already
/// running (the start event came before the socket was up) looks the game up.
/// Its first read heals like every fetch a screen depends on: retried until
/// it answers ([retryForever]); 02 and 03 say "One moment" meanwhile.

final class LobbyNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          LobbyNotifier,
          AsyncValue<LobbyState>,
          LobbyState,
          FutureOr<LobbyState>,
          String
        > {
  const LobbyNotifierFamily._()
    : super(
        retry: retryForever,
        name: r'lobbyProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Manages lobby state for a given lobby code.
  ///
  /// Coordinates HTTP state fetches with real-time WebSocket events.
  /// This is a family provider keyed by lobby code -- one instance per lobby.
  ///
  /// Lifecycle:
  /// 1. [build] fetches initial lobby state via HTTP and connects the WebSocket.
  /// 2. WebSocket events update state in real-time.
  /// 3. [ref.onDispose] closes the WebSocket connection.
  ///
  /// WebSocket event handling per the API contract:
  /// - `player_joined` / `player_left` -> re-fetch full lobby state (events lack complete data)
  /// - `lobby_update` -> update settings (role configuration changed by host)
  /// - `game_started` -> extract game_id for navigation (WS provider auto-disposes)
  ///
  /// A table runs several games one after another: every start sets a new
  /// [LobbyState.startedGameId], and a lobby opened while a game is already
  /// running (the start event came before the socket was up) looks the game up.
  /// Its first read heals like every fetch a screen depends on: retried until
  /// it answers ([retryForever]); 02 and 03 say "One moment" meanwhile.

  LobbyNotifierProvider call(String code) =>
      LobbyNotifierProvider._(argument: code, from: this);

  @override
  String toString() => r'lobbyProvider';
}

/// Manages lobby state for a given lobby code.
///
/// Coordinates HTTP state fetches with real-time WebSocket events.
/// This is a family provider keyed by lobby code -- one instance per lobby.
///
/// Lifecycle:
/// 1. [build] fetches initial lobby state via HTTP and connects the WebSocket.
/// 2. WebSocket events update state in real-time.
/// 3. [ref.onDispose] closes the WebSocket connection.
///
/// WebSocket event handling per the API contract:
/// - `player_joined` / `player_left` -> re-fetch full lobby state (events lack complete data)
/// - `lobby_update` -> update settings (role configuration changed by host)
/// - `game_started` -> extract game_id for navigation (WS provider auto-disposes)
///
/// A table runs several games one after another: every start sets a new
/// [LobbyState.startedGameId], and a lobby opened while a game is already
/// running (the start event came before the socket was up) looks the game up.
/// Its first read heals like every fetch a screen depends on: retried until
/// it answers ([retryForever]); 02 and 03 say "One moment" meanwhile.

abstract class _$LobbyNotifier extends $AsyncNotifier<LobbyState> {
  late final _$args = ref.$arg as String;
  String get code => _$args;

  FutureOr<LobbyState> build(String code);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<LobbyState>, LobbyState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<LobbyState>, LobbyState>,
              AsyncValue<LobbyState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
