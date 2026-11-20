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

@ProviderFor(skinLoader)
const skinLoaderProvider = SkinLoaderProvider._();

final class SkinLoaderProvider
    extends $FunctionalProvider<SkinLoader, SkinLoader, SkinLoader>
    with $Provider<SkinLoader> {
  const SkinLoaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'skinLoaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$skinLoaderHash();

  @$internal
  @override
  $ProviderElement<SkinLoader> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SkinLoader create(Ref ref) {
    return skinLoader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SkinLoader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SkinLoader>(value),
    );
  }
}

String _$skinLoaderHash() => r'34d429e8f55f3070c4e6d0cf186e5b632077cb16';

/// The skin the app starts in: the one [restoreSkin] read, else the default.

@ProviderFor(initialSkin)
const initialSkinProvider = InitialSkinProvider._();

/// The skin the app starts in: the one [restoreSkin] read, else the default.

final class InitialSkinProvider
    extends $FunctionalProvider<SkinId, SkinId, SkinId>
    with $Provider<SkinId> {
  /// The skin the app starts in: the one [restoreSkin] read, else the default.
  const InitialSkinProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'initialSkinProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$initialSkinHash();

  @$internal
  @override
  $ProviderElement<SkinId> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SkinId create(Ref ref) {
    return initialSkin(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SkinId value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SkinId>(value),
    );
  }
}

String _$initialSkinHash() => r'abc349df81cdea7693273701108682ee52864990';

/// The skin chosen on this device.

@ProviderFor(SkinChoice)
const skinChoiceProvider = SkinChoiceProvider._();

/// The skin chosen on this device.
final class SkinChoiceProvider extends $NotifierProvider<SkinChoice, SkinId> {
  /// The skin chosen on this device.
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

String _$skinChoiceHash() => r'34b2e9ea193683c0d2a5dc02939f1deef08a142e';

/// The skin chosen on this device.

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
