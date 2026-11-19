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

/// The skin chosen on this device: Shadow paper until the saved choice has
/// been read, then the saved one. A choice made before the saved one is read
/// wins over it.

@ProviderFor(SkinChoice)
const skinChoiceProvider = SkinChoiceProvider._();

/// The skin chosen on this device: Shadow paper until the saved choice has
/// been read, then the saved one. A choice made before the saved one is read
/// wins over it.
final class SkinChoiceProvider extends $NotifierProvider<SkinChoice, SkinId> {
  /// The skin chosen on this device: Shadow paper until the saved choice has
  /// been read, then the saved one. A choice made before the saved one is read
  /// wins over it.
  const SkinChoiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'skinChoiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$skinChoiceHash();

  @$internal
  @override
  SkinChoice create() => SkinChoice();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SkinId value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SkinId>(value),
    );
  }
}

String _$skinChoiceHash() => r'6673fb4ec064eec666f83e0441791eb64a1de2b5';

/// The skin chosen on this device: Shadow paper until the saved choice has
/// been read, then the saved one. A choice made before the saved one is read
/// wins over it.

abstract class _$SkinChoice extends $Notifier<SkinId> {
  SkinId build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<SkinId, SkinId>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SkinId, SkinId>,
              SkinId,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// The app's Material theme, from the chosen skin.

@ProviderFor(appTheme)
const appThemeProvider = AppThemeProvider._();

/// The app's Material theme, from the chosen skin.

final class AppThemeProvider
    extends $FunctionalProvider<ThemeData, ThemeData, ThemeData>
    with $Provider<ThemeData> {
  /// The app's Material theme, from the chosen skin.
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

String _$appThemeHash() => r'40ae0375a0643576a167b748bd73fae50107e10d';
