# Implementation Plan: Frontend Game Integration Layer
*Path: kitty-specs/005-frontend-game-integration-layer/plan.md*

**Branch**: `main` | **Date**: 2026-03-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/kitty-specs/005-frontend-game-integration-layer/spec.md`

## Summary

Build the missing screens, wire existing UI components to the Django backend, and deliver a playable end-to-end ONUW game. The frontend already has a design system with game-phase widgets (NightActionPrompt, VoteSubmission, VoteReveal, GameResults, etc.) but lacks assembled screens, backend connectivity, WebSocket integration, and game state management. This feature adds:

1. **Auth interceptor** — JWT bearer token injection and automatic refresh for all authenticated API calls
2. **WebSocket layer** — cross-platform WebSocket client with exponential backoff reconnection
3. **State management** — Riverpod notifiers for lobby and game state, driven by HTTP responses and WebSocket events
4. **New screens** — Lobby, game container (phase router), role reveal, night waiting, Seer choice, night action result, discussion, reconnection overlay
5. **Backend glue** — 4 small backend additions (lobby PATCH, game_started handler, roles_in_game field, elimination_reason field)

## Technical Context

**Language/Version**: Dart SDK ^3.10.4, Flutter (stable), Python 3.12 (backend changes)
**Primary Dependencies**: Riverpod 3.0 (code-gen), GoRouter 17.0, Dio 5.9, Freezed 3.2, web_socket_channel ^3.0.0 (new), Django 6.0 / DRF 3.16 / Channels 4.3 (backend)
**Storage**: flutter_secure_storage (JWT tokens, user profile) — no local game state persistence
**Testing**: flutter_test + mocktail 1.0 + fake_async (frontend), pytest 8.x (backend changes)
**Target Platform**: Web (Chrome) primary, iOS/Android eventually — all code must be cross-platform
**Project Type**: Monorepo — `frontend/` (Flutter) + `backend/` (Django)
**Performance Goals**: <500ms for game actions, <2s for real-time updates (WebSocket events), 60fps UI animations
**Constraints**: Phone-sized screens primary, server-authoritative (no client game logic), one WebSocket at a time, one active game per user
**Scale/Scope**: 3–10 players per game, ~10 concurrent lobbies, 7 new screens, ~25 new files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| Server-authoritative | PASS | Frontend sends actions via HTTP POST, receives state via WebSocket. No game logic client-side. |
| Hidden information | PASS | Frontend only displays data from player-scoped API responses. Vote targets hidden until vote_reveal. Roles hidden until results. |
| State machine | PASS | Phase transitions driven by server WebSocket events. Frontend treats server as authoritative. |
| Atomicity | N/A | Atomicity is a backend concern — frontend doesn't mutate game state. |
| Determinism | N/A | Randomness is server-side — frontend has no RNG. |
| Separate game apps | PASS | Frontend feature structure mirrors backend: `features/lobby/` (core) and `features/game/` (ONUW-specific). |
| HTTP for state changes, WS for events | PASS | All player actions via REST POST. All real-time updates via WebSocket. |
| No game logic in widgets | PASS | Widgets display server state. Phase routing driven by GameNotifier state, not widget logic. |
| Design tokens | PASS | All new screens use `AppTokens` via `activeThemeProvider`. No hardcoded colors/spacing/typography. |
| Riverpod code-gen patterns | PASS | All new providers use `@riverpod` annotations with code generation. |
| Dispose resources | PASS | WebSocket connections and stream subscriptions disposed via `ref.onDispose`. |
| Handle loading/error states | PASS | AsyncNotifier provides AsyncValue for loading/error. Reconnection overlay for WebSocket drops. |

**Post-Phase 1 re-check**: All gates still pass. Data model adds no client-side game logic. API contracts confirm HTTP-for-actions, WS-for-events pattern. WebSocket design includes proper disposal.

## Project Structure

### Documentation (this feature)

```
kitty-specs/005-frontend-game-integration-layer/
├── plan.md              # This file
├── research.md          # Phase 0 — 9 research decisions (auth, WS, state, routing, etc.)
├── data-model.md        # Phase 1 — all Freezed models, provider signatures
├── quickstart.md        # Phase 1 — developer setup guide
├── contracts/
│   └── api-contracts.md # Phase 1 — REST + WebSocket contracts
└── tasks.md             # Phase 2 output (NOT created by /spec-kitty.plan)
```

### Source Code (repository root)

```
frontend/
├── lib/
│   ├── core/
│   │   ├── api/
│   │   │   ├── api_client.dart              # Existing — unauthenticated HTTP client
│   │   │   ├── api_exception.dart           # Existing — exception hierarchy
│   │   │   ├── auth_interceptor.dart        # NEW — JWT bearer + auto-refresh
│   │   │   ├── authenticated_client.dart    # NEW — Dio wrapper with interceptor
│   │   │   └── logging_interceptor.dart     # Existing
│   │   ├── config/
│   │   │   └── env.dart                     # UPDATE — add wsUrl getter
│   │   ├── router/
│   │   │   ├── routes.dart                  # UPDATE — add LobbyRoute, GameRoute
│   │   │   ├── routes.g.dart                # REGENERATE
│   │   │   └── app_router.dart              # UPDATE — add auth redirect guard
│   │   ├── websocket/
│   │   │   ├── websocket_channel.dart       # NEW — interface + connection state enum + event model
│   │   │   └── reconnecting_websocket.dart  # NEW — production impl with backoff
│   │   └── storage/                         # Existing — no changes
│   ├── design_system/
│   │   ├── models/
│   │   │   ├── game_result.dart             # UPDATE — nullable VoteResult targets, PlayerResult vote/elimination fields, GameResult centerCards/votes
│   │   │   └── ...                          # Existing — no other model changes
│   │   └── components/game/
│   │       └── night_action_prompt.dart     # UPDATE — fix empty team text for Mason/Minion
│   ├── features/
│   │   ├── auth/
│   │   │   └── presentation/
│   │   │       ├── auth_notifier.dart       # UPDATE — add authenticatedClientProvider
│   │   │       └── home_screen.dart         # UPDATE — add lobby create/join UI
│   │   ├── lobby/                           # NEW feature module
│   │   │   ├── domain/
│   │   │   │   ├── lobby_state.dart         # Freezed: LobbyState, LobbyPlayer
│   │   │   │   └── role_config.dart         # Validation, presets, step sizes
│   │   │   ├── data/
│   │   │   │   └── lobby_service.dart       # HTTP: create, join, leave, ready, start, updateRoles
│   │   │   └── presentation/
│   │   │       ├── lobby_notifier.dart      # Riverpod: state + WS events
│   │   │       ├── lobby_notifier.g.dart    # GENERATED
│   │   │       ├── lobby_screen.dart        # Lobby UI assembly
│   │   │       └── role_config_sheet.dart   # Role selection bottom sheet
│   │   └── game/                            # NEW feature module
│   │       ├── domain/
│   │       │   ├── game_session_state.dart  # Freezed: GameSessionState, YourRole, GamePlayer
│   │       │   ├── night_state.dart         # Freezed: ActionPrompt, ActionResult, NightSubView
│   │       │   └── voting_state.dart        # Freezed: VoteProgress, VoteRevealData
│   │       ├── data/
│   │       │   └── game_service.dart        # HTTP: submitAction, submitVote, endDiscussion, fetchResults, fetchMe
│   │       └── presentation/
│   │           ├── game_notifier.dart       # Riverpod: game state machine + WS events
│   │           ├── game_notifier.g.dart     # GENERATED
│   │           ├── timer_provider.dart      # Countdown from server deadline
│   │           ├── game_container_screen.dart  # Phase router shell
│   │           ├── role_reveal_view.dart    # Card flip animation
│   │           ├── night_waiting_view.dart  # "The village sleeps..."
│   │           ├── seer_choice_view.dart    # peek_player vs peek_center
│   │           ├── night_result_view.dart   # Action result display
│   │           ├── discussion_view.dart     # Timer + roles + host controls
│   │           ├── voting_view.dart         # VoteSubmission wrapper with progress
│   │           ├── vote_reveal_view.dart    # VoteReveal wrapper with fallback
│   │           ├── results_view.dart        # GameResults wrapper with data fetch
│   │           └── reconnection_overlay.dart # WS disconnect overlay
│   └── main.dart                            # Existing — no changes
├── test/
│   ├── core/api/
│   │   └── auth_interceptor_test.dart       # NEW
│   ├── core/websocket/
│   │   └── reconnecting_websocket_test.dart # NEW
│   ├── features/lobby/
│   │   ├── domain/role_config_test.dart     # NEW
│   │   ├── data/lobby_service_test.dart     # NEW
│   │   └── presentation/lobby_notifier_test.dart # NEW
│   ├── features/game/
│   │   ├── data/game_service_test.dart      # NEW
│   │   ├── presentation/game_notifier_test.dart  # NEW
│   │   └── presentation/timer_provider_test.dart # NEW
│   └── helpers/
│       └── mock_websocket.dart              # UPDATE — promote interface to lib/
└── integration_test/
    └── game_flow_test.dart                  # NEW — end-to-end lobby→game→results

backend/
├── apps/core/
│   ├── views.py                             # UPDATE — add PATCH handler to LobbyDetailView (FR-030)
│   └── consumers.py                         # UPDATE — add game_started handler to LobbyConsumer (FR-031)
├── apps/onuw/
│   ├── serializers.py                       # UPDATE — add roles_in_game to GameMeSerializer (FR-032)
│   └── views.py                             # UPDATE — add elimination_reason to results (FR-033)
└── tests/
    ├── core/test_lobby_patch.py             # NEW
    ├── core/test_game_started_handler.py    # NEW
    └── onuw/test_results_elimination_reason.py # NEW
```

**Structure Decision**: Monorepo with existing `frontend/` + `backend/` layout. Frontend follows the established feature-based architecture (`features/<name>/domain/`, `data/`, `presentation/`). New features (`lobby/`, `game/`) parallel the existing `auth/` feature structure. Core infrastructure (`websocket/`, `api/`) lives in `core/`. No new top-level directories needed.

## Complexity Tracking

No constitution violations. The feature is large in scope (7 new screens, 2 new feature modules, WebSocket layer, 4 backend changes) but architecturally straightforward — it follows existing patterns (Riverpod notifiers, Freezed models, GoRouter typed routes, feature-module layout) and composes existing design system widgets.

## Phase 0: Research

**Status**: Complete. See [research.md](research.md).

9 research decisions documented:

| # | Topic | Decision |
|---|-------|----------|
| R1 | Auth interceptor | Separate `AuthenticatedClient` with `QueuedInterceptorsWrapper` to avoid circular refresh dependency |
| R2 | WebSocket management | `ReconnectingWebSocket` implementing `WebSocketChannelInterface` (promoted from test helpers) |
| R3 | State management | Two `AsyncNotifier`s (LobbyNotifier, GameNotifier) following AuthNotifier pattern |
| R4 | Routing | Extend GoRouter with `LobbyRoute`, `GameRoute`, auth redirect guard |
| R5 | WebSocket auth | JWT as query parameter (browser WebSocket API doesn't support custom headers) |
| R6 | Night sub-views | State machine enum in GameNotifier, not URL routing |
| R7 | Model updates | Extend existing Freezed models in-place (nullable VoteResult targets, PlayerResult vote/elimination fields) |
| R8 | Package additions | Only `web_socket_channel ^3.0.0` (everything else already in pubspec) |
| R9 | Backend changes | 4 targeted additions, no architectural changes (FR-030 through FR-033) |

## Phase 1: Design & Contracts

**Status**: Complete.

### Artifacts

- **[data-model.md](data-model.md)** — All Freezed model definitions:
  - Updated: `VoteResult` (nullable targets), `PlayerResult` (+voteTarget, +eliminationReason), `GameResult` (+votes, +centerCards)
  - New: `LobbyState`, `LobbyPlayer`, `RoleConfig`, `GameSessionState`, `YourRole`, `GamePlayer`, `ActionPrompt`, `ActionResult`, `NightSubView`, `VoteProgress`, `VoteRevealData`, `WebSocketConnectionState`, `WebSocketEvent`
  - New providers: `authenticatedClientProvider`, `lobbyServiceProvider`, `lobbyNotifierProvider`, `gameServiceProvider`, `gameNotifierProvider`, `countdownTimerProvider`, `webSocketConnectionProvider`

- **[contracts/api-contracts.md](contracts/api-contracts.md)** — Complete REST and WebSocket contracts:
  - 12 REST endpoints (2 existing auth, 6 lobby, 4 game) with request/response shapes
  - 2 WebSocket channels (lobby: 5 event types, game: 8 event types) with frontend action per event
  - Action request formats for all 7 night action types + skip
  - Frontend-to-backend mapping table

- **[quickstart.md](quickstart.md)** — Developer setup guide:
  - Prerequisites, dependency setup (only `web_socket_channel` is new)
  - Development workflow for Freezed models, Riverpod providers, GoRouter routes
  - Quality gates and testing strategy
  - Key files ordered by implementation dependency

### Architecture Decisions

```
                    ┌─────────────────────┐
                    │     GoRouter        │
                    │  / → HomeScreen     │
                    │  /lobby/:code →     │
                    │    LobbyScreen      │
                    │  /game/:id →        │
                    │    GameContainer    │
                    └────────┬────────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
     ┌────────▼───────┐ ┌───▼──────┐ ┌─────▼──────┐
     │  AuthNotifier   │ │ Lobby    │ │  Game      │
     │  (keepAlive)    │ │ Notifier │ │  Notifier  │
     │                 │ │ (family) │ │  (family)  │
     └────────┬───────┘ └───┬──────┘ └─────┬──────┘
              │              │              │
     ┌────────▼───────┐ ┌───▼──────┐ ┌─────▼──────┐
     │ AuthRepository  │ │ Lobby    │ │  Game      │
     │ AuthService     │ │ Service  │ │  Service   │
     └────────┬───────┘ └───┬──────┘ └─────┬──────┘
              │              │              │
     ┌────────▼───────┐ ┌───▼──────────────▼──────┐
     │   ApiClient     │ │   AuthenticatedClient    │
     │ (unauthenticated│ │ (JWT interceptor + Dio)  │
     │  for auth calls)│ └───────────┬─────────────┘
     └────────────────┘              │
                          ┌──────────▼──────────┐
                          │  ReconnectingWebSocket│
                          │  (lobby OR game)     │
                          └─────────────────────┘
```

**Night phase sub-view state machine** (driven by WebSocket events, not URL routing):

```
wave_start/wave_waiting ──→ WAITING
action_prompt (multi)   ──→ SEER_CHOICE ──→ ACTION_PROMPT
action_prompt (single)  ──→ ACTION_PROMPT
action_result           ──→ ACTION_RESULT
see_team empty + wolf   ──→ LONE_WEREWOLF_PEEK
wave_complete           ──→ WAITING
phase_change            ──→ (exit night)
```

**Game container phase routing** (in GameContainerScreen):

```
GamePhase.night      → NightSubView state machine
GamePhase.discussion → DiscussionView
GamePhase.voting     → VotingView / VoteRevealView
GamePhase.results    → ResultsView
(+ RoleRevealView as initial interstitial before night)
```
