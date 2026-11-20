// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'protocol_two_game.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(healTiming)
const healTimingProvider = HealTimingProvider._();

final class HealTimingProvider
    extends $FunctionalProvider<HealTiming, HealTiming, HealTiming>
    with $Provider<HealTiming> {
  const HealTimingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'healTimingProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$healTimingHash();

  @$internal
  @override
  $ProviderElement<HealTiming> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  HealTiming create(Ref ref) {
    return healTiming(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(HealTiming value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<HealTiming>(value),
    );
  }
}

String _$healTimingHash() => r'c64c9b0391f799d323e9d1cff22c6c37b64b8ea2';

/// Counts the app coming back to the foreground (each value a new resume).

@ProviderFor(appResumes)
const appResumesProvider = AppResumesProvider._();

/// Counts the app coming back to the foreground (each value a new resume).

final class AppResumesProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  /// Counts the app coming back to the foreground (each value a new resume).
  const AppResumesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appResumesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appResumesHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return appResumes(ref);
  }
}

String _$appResumesHash() => r'ebcdbb303b188fcc6a52cd00bd80c1e8232ba161';

/// A night protocol 2 game for the rebuilt screens, keyed by game id (the
/// old screens keep [GameNotifier] on protocol 1). The game id comes from
/// `/me/table/` (`tableScreenProvider`), so a new deal replaces this game.
///
/// Server state in: `/me/` fetches go out one at a time (a request made
/// while one is out runs once after it), each numbered; a reply older than
/// one applied, or of an earlier stage, is dropped. Socket events only ask
/// for a fetch or update a value `/me/` holds in the same form ([GameEvent]);
/// reconnect, resume and the stage's deadline fetch too, so anything missed
/// heals and the screen is a function of fetched state alone.
///
/// Taps out: through the [Outbox], one request per kind in flight, later
/// taps coalescing to the latest, each keyed to its stage (and turn) and
/// dropped when that ends. The shown state is derived from it.

@ProviderFor(ProtocolTwoGameNotifier)
const protocolTwoGameProvider = ProtocolTwoGameNotifierFamily._();

/// A night protocol 2 game for the rebuilt screens, keyed by game id (the
/// old screens keep [GameNotifier] on protocol 1). The game id comes from
/// `/me/table/` (`tableScreenProvider`), so a new deal replaces this game.
///
/// Server state in: `/me/` fetches go out one at a time (a request made
/// while one is out runs once after it), each numbered; a reply older than
/// one applied, or of an earlier stage, is dropped. Socket events only ask
/// for a fetch or update a value `/me/` holds in the same form ([GameEvent]);
/// reconnect, resume and the stage's deadline fetch too, so anything missed
/// heals and the screen is a function of fetched state alone.
///
/// Taps out: through the [Outbox], one request per kind in flight, later
/// taps coalescing to the latest, each keyed to its stage (and turn) and
/// dropped when that ends. The shown state is derived from it.
final class ProtocolTwoGameNotifierProvider
    extends $AsyncNotifierProvider<ProtocolTwoGameNotifier, ProtocolTwoGame> {
  /// A night protocol 2 game for the rebuilt screens, keyed by game id (the
  /// old screens keep [GameNotifier] on protocol 1). The game id comes from
  /// `/me/table/` (`tableScreenProvider`), so a new deal replaces this game.
  ///
  /// Server state in: `/me/` fetches go out one at a time (a request made
  /// while one is out runs once after it), each numbered; a reply older than
  /// one applied, or of an earlier stage, is dropped. Socket events only ask
  /// for a fetch or update a value `/me/` holds in the same form ([GameEvent]);
  /// reconnect, resume and the stage's deadline fetch too, so anything missed
  /// heals and the screen is a function of fetched state alone.
  ///
  /// Taps out: through the [Outbox], one request per kind in flight, later
  /// taps coalescing to the latest, each keyed to its stage (and turn) and
  /// dropped when that ends. The shown state is derived from it.
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
    r'8c908891efe3c3a7138d86168c2c4c56bb46182f';

/// A night protocol 2 game for the rebuilt screens, keyed by game id (the
/// old screens keep [GameNotifier] on protocol 1). The game id comes from
/// `/me/table/` (`tableScreenProvider`), so a new deal replaces this game.
///
/// Server state in: `/me/` fetches go out one at a time (a request made
/// while one is out runs once after it), each numbered; a reply older than
/// one applied, or of an earlier stage, is dropped. Socket events only ask
/// for a fetch or update a value `/me/` holds in the same form ([GameEvent]);
/// reconnect, resume and the stage's deadline fetch too, so anything missed
/// heals and the screen is a function of fetched state alone.
///
/// Taps out: through the [Outbox], one request per kind in flight, later
/// taps coalescing to the latest, each keyed to its stage (and turn) and
/// dropped when that ends. The shown state is derived from it.

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
  /// old screens keep [GameNotifier] on protocol 1). The game id comes from
  /// `/me/table/` (`tableScreenProvider`), so a new deal replaces this game.
  ///
  /// Server state in: `/me/` fetches go out one at a time (a request made
  /// while one is out runs once after it), each numbered; a reply older than
  /// one applied, or of an earlier stage, is dropped. Socket events only ask
  /// for a fetch or update a value `/me/` holds in the same form ([GameEvent]);
  /// reconnect, resume and the stage's deadline fetch too, so anything missed
  /// heals and the screen is a function of fetched state alone.
  ///
  /// Taps out: through the [Outbox], one request per kind in flight, later
  /// taps coalescing to the latest, each keyed to its stage (and turn) and
  /// dropped when that ends. The shown state is derived from it.

  ProtocolTwoGameNotifierProvider call(String gameId) =>
      ProtocolTwoGameNotifierProvider._(argument: gameId, from: this);

  @override
  String toString() => r'protocolTwoGameProvider';
}

/// A night protocol 2 game for the rebuilt screens, keyed by game id (the
/// old screens keep [GameNotifier] on protocol 1). The game id comes from
/// `/me/table/` (`tableScreenProvider`), so a new deal replaces this game.
///
/// Server state in: `/me/` fetches go out one at a time (a request made
/// while one is out runs once after it), each numbered; a reply older than
/// one applied, or of an earlier stage, is dropped. Socket events only ask
/// for a fetch or update a value `/me/` holds in the same form ([GameEvent]);
/// reconnect, resume and the stage's deadline fetch too, so anything missed
/// heals and the screen is a function of fetched state alone.
///
/// Taps out: through the [Outbox], one request per kind in flight, later
/// taps coalescing to the latest, each keyed to its stage (and turn) and
/// dropped when that ends. The shown state is derived from it.

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
