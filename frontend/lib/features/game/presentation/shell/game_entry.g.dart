// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_entry.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Which night [gameId] runs, read once from its `/me/` (it never changes).

@ProviderFor(gameProtocol)
const gameProtocolProvider = GameProtocolFamily._();

/// Which night [gameId] runs, read once from its `/me/` (it never changes).

final class GameProtocolProvider
    extends
        $FunctionalProvider<
          AsyncValue<NightProtocol>,
          NightProtocol,
          FutureOr<NightProtocol>
        >
    with $FutureModifier<NightProtocol>, $FutureProvider<NightProtocol> {
  /// Which night [gameId] runs, read once from its `/me/` (it never changes).
  const GameProtocolProvider._({
    required GameProtocolFamily super.from,
    required String super.argument,
  }) : super(
         retry: _retryUnlessRefused,
         name: r'gameProtocolProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$gameProtocolHash();

  @override
  String toString() {
    return r'gameProtocolProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<NightProtocol> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<NightProtocol> create(Ref ref) {
    final argument = this.argument as String;
    return gameProtocol(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GameProtocolProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$gameProtocolHash() => r'3fe6eb1e3b7a4cbc6d489fc387dc9e697eca6161';

/// Which night [gameId] runs, read once from its `/me/` (it never changes).

final class GameProtocolFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<NightProtocol>, String> {
  const GameProtocolFamily._()
    : super(
        retry: _retryUnlessRefused,
        name: r'gameProtocolProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Which night [gameId] runs, read once from its `/me/` (it never changes).

  GameProtocolProvider call(String gameId) =>
      GameProtocolProvider._(argument: gameId, from: this);

  @override
  String toString() => r'gameProtocolProvider';
}
