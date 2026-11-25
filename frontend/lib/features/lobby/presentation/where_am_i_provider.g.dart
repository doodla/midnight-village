// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'where_am_i_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where this player sits (`GET /me/table/`): the first fetch of a cold
/// start, fetched again (invalidated) when the table may have moved on (a
/// phase change, play again, a host change, leave, reconnect, a lobby that
/// says its table is in a game this phone was not told of). Coming back to
/// the app reads it again at once, whatever the screen: an event missed
/// while the phone slept is healed by that one read. A failed fetch is
/// retried until it succeeds ([retryForever]). At a waiting table or a
/// finished game, where only an event would say the table moved on, it is
/// also polled slowly ([HealTiming.tablePoll]): the backstop, never the way
/// a missed event heals; a poll that brings the same answer is not a new
/// state (nothing is told, so nothing is drawn). Null: at no table. Every answer is kept on the
/// device as the last seat ([LastSeat]).
///
/// A read asked for right after the server said where this player sits (an
/// answer: a table started or joined, a deal, play again; or an event:
/// `game_started`, `play_again`) takes that seat ([SeatSeed]) and sends
/// nothing: the server has said it already.

@ProviderFor(myTable)
const myTableProvider = MyTableProvider._();

/// Where this player sits (`GET /me/table/`): the first fetch of a cold
/// start, fetched again (invalidated) when the table may have moved on (a
/// phase change, play again, a host change, leave, reconnect, a lobby that
/// says its table is in a game this phone was not told of). Coming back to
/// the app reads it again at once, whatever the screen: an event missed
/// while the phone slept is healed by that one read. A failed fetch is
/// retried until it succeeds ([retryForever]). At a waiting table or a
/// finished game, where only an event would say the table moved on, it is
/// also polled slowly ([HealTiming.tablePoll]): the backstop, never the way
/// a missed event heals; a poll that brings the same answer is not a new
/// state (nothing is told, so nothing is drawn). Null: at no table. Every answer is kept on the
/// device as the last seat ([LastSeat]).
///
/// A read asked for right after the server said where this player sits (an
/// answer: a table started or joined, a deal, play again; or an event:
/// `game_started`, `play_again`) takes that seat ([SeatSeed]) and sends
/// nothing: the server has said it already.

final class MyTableProvider
    extends
        $FunctionalProvider<AsyncValue<MyTable?>, MyTable?, FutureOr<MyTable?>>
    with $FutureModifier<MyTable?>, $FutureProvider<MyTable?> {
  /// Where this player sits (`GET /me/table/`): the first fetch of a cold
  /// start, fetched again (invalidated) when the table may have moved on (a
  /// phase change, play again, a host change, leave, reconnect, a lobby that
  /// says its table is in a game this phone was not told of). Coming back to
  /// the app reads it again at once, whatever the screen: an event missed
  /// while the phone slept is healed by that one read. A failed fetch is
  /// retried until it succeeds ([retryForever]). At a waiting table or a
  /// finished game, where only an event would say the table moved on, it is
  /// also polled slowly ([HealTiming.tablePoll]): the backstop, never the way
  /// a missed event heals; a poll that brings the same answer is not a new
  /// state (nothing is told, so nothing is drawn). Null: at no table. Every answer is kept on the
  /// device as the last seat ([LastSeat]).
  ///
  /// A read asked for right after the server said where this player sits (an
  /// answer: a table started or joined, a deal, play again; or an event:
  /// `game_started`, `play_again`) takes that seat ([SeatSeed]) and sends
  /// nothing: the server has said it already.
  const MyTableProvider._()
    : super(
        from: null,
        argument: null,
        retry: retryForever,
        name: r'myTableProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$myTableHash();

  @$internal
  @override
  $FutureProviderElement<MyTable?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<MyTable?> create(Ref ref) {
    return myTable(ref);
  }
}

String _$myTableHash() => r'4348ad4e9a72312c1a6232b6dabd717fa22787e2';

@ProviderFor(seatSeed)
const seatSeedProvider = SeatSeedProvider._();

final class SeatSeedProvider
    extends $FunctionalProvider<SeatSeed, SeatSeed, SeatSeed>
    with $Provider<SeatSeed> {
  const SeatSeedProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'seatSeedProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$seatSeedHash();

  @$internal
  @override
  $ProviderElement<SeatSeed> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SeatSeed create(Ref ref) {
    return seatSeed(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SeatSeed value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SeatSeed>(value),
    );
  }
}

String _$seatSeedHash() => r'6a371c8d3c88ed4aaaf838bd42cea21cfe2101ac';
