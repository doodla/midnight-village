// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tab_storage_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// This tab's own storage (`TabStorage`); a test overrides it with memory.

@ProviderFor(tabStorage)
const tabStorageProvider = TabStorageProvider._();

/// This tab's own storage (`TabStorage`); a test overrides it with memory.

final class TabStorageProvider
    extends $FunctionalProvider<TabStorage, TabStorage, TabStorage>
    with $Provider<TabStorage> {
  /// This tab's own storage (`TabStorage`); a test overrides it with memory.
  const TabStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tabStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tabStorageHash();

  @$internal
  @override
  $ProviderElement<TabStorage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TabStorage create(Ref ref) {
    return tabStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TabStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TabStorage>(value),
    );
  }
}

String _$tabStorageHash() => r'96ff699291bd74f9864bc4c824453603edf5644f';
