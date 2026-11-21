// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'healing.dart';

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
        isAutoDispose: false,
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

String _$healTimingHash() => r'646181cf10651d5e6b5bec7417077431dedd1b27';

/// The clock the app compares server deadlines with when the server's own
/// (its `Date` header) cannot be read. Tests set it.

@ProviderFor(clock)
const clockProvider = ClockProvider._();

/// The clock the app compares server deadlines with when the server's own
/// (its `Date` header) cannot be read. Tests set it.

final class ClockProvider
    extends
        $FunctionalProvider<
          DateTime Function(),
          DateTime Function(),
          DateTime Function()
        >
    with $Provider<DateTime Function()> {
  /// The clock the app compares server deadlines with when the server's own
  /// (its `Date` header) cannot be read. Tests set it.
  const ClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clockProvider',
        isAutoDispose: false,
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

String _$clockHash() => r'3f65ad34ac6fcd532de9004042bdf2ed2bd85b13';

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
