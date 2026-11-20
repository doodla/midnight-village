// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Core game state machine that handles all WebSocket events and exposes
/// action methods.
///
/// Family provider keyed by game ID. Fetches initial state via REST, then
/// listens to a WebSocket stream for real-time updates. Each WS event type
/// is handled by a discrete method for testability.
///
/// The [NightSubView] state machine is display-only -- it determines which
/// view the [GameContainerScreen] renders during the night phase.

@ProviderFor(GameNotifier)
const gameProvider = GameNotifierFamily._();

/// Core game state machine that handles all WebSocket events and exposes
/// action methods.
///
/// Family provider keyed by game ID. Fetches initial state via REST, then
/// listens to a WebSocket stream for real-time updates. Each WS event type
/// is handled by a discrete method for testability.
///
/// The [NightSubView] state machine is display-only -- it determines which
/// view the [GameContainerScreen] renders during the night phase.
final class GameNotifierProvider
    extends $AsyncNotifierProvider<GameNotifier, GameSessionState> {
  /// Core game state machine that handles all WebSocket events and exposes
  /// action methods.
  ///
  /// Family provider keyed by game ID. Fetches initial state via REST, then
  /// listens to a WebSocket stream for real-time updates. Each WS event type
  /// is handled by a discrete method for testability.
  ///
  /// The [NightSubView] state machine is display-only -- it determines which
  /// view the [GameContainerScreen] renders during the night phase.
  const GameNotifierProvider._({
    required GameNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'gameProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$gameNotifierHash();

  @override
  String toString() {
    return r'gameProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  GameNotifier create() => GameNotifier();

  @override
  bool operator ==(Object other) {
    return other is GameNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$gameNotifierHash() => r'5aa245ac49ff0f9a20c4fd5ce3612db4e4a258cc';

/// Core game state machine that handles all WebSocket events and exposes
/// action methods.
///
/// Family provider keyed by game ID. Fetches initial state via REST, then
/// listens to a WebSocket stream for real-time updates. Each WS event type
/// is handled by a discrete method for testability.
///
/// The [NightSubView] state machine is display-only -- it determines which
/// view the [GameContainerScreen] renders during the night phase.

final class GameNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          GameNotifier,
          AsyncValue<GameSessionState>,
          GameSessionState,
          FutureOr<GameSessionState>,
          String
        > {
  const GameNotifierFamily._()
    : super(
        retry: null,
        name: r'gameProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Core game state machine that handles all WebSocket events and exposes
  /// action methods.
  ///
  /// Family provider keyed by game ID. Fetches initial state via REST, then
  /// listens to a WebSocket stream for real-time updates. Each WS event type
  /// is handled by a discrete method for testability.
  ///
  /// The [NightSubView] state machine is display-only -- it determines which
  /// view the [GameContainerScreen] renders during the night phase.

  GameNotifierProvider call(String gameId) =>
      GameNotifierProvider._(argument: gameId, from: this);

  @override
  String toString() => r'gameProvider';
}

/// Core game state machine that handles all WebSocket events and exposes
/// action methods.
///
/// Family provider keyed by game ID. Fetches initial state via REST, then
/// listens to a WebSocket stream for real-time updates. Each WS event type
/// is handled by a discrete method for testability.
///
/// The [NightSubView] state machine is display-only -- it determines which
/// view the [GameContainerScreen] renders during the night phase.

abstract class _$GameNotifier extends $AsyncNotifier<GameSessionState> {
  late final _$args = ref.$arg as String;
  String get gameId => _$args;

  FutureOr<GameSessionState> build(String gameId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref =
        this.ref as $Ref<AsyncValue<GameSessionState>, GameSessionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<GameSessionState>, GameSessionState>,
              AsyncValue<GameSessionState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
