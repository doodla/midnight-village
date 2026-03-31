# Research: Frontend Game Integration Layer

**Feature**: 005-frontend-game-integration-layer
**Date**: 2026-03-31

## R1: Auth Interceptor Architecture

**Decision**: Create a separate `AuthenticatedClient` wrapping Dio with an `AuthInterceptor`, rather than modifying the existing `ApiClient`.

**Rationale**: The existing `ApiClient` is deliberately unauthenticated — used for public endpoints like guest registration and token refresh. Adding auth to it would create a circular dependency: the interceptor needs to call the refresh endpoint, which would go through the interceptor itself. A separate authenticated client avoids this cleanly.

**Design**:
- `AuthInterceptor` (Dio `Interceptor`) reads the access token from `TokenStorage`, adds `Authorization: Bearer <token>` header on every request.
- On 401 response, the interceptor reads the refresh token from `TokenStorage`, calls `/auth/token/refresh/` via the unauthenticated `ApiClient` (no recursion), saves new tokens, and retries the original request.
- If refresh fails (401 from refresh endpoint), the interceptor clears tokens and signals the auth notifier to redirect to the auth screen.
- `AuthenticatedClient` extends `ApiClient`'s API surface (get, post, patch, delete) but uses its own Dio instance with the interceptor attached.

**Alternatives considered**:
- *Modifying ApiClient to conditionally add interceptor*: Rejected — mixes concerns, makes testing harder, risks interceptor recursion.
- *Using Dio's QueuedInterceptor for token refresh*: Considered — `QueuedInterceptorsWrapper` serializes requests during refresh, preventing multiple simultaneous refresh calls. Worth using if concurrent requests are common. Decision: use `QueuedInterceptorsWrapper` since game state polling and WebSocket reconnection can trigger concurrent requests.

**Existing code informing this**: `api_client.dart:12-29` (unauthenticated Dio setup), `auth_service.dart:81-110` (refresh token call pattern), `auth_notifier.dart:41-47` (state management on auth failure).

## R2: WebSocket Connection Management

**Decision**: Create a `ReconnectingWebSocket` wrapper in `core/websocket/` that implements `WebSocketChannelInterface` (already defined in test helpers) and adds automatic reconnection with exponential backoff.

**Rationale**: The test harness already defines `WebSocketChannelInterface` (`test/helpers/mock_websocket.dart:8-20`) as the contract. Production code should implement this same interface so tests can swap in `MockWebSocketChannel` without changing provider types.

**Design**:
- `WebSocketChannelInterface` is promoted from `test/helpers/` to `lib/core/websocket/websocket_channel.dart` as the canonical interface.
- `ReconnectingWebSocket` wraps `web_socket_channel`'s `WebSocketChannel`, implements `WebSocketChannelInterface`, and adds:
  - Automatic reconnection on close/error with exponential backoff (1s, 2s, 4s, 8s, max 30s)
  - `connectionState` stream (connecting, connected, disconnected, reconnecting) for the reconnection overlay
  - JWT token injection as query parameter: `ws://host/ws/game/123/?token=<jwt>`
  - `dispose()` to stop reconnection attempts
- A Riverpod provider (`webSocketConnectionProvider`) creates/manages the connection lifecycle, disposing on navigation away.
- The test `webSocketProvider` (already in `test_harness.dart:56-59`) remains unchanged — it provides `MockWebSocketChannel`.

**Alternatives considered**:
- *Using `dart:io` WebSocket directly*: Rejected — not available on web platform. `web_socket_channel` provides cross-platform support.
- *Single global WebSocket*: Rejected — the app connects to one channel at a time (lobby OR game), but channels have different URLs. The provider manages one connection, disposed and recreated on navigation.
- *`web_socket_channel` reconnection plugins*: No mature package found. Custom implementation is small (~80 lines) and gives full control over backoff and state reporting.

**Existing code informing this**: `mock_websocket.dart` (interface contract), `test_harness.dart:52-59` (provider shape), `env.dart:12-23` (URL pattern).

## R3: State Management Architecture

**Decision**: Two Riverpod `AsyncNotifier`s — `LobbyNotifier` and `GameNotifier` — following the existing `AuthNotifier` pattern. Each coordinates HTTP responses with WebSocket events.

**Rationale**: The auth feature uses `@Riverpod(keepAlive: true)` with `_$AuthNotifier` code-gen. Lobby and game state have the same shape: initial HTTP fetch for state, WebSocket events for real-time updates, error handling for API failures.

**Design**:
- **LobbyNotifier** (`@Riverpod(keepAlive: false)` — disposed when leaving lobby):
  - `build(String lobbyCode)`: Fetches lobby state via GET, connects lobby WebSocket, listens to events.
  - Methods: `toggleReady()`, `startGame()`, `leave()`, `updateRoleConfig(Map<RoleId, int>)`.
  - WebSocket events update state: `player_joined` → re-fetch full lobby (spec US3 AS7), `player_ready` → toggle in list, `lobby_update` → update settings, `game_started` → navigate to game.
  - Disposed via `ref.onDispose` — closes WebSocket, cancels subscriptions.

- **GameNotifier** (`@Riverpod(keepAlive: false)` — disposed when leaving game):
  - `build(String gameId)`: Fetches game state via GET `/games/<id>/me/`, connects game WebSocket, listens to events.
  - Methods: `submitAction(actionType, targets)`, `submitVote(targetPlayerId)`, `endDiscussion()`.
  - WebSocket events drive phase/sub-view transitions: `wave_start`, `action_prompt`, `action_result`, `wave_complete`, `phase_change`, `vote_submitted`, `vote_reveal`, `game_results`.
  - Sub-states derived via `select()`: `currentPhaseProvider`, `nightStateProvider`, `voteProgressProvider`, `timerDeadlineProvider`.

- **TimerProvider** (separate, reusable):
  - Takes a `DateTime? deadline`, ticks every second, computes remaining `Duration`.
  - Uses `Timer.periodic` inside a `@riverpod` function provider.
  - Returns `null` when deadline is null or passed.

**Alternatives considered**:
- *Single GameNotifier for both lobby and game*: Rejected — lobby and game have different WebSocket channels, different state shapes, different lifecycles. Merging them would create a god-object.
- *StateNotifier instead of AsyncNotifier*: Rejected — `AsyncNotifier` provides `AsyncValue` out of the box for loading/error states, matching the auth pattern.
- *Separate providers per phase*: Rejected — game state is a single entity that transitions between phases. Splitting would duplicate the WebSocket subscription logic.

**Existing code informing this**: `auth_notifier.dart` (Riverpod pattern), `auth_state.dart` (Freezed sealed class pattern), `test_harness.dart:25-50` (placeholder types to replace).

## R4: Routing and Navigation

**Decision**: Extend existing GoRouter with typed routes and an auth redirect guard.

**Rationale**: The app uses `go_router` with `@TypedGoRoute` code-gen (`routes.dart:9`). Only `HomeRoute` exists. Adding lobby and game routes follows the same pattern. Auth guard uses `redirect` callback checking `AuthNotifier` state.

**Design**:
- `HomeRoute` (existing, path: `/`)
- `LobbyRoute` (new, path: `/lobby/:code`) — requires auth
- `GameRoute` (new, path: `/game/:gameId`) — requires auth
- Auth redirect: `GoRouter.redirect` callback reads `authNotifierProvider`. If unauthenticated and target requires auth, redirect to `/`. If authenticated and startup detects active game via `/me/current-game/`, redirect to `/game/:id`.
- Game-start navigation: On `game_started` WebSocket event, `LobbyNotifier` calls `context.go('/game/$gameId')`.
- Results exit: "Return to Home" calls `context.go('/')`.

**Alternatives considered**:
- *Shell routes for game container*: Considered — `ShellRoute` could wrap game sub-views with `PhaseIndicator` and `AtmosphericBackground`. But the game container is already a single screen that internally switches sub-views via state, not via nested routes. Using shell routes would push phase state into the URL, which doesn't match the server-driven model.
- *Named routes instead of typed routes*: Rejected — typed routes are the established pattern and provide compile-time safety.

**Existing code informing this**: `routes.dart` (TypedGoRoute pattern), `app_router.dart` (router config), `app.dart` (MaterialApp.router).

## R5: WebSocket Auth Token Passing

**Decision**: Pass JWT as a query parameter in the WebSocket URL.

**Rationale**: Django Channels' `TokenAuthMiddleware` (or custom middleware) typically reads the token from query params during the ASGI handshake. The browser's WebSocket API doesn't support custom headers, so query params are the standard approach for web clients. The backend consumers already require JWT in scope.

**Design**: `ws://host/ws/game/<id>/?token=<access_token>`. The `ReconnectingWebSocket` reads the current access token from `TokenStorage` at connection time (and on each reconnection attempt, to pick up refreshed tokens).

**Alternatives considered**:
- *Cookie-based auth*: Rejected — the app uses JWT, not sessions. Adding cookie auth would be a separate auth mechanism.
- *First-message auth*: Rejected — Django Channels authenticates during the ASGI upgrade, not after connection. A message-based auth would require custom consumer logic that doesn't exist.

**Existing code informing this**: Backend consumers (JWT in scope), `token_storage.dart` (async token access).

## R6: Night Phase Sub-View Routing

**Decision**: The game container uses a state machine (not URL routing) to determine which night sub-view to show.

**Rationale**: The night phase has complex sub-view transitions that are driven by WebSocket events, not user navigation: waiting → action prompt → result → waiting → next wave. The Seer has an extra choice step. The Doppelganger has multi-step flows. URL routing can't express these transient states cleanly.

**Design**: `GameNotifier` maintains a `NightSubView` enum:
- `waiting` — shows `NightWaitingView`
- `seerChoice` — shows `SeerChoiceView` (when `action_prompt.action_types.length > 1`)
- `actionPrompt` — shows `NightActionPrompt` (existing widget)
- `actionResult` — shows `NightResultView`
- `loneWerewolfPeek` — shows `CenterCards` with `maxSelections: 1` after empty team display

WebSocket events drive transitions:
- `wave_start` / `wave_waiting` → `waiting`
- `action_prompt` with multiple types → `seerChoice`
- `action_prompt` with single type → `actionPrompt`
- `action_result` → `actionResult`
- `wave_complete` → `waiting` (until next event)

**Existing code informing this**: `night_action_prompt.dart` (existing widget API), `night_action.dart` (NightActionType enum), `center_cards.dart` (maxSelections parameter).

## R7: Model Updates to Existing Design System

**Decision**: Extend existing Freezed models in-place rather than creating parallel models.

**Rationale**: The design system models (`GameResult`, `VoteResult`, `PlayerResult`) are already used by existing widgets. Creating separate "integration" models would require mapping layers. Instead, extend the existing models with the missing fields.

**Changes**:
- `VoteResult`: Make `targetId` and `targetName` nullable (`String?`) — abstainers have null targets.
- `PlayerResult`: Add `voteTargetId` (`String?`), `voteTargetName` (`String?`), `eliminationReason` (`EliminationReason?` enum: `vote`, `hunterChain`).
- `GameResult`: Add `centerCards` (`List<RoleId>`), `votes` (`List<VoteResult>`).

**Existing code informing this**: `game_result.dart` (current model shapes), `game_results_test.dart` (existing tests to update), `vote_reveal.dart` (VoteResult usage).

## R8: Package Additions

**Decision**: Add `web_socket_channel` as the only new dependency.

**Rationale**: The project already has all other needed packages (Dio, Riverpod, Freezed, GoRouter, flutter_secure_storage). `web_socket_channel` is the standard Flutter package for cross-platform WebSocket support.

**Package**: `web_socket_channel: ^3.0.0` (latest stable, supports web + mobile).

**Existing code informing this**: `pubspec.yaml` (current dependencies), `mock_websocket.dart` (interface already modeled after web_socket_channel's API).

## R9: Backend Changes Scope

**Decision**: Four targeted backend additions, no architectural changes.

| FR | Change | File | Scope |
|----|--------|------|-------|
| FR-030 | PATCH `/api/lobbies/<code>/` | `backend/apps/core/views.py` | New view method on `LobbyDetailView`. Host-only (403 for non-host). Validates settings same as `GameStartView`. Broadcasts `lobby_update` via WS. |
| FR-031 | `game_started` handler | `backend/apps/core/consumers.py` | Add `game_started` method to `LobbyConsumer` that forwards `game.started` channel event to WebSocket clients. ~5 lines. |
| FR-032 | `roles_in_game` field | `backend/apps/onuw/serializers.py` | Add `roles_in_game` to `GameMeSerializer` from `game.settings["roles"]`. SerializerMethodField. |
| FR-033 | `elimination_reason` field | `backend/apps/onuw/views.py` | Add per-player `elimination_reason` (`"vote"` or `"hunter_chain"`) to results endpoint response. Requires reading from game resolution data. |

All existing backend tests must continue to pass. New tests required for each change.
