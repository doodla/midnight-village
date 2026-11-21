// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'table_screen.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LocalStepsNotifier)
const localStepsProvider = LocalStepsNotifierProvider._();

final class LocalStepsNotifierProvider
    extends $NotifierProvider<LocalStepsNotifier, StepRecord> {
  const LocalStepsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localStepsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localStepsNotifierHash();

  @$internal
  @override
  LocalStepsNotifier create() => LocalStepsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(StepRecord value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<StepRecord>(value),
    );
  }
}

String _$localStepsNotifierHash() =>
    r'd1d172100dcbe0d922c2450076a11901f88f09ae';

abstract class _$LocalStepsNotifier extends $Notifier<StepRecord> {
  StepRecord build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<StepRecord, StepRecord>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<StepRecord, StepRecord>,
              StepRecord,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// The one screen for this phone: `/me/table/` names the table and its game
/// (so a new deal replaces the old game), that game's `/me/` refines it, and
/// the local steps are applied ([screenFor]). While either is fetched again
/// the values held are used, so the screen never drops to loading or an
/// error while there is something to show. A game that is gone is 01.

@ProviderFor(tableScreen)
const tableScreenProvider = TableScreenProvider._();

/// The one screen for this phone: `/me/table/` names the table and its game
/// (so a new deal replaces the old game), that game's `/me/` refines it, and
/// the local steps are applied ([screenFor]). While either is fetched again
/// the values held are used, so the screen never drops to loading or an
/// error while there is something to show. A game that is gone is 01.

final class TableScreenProvider
    extends
        $FunctionalProvider<
          AsyncValue<TableScreen>,
          AsyncValue<TableScreen>,
          AsyncValue<TableScreen>
        >
    with $Provider<AsyncValue<TableScreen>> {
  /// The one screen for this phone: `/me/table/` names the table and its game
  /// (so a new deal replaces the old game), that game's `/me/` refines it, and
  /// the local steps are applied ([screenFor]). While either is fetched again
  /// the values held are used, so the screen never drops to loading or an
  /// error while there is something to show. A game that is gone is 01.
  const TableScreenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tableScreenProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tableScreenHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<TableScreen>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AsyncValue<TableScreen> create(Ref ref) {
    return tableScreen(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<TableScreen> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<TableScreen>>(value),
    );
  }
}

String _$tableScreenHash() => r'dacb1c3c288c292b18a2675ca634e1d9fee630f7';
