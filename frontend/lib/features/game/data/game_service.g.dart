// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the game service with an authenticated client.

@ProviderFor(gameService)
const gameServiceProvider = GameServiceProvider._();

/// Provides the game service with an authenticated client.

final class GameServiceProvider
    extends $FunctionalProvider<GameService, GameService, GameService>
    with $Provider<GameService> {
  /// Provides the game service with an authenticated client.
  const GameServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gameServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gameServiceHash();

  @$internal
  @override
  $ProviderElement<GameService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GameService create(Ref ref) {
    return gameService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GameService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GameService>(value),
    );
  }
}

String _$gameServiceHash() => r'5f6fb854033ff2faf6c3e8f91a78af8a5f3da358';
