// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_router.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Application router with auth redirect guard.
///
/// Redirect rules:
/// - Unauthenticated users on `/lobby/*` or `/game/*` are redirected to `/`.
/// - Authenticated users at `/` with an active game are redirected to
///   `/game/:id` (result is cached; cache is cleared on auth state changes).

@ProviderFor(appRouter)
const appRouterProvider = AppRouterProvider._();

/// Application router with auth redirect guard.
///
/// Redirect rules:
/// - Unauthenticated users on `/lobby/*` or `/game/*` are redirected to `/`.
/// - Authenticated users at `/` with an active game are redirected to
///   `/game/:id` (result is cached; cache is cleared on auth state changes).

final class AppRouterProvider
    extends $FunctionalProvider<GoRouter, GoRouter, GoRouter>
    with $Provider<GoRouter> {
  /// Application router with auth redirect guard.
  ///
  /// Redirect rules:
  /// - Unauthenticated users on `/lobby/*` or `/game/*` are redirected to `/`.
  /// - Authenticated users at `/` with an active game are redirected to
  ///   `/game/:id` (result is cached; cache is cleared on auth state changes).
  const AppRouterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appRouterProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appRouterHash();

  @$internal
  @override
  $ProviderElement<GoRouter> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  GoRouter create(Ref ref) {
    return appRouter(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GoRouter value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GoRouter>(value),
    );
  }
}

String _$appRouterHash() => r'e62b3a352ed708232d10b0831862e8652599f117';
