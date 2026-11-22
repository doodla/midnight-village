// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_back_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The card back of game [gameId]: one for the whole game and every phone at
/// the table (`CardBack.forGame`, from the game's id). A provider only so the
/// screen gallery can pin it (`test_screens/`); nothing else overrides it.

@ProviderFor(gameCardBack)
const gameCardBackProvider = GameCardBackFamily._();

/// The card back of game [gameId]: one for the whole game and every phone at
/// the table (`CardBack.forGame`, from the game's id). A provider only so the
/// screen gallery can pin it (`test_screens/`); nothing else overrides it.

final class GameCardBackProvider
    extends $FunctionalProvider<CardBack, CardBack, CardBack>
    with $Provider<CardBack> {
  /// The card back of game [gameId]: one for the whole game and every phone at
  /// the table (`CardBack.forGame`, from the game's id). A provider only so the
  /// screen gallery can pin it (`test_screens/`); nothing else overrides it.
  const GameCardBackProvider._({
    required GameCardBackFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'gameCardBackProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$gameCardBackHash();

  @override
  String toString() {
    return r'gameCardBackProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<CardBack> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CardBack create(Ref ref) {
    final argument = this.argument as String;
    return gameCardBack(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CardBack value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CardBack>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GameCardBackProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$gameCardBackHash() => r'd2b4676c307e2c51f1df392bdf4d07b1416bb2f0';

/// The card back of game [gameId]: one for the whole game and every phone at
/// the table (`CardBack.forGame`, from the game's id). A provider only so the
/// screen gallery can pin it (`test_screens/`); nothing else overrides it.

final class GameCardBackFamily extends $Family
    with $FunctionalFamilyOverride<CardBack, String> {
  const GameCardBackFamily._()
    : super(
        retry: null,
        name: r'gameCardBackProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The card back of game [gameId]: one for the whole game and every phone at
  /// the table (`CardBack.forGame`, from the game's id). A provider only so the
  /// screen gallery can pin it (`test_screens/`); nothing else overrides it.

  GameCardBackProvider call(String gameId) =>
      GameCardBackProvider._(argument: gameId, from: this);

  @override
  String toString() => r'gameCardBackProvider';
}
