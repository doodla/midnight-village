// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the API client.

@ProviderFor(apiClient)
const apiClientProvider = ApiClientProvider._();

/// Provides the API client.

final class ApiClientProvider
    extends $FunctionalProvider<ApiClient, ApiClient, ApiClient>
    with $Provider<ApiClient> {
  /// Provides the API client.
  const ApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apiClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apiClientHash();

  @$internal
  @override
  $ProviderElement<ApiClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ApiClient create(Ref ref) {
    return apiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ApiClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ApiClient>(value),
    );
  }
}

String _$apiClientHash() => r'90c807f03b90249684265cc91739139c2c89eeb9';

/// Provides the token storage: the session's tokens, held in memory once
/// read ([TokenStorage]).

@ProviderFor(tokenStorage)
const tokenStorageProvider = TokenStorageProvider._();

/// Provides the token storage: the session's tokens, held in memory once
/// read ([TokenStorage]).

final class TokenStorageProvider
    extends $FunctionalProvider<TokenStorage, TokenStorage, TokenStorage>
    with $Provider<TokenStorage> {
  /// Provides the token storage: the session's tokens, held in memory once
  /// read ([TokenStorage]).
  const TokenStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tokenStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tokenStorageHash();

  @$internal
  @override
  $ProviderElement<TokenStorage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TokenStorage create(Ref ref) {
    return tokenStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TokenStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TokenStorage>(value),
    );
  }
}

String _$tokenStorageHash() => r'd80620ed4fcc8328583d0e00a6d7a65a5af56056';

/// Provides the user storage.

@ProviderFor(userStorage)
const userStorageProvider = UserStorageProvider._();

/// Provides the user storage.

final class UserStorageProvider
    extends $FunctionalProvider<UserStorage, UserStorage, UserStorage>
    with $Provider<UserStorage> {
  /// Provides the user storage.
  const UserStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userStorageProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userStorageHash();

  @$internal
  @override
  $ProviderElement<UserStorage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UserStorage create(Ref ref) {
    return userStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserStorage>(value),
    );
  }
}

String _$userStorageHash() => r'ee46eb5d1e89c58e6e430d8f0dbfc73d34944924';

/// Provides the auth service.

@ProviderFor(authService)
const authServiceProvider = AuthServiceProvider._();

/// Provides the auth service.

final class AuthServiceProvider
    extends $FunctionalProvider<AuthService, AuthService, AuthService>
    with $Provider<AuthService> {
  /// Provides the auth service.
  const AuthServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authServiceHash();

  @$internal
  @override
  $ProviderElement<AuthService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthService create(Ref ref) {
    return authService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthService>(value),
    );
  }
}

String _$authServiceHash() => r'36a036816d4bcbf1c7e30dce4d5ccfd86fd0fd70';

/// Provides the auth repository.

@ProviderFor(authRepository)
const authRepositoryProvider = AuthRepositoryProvider._();

/// Provides the auth repository.

final class AuthRepositoryProvider
    extends $FunctionalProvider<AuthRepository, AuthRepository, AuthRepository>
    with $Provider<AuthRepository> {
  /// Provides the auth repository.
  const AuthRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authRepositoryHash();

  @$internal
  @override
  $ProviderElement<AuthRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthRepository create(Ref ref) {
    return authRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRepository>(value),
    );
  }
}

String _$authRepositoryHash() => r'833c3aaef5bca9ba35799a3c74f84a55afaa6f2d';

/// Provides the authenticated HTTP client with JWT injection and auto-refresh.
///
/// Uses [AuthInterceptor] to add bearer tokens to every request and handle
/// 401 responses by refreshing the access token. On refresh failure, the
/// interceptor signals auth failure by invalidating [authProvider], which
/// resets auth state to unauthenticated.

@ProviderFor(authenticatedClient)
const authenticatedClientProvider = AuthenticatedClientProvider._();

/// Provides the authenticated HTTP client with JWT injection and auto-refresh.
///
/// Uses [AuthInterceptor] to add bearer tokens to every request and handle
/// 401 responses by refreshing the access token. On refresh failure, the
/// interceptor signals auth failure by invalidating [authProvider], which
/// resets auth state to unauthenticated.

final class AuthenticatedClientProvider
    extends
        $FunctionalProvider<
          AuthenticatedClient,
          AuthenticatedClient,
          AuthenticatedClient
        >
    with $Provider<AuthenticatedClient> {
  /// Provides the authenticated HTTP client with JWT injection and auto-refresh.
  ///
  /// Uses [AuthInterceptor] to add bearer tokens to every request and handle
  /// 401 responses by refreshing the access token. On refresh failure, the
  /// interceptor signals auth failure by invalidating [authProvider], which
  /// resets auth state to unauthenticated.
  const AuthenticatedClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authenticatedClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authenticatedClientHash();

  @$internal
  @override
  $ProviderElement<AuthenticatedClient> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  AuthenticatedClient create(Ref ref) {
    return authenticatedClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthenticatedClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthenticatedClient>(value),
    );
  }
}

String _$authenticatedClientHash() =>
    r'2beb9e2c0819d46ac09a2438cc0a757dfbab0ec3';

/// Manages authentication state.
///
/// The saved account is read back at start ([AuthRepository.tryRestoreSession]:
/// from storage alone while its access token works). A try the server does
/// not answer (no network, a timeout, a 5xx) is made again by itself, with
/// the backoff every healing fetch uses ([HealTiming.retryAfter]), until it
/// answers; meanwhile the state stays [AuthInitial] (`unanswered`), never
/// "signed out", so no screen offers a new account. Only the server refusing
/// the saved account (it is gone) signs out.

@ProviderFor(AuthNotifier)
const authProvider = AuthNotifierProvider._();

/// Manages authentication state.
///
/// The saved account is read back at start ([AuthRepository.tryRestoreSession]:
/// from storage alone while its access token works). A try the server does
/// not answer (no network, a timeout, a 5xx) is made again by itself, with
/// the backoff every healing fetch uses ([HealTiming.retryAfter]), until it
/// answers; meanwhile the state stays [AuthInitial] (`unanswered`), never
/// "signed out", so no screen offers a new account. Only the server refusing
/// the saved account (it is gone) signs out.
final class AuthNotifierProvider
    extends $NotifierProvider<AuthNotifier, AuthState> {
  /// Manages authentication state.
  ///
  /// The saved account is read back at start ([AuthRepository.tryRestoreSession]:
  /// from storage alone while its access token works). A try the server does
  /// not answer (no network, a timeout, a 5xx) is made again by itself, with
  /// the backoff every healing fetch uses ([HealTiming.retryAfter]), until it
  /// answers; meanwhile the state stays [AuthInitial] (`unanswered`), never
  /// "signed out", so no screen offers a new account. Only the server refusing
  /// the saved account (it is gone) signs out.
  const AuthNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authNotifierHash();

  @$internal
  @override
  AuthNotifier create() => AuthNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthState>(value),
    );
  }
}

String _$authNotifierHash() => r'459652c29f6e35d07ec90a8bfd73d095f63c2580';

/// Manages authentication state.
///
/// The saved account is read back at start ([AuthRepository.tryRestoreSession]:
/// from storage alone while its access token works). A try the server does
/// not answer (no network, a timeout, a 5xx) is made again by itself, with
/// the backoff every healing fetch uses ([HealTiming.retryAfter]), until it
/// answers; meanwhile the state stays [AuthInitial] (`unanswered`), never
/// "signed out", so no screen offers a new account. Only the server refusing
/// the saved account (it is gone) signs out.

abstract class _$AuthNotifier extends $Notifier<AuthState> {
  AuthState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AuthState, AuthState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AuthState, AuthState>,
              AuthState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
