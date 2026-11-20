// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'protocol_two_game.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A game for the shell's screens, keyed by game id. The game id comes from
/// `/me/table/` (`tableScreenProvider`), so a new deal replaces this game.
///
/// Server state in: `/me/` fetches go out one at a time (a request made
/// while one is out runs once after it), so a reply can never overtake a
/// newer one. A failed fetch is made again with backoff until one succeeds;
/// socket events only ask for a fetch or update a value `/me/` holds in the
/// same form ([GameEvent]); reconnect, resume and the stage's deadline fetch
/// too. The screen is a function of fetched state alone.
///
/// Taps out: through the [Outbox], one request per kind in flight, later
/// taps coalescing to the latest, each keyed to its stage (and turn) and
/// dropped when that ends. The shown state is derived from it.
///
/// Known and accepted: a request whose answer was lost but which the server
/// processes later can land after a newer tap of the same lane (the latest
/// is resent only after a fetch, but the server orders what it receives);
/// closing that needs a per-phone sequence number on the server.
///
/// Riverpod's own retry is off ([noRetry]): this notifier retries its
/// fetches itself, and a Riverpod rebuild would drop the taps in flight.

@ProviderFor(ProtocolTwoGameNotifier)
const protocolTwoGameProvider = ProtocolTwoGameNotifierFamily._();

/// A game for the shell's screens, keyed by game id. The game id comes from
/// `/me/table/` (`tableScreenProvider`), so a new deal replaces this game.
///
/// Server state in: `/me/` fetches go out one at a time (a request made
/// while one is out runs once after it), so a reply can never overtake a
/// newer one. A failed fetch is made again with backoff until one succeeds;
/// socket events only ask for a fetch or update a value `/me/` holds in the
/// same form ([GameEvent]); reconnect, resume and the stage's deadline fetch
/// too. The screen is a function of fetched state alone.
///
/// Taps out: through the [Outbox], one request per kind in flight, later
/// taps coalescing to the latest, each keyed to its stage (and turn) and
/// dropped when that ends. The shown state is derived from it.
///
/// Known and accepted: a request whose answer was lost but which the server
/// processes later can land after a newer tap of the same lane (the latest
/// is resent only after a fetch, but the server orders what it receives);
/// closing that needs a per-phone sequence number on the server.
///
/// Riverpod's own retry is off ([noRetry]): this notifier retries its
/// fetches itself, and a Riverpod rebuild would drop the taps in flight.
final class ProtocolTwoGameNotifierProvider
    extends $AsyncNotifierProvider<ProtocolTwoGameNotifier, ProtocolTwoGame> {
  /// A game for the shell's screens, keyed by game id. The game id comes from
  /// `/me/table/` (`tableScreenProvider`), so a new deal replaces this game.
  ///
  /// Server state in: `/me/` fetches go out one at a time (a request made
  /// while one is out runs once after it), so a reply can never overtake a
  /// newer one. A failed fetch is made again with backoff until one succeeds;
  /// socket events only ask for a fetch or update a value `/me/` holds in the
  /// same form ([GameEvent]); reconnect, resume and the stage's deadline fetch
  /// too. The screen is a function of fetched state alone.
  ///
  /// Taps out: through the [Outbox], one request per kind in flight, later
  /// taps coalescing to the latest, each keyed to its stage (and turn) and
  /// dropped when that ends. The shown state is derived from it.
  ///
  /// Known and accepted: a request whose answer was lost but which the server
  /// processes later can land after a newer tap of the same lane (the latest
  /// is resent only after a fetch, but the server orders what it receives);
  /// closing that needs a per-phone sequence number on the server.
  ///
  /// Riverpod's own retry is off ([noRetry]): this notifier retries its
  /// fetches itself, and a Riverpod rebuild would drop the taps in flight.
  const ProtocolTwoGameNotifierProvider._({
    required ProtocolTwoGameNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: noRetry,
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
    r'f8d6cafa0487a4f6f69163e922b7e7e842c782da';

/// A game for the shell's screens, keyed by game id. The game id comes from
/// `/me/table/` (`tableScreenProvider`), so a new deal replaces this game.
///
/// Server state in: `/me/` fetches go out one at a time (a request made
/// while one is out runs once after it), so a reply can never overtake a
/// newer one. A failed fetch is made again with backoff until one succeeds;
/// socket events only ask for a fetch or update a value `/me/` holds in the
/// same form ([GameEvent]); reconnect, resume and the stage's deadline fetch
/// too. The screen is a function of fetched state alone.
///
/// Taps out: through the [Outbox], one request per kind in flight, later
/// taps coalescing to the latest, each keyed to its stage (and turn) and
/// dropped when that ends. The shown state is derived from it.
///
/// Known and accepted: a request whose answer was lost but which the server
/// processes later can land after a newer tap of the same lane (the latest
/// is resent only after a fetch, but the server orders what it receives);
/// closing that needs a per-phone sequence number on the server.
///
/// Riverpod's own retry is off ([noRetry]): this notifier retries its
/// fetches itself, and a Riverpod rebuild would drop the taps in flight.

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
        retry: noRetry,
        name: r'protocolTwoGameProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// A game for the shell's screens, keyed by game id. The game id comes from
  /// `/me/table/` (`tableScreenProvider`), so a new deal replaces this game.
  ///
  /// Server state in: `/me/` fetches go out one at a time (a request made
  /// while one is out runs once after it), so a reply can never overtake a
  /// newer one. A failed fetch is made again with backoff until one succeeds;
  /// socket events only ask for a fetch or update a value `/me/` holds in the
  /// same form ([GameEvent]); reconnect, resume and the stage's deadline fetch
  /// too. The screen is a function of fetched state alone.
  ///
  /// Taps out: through the [Outbox], one request per kind in flight, later
  /// taps coalescing to the latest, each keyed to its stage (and turn) and
  /// dropped when that ends. The shown state is derived from it.
  ///
  /// Known and accepted: a request whose answer was lost but which the server
  /// processes later can land after a newer tap of the same lane (the latest
  /// is resent only after a fetch, but the server orders what it receives);
  /// closing that needs a per-phone sequence number on the server.
  ///
  /// Riverpod's own retry is off ([noRetry]): this notifier retries its
  /// fetches itself, and a Riverpod rebuild would drop the taps in flight.

  ProtocolTwoGameNotifierProvider call(String gameId) =>
      ProtocolTwoGameNotifierProvider._(argument: gameId, from: this);

  @override
  String toString() => r'protocolTwoGameProvider';
}

/// A game for the shell's screens, keyed by game id. The game id comes from
/// `/me/table/` (`tableScreenProvider`), so a new deal replaces this game.
///
/// Server state in: `/me/` fetches go out one at a time (a request made
/// while one is out runs once after it), so a reply can never overtake a
/// newer one. A failed fetch is made again with backoff until one succeeds;
/// socket events only ask for a fetch or update a value `/me/` holds in the
/// same form ([GameEvent]); reconnect, resume and the stage's deadline fetch
/// too. The screen is a function of fetched state alone.
///
/// Taps out: through the [Outbox], one request per kind in flight, later
/// taps coalescing to the latest, each keyed to its stage (and turn) and
/// dropped when that ends. The shown state is derived from it.
///
/// Known and accepted: a request whose answer was lost but which the server
/// processes later can land after a newer tap of the same lane (the latest
/// is resent only after a fetch, but the server orders what it receives);
/// closing that needs a per-phone sequence number on the server.
///
/// Riverpod's own retry is off ([noRetry]): this notifier retries its
/// fetches itself, and a Riverpod rebuild would drop the taps in flight.

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
