// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'where_am_i_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Where this player sits (`GET /me/table/`): the first fetch of a cold
/// start, fetched again (invalidated) when the table may have moved on (a
/// phase change, play again, a host change, leave, reconnect, resume). A
/// failed fetch is retried until it succeeds ([retryForever]). At a waiting
/// table or a finished game, where only an event would say the table moved
/// on, it is also polled slowly ([HealTiming.tablePoll]). Null: at no table.

@ProviderFor(myTable)
const myTableProvider = MyTableProvider._();

/// Where this player sits (`GET /me/table/`): the first fetch of a cold
/// start, fetched again (invalidated) when the table may have moved on (a
/// phase change, play again, a host change, leave, reconnect, resume). A
/// failed fetch is retried until it succeeds ([retryForever]). At a waiting
/// table or a finished game, where only an event would say the table moved
/// on, it is also polled slowly ([HealTiming.tablePoll]). Null: at no table.

final class MyTableProvider
    extends
        $FunctionalProvider<AsyncValue<MyTable?>, MyTable?, FutureOr<MyTable?>>
    with $FutureModifier<MyTable?>, $FutureProvider<MyTable?> {
  /// Where this player sits (`GET /me/table/`): the first fetch of a cold
  /// start, fetched again (invalidated) when the table may have moved on (a
  /// phase change, play again, a host change, leave, reconnect, resume). A
  /// failed fetch is retried until it succeeds ([retryForever]). At a waiting
  /// table or a finished game, where only an event would say the table moved
  /// on, it is also polled slowly ([HealTiming.tablePoll]). Null: at no table.
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

String _$myTableHash() => r'ab08f68aa2c1371fd5dc6dc6860cbc326a535a74';
