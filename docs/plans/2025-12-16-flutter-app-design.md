# Flutter App Design

> Companion app for Midnight Village - One Night Ultimate Werewolf digital assistant.

## Decisions

| Decision | Choice |
|----------|--------|
| Platforms | All (Web, iOS, Android) |
| State management | Riverpod 3.x with code generation |
| Routing | go_router with type-safe routes |
| Auth flow | Anonymous by default (guest accounts) |
| Theme | Dark only |
| Join methods | Room code + QR scan + share link |
| Offline handling | Auto-reconnect, no offline actions |
| Project structure | Hybrid (core + features) |

### MVP Clarifications (from brainstorming)

| Topic | Decision | Rationale |
|-------|----------|-----------|
| Display name storage | New `display_name` field | Not reusing `first_name`; cleaner separation |
| Name generation | Hardcoded word lists | ~100 adjectives × ~100 animals = 10K combinations, no dependencies |
| Display name validation | Unicode letters + spaces | Supports international names; regex: `^[\p{L}\p{N}]+( [\p{L}\p{N}]+)*$` |
| Guest upgrade path | Deferred | Not MVP; can add later without schema changes |
| Returning user flow | Silent refresh on launch | Try refresh token automatically; only show signup if refresh fails |
| WebSocket auth | Deferred | MVP doesn't use WebSockets; add when building Lobby feature |
| `AuthenticatedClient` | Deferred | MVP only calls unauthenticated guest endpoint + refresh (token in body) |
| Backend test scope | Happy path + edge cases | ~8 tests covering validation, generation, token response |

---

## MVP: Foundation Validation

The first implementation milestone is a minimal screen that validates all architectural patterns before building features.

### Goal

A single screen that:
1. Checks for stored tokens on launch
2. If no tokens: shows display name input + "Continue" button
3. Creates guest account → stores tokens → shows "Hello, [display_name]!"

### Why This Scope

- **UI-light, architecture-heavy**: Simple UI lets us focus on validating the patterns
- **End-to-end proof**: Real backend endpoint, real token storage, real state management
- **No shortcuts**: Uses all production patterns (Riverpod codegen, Freezed, go_router, interceptors)

### Screen Layout

```
┌─────────────────────────┐
│                         │
│   Midnight Village      │
│                         │
│   ┌─────────────────┐   │
│   │ Display name... │   │  ← optional, placeholder generated if empty
│   └─────────────────┘   │
│                         │
│   ┌─────────────────┐   │
│   │    Continue     │   │
│   └─────────────────┘   │
│                         │
└─────────────────────────┘

         ↓ after auth

┌─────────────────────────┐
│                         │
│   Hello, SwiftOwl!      │
│                         │
│   (token stored ✓)      │
│                         │
└─────────────────────────┘
```

### Backend Endpoint Required

`POST /api/auth/guest/` - creates guest account with optional display name.

**Request:**
```json
{"display_name": "Alice"}  // optional - empty/missing generates placeholder
```

**Response:**
```json
{
  "access": "eyJ...",
  "refresh": "eyJ...",
  "user": {
    "id": 1,
    "display_name": "Alice"  // or "SwiftOwl" if not provided
  }
}
```

**Backend implementation:**
- Creates `User` with `username`: UUID (internal), `display_name`: provided or generated, `is_guest`: True
- Display name validation: max 20 chars, trimmed, whitespace-only → generate
- Generated names: adjective + animal (e.g., "SwiftOwl", "BlueFox") - ~10K combinations

### Backend Tests (MVP)

Test file: `tests/test_guest_auth.py`

| Test Case | What it verifies |
|-----------|------------------|
| `test_create_guest_with_display_name` | Provided name is stored, tokens returned |
| `test_create_guest_without_display_name` | Name is generated (AdjectiveAnimal format) |
| `test_create_guest_empty_display_name` | Empty string triggers generation |
| `test_create_guest_whitespace_only` | Whitespace-only triggers generation |
| `test_create_guest_display_name_trimmed` | Leading/trailing whitespace stripped |
| `test_create_guest_display_name_max_length` | Names > 20 chars rejected (400) |
| `test_create_guest_display_name_invalid_chars` | Control chars / special symbols rejected |
| `test_guest_user_fields_set_correctly` | `is_guest=True`, `username` is UUID format |

### Files Created (MVP)

```
lib/
  main.dart                       # Entry point, ProviderScope
  app.dart                        # MaterialApp.router, dark theme
  core/
    api/
      api_client.dart             # Base Dio, no auth
      api_exception.dart          # Typed exceptions
      logging_interceptor.dart    # Request/response logging
    config/
      env.dart                    # Environment switching
    logging/
      app_logger.dart             # Logger setup
    storage/
      token_storage.dart          # Secure storage wrapper
    router/
      app_router.dart             # go_router setup
      routes.dart                 # Route definitions (+ routes.g.dart generated)
  features/
    auth/
      data/
        auth_service.dart         # API calls: createGuest, refresh
        auth_repository.dart      # Coordinates service + storage
      domain/
        user.dart                 # User model (+ user.freezed.dart, user.g.dart generated)
        auth_state.dart           # Sealed: initial/loading/authenticated/unauthenticated/error
      presentation/
        auth_notifier.dart        # @riverpod, manages AuthState (+ auth_notifier.g.dart generated)
        home_screen.dart          # The one MVP screen
```

**Deferred to Lobby feature:**
- `authenticated_client.dart` (JWT interceptor)
- `core/websocket/` (WebSocket layer)
- Widget extraction (`display_name_field.dart`, `continue_button.dart`)

### Auth State Model (MVP)

Pattern reused across all features:

```dart
// lib/features/auth/domain/auth_state.dart
@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.initial() = AuthInitial;
  const factory AuthState.loading() = AuthLoading;
  const factory AuthState.authenticated(User user) = AuthAuthenticated;
  const factory AuthState.unauthenticated() = AuthUnauthenticated;
  const factory AuthState.error(String message) = AuthError;
}
```

**Why `unauthenticated` separate from `initial`:**
- `initial` = app just launched, checking stored tokens
- `unauthenticated` = checked storage, no valid tokens (show welcome screen)

**Startup flow:**
```
initial → (check storage)
              ↓
    ┌─────────┴─────────┐
    │                   │
no tokens         tokens found
    ↓                   ↓
unauthenticated   (silent refresh)
    ↓                   ↓
(tap Continue)    ┌─────┴─────┐
    ↓             │           │
  loading      success     failure
    ↓             ↓           ↓
authenticated  authenticated  unauthenticated
  OR error                    (show welcome)
```

**Key behavior:** Returning guests with expired access tokens get silent refresh. Only show welcome screen if refresh also fails.

**HomeScreen UI mapping:**
```dart
return switch (authState) {
  AuthInitial() => const SplashScreen(),      // brief, checking storage
  AuthLoading() => const LoadingIndicator(),
  AuthAuthenticated(user: final u) => HelloScreen(user: u),
  AuthUnauthenticated() => const WelcomeScreen(),
  AuthError(message: final m) => ErrorView(message: m, onRetry: ...),
};
```

### Testing (MVP)

Tests at each layer that prove real behavior:

| Layer | What breaks | Test type |
|-------|-------------|-----------|
| `TokenStorage` | Tokens not persisted across app restart | Unit test |
| `AuthService.createGuest` | Wrong request format, bad response parsing | Unit test |
| `AuthRepository` | Service + storage not coordinated | Integration test |
| `AuthInterceptor` | Token not attached, refresh not triggered | Integration test |
| `AuthNotifier` | State transitions wrong | Unit test |
| `HomeScreen` | Button doesn't trigger auth, states not shown | Widget test |

**Key integration test (the one that matters most):**
```dart
test('full auth flow: create guest → store tokens → use on next request', () async {
  // 1. Start with no tokens
  // 2. Call createGuest
  // 3. Verify tokens stored
  // 4. Make authenticated request
  // 5. Verify Authorization header present
});
```

**Skip testing:**
- Generated code (Freezed, Riverpod)
- Trivial code (`Env.apiUrl` switch)
- No-logic setup (logger config)

---

## Project Structure

**Hybrid approach** (feature-first with shared core):
- **Scales well** - Each feature encapsulates its UI, state, and models
- **Avoids duplication** - Shared services (API, auth, WebSocket) in `core/`
- **Easy navigation** - All files for a feature in one place

```
frontend/
├── justfile                      # Flutter commands (build, test, run)
├── lib/
│   ├── main.dart                 # Entry point, app initialization
│   ├── app.dart                  # MaterialApp, theme, router setup
│   │
│   ├── core/                     # Shared infrastructure
│   │   ├── api/                  # REST API client, endpoints
│   │   ├── websocket/            # WebSocket service, reconnection
│   │   ├── storage/              # Secure token storage
│   │   ├── theme/                # Dark theme definition
│   │   └── router/               # go_router config, guards
│   │
│   ├── features/
│   │   ├── auth/                 # Anonymous auth, display name
│   │   ├── home/                 # Landing screen, create/join options
│   │   ├── lobby/                # Lobby screen, player list, ready up
│   │   └── game/                 # Game phases (future: ONUW-specific)
│   │
│   └── shared/                   # Reusable widgets, extensions
│       ├── widgets/
│       └── extensions/
│
├── test/                         # Tests mirror lib/ structure
├── pubspec.yaml                  # Dependencies and metadata
└── analysis_options.yaml         # Linter configuration
```

Each feature folder contains:
- `screens/` - Full page widgets
- `providers/` - Riverpod providers for state
- `widgets/` - Feature-specific components
- `models/` - Data classes (freezed)

---

## Core Services

### API Layer

Layered architecture for HTTP:

```
┌─────────────────────────────────────┐
│  LobbyService / GameService / etc.  │  ← Feature-specific
├─────────────────────────────────────┤
│         AuthenticatedClient         │  ← Dio with interceptors (JWT, retry)
├─────────────────────────────────────┤
│            ApiClient                │  ← Raw Dio instance, base config
└─────────────────────────────────────┘
```

```dart
// Use Dart 3 records for simple data
typedef TokenPair = ({String access, String refresh});

// api_client.dart - Low-level Dio wrapper
class ApiClient {
  final Dio _dio;

  ApiClient({required String baseUrl})
    : _dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ));

  Future<Response> get(String path) => _dio.get(path);
  Future<Response> post(String path, {Object? body}) => _dio.post(path, data: body);
}

// auth_service.dart - Token management
class AuthService {
  final ApiClient _client;
  TokenPair? _tokens;

  /// Creates a guest account. Display name is optional - server generates one if not provided.
  Future<({TokenPair tokens, User user})> createGuest({String? displayName}) async {
    final response = await _client.post('/auth/guest/', body: {
      if (displayName != null && displayName.trim().isNotEmpty)
        'display_name': displayName.trim(),
    });
    return (
      tokens: (access: response.data['access'], refresh: response.data['refresh']),
      user: User.fromJson(response.data['user']),
    );
  }

  Future<TokenPair> refresh() async {
    final response = await _client.post('/auth/token/refresh/', body: {'refresh': _tokens!.refresh});
    _tokens = (access: response.data['access'], refresh: _tokens!.refresh);
    return _tokens!;
  }

  String? get accessToken => _tokens?.access;
}

// authenticated_client.dart - Dio with JWT interceptor
class AuthenticatedClient {
  final Dio _dio;
  final AuthService _auth;

  AuthenticatedClient(String baseUrl, this._auth)
    : _dio = Dio(BaseOptions(baseUrl: baseUrl)) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = _auth.accessToken;
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          try {
            await _auth.refresh();
            final retryOptions = e.requestOptions;
            retryOptions.headers['Authorization'] = 'Bearer ${_auth.accessToken}';
            final response = await _dio.fetch(retryOptions);
            handler.resolve(response);
          } catch (_) {
            handler.next(e);
          }
        } else {
          handler.next(e);
        }
      },
    ));
  }

  Future<Response> get(String path) => _dio.get(path);
  Future<Response> post(String path, {Object? body}) => _dio.post(path, data: body);
}

// lobby_service.dart - Lobby operations
class LobbyService {
  final AuthenticatedClient _client;

  LobbyService(this._client);

  Future<Lobby> create(String gameType, {int maxPlayers = 10}) async {
    final response = await _client.post('/lobbies/', body: {
      'game_type': gameType,
      'max_players': maxPlayers,
    });
    return Lobby.fromJson(response.data);
  }

  Future<Lobby> get(String code) async {
    final response = await _client.get('/lobbies/$code/');
    return Lobby.fromJson(response.data);
  }

  Future<Lobby> join(String code) async {
    final response = await _client.post('/lobbies/$code/join/');
    return Lobby.fromJson(response.data);
  }

  Future<void> leave(String code) => _client.post('/lobbies/$code/leave/');

  Future<Lobby> setReady(String code, bool isReady) async {
    final response = await _client.post('/lobbies/$code/ready/', body: {'is_ready': isReady});
    return Lobby.fromJson(response.data);
  }
}
```

### WebSocket Layer

Using `web_socket_client` for built-in reconnection with exponential backoff:

```
┌─────────────────────────────────────┐
│  LobbyChannel / GameChannel / etc.  │  ← Feature-specific typed events
├─────────────────────────────────────┤
│         AuthenticatedWsClient       │  ← Attaches JWT, typed event parsing
├─────────────────────────────────────┤
│            WsClient                 │  ← web_socket_client with backoff
└─────────────────────────────────────┘
```

```dart
import 'package:web_socket_client/web_socket_client.dart';

// ws_client.dart - Low-level with built-in reconnection
class WsClient {
  WebSocket? _socket;

  Stream<String> connect(String url) {
    _socket = WebSocket(
      Uri.parse(url),
      backoff: BinaryExponentialBackoff(
        initial: const Duration(seconds: 1),
        maximumStep: 6, // Max 64 seconds between retries
      ),
    );
    return _socket!.messages.cast<String>();
  }

  void send(String message) => _socket?.send(message);

  void disconnect() => _socket?.close();

  Stream<ConnectionState> get connectionState => _socket?.connection ?? const Stream.empty();
}

// authenticated_ws_client.dart - Adds auth, parses JSON
class AuthenticatedWsClient {
  final WsClient _client;
  final AuthService _auth;

  AuthenticatedWsClient(this._client, this._auth);

  Stream<Map<String, dynamic>> connect(String path) {
    final token = _auth.accessToken;
    final url = 'ws://$baseWsUrl$path?token=$token';
    return _client.connect(url).map((msg) => jsonDecode(msg) as Map<String, dynamic>);
  }

  void send(Map<String, dynamic> message) => _client.send(jsonEncode(message));
  void disconnect() => _client.disconnect();
}

// lobby_channel.dart - Lobby-specific typed events
class LobbyChannel {
  final AuthenticatedWsClient _client;

  LobbyChannel(this._client);

  Stream<LobbyEvent> connect(String lobbyCode) {
    return _client.connect('/ws/lobby/$lobbyCode/').map(_parseEvent);
  }

  LobbyEvent _parseEvent(Map<String, dynamic> json) {
    return switch (json['type']) {
      'player_joined' => PlayerJoinedEvent(json['username']),
      'player_left' => PlayerLeftEvent(json['username']),
      'player_ready' => PlayerReadyEvent(json['username'], json['is_ready']),
      'lobby_update' => LobbyStateEvent(Lobby.fromJson(json['data'])),
      _ => UnknownEvent(json),
    };
  }
}

// lobby_events.dart - Typed events using sealed classes
sealed class LobbyEvent {}
class PlayerJoinedEvent extends LobbyEvent {
  final String username;
  PlayerJoinedEvent(this.username);
}
class PlayerLeftEvent extends LobbyEvent {
  final String username;
  PlayerLeftEvent(this.username);
}
class PlayerReadyEvent extends LobbyEvent {
  final String username;
  final bool isReady;
  PlayerReadyEvent(this.username, this.isReady);
}
class LobbyStateEvent extends LobbyEvent {
  final Lobby lobby;
  LobbyStateEvent(this.lobby);
}
class UnknownEvent extends LobbyEvent {
  final Map<String, dynamic> raw;
  UnknownEvent(this.raw);
}
```

### Token Storage

Uses `flutter_secure_storage` for JWT tokens. On app start, checks for existing token → auto-login as returning guest.

---

## Screens & Navigation

### Type-Safe Routes

Using `go_router_builder` for compile-time route safety:

```dart
// lib/core/router/routes.dart
part 'routes.g.dart';

@TypedGoRoute<HomeRoute>(path: '/')
class HomeRoute extends GoRouteData {
  const HomeRoute();

  @override
  Widget build(BuildContext context, GoRouterState state) => const HomeScreen();
}

@TypedGoRoute<LobbyRoute>(path: '/lobby/:code')
class LobbyRoute extends GoRouteData {
  final String code;

  const LobbyRoute(this.code);

  @override
  Widget build(BuildContext context, GoRouterState state) => LobbyScreen(code: code);
}

@TypedGoRoute<LobbyJoinRoute>(path: '/lobby/:code/join')
class LobbyJoinRoute extends GoRouteData {
  final String code;

  const LobbyJoinRoute(this.code);

  @override
  Widget build(BuildContext context, GoRouterState state) => LobbyJoinHandler(code: code);
}

@TypedGoRoute<GameRoute>(path: '/game/:code')
class GameRoute extends GoRouteData {
  final String code;

  const GameRoute(this.code);

  @override
  Widget build(BuildContext context, GoRouterState state) => GameScreen(code: code);
}

// Usage - type-safe navigation:
const HomeRoute().go(context);
LobbyRoute('ABC123').go(context);
```

### Screen Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  HomeScreen  │────►│ LobbyScreen  │────►│  GameScreen  │
│              │     │              │     │   (future)   │
│ • Create     │     │ • Player list│     │              │
│ • Join code  │     │ • Ready up   │     │ • Night      │
│ • Scan QR    │     │ • Host start │     │ • Discussion │
│              │     │ • Leave      │     │ • Voting     │
└──────────────┘     └──────────────┘     └──────────────┘
       │                                         │
       └─────────── /lobby/:code/join ───────────┘
                   (share link entry)
```

### HomeScreen

- Display name input (editable, persisted)
- "Create Lobby" button → creates lobby → navigates to `/lobby/:code`
- "Join Lobby" → text field for code OR QR scanner
- If returning user, shows their display name from storage

### LobbyScreen

- Connected via WebSocket for real-time updates
- Shows lobby code (big, copyable) + share button + QR code display
- Player list with ready indicators
- Ready toggle button
- Host sees "Start Game" (disabled until minimum players ready)
- Leave button (host leaving = lobby deleted)

---

## Riverpod Providers

Using Riverpod 3.x with code generation (`@riverpod` annotation). Since we're already using Freezed for data classes, code generation is a natural fit.

### App Initialization

Auth resolved BEFORE app runs - no async loading states throughout app:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient(baseUrl: env.apiUrl);
  final authService = AuthService(apiClient);
  final authState = await authService.initializeAuth();

  runApp(ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(authService),
    ],
    child: const App(),
  ));
}
```

### Core Providers

Using `@riverpod` annotation for all providers:

```dart
// providers/core_providers.dart
part 'core_providers.g.dart';

@riverpod
ApiClient apiClient(ApiClientRef ref) {
  return ApiClient(baseUrl: env.apiUrl);
}

@riverpod
AuthService authService(AuthServiceRef ref) {
  return AuthService(ref.watch(apiClientProvider));
}

@riverpod
WsClient wsClient(WsClientRef ref) {
  return WsClient();
}

@riverpod
AuthenticatedClient authenticatedClient(AuthenticatedClientRef ref) {
  return AuthenticatedClient(
    env.apiUrl,
    ref.watch(authServiceProvider),
  );
}

@riverpod
AuthenticatedWsClient authenticatedWsClient(AuthenticatedWsClientRef ref) {
  return AuthenticatedWsClient(
    ref.watch(wsClientProvider),
    ref.watch(authServiceProvider),
  );
}

@riverpod
LobbyService lobbyService(LobbyServiceRef ref) {
  return LobbyService(ref.watch(authenticatedClientProvider));
}

@riverpod
LobbyChannel lobbyChannel(LobbyChannelRef ref) {
  return LobbyChannel(ref.watch(authenticatedWsClientProvider));
}
```

### Lobby State

Explicit connection states - using sealed classes with Dart 3 pattern matching:

```dart
sealed class LobbyConnectionState {}

class LobbyLoading extends LobbyConnectionState {}

class LobbyConnected extends LobbyConnectionState {
  final Lobby lobby;
  LobbyConnected(this.lobby);
}

class LobbyReconnecting extends LobbyConnectionState {
  final Lobby lastKnown;
  LobbyReconnecting(this.lastKnown);
}

class LobbyError extends LobbyConnectionState {
  final String message;
  final Lobby? lastKnown;
  LobbyError(this.message, {this.lastKnown});
}
```

Using `Notifier` (not deprecated StateNotifier):

```dart
// features/lobby/providers/lobby_provider.dart
part 'lobby_provider.g.dart';

@riverpod
class LobbyNotifier extends _$LobbyNotifier {
  StreamSubscription<LobbyEvent>? _subscription;

  @override
  LobbyConnectionState? build() => null;

  Future<void> connect(String code) async {
    state = LobbyLoading();

    try {
      final lobbyService = ref.read(lobbyServiceProvider);
      final lobbyChannel = ref.read(lobbyChannelProvider);

      // Fetch initial state
      final lobby = await lobbyService.get(code);
      state = LobbyConnected(lobby);

      // Subscribe to WebSocket updates
      _subscription = lobbyChannel.connect(code).listen(
        _handleEvent,
        onError: (_) => _handleDisconnect(),
        onDone: _handleDisconnect,
      );
    } catch (e) {
      state = LobbyError('Failed to connect: $e');
    }
  }

  Future<void> join(String code) async {
    state = LobbyLoading();

    try {
      final lobbyService = ref.read(lobbyServiceProvider);
      final lobby = await lobbyService.join(code);
      await connect(lobby.code);
    } catch (e) {
      state = LobbyError('Failed to join: $e');
    }
  }

  Future<void> leave() async {
    if (state case LobbyConnected(lobby: final lobby)) {
      try {
        await ref.read(lobbyServiceProvider).leave(lobby.code);
        _cleanup();
        state = null;
      } catch (e) {
        // Still leave locally even if API fails
        _cleanup();
        state = null;
      }
    }
  }

  Future<void> setReady(bool ready) async {
    if (state case LobbyConnected(lobby: final lobby)) {
      try {
        final updated = await ref.read(lobbyServiceProvider).setReady(lobby.code, ready);
        state = LobbyConnected(updated);
      } catch (e) {
        // Optimistic update failed - state will be corrected by WebSocket
      }
    }
  }

  void _handleEvent(LobbyEvent event) {
    final currentLobby = switch (state) {
      LobbyConnected(lobby: final l) => l,
      LobbyReconnecting(lastKnown: final l) => l,
      _ => null,
    };

    if (currentLobby == null) return;

    switch (event) {
      case PlayerJoinedEvent(username: final name):
        // Update lobby.players
        break;
      case PlayerLeftEvent(username: final name):
        // Update lobby.players
        break;
      case PlayerReadyEvent(username: final name, isReady: final ready):
        // Update player ready state
        break;
      case LobbyStateEvent(lobby: final lobby):
        state = LobbyConnected(lobby);
      case UnknownEvent():
        // Ignore
        break;
    }
  }

  void _handleDisconnect() {
    if (state case LobbyConnected(lobby: final lobby)) {
      state = LobbyReconnecting(lobby);
      // WsClient handles reconnection automatically
    }
  }

  void _cleanup() {
    _subscription?.cancel();
    _subscription = null;
  }
}
```

Convenience selectors using Dart 3 pattern matching:

```dart
@riverpod
Lobby? currentLobby(CurrentLobbyRef ref) {
  final state = ref.watch(lobbyNotifierProvider);
  return switch (state) {
    LobbyConnected(lobby: final l) => l,
    LobbyReconnecting(lastKnown: final l) => l,
    LobbyError(lastKnown: final l) => l,
    _ => null,
  };
}

@riverpod
bool isConnected(IsConnectedRef ref) {
  return ref.watch(lobbyNotifierProvider) is LobbyConnected;
}
```

### User State

```dart
@riverpod
class UserNotifier extends _$UserNotifier {
  @override
  User build() {
    // Load from storage on init
    final storage = ref.read(storageProvider);
    return storage.loadUser() ?? User.guest();
  }

  Future<void> updateDisplayName(String name) async {
    final storage = ref.read(storageProvider);
    await storage.saveDisplayName(name);
    state = state.copyWith(displayName: name);
  }
}
```

### UI Pattern Matching

In widgets, use Dart 3 switch expressions (not `.when()`/`.map()`):

```dart
class LobbyScreenContent extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lobbyState = ref.watch(lobbyNotifierProvider);

    return switch (lobbyState) {
      null => const HomeRedirect(),
      LobbyLoading() => const LoadingView(),
      LobbyConnected(lobby: final lobby) => LobbyView(lobby: lobby),
      LobbyReconnecting(lastKnown: final lobby) => Stack(
        children: [
          LobbyView(lobby: lobby),
          const ReconnectingBanner(),
        ],
      ),
      LobbyError(message: final msg, lastKnown: final lobby) => lobby != null
        ? LobbyView(lobby: lobby, errorBanner: msg)
        : ErrorView(message: msg),
    };
  }
}
```

### Design Rationale

- **Auth at startup**: No loading states scattered throughout app
- **Single LobbyNotifier**: One place for all lobby state and actions
- **Explicit sealed class**: Clear connection states, easy to debug
- **Convenience selectors**: Common UI patterns pre-built
- **`@riverpod` code generation**: Type-safe, less boilerplate, autoDispose by default
- **Dart 3 patterns**: Modern switch expressions instead of `.when()`/`.map()`

---

## Dependencies

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter

  # State management - Riverpod 3.x
  flutter_riverpod: ^3.0.3
  riverpod_annotation: ^3.0.3

  # Routing - type-safe
  go_router: ^14.0.0

  # Networking
  dio: ^5.4.0                    # HTTP client - chosen for:
                                 #   • Interceptors (JWT refresh, retry, logging)
                                 #   • Global configuration (base URL, timeouts)
                                 #   • Better error handling than http package
  web_socket_client: ^0.1.0      # WebSocket with built-in reconnection/backoff

  # Storage
  flutter_secure_storage: ^9.0.0 # Token storage
  shared_preferences: ^2.2.0     # User preferences (display name)

  # Data classes
  freezed_annotation: ^2.4.0
  json_annotation: ^4.8.0

  # QR
  qr_flutter: ^4.1.0             # Display QR codes
  # mobile_scanner: ^4.0.0       # Add when implementing QR scan feature

  # UI utilities
  gap: ^3.0.0                    # Spacing widget

  # Logging
  logger: ^2.0.0                 # Structured logging with levels

dev_dependencies:
  flutter_test:
    sdk: flutter

  # Code generation
  build_runner: ^2.4.0
  riverpod_generator: ^3.0.3
  freezed: ^2.4.0
  json_serializable: ^6.7.0
  go_router_builder: ^2.4.0      # Type-safe route generation

  # Testing
  mocktail: ^1.0.0               # Mocking

  # Linting
  flutter_lints: ^3.0.0
```

### Code Generation Strategy

Since we're using Freezed for data classes, we use code generation for providers too:

**Benefits:**
- Better syntax, no manual provider type selection
- Stateful hot-reload support
- Parameters to providers unrestricted (no `.family` needed)
- Providers are `autoDispose` by default

**Development workflow:**
```bash
# Run once
dart run build_runner build --delete-conflicting-outputs

# Or watch mode during development
dart run build_runner watch --delete-conflicting-outputs
```

**Notes:**
- `mobile_scanner` deferred until QR scan feature is implemented (avoids camera permissions early)
- All generated files use `.g.dart` extension

---

## Error Handling

### Typed Error Hierarchy

```dart
sealed class ApiError implements Exception {}

class NetworkError extends ApiError {
  final String message;
  NetworkError(this.message);
}

class UnauthorizedError extends ApiError {} // 401 - handled by interceptor

class NotFoundError extends ApiError {      // 404
  final String resource;
  NotFoundError(this.resource);
}

class ValidationError extends ApiError {    // 400
  final Map<String, List<String>> fields;
  ValidationError(this.fields);
}

class ServerError extends ApiError {        // 5xx
  final int statusCode;
  ServerError(this.statusCode);
}

// Map Dio errors to typed errors
ApiError mapDioError(DioException e) {
  return switch (e.response?.statusCode) {
    401 => UnauthorizedError(),
    404 => NotFoundError(e.requestOptions.path),
    400 => ValidationError(e.response?.data['errors'] ?? {}),
    >= 500 => ServerError(e.response!.statusCode!),
    _ => NetworkError(e.message ?? 'Unknown error'),
  };
}
```

### Strategy: Exceptions + Helper Extension

Services throw typed exceptions (clean implementation):

```dart
Future<Lobby> join(String code) async {
  try {
    final response = await _client.post('/lobbies/$code/join/');
    return Lobby.fromJson(response.data);
  } on DioException catch (e) {
    throw mapDioError(e);
  }
}
```

Helper extension for common UI error handling:

```dart
extension ApiCallExtension<T> on Future<T> {
  Future<T?> withErrorHandling(
    BuildContext context, {
    String? notFoundMessage,
  }) async {
    try {
      return await this;
    } on NotFoundError {
      showSnackbar(context, notFoundMessage ?? 'Not found');
    } on ValidationError catch (e) {
      showSnackbar(context, e.fields['detail']?.first ?? 'Invalid request');
    } on NetworkError {
      showSnackbar(context, 'Check your connection');
    } on ApiError {
      showSnackbar(context, 'Something went wrong');
    }
    return null;
  }
}
```

Clean call sites with standard handling + custom messages when needed:

```dart
void _onJoinPressed() async {
  final lobby = await ref
      .read(lobbyServiceProvider)
      .join(code)
      .withErrorHandling(context, notFoundMessage: 'Lobby not found');

  if (lobby != null) {
    ref.read(lobbyNotifierProvider.notifier).connect(lobby.code);
    LobbyRoute(lobby.code).go(context);
  }
}
```

### WebSocket Errors

Handled by `LobbyConnectionState` transitions:
- Connection drop → `LobbyReconnecting` (WsClient auto-reconnects)
- Reconnect failure → `LobbyError`
- UI reacts to state changes, not raw exceptions

---

## Testing Strategy

### Test Structure

```
test/
├── core/
│   ├── api/
│   │   ├── api_client_test.dart
│   │   └── authenticated_client_test.dart
│   └── websocket/
│       ├── ws_client_test.dart
│       └── authenticated_ws_client_test.dart
│
├── features/
│   ├── auth/
│   │   └── auth_service_test.dart
│   ├── lobby/
│   │   ├── lobby_service_test.dart
│   │   ├── lobby_notifier_test.dart
│   │   ├── lobby_channel_test.dart
│   │   └── lobby_screen_test.dart
│   └── home/
│       └── home_screen_test.dart
│
└── helpers/
    ├── mocks.dart                # All mocktail mocks
    ├── test_container.dart       # ProviderContainer factory
    └── pump_app.dart             # Widget test wrapper
```

### Testing Notifiers with ProviderContainer

```dart
// test/features/lobby/lobby_notifier_test.dart
void main() {
  late MockLobbyService mockLobbyService;
  late MockLobbyChannel mockLobbyChannel;
  late ProviderContainer container;

  setUp(() {
    mockLobbyService = MockLobbyService();
    mockLobbyChannel = MockLobbyChannel();

    container = ProviderContainer(
      overrides: [
        lobbyServiceProvider.overrideWithValue(mockLobbyService),
        lobbyChannelProvider.overrideWithValue(mockLobbyChannel),
      ],
    );
  });

  tearDown(() => container.dispose());

  test('connect() transitions from null → Loading → Connected', () async {
    final states = <LobbyConnectionState?>[];
    container.listen(lobbyNotifierProvider, (_, next) => states.add(next));

    final lobby = Lobby(code: 'ABC', players: []);
    when(() => mockLobbyService.get('ABC')).thenAnswer((_) async => lobby);
    when(() => mockLobbyChannel.connect('ABC')).thenAnswer((_) => const Stream.empty());

    await container.read(lobbyNotifierProvider.notifier).connect('ABC');

    expect(states, [
      isA<LobbyLoading>(),
      isA<LobbyConnected>(),
    ]);
  });

  test('connect() transitions to Error on failure', () async {
    when(() => mockLobbyService.get('ABC')).thenThrow(NotFoundError('Lobby'));
    when(() => mockLobbyChannel.connect('ABC')).thenAnswer((_) => const Stream.empty());

    await container.read(lobbyNotifierProvider.notifier).connect('ABC');

    expect(container.read(lobbyNotifierProvider), isA<LobbyError>());
  });
}
```

### Widget Testing with State Overrides

```dart
// test/helpers/pump_app.dart
extension WidgetTesterX on WidgetTester {
  Future<void> pumpApp(Widget widget, {List<Override> overrides = const []}) async {
    await pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(home: widget),
      ),
    );
  }
}

// test/features/lobby/lobby_screen_test.dart
void main() {
  testWidgets('shows loading indicator when LobbyLoading', (tester) async {
    await tester.pumpApp(
      const LobbyScreen(code: 'ABC'),
      overrides: [
        lobbyNotifierProvider.overrideWith((ref) => LobbyLoading()),
      ],
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('shows player list when LobbyConnected', (tester) async {
    final lobby = Lobby(code: 'ABC', players: [
      Player(username: 'alice', isReady: true),
      Player(username: 'bob', isReady: false),
    ]);

    await tester.pumpApp(
      const LobbyScreen(code: 'ABC'),
      overrides: [
        lobbyNotifierProvider.overrideWith((ref) => LobbyConnected(lobby)),
      ],
    );

    expect(find.text('alice'), findsOneWidget);
    expect(find.text('bob'), findsOneWidget);
  });

  testWidgets('shows reconnecting banner when LobbyReconnecting', (tester) async {
    final lobby = Lobby(code: 'ABC', players: []);

    await tester.pumpApp(
      const LobbyScreen(code: 'ABC'),
      overrides: [
        lobbyNotifierProvider.overrideWith((ref) => LobbyReconnecting(lobby)),
      ],
    );

    expect(find.text('Reconnecting...'), findsOneWidget);
  });
}
```

### Test Helpers

```dart
// test/helpers/mocks.dart
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}
class MockAuthenticatedClient extends Mock implements AuthenticatedClient {}
class MockAuthService extends Mock implements AuthService {}
class MockLobbyService extends Mock implements LobbyService {}
class MockWsClient extends Mock implements WsClient {}
class MockLobbyChannel extends Mock implements LobbyChannel {}

// test/helpers/test_container.dart
ProviderContainer createTestContainer({List<Override> overrides = const []}) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}
```

### Coverage Targets

- **Services & channels**: 90%+
- **Notifiers**: 85%+
- **Widget tests**: 70%+ (focus on critical screens)
- **Overall**: 80%+

Skip testing:
- Generated code (freezed, riverpod_generator)
- Simple data classes with no logic
- `main.dart` app initialization

---

## Environment Configuration

Dev defaults with prod override via `--dart-define`. No extra packages needed.

```dart
// lib/core/config/env.dart
class Env {
  static const env = String.fromEnvironment('ENV', defaultValue: 'dev');

  static bool get isDev => env == 'dev';
  static bool get isProd => env == 'prod';

  static String get apiUrl => switch (env) {
    'prod' => 'https://TODO_PROD_DOMAIN/api',  // TODO: Set production URL
    _ => 'http://localhost:8000/api',
  };

  static String get wsUrl => switch (env) {
    'prod' => 'wss://TODO_PROD_DOMAIN',  // TODO: Set production URL
    _ => 'ws://localhost:8000',
  };
}
```

**justfile commands:**

```just
# Dev - just run, no flags needed
run:
    flutter run

# Prod builds - only place you need the flag
build-web:
    flutter build web --dart-define=ENV=prod

build-ios:
    flutter build ios --dart-define=ENV=prod

build-android:
    flutter build appbundle --dart-define=ENV=prod
```

**Dev workflow:** `just run` — defaults to localhost, debug enabled.

---

## Logging

Production-level structured logging using `logger` package. Not shipping to remote service yet, but infrastructure ready.

### App Logger

```dart
// lib/core/logging/app_logger.dart
import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: Env.isDev,
    dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
  ),
  level: Env.isDev ? Level.debug : Level.warning,  // Prod only logs warnings+
);

// Usage throughout app
logger.d('Debug message');      // Debug - dev only
logger.i('User joined lobby');  // Info
logger.w('Retry attempt 2');    // Warning
logger.e('Failed to connect', error: e, stackTrace: stack);  // Error
```

### Network Logging

Dio interceptor that uses the app logger:

```dart
// lib/core/api/logging_interceptor.dart
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
    logger.e('✕ ${err.requestOptions.path}', error: err);
    handler.next(err);
  }
}
```

Add to `ApiClient` and `AuthenticatedClient`:

```dart
_dio.interceptors.add(LoggingInterceptor());
```

### Future: Remote Reporting

When adding Sentry or similar, swap the `Logger` output - no changes to call sites throughout app.

---

## Security

### Token Storage

Using `flutter_secure_storage` - tokens encrypted at rest on device.

### Token Expiration Handling

Interceptor handles 401 → refresh → retry. If refresh token also expired, clear auth and redirect:

```dart
// In AuthenticatedClient interceptor
onError: (DioException e, handler) async {
  if (e.response?.statusCode == 401) {
    try {
      await _auth.refresh();
      final retryOptions = e.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer ${_auth.accessToken}';
      final response = await _dio.fetch(retryOptions);
      handler.resolve(response);
    } catch (_) {
      // Refresh failed - clear auth, app will redirect to home
      await _auth.logout();
      handler.reject(e);
    }
  } else {
    handler.next(e);
  }
}
```

```dart
// In AuthService
Future<void> logout() async {
  _tokens = null;
  await _storage.deleteAll();
  // App sees null auth state → auto-creates new guest on next action
}
```

### WebSocket Authentication

Token passed via query param: `ws://host/ws/lobby/ABC?token=xyz`

Standard approach for WebSocket auth. Alternative (token as first message) adds complexity without meaningful security benefit for this app.

### Input Validation

- **Display names**: Limit length (e.g., 20 chars), trim whitespace
- **Lobby codes**: Server-validated, 6-char alphanumeric

```dart
String sanitizeDisplayName(String name) {
  return name.trim().substring(0, min(name.length, 20));
}
```

### Not Implemented (Overkill for MVP)

- **SSL pinning** - Adds complexity, breaks on cert rotation. Add later if needed.

