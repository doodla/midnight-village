// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skin_choice.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(devicePreferences)
const devicePreferencesProvider = DevicePreferencesProvider._();

final class DevicePreferencesProvider
    extends
        $FunctionalProvider<
          DevicePreferences,
          DevicePreferences,
          DevicePreferences
        >
    with $Provider<DevicePreferences> {
  const DevicePreferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devicePreferencesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devicePreferencesHash();

  @$internal
  @override
  $ProviderElement<DevicePreferences> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DevicePreferences create(Ref ref) {
    return devicePreferences(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DevicePreferences value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DevicePreferences>(value),
    );
  }
}

String _$devicePreferencesHash() => r'e563ed37adaae5fb4703086c62aaf296483ff934';

/// The app's Material theme, from the skin. There is one look
/// ([SkinId.fallback]); a future look is a separate design, not a switch.

@ProviderFor(appTheme)
const appThemeProvider = AppThemeProvider._();

/// The app's Material theme, from the skin. There is one look
/// ([SkinId.fallback]); a future look is a separate design, not a switch.

final class AppThemeProvider
    extends $FunctionalProvider<ThemeData, ThemeData, ThemeData>
    with $Provider<ThemeData> {
  /// The app's Material theme, from the skin. There is one look
  /// ([SkinId.fallback]); a future look is a separate design, not a switch.
  const AppThemeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appThemeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appThemeHash();

  @$internal
  @override
  $ProviderElement<ThemeData> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ThemeData create(Ref ref) {
    return appTheme(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeData value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeData>(value),
    );
  }
}

String _$appThemeHash() => r'd18767f52669c78876fa512f8b4ff32ccc0d375b';
