// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'where_am_i_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where this player sits (`GET /me/table/`): the first fetch of a cold
/// start, and fetched again (invalidated) when the table moves on (play
/// again, leave). Null: at no table.

@ProviderFor(myTable)
const myTableProvider = MyTableProvider._();

/// Where this player sits (`GET /me/table/`): the first fetch of a cold
/// start, and fetched again (invalidated) when the table moves on (play
/// again, leave). Null: at no table.

final class MyTableProvider
    extends
        $FunctionalProvider<AsyncValue<MyTable?>, MyTable?, FutureOr<MyTable?>>
    with $FutureModifier<MyTable?>, $FutureProvider<MyTable?> {
  /// Where this player sits (`GET /me/table/`): the first fetch of a cold
  /// start, and fetched again (invalidated) when the table moves on (play
  /// again, leave). Null: at no table.
  const MyTableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
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

String _$myTableHash() => r'6f765438a6023d9b091f531465407b7c1dd1cf9d';

/// The clock the app compares server deadlines with. Tests set it.

@ProviderFor(clock)
const clockProvider = ClockProvider._();

/// The clock the app compares server deadlines with. Tests set it.

final class ClockProvider
    extends
        $FunctionalProvider<
          DateTime Function(),
          DateTime Function(),
          DateTime Function()
        >
    with $Provider<DateTime Function()> {
  /// The clock the app compares server deadlines with. Tests set it.
  const ClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clockProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clockHash();

  @$internal
  @override
  $ProviderElement<DateTime Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DateTime Function() create(Ref ref) {
    return clock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime Function()>(value),
    );
  }
}

String _$clockHash() => r'3b571c5a0c08b7391c0eed04391003191bab6ccf';
