# Implementation Plan: Frontend Game Integration Layer
*Path: [kitty-specs/005-frontend-game-integration-layer/plan.md](plan.md)*

**Branch**: `main` | **Date**: 2026-03-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/kitty-specs/005-frontend-game-integration-layer/spec.md`

## Summary

Build the missing screens (lobby, game container, role reveal, night waiting, discussion, reconnection overlay), wire existing game UI components to the Django backend via HTTP+WebSocket, and deliver a playable end-to-end ONUW game. The frontend uses Riverpod AsyncNotifiers for lobby/game state, a WebSocket service for real-time events, and a Dio auth interceptor for JWT management. Four small backend changes (FR-030 through FR-033) are also required.

## Technical Context

**Language/Version**: Dart SDK ^3.10.4, Flutter (stable), Python 3.12 (backend changes)
**Primary Dependencies**: Riverpod 3.0 (code-gen), GoRouter 17.0, Dio 5.9, Freezed 3.2, web_socket_channel, Django 6.0 + DRF 3.16 + Channels 4.3 (backend)
**Storage**: FlutterSecureStorage for tokens/user data (existing), PostgreSQL + Redis (backend, existing)
**Testing**: flutter_test + mocktail 1.0 (frontend), pytest 8.x (backend). 80% coverage target both sides.
**Target Platform**: Web (Chrome) primary, iOS/Android eventually
**Project Type**: Web application (monorepo: `backend/` + `frontend/`)
**Performance Goals**: <500ms for game actions, real-time updates within 2 seconds of server event
**Constraints**: Server-authoritative (no game logic client-side), phone-sized screens primary, single active game per user
**Scale/Scope**: ~10 concurrent lobbies, 3-10 players per game, 7 new screens, 4 backend endpoint changes

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Status | Notes |
|------|--------|-------|
| Server-authoritative — no game logic client-side | PASS | All game state comes from API/WebSocket. Frontend only displays and submits actions. |
| Hidden information — player-scoped API responses | PASS | GameMeSerializer already scopes data. Frontend maps IDs to names from local player list. |
| State machine — valid phase transitions | PASS | Game container switches views based on server-broadcast `phase_change` events. |
| Atomicity — @atomic for mutations | PASS (backend) | Existing backend uses `@atomic`. Frontend is read-display. |
| Determinism — seeded randomness | N/A (frontend) | No randomness in frontend. |
| No game logic in widgets | PASS | Widgets display server state and fire callbacks. Phase routing driven by GameState provider. |
| Design tokens — no hardcoded values | PASS | All new screens must use `AppTokens` via `activeThemeProvider`. |
| Riverpod code-gen patterns | PASS | Follow existing `@Riverpod(keepAlive: true)` AsyncNotifier pattern from AuthNotifier. |
| Dispose WebSocket/stream subscriptions | PASS | WebSocket service manages lifecycle; providers handle cleanup on dispose. |
| Handle loading/error with AsyncValue | PASS | All async state uses Riverpod AsyncValue patterns. |
| Tests verify behavior not implementation | PASS | Test user-visible outcomes (screen shows correct phase, action submits correctly). |
| ONUW engine stays pure Python | PASS | Backend changes are in serializers/views/consumers, not engine. |
| 80% coverage enforced | PASS | Both frontend and backend maintain coverage targets. |

## Project Structure

### Documentation (this feature)

```
kitty-specs/005-frontend-game-integration-layer/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── lobby-api.md     # Lobby HTTP + WebSocket contracts
│   └── game-api.md      # Game HTTP + WebSocket contracts
└── tasks.md             # Phase 2 output (NOT created by /spec-kitty.plan)
```

### Source Code (repository root)

```
backend/
├── apps/
│   ├── core/
│   │   ├── consumers.py      # LobbyConsumer — add game_started handler (FR-031)
│   │   ├── views.py           # Add PATCH lobby endpoint (FR-030)
│   │   ├── urls.py            # Register PATCH route
│   │   └── serializers.py     # Lobby settings serializer
│   └── onuw/
│       ├── consumers.py       # GameConsumer (existing, no changes)
│       ├── serializers.py     # Add roles_in_game (FR-032), elimination_reason (FR-033)
│       └── views.py           # ResultsView — add elimination_reason
└── tests/

frontend/
├── lib/
│   ├── core/
│   │   ├── api/
│   │   │   ├── api_client.dart          # Existing — stays unauthenticated
│   │   │   ├── authenticated_client.dart # NEW: Wraps Dio with auth interceptor
│   │   │   └── auth_interceptor.dart    # NEW: JWT bearer + refresh via QueuedInterceptor
│   │   ├── router/
│   │   │   └── routes.dart              # Add lobby, game, results routes
│   │   └── websocket/
│   │       ├── websocket_channel.dart       # NEW: Promote WebSocketChannelInterface from test
│   │       └── reconnecting_websocket.dart  # NEW: Production impl with exponential backoff
│   ├── features/
│   │   ├── auth/                        # Existing (minor extensions)
│   │   ├── lobby/
│   │   │   ├── data/
│   │   │   │   └── lobby_service.dart   # NEW: HTTP calls for lobby CRUD
│   │   │   ├── domain/
│   │   │   │   └── lobby_state.dart     # NEW: Freezed lobby state model
│   │   │   └── presentation/
│   │   │       ├── lobby_notifier.dart   # NEW: Riverpod AsyncNotifier
│   │   │       ├── lobby_screen.dart     # NEW: Lobby UI
│   │   │       └── role_config/
│   │   │           └── role_config_widget.dart  # NEW: Role +/- controls + presets
│   │   └── game/
│   │       ├── data/
│   │       │   └── game_service.dart     # NEW: HTTP calls for game actions
│   │       ├── domain/
│   │       │   └── game_state.dart       # NEW: Freezed game state model
│   │       └── presentation/
│   │           ├── game_notifier.dart    # NEW: Riverpod AsyncNotifier
│   │           ├── game_container.dart   # NEW: Phase-switching shell
│   │           ├── role_reveal_view.dart # NEW: Card flip animation
│   │           ├── night_phase/
│   │           │   ├── night_action_view.dart    # NEW: Wraps NightActionPrompt + result
│   │           │   ├── night_result_view.dart    # NEW: Action result display
│   │           │   ├── night_waiting_view.dart   # NEW: "Village sleeps..." screen
│   │           │   └── seer_choice_view.dart     # NEW: peek_player vs peek_center
│   │           ├── discussion_view.dart  # NEW: Timer + roles + host controls
│   │           ├── voting_view.dart      # NEW: Wraps VoteSubmission + progress
│   │           ├── vote_reveal_view.dart # NEW: Wraps VoteReveal with staging
│   │           └── results_view.dart     # NEW: Wraps GameResults with data fetch
│   └── design_system/
│       ├── components/game/
│       │   └── night_action_prompt.dart  # MODIFY: Fix empty-state messages
│       └── models/
│           └── game_result.dart          # MODIFY: Add voteTargetName, centerCards, nullable VoteResult fields
└── test/
    ├── features/
    │   ├── lobby/
    │   │   ├── lobby_service_test.dart
    │   │   ├── lobby_notifier_test.dart
    │   │   └── lobby_screen_test.dart
    │   └── game/
    │       ├── game_service_test.dart
    │       ├── game_notifier_test.dart
    │       ├── game_container_test.dart
    │       └── night_phase/
    │           └── night_action_view_test.dart
    ├── core/
    │   ├── websocket_service_test.dart
    │   └── auth_interceptor_test.dart
    └── helpers/
        └── mock_websocket.dart           # Existing test helper
```

**Structure Decision**: Follows the existing monorepo layout. Frontend features organized by domain (`lobby/`, `game/`) with the established `data/domain/presentation` layer pattern from `features/auth/`. Backend changes are minimal additions to existing apps.

## Architecture Decisions

### 1. WebSocket Connection (ReconnectingWebSocket)

A `ReconnectingWebSocket` class implements `WebSocketChannelInterface` (promoted from `test/helpers/mock_websocket.dart` to `lib/core/websocket/websocket_channel.dart`). It wraps `web_socket_channel`'s `WebSocketChannel` and adds:
- JWT token injection as query parameter: `ws://host/ws/game/123/?token=<jwt>`
- Automatic reconnection on close/error with exponential backoff (1s, 2s, 4s, 8s, max 30s)
- `connectionState` stream (connecting, connected, disconnected, reconnecting) for the reconnection overlay
- `dispose()` to stop reconnection attempts

A Riverpod family provider (`webSocketConnectionProvider(url)`) creates/manages one connection at a time. Tests swap in `MockWebSocketChannel` via provider overrides.

**Why implement the test interface**: The test harness already defines `WebSocketChannelInterface`. Production code implementing the same interface means tests work without changing provider types.

### 2. State Management (Riverpod AsyncNotifier per Domain)

Two primary notifiers following the AuthNotifier pattern:

- **LobbyNotifier**: Manages lobby state (players, ready states, host flag, settings). Updates from both HTTP responses and WebSocket events. Disposed when leaving lobby.
- **GameNotifier**: Manages game state (phase, wave, deadline, role, action prompt, players, results). Updates from HTTP (initial fetch, reconnect) and WebSocket events (real-time). Disposed when leaving game.

Both use `@Riverpod(keepAlive: true)` and Freezed state models, consistent with AuthNotifier.

### 3. Phase Routing (Widget-Level, Not GoRouter)

The game container is a single GoRouter route (`/game/:gameId`). Phase switching happens inside the container widget based on `GameState.phase`:
- `night` → Night sub-views (waiting, action prompt, result)
- `discussion` → Discussion view
- `voting` → Voting view (VoteSubmission → VoteReveal staging)
- `results` → Results view

**Why not GoRouter sub-routes per phase**: Phase transitions are server-driven via WebSocket. Using GoRouter would require syncing URL state with server state, adding complexity with no benefit. The game container pattern is simpler and guarantees the displayed phase matches server state.

### 4. Auth Interceptor (Separate Authenticated Client)

A separate `AuthenticatedClient` wrapping Dio with an `AuthInterceptor`, rather than modifying the existing `ApiClient`. The existing `ApiClient` is deliberately unauthenticated — used for public endpoints like guest registration and token refresh. Adding auth to it would create circular dependency (interceptor calls refresh endpoint through itself).

- `AuthInterceptor` (Dio `QueuedInterceptorsWrapper`) reads access token from `TokenStorage`, adds `Authorization: Bearer <token>` header
- On 401 response, calls `/auth/token/refresh/` via the unauthenticated `ApiClient` (no recursion), saves new tokens, retries
- On refresh failure, clears tokens and signals auth notifier to redirect to auth screen
- `AuthenticatedClient` provides the same API surface (get, post, patch, delete) with its own Dio instance

### 5. Timer Provider (Computed from Server Deadline)

A Riverpod provider that computes remaining time as `deadline - DateTime.now()`, updating every second via a `Timer.periodic`. The spec explicitly requires server-deadline-driven timers (not client-side duration) to avoid clock drift.

### 6. Reconnection Overlay (Global Overlay Widget)

The reconnection overlay is a widget in the `MvScaffold` or app shell that listens to WebSocket connection state. When disconnected, it shows a semi-transparent overlay with spinner. When reconnected, it:
1. Dismisses the overlay
2. Triggers a re-fetch of current game state via `GET /games/<id>/me/`
3. The GameNotifier updates, and the game container re-renders the correct phase

### 7. Backend Changes (Minimal, Scoped)

Four backend changes per FR-030 through FR-033:
- **FR-030**: PATCH `/api/lobbies/<code>/` — host-only settings update with lobby_update broadcast
- **FR-031**: `game_started` handler on LobbyConsumer — forward event to WebSocket clients
- **FR-032**: `roles_in_game` field on GameMeSerializer — serialize game settings roles
- **FR-033**: `elimination_reason` on results endpoint — distinguish vote vs Hunter chain

All are additive. No existing API contracts change. All existing tests must continue to pass.

## Complexity Tracking

*No constitution violations to justify.*
