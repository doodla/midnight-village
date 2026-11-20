// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'protocol_two_game.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A night protocol 2 game for the rebuilt screens, keyed by game id (the
/// old screens keep [GameNotifier] on protocol 1).
///
/// The one rule: the screen is a function of fetched state. Socket events
/// only ask for `/me/` again or update a value `/me/` holds in the same form
/// ([GameEvent]); a missed event is healed by the next fetch (reconnect, the
/// stage's deadline, the next event), so events in any order, repeated or
/// dropped, then a fetch, end in the same state as a cold start.

@ProviderFor(ProtocolTwoGameNotifier)
const protocolTwoGameProvider = ProtocolTwoGameNotifierFamily._();

/// A night protocol 2 game for the rebuilt screens, keyed by game id (the
/// old screens keep [GameNotifier] on protocol 1).
///
/// The one rule: the screen is a function of fetched state. Socket events
/// only ask for `/me/` again or update a value `/me/` holds in the same form
/// ([GameEvent]); a missed event is healed by the next fetch (reconnect, the
/// stage's deadline, the next event), so events in any order, repeated or
/// dropped, then a fetch, end in the same state as a cold start.
final class ProtocolTwoGameNotifierProvider
    extends $AsyncNotifierProvider<ProtocolTwoGameNotifier, ProtocolTwoGame> {
  /// A night protocol 2 game for the rebuilt screens, keyed by game id (the
  /// old screens keep [GameNotifier] on protocol 1).
  ///
  /// The one rule: the screen is a function of fetched state. Socket events
  /// only ask for `/me/` again or update a value `/me/` holds in the same form
  /// ([GameEvent]); a missed event is healed by the next fetch (reconnect, the
  /// stage's deadline, the next event), so events in any order, repeated or
  /// dropped, then a fetch, end in the same state as a cold start.
  const ProtocolTwoGameNotifierProvider._({
    required ProtocolTwoGameNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'protocolTwoGameProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$protocolTwoGameNotifierHash();

  @override
  String toString() {
    return r'protocolTwoGameProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ProtocolTwoGameNotifier create() => ProtocolTwoGameNotifier();

  @override
  bool operator ==(Object other) {
    return other is ProtocolTwoGameNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$protocolTwoGameNotifierHash() =>
    r'0253d13160a374cec20a258f329007926fa6faf2';

/// A night protocol 2 game for the rebuilt screens, keyed by game id (the
/// old screens keep [GameNotifier] on protocol 1).
///
/// The one rule: the screen is a function of fetched state. Socket events
/// only ask for `/me/` again or update a value `/me/` holds in the same form
/// ([GameEvent]); a missed event is healed by the next fetch (reconnect, the
/// stage's deadline, the next event), so events in any order, repeated or
/// dropped, then a fetch, end in the same state as a cold start.

final class ProtocolTwoGameNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          ProtocolTwoGameNotifier,
          AsyncValue<ProtocolTwoGame>,
          ProtocolTwoGame,
          FutureOr<ProtocolTwoGame>,
          String
        > {
  const ProtocolTwoGameNotifierFamily._()
    : super(
        retry: null,
        name: r'protocolTwoGameProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A night protocol 2 game for the rebuilt screens, keyed by game id (the
  /// old screens keep [GameNotifier] on protocol 1).
  ///
  /// The one rule: the screen is a function of fetched state. Socket events
  /// only ask for `/me/` again or update a value `/me/` holds in the same form
  /// ([GameEvent]); a missed event is healed by the next fetch (reconnect, the
  /// stage's deadline, the next event), so events in any order, repeated or
  /// dropped, then a fetch, end in the same state as a cold start.

  ProtocolTwoGameNotifierProvider call(String gameId) =>
      ProtocolTwoGameNotifierProvider._(argument: gameId, from: this);

  @override
  String toString() => r'protocolTwoGameProvider';
}

/// A night protocol 2 game for the rebuilt screens, keyed by game id (the
/// old screens keep [GameNotifier] on protocol 1).
///
/// The one rule: the screen is a function of fetched state. Socket events
/// only ask for `/me/` again or update a value `/me/` holds in the same form
/// ([GameEvent]); a missed event is healed by the next fetch (reconnect, the
/// stage's deadline, the next event), so events in any order, repeated or
/// dropped, then a fetch, end in the same state as a cold start.

abstract class _$ProtocolTwoGameNotifier
    extends $AsyncNotifier<ProtocolTwoGame> {
  late final _$args = ref.$arg as String;
  String get gameId => _$args;

  FutureOr<ProtocolTwoGame> build(String gameId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<ProtocolTwoGame>, ProtocolTwoGame>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ProtocolTwoGame>, ProtocolTwoGame>,
              AsyncValue<ProtocolTwoGame>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// The screen for game [gameId] (night protocol 2), from `/me/table/` and the
/// game's `/me/`: loading until both are in.

@ProviderFor(protocolTwoScreen)
const protocolTwoScreenProvider = ProtocolTwoScreenFamily._();

/// The screen for game [gameId] (night protocol 2), from `/me/table/` and the
/// game's `/me/`: loading until both are in.

final class ProtocolTwoScreenProvider
    extends
        $FunctionalProvider<
          AsyncValue<AppScreen>,
          AsyncValue<AppScreen>,
          AsyncValue<AppScreen>
        >
    with $Provider<AsyncValue<AppScreen>> {
  /// The screen for game [gameId] (night protocol 2), from `/me/table/` and the
  /// game's `/me/`: loading until both are in.
  const ProtocolTwoScreenProvider._({
    required ProtocolTwoScreenFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'protocolTwoScreenProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$protocolTwoScreenHash();

  @override
  String toString() {
    return r'protocolTwoScreenProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<AsyncValue<AppScreen>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<AppScreen> create(Ref ref) {
    final argument = this.argument as String;
    return protocolTwoScreen(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<AppScreen> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<AppScreen>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ProtocolTwoScreenProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$protocolTwoScreenHash() => r'e58d971280ced02abd657c193968d91ecf741e28';

/// The screen for game [gameId] (night protocol 2), from `/me/table/` and the
/// game's `/me/`: loading until both are in.

final class ProtocolTwoScreenFamily extends $Family
    with $FunctionalFamilyOverride<AsyncValue<AppScreen>, String> {
  const ProtocolTwoScreenFamily._()
    : super(
        retry: null,
        name: r'protocolTwoScreenProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The screen for game [gameId] (night protocol 2), from `/me/table/` and the
  /// game's `/me/`: loading until both are in.

  ProtocolTwoScreenProvider call(String gameId) =>
      ProtocolTwoScreenProvider._(argument: gameId, from: this);

  @override
  String toString() => r'protocolTwoScreenProvider';
}
