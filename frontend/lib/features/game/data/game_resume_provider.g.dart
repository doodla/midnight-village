// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_resume_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the [GameResumeService] for checking active games on startup.
///
/// Kept alive so the cached result persists across navigations.

@ProviderFor(gameResumeService)
const gameResumeServiceProvider = GameResumeServiceProvider._();

/// Provides the [GameResumeService] for checking active games on startup.
///
/// Kept alive so the cached result persists across navigations.

final class GameResumeServiceProvider
    extends
        $FunctionalProvider<
          GameResumeService,
          GameResumeService,
          GameResumeService
        >
    with $Provider<GameResumeService> {
  /// Provides the [GameResumeService] for checking active games on startup.
  ///
  /// Kept alive so the cached result persists across navigations.
  const GameResumeServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gameResumeServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gameResumeServiceHash();

  @$internal
  @override
  $ProviderElement<GameResumeService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GameResumeService create(Ref ref) {
    return gameResumeService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GameResumeService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GameResumeService>(value),
    );
  }
}

String _$gameResumeServiceHash() => r'a854454c28bb979be8bef0af6d46efdc1b4ce0ff';
