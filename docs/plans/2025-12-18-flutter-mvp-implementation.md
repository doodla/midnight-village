# Flutter MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a Flutter app that validates all architectural patterns through a single-screen guest authentication flow.

**Architecture:** Feature-first hybrid structure with shared core. Guest auth creates anonymous accounts with auto-generated display names. Riverpod 3.x with code generation manages state. Token storage uses flutter_secure_storage for persistence.

**Tech Stack:** Flutter 3.x, Riverpod 3.x (code gen), go_router, Dio, Freezed, flutter_secure_storage

---

## Prerequisites

Before starting, ensure you have:
- Flutter SDK installed (`flutter --version`)
- Backend running at `http://localhost:8000` (run `just dev` from repo root)

---

## Task 1: Create Flutter Project

**Files:**
- Create: `frontend/` (entire Flutter project structure)

**Step 1: Create Flutter project**

Run from repository root:
```bash
cd /Users/doodla/Code/midnight-village
flutter create frontend --org com.midnightvillage --project-name midnight_village --platforms=web,ios,android
```

**Step 2: Verify project created**

Run:
```bash
ls frontend/lib/main.dart
```
Expected: File exists

**Step 3: Test default app runs**

Run:
```bash
cd frontend && flutter run -d chrome --web-port=3000
```
Expected: Default Flutter counter app appears in browser

Press `q` to quit.

**Step 4: Commit**

```bash
git add frontend/
git commit -m "chore: scaffold Flutter project"
```

---

## Task 2: Configure Dependencies

**Files:**
- Modify: `frontend/pubspec.yaml`

**Step 1: Replace pubspec.yaml content**

Replace entire `frontend/pubspec.yaml` with:

```yaml
name: midnight_village
description: Companion app for Midnight Village - One Night Ultimate Werewolf digital assistant.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.5.0

dependencies:
  flutter:
    sdk: flutter

  # State management - Riverpod 3.x with code generation
  flutter_riverpod: ^3.0.0-dev.3
  riverpod_annotation: ^3.0.0-dev.3

  # Routing - type-safe
  go_router: ^14.6.2

  # Networking
  dio: ^5.7.0

  # Storage
  flutter_secure_storage: ^9.2.2

  # Data classes
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0

  # Logging
  logger: ^2.5.0

dev_dependencies:
  flutter_test:
    sdk: flutter

  # Code generation
  build_runner: ^2.4.13
  riverpod_generator: ^3.0.0-dev.11
  freezed: ^2.5.7
  json_serializable: ^6.9.0
  go_router_builder: ^2.7.1

  # Testing
  mocktail: ^1.0.4

  # Linting
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
```

**Step 2: Install dependencies**

Run:
```bash
cd frontend && flutter pub get
```
Expected: "Got dependencies!" or similar success message

**Step 3: Commit**

```bash
git add frontend/pubspec.yaml frontend/pubspec.lock
git commit -m "chore: configure Flutter dependencies"
```

---

## Task 3: Create Environment Configuration

**Files:**
- Create: `frontend/lib/core/config/env.dart`

**Step 1: Create directory structure**

Run:
```bash
mkdir -p frontend/lib/core/config
```

**Step 2: Create env.dart**

Create `frontend/lib/core/config/env.dart`:

```dart
/// Environment configuration.
///
/// Dev defaults with prod override via `--dart-define=ENV=prod`.
class Env {
  Env._();

  static const String _env = String.fromEnvironment('ENV', defaultValue: 'dev');

  static bool get isDev => _env == 'dev';
  static bool get isProd => _env == 'prod';

  static String get apiUrl => switch (_env) {
        'prod' => 'https://TODO_PROD_DOMAIN/api',
        _ => 'http://localhost:8000/api',
      };
}
```

**Step 3: Verify file created**

Run:
```bash
cat frontend/lib/core/config/env.dart
```
Expected: File contents displayed

**Step 4: Commit**

```bash
git add frontend/lib/core/config/
git commit -m "feat: add environment configuration"
```

---

## Task 4: Create Logger

**Files:**
- Create: `frontend/lib/core/logging/app_logger.dart`

**Step 1: Create directory**

Run:
```bash
mkdir -p frontend/lib/core/logging
```

**Step 2: Create app_logger.dart**

Create `frontend/lib/core/logging/app_logger.dart`:

```dart
import 'package:logger/logger.dart';

import '../config/env.dart';

/// Global application logger.
///
/// Log levels filtered by environment:
/// - Dev: debug and above
/// - Prod: warning and above
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: Env.isDev,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
  level: Env.isDev ? Level.debug : Level.warning,
);
```

**Step 3: Commit**

```bash
git add frontend/lib/core/logging/
git commit -m "feat: add structured logger"
```

---

## Task 5: Create API Exception Types

**Files:**
- Create: `frontend/lib/core/api/api_exception.dart`

**Step 1: Create directory**

Run:
```bash
mkdir -p frontend/lib/core/api
```

**Step 2: Create api_exception.dart**

Create `frontend/lib/core/api/api_exception.dart`:

```dart
import 'package:dio/dio.dart';

/// Base class for API errors.
sealed class ApiException implements Exception {
  const ApiException();
}

/// Network connectivity error.
class NetworkException extends ApiException {
  const NetworkException(this.message);
  final String message;

  @override
  String toString() => 'NetworkException: $message';
}

/// Server returned 401 Unauthorized.
class UnauthorizedException extends ApiException {
  const UnauthorizedException();

  @override
  String toString() => 'UnauthorizedException';
}

/// Server returned 404 Not Found.
class NotFoundException extends ApiException {
  const NotFoundException(this.resource);
  final String resource;

  @override
  String toString() => 'NotFoundException: $resource';
}

/// Server returned 400 with validation errors.
class ValidationException extends ApiException {
  const ValidationException(this.errors);
  final Map<String, List<String>> errors;

  @override
  String toString() => 'ValidationException: $errors';
}

/// Server returned 5xx error.
class ServerException extends ApiException {
  const ServerException(this.statusCode);
  final int statusCode;

  @override
  String toString() => 'ServerException: $statusCode';
}

/// Maps Dio exceptions to typed API exceptions.
ApiException mapDioException(DioException e) {
  final statusCode = e.response?.statusCode;

  if (e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout) {
    return NetworkException(e.message ?? 'Connection failed');
  }

  return switch (statusCode) {
    401 => const UnauthorizedException(),
    404 => NotFoundException(e.requestOptions.path),
    400 => ValidationException(_parseValidationErrors(e.response?.data)),
    >= 500 => ServerException(statusCode!),
    _ => NetworkException(e.message ?? 'Unknown error'),
  };
}

Map<String, List<String>> _parseValidationErrors(dynamic data) {
  if (data is! Map<String, dynamic>) return {};

  final errors = <String, List<String>>{};
  data.forEach((key, value) {
    if (value is List) {
      errors[key] = value.map((e) => e.toString()).toList();
    } else if (value is String) {
      errors[key] = [value];
    }
  });
  return errors;
}
```

**Step 3: Commit**

```bash
git add frontend/lib/core/api/
git commit -m "feat: add typed API exceptions"
```

---

## Task 6: Create Logging Interceptor

**Files:**
- Create: `frontend/lib/core/api/logging_interceptor.dart`

**Step 1: Create logging_interceptor.dart**

Create `frontend/lib/core/api/logging_interceptor.dart`:

```dart
import 'package:dio/dio.dart';

import '../logging/app_logger.dart';

/// Dio interceptor that logs HTTP requests and responses.
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    logger.d('→ ${options.method} ${options.path}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    logger.d('← ${response.statusCode} ${response.requestOptions.path}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    logger.e(
      '✕ ${err.requestOptions.method} ${err.requestOptions.path}',
      error: err,
    );
    handler.next(err);
  }
}
```

**Step 2: Commit**

```bash
git add frontend/lib/core/api/logging_interceptor.dart
git commit -m "feat: add HTTP logging interceptor"
```

---

## Task 7: Create API Client

**Files:**
- Create: `frontend/lib/core/api/api_client.dart`

**Step 1: Create api_client.dart**

Create `frontend/lib/core/api/api_client.dart`:

```dart
import 'package:dio/dio.dart';

import '../config/env.dart';
import 'logging_interceptor.dart';

/// Low-level HTTP client wrapper around Dio.
///
/// No authentication - used for public endpoints like guest registration.
class ApiClient {
  ApiClient({String? baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? Env.apiUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ) {
    if (Env.isDev) {
      _dio.interceptors.add(LoggingInterceptor());
    }
  }

  final Dio _dio;

  Future<Response<T>> get<T>(String path) => _dio.get<T>(path);

  Future<Response<T>> post<T>(String path, {Object? data}) =>
      _dio.post<T>(path, data: data);
}
```

**Step 2: Commit**

```bash
git add frontend/lib/core/api/api_client.dart
git commit -m "feat: add base API client"
```

---

## Task 8: Create Token Storage

**Files:**
- Create: `frontend/lib/core/storage/token_storage.dart`

**Step 1: Create directory**

Run:
```bash
mkdir -p frontend/lib/core/storage
```

**Step 2: Create token_storage.dart**

Create `frontend/lib/core/storage/token_storage.dart`:

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage wrapper for JWT tokens.
///
/// Uses platform-specific secure storage (Keychain on iOS, EncryptedSharedPreferences on Android).
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  final FlutterSecureStorage _storage;

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  Future<String?> get accessToken => _storage.read(key: _accessTokenKey);

  Future<String?> get refreshToken => _storage.read(key: _refreshTokenKey);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _storage.write(key: _accessTokenKey, value: accessToken),
      _storage.write(key: _refreshTokenKey, value: refreshToken),
    ]);
  }

  Future<void> deleteTokens() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
    ]);
  }

  Future<bool> get hasTokens async {
    final access = await accessToken;
    return access != null && access.isNotEmpty;
  }
}
```

**Step 3: Commit**

```bash
git add frontend/lib/core/storage/
git commit -m "feat: add secure token storage"
```

---

## Task 9: Create User Model

**Files:**
- Create: `frontend/lib/features/auth/domain/user.dart`

**Step 1: Create directory structure**

Run:
```bash
mkdir -p frontend/lib/features/auth/domain
```

**Step 2: Create user.dart**

Create `frontend/lib/features/auth/domain/user.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// User model representing an authenticated user.
@freezed
class User with _$User {
  const factory User({
    required int id,
    @JsonKey(name: 'display_name') required String displayName,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```

**Step 3: Run code generation**

Run:
```bash
cd frontend && dart run build_runner build --delete-conflicting-outputs
```
Expected: Build completed successfully, generates `user.freezed.dart` and `user.g.dart`

**Step 4: Verify generated files**

Run:
```bash
ls frontend/lib/features/auth/domain/
```
Expected: `user.dart`, `user.freezed.dart`, `user.g.dart`

**Step 5: Commit**

```bash
git add frontend/lib/features/auth/domain/
git commit -m "feat: add User model with Freezed"
```

---

## Task 10: Create Auth State

**Files:**
- Create: `frontend/lib/features/auth/domain/auth_state.dart`

**Step 1: Create auth_state.dart**

Create `frontend/lib/features/auth/domain/auth_state.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

import 'user.dart';

part 'auth_state.freezed.dart';

/// Authentication state machine.
///
/// States:
/// - [AuthInitial]: App just launched, checking stored tokens
/// - [AuthLoading]: Authentication in progress
/// - [AuthAuthenticated]: User is authenticated
/// - [AuthUnauthenticated]: No valid tokens, show welcome screen
/// - [AuthError]: Authentication failed with error
@freezed
sealed class AuthState with _$AuthState {
  /// App just launched, checking stored tokens.
  const factory AuthState.initial() = AuthInitial;

  /// Authentication in progress (creating guest, refreshing token).
  const factory AuthState.loading() = AuthLoading;

  /// User is authenticated.
  const factory AuthState.authenticated(User user) = AuthAuthenticated;

  /// No valid tokens, show welcome screen.
  const factory AuthState.unauthenticated() = AuthUnauthenticated;

  /// Authentication failed with error message.
  const factory AuthState.error(String message) = AuthError;
}
```

**Step 2: Run code generation**

Run:
```bash
cd frontend && dart run build_runner build --delete-conflicting-outputs
```
Expected: Build completed, generates `auth_state.freezed.dart`

**Step 3: Commit**

```bash
git add frontend/lib/features/auth/domain/auth_state.dart frontend/lib/features/auth/domain/auth_state.freezed.dart
git commit -m "feat: add AuthState sealed class"
```

---

## Task 11: Create Auth Service

**Files:**
- Create: `frontend/lib/features/auth/data/auth_service.dart`

**Step 1: Create directory**

Run:
```bash
mkdir -p frontend/lib/features/auth/data
```

**Step 2: Create auth_service.dart**

Create `frontend/lib/features/auth/data/auth_service.dart`:

```dart
import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../domain/user.dart';

/// Token pair returned from authentication endpoints.
typedef TokenPair = ({String access, String refresh});

/// Authentication response containing tokens and user info.
typedef AuthResponse = ({TokenPair tokens, User user});

/// Service for authentication API calls.
class AuthService {
  AuthService({required ApiClient apiClient}) : _client = apiClient;

  final ApiClient _client;

  /// Creates a guest account.
  ///
  /// [displayName] is optional - server generates one if not provided.
  /// Returns tokens and user info on success.
  /// Throws [ApiException] on failure.
  Future<AuthResponse> createGuest({String? displayName}) async {
    try {
      final body = <String, dynamic>{};
      if (displayName != null && displayName.trim().isNotEmpty) {
        body['display_name'] = displayName.trim();
      }

      final response = await _client.post<Map<String, dynamic>>(
        '/auth/guest/',
        data: body,
      );

      final data = response.data!;
      return (
        tokens: (
          access: data['access'] as String,
          refresh: data['refresh'] as String,
        ),
        user: User.fromJson(data['user'] as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Refreshes access token using refresh token.
  ///
  /// Returns new token pair on success.
  /// Throws [ApiException] on failure.
  Future<TokenPair> refreshToken(String refreshToken) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/auth/token/refresh/',
        data: {'refresh': refreshToken},
      );

      final data = response.data!;
      return (
        access: data['access'] as String,
        refresh: data['refresh'] as String? ?? refreshToken,
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }
}
```

**Step 3: Commit**

```bash
git add frontend/lib/features/auth/data/
git commit -m "feat: add AuthService for API calls"
```

---

## Task 12: Create Auth Repository

**Files:**
- Create: `frontend/lib/features/auth/data/auth_repository.dart`

**Step 1: Create auth_repository.dart**

Create `frontend/lib/features/auth/data/auth_repository.dart`:

```dart
import '../../../core/api/api_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/user.dart';
import 'auth_service.dart';

/// Repository coordinating auth service and token storage.
///
/// Single source of truth for authentication state.
class AuthRepository {
  AuthRepository({
    required AuthService authService,
    required TokenStorage tokenStorage,
  })  : _authService = authService,
        _tokenStorage = tokenStorage;

  final AuthService _authService;
  final TokenStorage _tokenStorage;

  /// Checks for stored tokens and attempts silent refresh.
  ///
  /// Returns user if refresh succeeds, null if no tokens or refresh fails.
  Future<User?> tryRestoreSession() async {
    final hasTokens = await _tokenStorage.hasTokens;
    if (!hasTokens) {
      logger.d('No stored tokens found');
      return null;
    }

    final refreshToken = await _tokenStorage.refreshToken;
    if (refreshToken == null) {
      logger.d('No refresh token found');
      await _tokenStorage.deleteTokens();
      return null;
    }

    try {
      logger.d('Attempting silent token refresh');
      final tokens = await _authService.refreshToken(refreshToken);
      await _tokenStorage.saveTokens(
        accessToken: tokens.access,
        refreshToken: tokens.refresh,
      );
      logger.i('Session restored successfully');

      // For MVP, we don't have a /me endpoint, so return minimal user
      // In future, call /auth/me/ to get full user data
      return const User(id: 0, displayName: 'Returning User');
    } on ApiException catch (e) {
      logger.w('Session restore failed: $e');
      await _tokenStorage.deleteTokens();
      return null;
    }
  }

  /// Creates a guest account and stores tokens.
  ///
  /// [displayName] is optional - server generates one if not provided.
  /// Returns the created user.
  /// Throws [ApiException] on failure.
  Future<User> createGuest({String? displayName}) async {
    final response = await _authService.createGuest(displayName: displayName);

    await _tokenStorage.saveTokens(
      accessToken: response.tokens.access,
      refreshToken: response.tokens.refresh,
    );

    logger.i('Guest account created: ${response.user.displayName}');
    return response.user;
  }

  /// Clears stored tokens (logout).
  Future<void> logout() async {
    await _tokenStorage.deleteTokens();
    logger.i('Logged out');
  }
}
```

**Step 2: Commit**

```bash
git add frontend/lib/features/auth/data/auth_repository.dart
git commit -m "feat: add AuthRepository coordinating service and storage"
```

---

## Task 13: Create Auth Notifier (Riverpod)

**Files:**
- Create: `frontend/lib/features/auth/presentation/auth_notifier.dart`

**Step 1: Create directory**

Run:
```bash
mkdir -p frontend/lib/features/auth/presentation
```

**Step 2: Create auth_notifier.dart**

Create `frontend/lib/features/auth/presentation/auth_notifier.dart`:

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';
import '../data/auth_service.dart';
import '../domain/auth_state.dart';

part 'auth_notifier.g.dart';

/// Provides the API client.
@riverpod
ApiClient apiClient(ApiClientRef ref) => ApiClient();

/// Provides the token storage.
@riverpod
TokenStorage tokenStorage(TokenStorageRef ref) => TokenStorage();

/// Provides the auth service.
@riverpod
AuthService authService(AuthServiceRef ref) =>
    AuthService(apiClient: ref.watch(apiClientProvider));

/// Provides the auth repository.
@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) => AuthRepository(
      authService: ref.watch(authServiceProvider),
      tokenStorage: ref.watch(tokenStorageProvider),
    );

/// Manages authentication state.
@riverpod
class AuthNotifier extends _$AuthNotifier {
  @override
  AuthState build() {
    // Start in initial state, then check for stored session
    _checkStoredSession();
    return const AuthState.initial();
  }

  Future<void> _checkStoredSession() async {
    final repository = ref.read(authRepositoryProvider);
    final user = await repository.tryRestoreSession();

    if (user != null) {
      state = AuthState.authenticated(user);
    } else {
      state = const AuthState.unauthenticated();
    }
  }

  /// Creates a guest account with optional display name.
  Future<void> createGuest({String? displayName}) async {
    state = const AuthState.loading();

    try {
      final repository = ref.read(authRepositoryProvider);
      final user = await repository.createGuest(displayName: displayName);
      state = AuthState.authenticated(user);
    } on ValidationException catch (e) {
      final message = e.errors['display_name']?.first ??
          e.errors['detail']?.first ??
          'Invalid display name';
      state = AuthState.error(message);
    } on NetworkException catch (e) {
      logger.e('Network error during guest creation', error: e);
      state = const AuthState.error('Check your connection and try again');
    } on ApiException catch (e) {
      logger.e('API error during guest creation', error: e);
      state = const AuthState.error('Something went wrong. Please try again.');
    }
  }

  /// Logs out the current user.
  Future<void> logout() async {
    final repository = ref.read(authRepositoryProvider);
    await repository.logout();
    state = const AuthState.unauthenticated();
  }
}
```

**Step 3: Run code generation**

Run:
```bash
cd frontend && dart run build_runner build --delete-conflicting-outputs
```
Expected: Build completed, generates `auth_notifier.g.dart`

**Step 4: Commit**

```bash
git add frontend/lib/features/auth/presentation/
git commit -m "feat: add AuthNotifier with Riverpod"
```

---

## Task 14: Create Home Screen

**Files:**
- Create: `frontend/lib/features/auth/presentation/home_screen.dart`

**Step 1: Create home_screen.dart**

Create `frontend/lib/features/auth/presentation/home_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_state.dart';
import 'auth_notifier.dart';

/// MVP home screen demonstrating full auth flow.
///
/// Shows:
/// - Splash during initial load
/// - Welcome screen with display name input for unauthenticated users
/// - Hello message for authenticated users
/// - Error state with retry
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      body: SafeArea(
        child: switch (authState) {
          AuthInitial() => const _SplashView(),
          AuthLoading() => const _LoadingView(),
          AuthAuthenticated(:final user) => _AuthenticatedView(
              displayName: user.displayName,
            ),
          AuthUnauthenticated() => const _WelcomeView(),
          AuthError(:final message) => _ErrorView(message: message),
        },
      ),
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Midnight Village',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 24),
          CircularProgressIndicator(),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Creating account...'),
        ],
      ),
    );
  }
}

class _WelcomeView extends ConsumerStatefulWidget {
  const _WelcomeView();

  @override
  ConsumerState<_WelcomeView> createState() => _WelcomeViewState();
}

class _WelcomeViewState extends ConsumerState<_WelcomeView> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onContinue() {
    final displayName = _controller.text.trim();
    ref.read(authNotifierProvider.notifier).createGuest(
          displayName: displayName.isEmpty ? null : displayName,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Midnight Village',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Display name',
              hintText: 'Leave blank for random name',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _onContinue(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _onContinue,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthenticatedView extends StatelessWidget {
  const _AuthenticatedView({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Hello, $displayName!',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '(token stored ✓)',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends ConsumerWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                ref.invalidate(authNotifierProvider);
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Step 2: Commit**

```bash
git add frontend/lib/features/auth/presentation/home_screen.dart
git commit -m "feat: add HomeScreen with auth state rendering"
```

---

## Task 15: Create Router

**Files:**
- Create: `frontend/lib/core/router/routes.dart`
- Create: `frontend/lib/core/router/app_router.dart`

**Step 1: Create directory**

Run:
```bash
mkdir -p frontend/lib/core/router
```

**Step 2: Create routes.dart**

Create `frontend/lib/core/router/routes.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/home_screen.dart';

part 'routes.g.dart';

/// Home route - the MVP single screen.
@TypedGoRoute<HomeRoute>(path: '/')
class HomeRoute extends GoRouteData {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HomeScreen();
}
```

**Step 3: Create app_router.dart**

Create `frontend/lib/core/router/app_router.dart`:

```dart
import 'package:go_router/go_router.dart';

import 'routes.dart';

/// Application router configuration.
final appRouter = GoRouter(
  routes: $appRoutes,
  debugLogDiagnostics: true,
);
```

**Step 4: Run code generation**

Run:
```bash
cd frontend && dart run build_runner build --delete-conflicting-outputs
```
Expected: Build completed, generates `routes.g.dart`

**Step 5: Commit**

```bash
git add frontend/lib/core/router/
git commit -m "feat: add go_router with type-safe routes"
```

---

## Task 16: Create App Widget

**Files:**
- Create: `frontend/lib/app.dart`

**Step 1: Create app.dart**

Create `frontend/lib/app.dart`:

```dart
import 'package:flutter/material.dart';

import 'core/router/app_router.dart';

/// Root application widget.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Midnight Village',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      routerConfig: appRouter,
    );
  }
}
```

**Step 2: Commit**

```bash
git add frontend/lib/app.dart
git commit -m "feat: add App widget with dark theme"
```

---

## Task 17: Update Main Entry Point

**Files:**
- Modify: `frontend/lib/main.dart`

**Step 1: Replace main.dart**

Replace entire `frontend/lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
```

**Step 2: Run code generation one final time**

Run:
```bash
cd frontend && dart run build_runner build --delete-conflicting-outputs
```
Expected: Build completed successfully

**Step 3: Commit**

```bash
git add frontend/lib/main.dart
git commit -m "feat: configure main.dart with ProviderScope"
```

---

## Task 18: Verify Full App Runs

**Files:** None (verification only)

**Step 1: Start backend server**

In a terminal:
```bash
cd /Users/doodla/Code/midnight-village && just dev
```
Expected: Server running at `http://localhost:8000`

**Step 2: Run Flutter app**

In another terminal:
```bash
cd /Users/doodla/Code/midnight-village/frontend && flutter run -d chrome --web-port=3000
```
Expected: App launches in browser showing "Midnight Village" with display name input

**Step 3: Test guest creation flow**

1. Leave display name empty, click "Continue"
2. Expected: Shows "Hello, [RandomName]!" (e.g., "Hello, SwiftOwl!")

**Step 4: Test with custom name**

1. Hot reload (press `r` in terminal)
2. Enter "TestUser" in display name field
3. Click "Continue"
4. Expected: Shows "Hello, TestUser!"

**Step 5: Verify token persistence**

1. Close browser tab
2. Run app again: `flutter run -d chrome --web-port=3000`
3. Expected: Shows splash briefly, then "Hello, Returning User!" (session restored)

**Step 6: Document any issues**

If any step fails, note the error for debugging.

---

## Task 19: Add Flutter Commands to Root Justfile

**Files:**
- Modify: `justfile` (repository root)

**Step 1: Add frontend commands**

Add to end of root `justfile`:

```just
# --- Frontend ---

# Frontend justfile delegation helper
frontend_just := "just --justfile frontend/justfile --working-directory frontend"

# Run Flutter app (web)
flutter-run:
    cd frontend && flutter run -d chrome --web-port=3000

# Run Flutter code generation
flutter-build-runner:
    cd frontend && dart run build_runner build --delete-conflicting-outputs

# Run Flutter code generation (watch mode)
flutter-watch:
    cd frontend && dart run build_runner watch --delete-conflicting-outputs

# Run Flutter tests
flutter-test:
    cd frontend && flutter test

# Analyze Flutter code
flutter-analyze:
    cd frontend && flutter analyze
```

**Step 2: Commit**

```bash
git add justfile
git commit -m "chore: add Flutter commands to root justfile"
```

---

## Task 20: Create Frontend Justfile

**Files:**
- Create: `frontend/justfile`

**Step 1: Create justfile**

Create `frontend/justfile`:

```just
# Frontend Justfile for Midnight Village Flutter App
# Run `just` or `just --list` to see available commands

set shell := ["bash", "-uc"]

# Default: show help
default:
    @just --list

# --- Development ---

# Run app on Chrome
run:
    flutter run -d chrome --web-port=3000

# Run app on specific device
run-device device:
    flutter run -d {{device}}

# Run code generation
gen:
    dart run build_runner build --delete-conflicting-outputs

# Run code generation (watch mode)
watch:
    dart run build_runner watch --delete-conflicting-outputs

# --- Testing ---

# Run all tests
test:
    flutter test

# Run tests with coverage
test-cov:
    flutter test --coverage

# --- Code Quality ---

# Analyze code
analyze:
    flutter analyze

# Format code
format:
    dart format lib test

# Check formatting
format-check:
    dart format --set-exit-if-changed lib test

# --- Build ---

# Build for web (production)
build-web:
    flutter build web --dart-define=ENV=prod

# Build for iOS (production)
build-ios:
    flutter build ios --dart-define=ENV=prod

# Build for Android (production)
build-android:
    flutter build appbundle --dart-define=ENV=prod

# --- Utilities ---

# Get dependencies
deps:
    flutter pub get

# Clean build artifacts
clean:
    flutter clean && dart run build_runner clean
```

**Step 2: Commit**

```bash
git add frontend/justfile
git commit -m "chore: add frontend justfile"
```

---

## Task 21: Final Verification

**Step 1: Run analysis**

```bash
cd frontend && flutter analyze
```
Expected: No issues found

**Step 2: Run full flow test**

1. Stop any running backend/frontend
2. Start backend: `just dev`
3. Start frontend: `cd frontend && just run`
4. Test: Leave name empty → Continue → See generated name
5. Close browser, restart app → See "Returning User" (session restored)

**Step 3: Create final commit**

```bash
git add -A
git commit -m "feat: complete Flutter MVP foundation"
```

---

## Summary

This plan creates a fully functional Flutter MVP that validates:

1. **Project structure** - Feature-first hybrid architecture
2. **State management** - Riverpod 3.x with code generation
3. **Routing** - go_router with type-safe routes
4. **API integration** - Dio client with typed exceptions
5. **Token storage** - flutter_secure_storage for JWT persistence
6. **Data models** - Freezed for immutable data classes
7. **Auth flow** - Guest registration with display name, session restore

All architectural patterns from the design document are implemented and ready for extension when building the Lobby feature.
