// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'code_scanner.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The camera the app uses: `mobile_scanner` (Android and the web). Tests and
/// the screen gallery override this with their own.

@ProviderFor(codeScannerFactory)
const codeScannerFactoryProvider = CodeScannerFactoryProvider._();

/// The camera the app uses: `mobile_scanner` (Android and the web). Tests and
/// the screen gallery override this with their own.

final class CodeScannerFactoryProvider
    extends
        $FunctionalProvider<
          CodeScannerFactory,
          CodeScannerFactory,
          CodeScannerFactory
        >
    with $Provider<CodeScannerFactory> {
  /// The camera the app uses: `mobile_scanner` (Android and the web). Tests and
  /// the screen gallery override this with their own.
  const CodeScannerFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'codeScannerFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$codeScannerFactoryHash();

  @$internal
  @override
  $ProviderElement<CodeScannerFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CodeScannerFactory create(Ref ref) {
    return codeScannerFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CodeScannerFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CodeScannerFactory>(value),
    );
  }
}

String _$codeScannerFactoryHash() =>
    r'15b72e714f1bbe8d43e421c80183a3c83a44b6e1';
