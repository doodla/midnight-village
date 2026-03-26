// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_tokens_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ActiveTheme)
const activeThemeProvider = ActiveThemeProvider._();

final class ActiveThemeProvider
    extends $NotifierProvider<ActiveTheme, AppTokens> {
  const ActiveThemeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeThemeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeThemeHash();

  @$internal
  @override
  ActiveTheme create() => ActiveTheme();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppTokens value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppTokens>(value),
    );
  }
}

String _$activeThemeHash() => r'01fff0b651316dbf600c725ac0753327845580ad';

abstract class _$ActiveTheme extends $Notifier<AppTokens> {
  AppTokens build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AppTokens, AppTokens>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppTokens, AppTokens>,
              AppTokens,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
