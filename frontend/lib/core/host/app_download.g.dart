// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_download.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appDownload)
const appDownloadProvider = AppDownloadProvider._();

final class AppDownloadProvider
    extends $FunctionalProvider<AppDownload?, AppDownload?, AppDownload?>
    with $Provider<AppDownload?> {
  const AppDownloadProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDownloadProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDownloadHash();

  @$internal
  @override
  $ProviderElement<AppDownload?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDownload? create(Ref ref) {
    return appDownload(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDownload? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDownload?>(value),
    );
  }
}

String _$appDownloadHash() => r'649b727eb851565b24cefe1e36c5f8c0490b6645';
