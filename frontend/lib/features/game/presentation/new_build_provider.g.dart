// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'new_build_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// This build's commit (`BuildId.mine`). A test says which build the app is.

@ProviderFor(buildId)
const buildIdProvider = BuildIdProvider._();

/// This build's commit (`BuildId.mine`). A test says which build the app is.

final class BuildIdProvider extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// This build's commit (`BuildId.mine`). A test says which build the app is.
  const BuildIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'buildIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$buildIdHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return buildId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$buildIdHash() => r'f357712a35958b5ed74cdeced6d1b3eb7ee42aac';

/// The commit the live site was built from, or null when it cannot be read.

@ProviderFor(liveBuildFetch)
const liveBuildFetchProvider = LiveBuildFetchProvider._();

/// The commit the live site was built from, or null when it cannot be read.

final class LiveBuildFetchProvider
    extends
        $FunctionalProvider<
          Future<String?> Function(),
          Future<String?> Function(),
          Future<String?> Function()
        >
    with $Provider<Future<String?> Function()> {
  /// The commit the live site was built from, or null when it cannot be read.
  const LiveBuildFetchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'liveBuildFetchProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$liveBuildFetchHash();

  @$internal
  @override
  $ProviderElement<Future<String?> Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Future<String?> Function() create(Ref ref) {
    return liveBuildFetch(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Future<String?> Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Future<String?> Function()>(value),
    );
  }
}

String _$liveBuildFetchHash() => r'3df37d10a33da48cdaae39add7ccc871031729f3';

/// Brings the page's service worker up to date before a reload; false when it
/// could not. A test says how it goes.

@ProviderFor(workerRenewal)
const workerRenewalProvider = WorkerRenewalProvider._();

/// Brings the page's service worker up to date before a reload; false when it
/// could not. A test says how it goes.

final class WorkerRenewalProvider
    extends
        $FunctionalProvider<
          Future<bool> Function(),
          Future<bool> Function(),
          Future<bool> Function()
        >
    with $Provider<Future<bool> Function()> {
  /// Brings the page's service worker up to date before a reload; false when it
  /// could not. A test says how it goes.
  const WorkerRenewalProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workerRenewalProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workerRenewalHash();

  @$internal
  @override
  $ProviderElement<Future<bool> Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Future<bool> Function() create(Ref ref) {
    return workerRenewal(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Future<bool> Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Future<bool> Function()>(value),
    );
  }
}

String _$workerRenewalHash() => r'0ce5e7db2102a4f314961877cb33f9100f63bc15';

/// Reloads the page. A test counts reloads instead.

@ProviderFor(pageReload)
const pageReloadProvider = PageReloadProvider._();

/// Reloads the page. A test counts reloads instead.

final class PageReloadProvider
    extends
        $FunctionalProvider<
          Future<void> Function(),
          Future<void> Function(),
          Future<void> Function()
        >
    with $Provider<Future<void> Function()> {
  /// Reloads the page. A test counts reloads instead.
  const PageReloadProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pageReloadProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pageReloadHash();

  @$internal
  @override
  $ProviderElement<Future<void> Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Future<void> Function() create(Ref ref) {
    return pageReload(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Future<void> Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Future<void> Function()>(value),
    );
  }
}

String _$pageReloadHash() => r'2ecda1181f7f70fc6e25676289d5bd20d2f824d0';

/// The clock `NewBuild` measures how long the tab was away by (the healing
/// clock; a test moves its own).

@ProviderFor(newBuildClock)
const newBuildClockProvider = NewBuildClockProvider._();

/// The clock `NewBuild` measures how long the tab was away by (the healing
/// clock; a test moves its own).

final class NewBuildClockProvider
    extends
        $FunctionalProvider<
          DateTime Function(),
          DateTime Function(),
          DateTime Function()
        >
    with $Provider<DateTime Function()> {
  /// The clock `NewBuild` measures how long the tab was away by (the healing
  /// clock; a test moves its own).
  const NewBuildClockProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'newBuildClockProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$newBuildClockHash();

  @$internal
  @override
  $ProviderElement<DateTime Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DateTime Function() create(Ref ref) {
    return newBuildClock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime Function()>(value),
    );
  }
}

String _$newBuildClockHash() => r'43d5584d2c7279349d754f567e71648521f70fb9';

/// The app learning of a newer build and renewing itself at a safe moment
/// (`NewBuild`, `mayReloadNow`). Null where there is nothing to renew: a
/// local run, a test, the installed app. Started by `App`.

@ProviderFor(newBuild)
const newBuildProvider = NewBuildProvider._();

/// The app learning of a newer build and renewing itself at a safe moment
/// (`NewBuild`, `mayReloadNow`). Null where there is nothing to renew: a
/// local run, a test, the installed app. Started by `App`.

final class NewBuildProvider
    extends $FunctionalProvider<NewBuild?, NewBuild?, NewBuild?>
    with $Provider<NewBuild?> {
  /// The app learning of a newer build and renewing itself at a safe moment
  /// (`NewBuild`, `mayReloadNow`). Null where there is nothing to renew: a
  /// local run, a test, the installed app. Started by `App`.
  const NewBuildProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'newBuildProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$newBuildHash();

  @$internal
  @override
  $ProviderElement<NewBuild?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NewBuild? create(Ref ref) {
    return newBuild(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NewBuild? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NewBuild?>(value),
    );
  }
}

String _$newBuildHash() => r'8417ad81ef6a170a74a6e029c5f62355819a13cc';
