# Implementation Plan: Frontend Game Integration Layer

**Branch**: `main` | **Date**: 2026-03-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/kitty-specs/005-frontend-game-integration-layer/spec.md`

## Summary

Build the frontend integration layer that connects existing Flutter UI components to the Django backend, delivering a playable end-to-end ONUW game. This includes: JWT auth interceptor, WebSocket connection management with reconnection, Riverpod state management for lobby and game phases, 7 new screens/views (lobby, game container, role reveal, night waiting, night result, Seer choice, discussion), routing with auth guards, and 4 small backend additions (lobby PATCH, game_started handler, roles_in_game field, elimination_reason field).

## Technical Context

**Language/Version**: Dart SDK ^3.10.4 (Flutter stable) + Python 3.12 (Django 6.0 backend changes)
**Primary Dependencies**: Riverpod 3.0 (code-gen), Dio 5.9, GoRouter 17.0, Freezed 3.2, web_socket_channel 3.x (new), Django Channels 4.3
**Storage**: flutter_secure_storage (JWT tokens, user data) — already in use
**Testing**: flutter_test + mocktail 1.0 (frontend), pytest 8.x (backend)
**Target Platform**: Web (Chrome) primary, iOS/Android eventually
**Performance Goals**: <500ms game actions, <2s real-time event delivery
**Constraints**: Server-authoritative (no client-side game logic), hidden information (player-scoped responses), one WebSocket at a time
**Scale/Scope**: 7 new screens, ~15 new files, 4 backend changes, ~30 new tests

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| Server-authoritative | PASS | All game logic stays on server. Frontend sends actions via HTTP, receives state via WebSocket. |
| Hidden information | PASS | API responses player-scoped. Frontend never computes or displays another player's secret info. |
| State machine | PASS | Game phases driven by server `phase_change` events. Frontend renders based on current phase, never initiates transitions. |
| Atomicity | PASS | Backend uses `@atomic` / `select_for_update`. Frontend is stateless w.r.t. game logic. |
| Determinism | PASS | No randomness in frontend — all randomness is server-side with seeded RNG. |
| Separate game apps | PASS | Frontend mirrors backend: `features/lobby/` (core), `features/game/` (ONUW-specific). |
| HTTP for state changes, WS for events | PASS | All player actions (join, ready, start, night action, vote) via REST. WebSocket is receive-only. |
| No game logic in widgets | PASS | Widgets display server state. Vote tally computation from `vote_reveal` data is display-side aggregation, not game logic. |
| Design token system | PASS | All new screens use `AppTokens` via `activeThemeProvider`. No hardcoded colors/spacing/typography. |
| Riverpod code-gen patterns | PASS | New providers use `@riverpod` annotations matching existing `AuthNotifier` pattern. |
| TEST_FIRST directive | PASS | Plan follows test-first — tests written before implementation in each work package. |

## Project Structure

### Documentation (this feature)

```
kitty-specs/005-frontend-game-integration-layer/
├── plan.md              # This file
├── research.md          # Phase 0 output — 9 architectural decisions
├── data-model.md        # Phase 1 output — all Freezed models
├── quickstart.md        # Phase 1 output — setup and workflow guide
├── contracts/
│   └── api-contracts.md # Phase 1 output — REST + WebSocket contracts
└── tasks.md             # Phase 2 output (NOT created by /spec-kitty.plan)
```

### Source Code (repository root)

```
frontend/
├── lib/
│   ├── core/
│   │   ├── api/
│   │   │   ├── api_client.dart              # Existing — unauthenticated HTTP
│   │   │   ├── api_exception.dart           # Existing — sealed exception hierarchy
│   │   │   ├── auth_interceptor.dart        # NEW — JWT bearer + auto-refresh
│   │   │   └── authenticated_client.dart    # NEW — Dio wrapper with interceptor
│   │   ├── config/
│   │   │   └── env.dart                     # MODIFY — add wsUrl getter
│   │   ├── router/
│   │   │   └── routes.dart                  # MODIFY — add LobbyRoute, GameRoute, auth guard
│   │   └── websocket/
│   │       ├── websocket_channel.dart       # NEW — promote interface from test + connection state enum
│   │       └── reconnecting_websocket.dart  # NEW — exponential backoff reconnection
│   ├── features/
│   │   ├── auth/                            # Existing — extend with authenticated client provider
│   │   │   └── presentation/
│   │   │       └── auth_notifier.dart       # MODIFY — add authenticatedClientProvider
│   │   ├── lobby/                           # NEW feature module
│   │   │   ├── domain/
│   │   │   │   ├── lobby_state.dart         # Freezed: LobbyState, LobbyPlayer
│   │   │   │   └── role_config.dart         # Validation + presets utility
│   │   │   ├── data/
│   │   │   │   └── lobby_service.dart       # HTTP calls for lobby CRUD
│   │   │   └── presentation/
│   │   │       ├── lobby_notifier.dart      # Riverpod AsyncNotifier + WS events
│   │   │       └── lobby_screen.dart        # Lobby UI (compose existing widgets)
│   │   └── game/                            # NEW feature module
│   │       ├── domain/
│   │       │   ├── game_session_state.dart  # Freezed: GameSessionState, YourRole, GamePlayer
│   │       │   ├── night_state.dart         # Freezed: ActionPrompt, ActionResult, NightSubView enum
│   │       │   └── voting_state.dart        # Freezed: VoteProgress, VoteRevealData
│   │       ├── data/
│   │       │   └── game_service.dart        # HTTP calls for game actions
│   │       └── presentation/
│   │           ├── game_notifier.dart       # Riverpod AsyncNotifier + WS state machine
│   │           ├── timer_provider.dart      # Countdown from server deadline
│   │           ├── game_container_screen.dart # Phase router with transitions
│   │           ├── role_reveal_view.dart    # Card flip animation
│   │           ├── night_waiting_view.dart  # "The village sleeps..."
│   │           ├── night_result_view.dart   # Action result display
│   │           ├── seer_choice_view.dart    # peek_player vs peek_center
│   │           ├── discussion_view.dart     # Timer + roles + host controls
│   │           └── reconnection_overlay.dart # Semi-transparent reconnecting state
│   └── design_system/
│       └── models/
│           └── game_result.dart             # MODIFY — add nullable targets, centerCards, eliminationReason
│
├── test/
│   ├── core/
│   │   ├── api/
│   │   │   └── auth_interceptor_test.dart   # NEW
│   │   └── websocket/
│   │       └── reconnecting_websocket_test.dart # NEW
│   ├── features/
│   │   ├── lobby/
│   │   │   ├── domain/role_config_test.dart # NEW — validation pure logic
│   │   │   ├── data/lobby_service_test.dart # NEW — mock HTTP
│   │   │   └── presentation/lobby_notifier_test.dart # NEW — mock service + WS
│   │   └── game/
│   │       ├── data/game_service_test.dart  # NEW — mock HTTP
│   │       ├── presentation/
│   │       │   ├── game_notifier_test.dart  # NEW — state machine transitions
│   │       │   └── timer_provider_test.dart # NEW — fake_async
│   │       └── widget/
│   │           ├── lobby_screen_test.dart   # NEW — widget test
│   │           ├── game_container_test.dart # NEW — phase routing
│   │           └── role_reveal_test.dart    # NEW — animation
│   └── helpers/
│       └── mock_websocket.dart              # MODIFY — promote interface to lib/

backend/
├── apps/core/
│   ├── views.py                             # MODIFY — add PATCH to LobbyDetailView (FR-030)
│   └── consumers.py                         # MODIFY — add game_started handler (FR-031)
├── apps/onuw/
│   ├── serializers.py                       # MODIFY — add roles_in_game (FR-032)
│   └── views.py                             # MODIFY — add elimination_reason (FR-033)
└── tests/
    ├── core/
    │   ├── test_lobby_patch.py              # NEW — FR-030 tests
    │   └── test_lobby_game_started.py       # NEW — FR-031 tests
    └── onuw/
        ├── test_roles_in_game.py            # NEW — FR-032 tests
        └── test_elimination_reason.py       # NEW — FR-033 tests
```

**Structure Decision**: Web application layout following the existing monorepo convention. Frontend uses feature-based modules (`features/lobby/`, `features/game/`) with domain/data/presentation layers, matching the existing `features/auth/` pattern. Backend changes are minimal additions to existing apps.

## Complexity Tracking

No constitution violations. All design decisions align with established patterns.

## Architecture Decisions

All 9 research decisions are documented in [research.md](research.md). Key decisions:

1. **R1 — Auth Interceptor**: Separate `AuthenticatedClient` wrapping Dio with `QueuedInterceptorsWrapper` for thread-safe token refresh. Avoids circular dependency with unauthenticated `ApiClient`.

2. **R2 — WebSocket Management**: `ReconnectingWebSocket` with exponential backoff (1s→30s max). Promotes `WebSocketChannelInterface` from test helpers to production code. JWT passed as query param.

3. **R3 — State Management**: Two `AsyncNotifier`s (`LobbyNotifier`, `GameNotifier`) following `AuthNotifier` pattern. Family providers keyed by lobby code / game ID. Separate `TimerProvider` using server-provided deadlines.

4. **R4 — Routing**: Extend GoRouter with `LobbyRoute(/lobby/:code)` and `GameRoute(/game/:gameId)`. Auth redirect guard. No shell routes — game container manages sub-views internally via state machine.

5. **R6 — Night Sub-Views**: State machine (`NightSubView` enum) drives which sub-view renders during night phase. WebSocket events trigger transitions. Not URL-routed.

6. **R7 — Model Updates**: Extend existing Freezed models in-place (`VoteResult`, `PlayerResult`, `GameResult`) rather than creating parallel models.

## Dependency Graph

```
                    ┌──────────────┐
                    │  Backend     │
                    │  FR-030..033 │
                    └──────┬───────┘
                           │ (independent of frontend)
                           │
    ┌──────────────────────┼──────────────────────────┐
    │                      │                           │
    v                      v                           v
┌─────────┐    ┌───────────────────┐    ┌──────────────────┐
│ Auth     │    │ WebSocket         │    │ Model Updates    │
│Intercept │    │ Infrastructure    │    │ (game_result.dart)│
│ + Client │    │ (channel, recon.) │    │                  │
└────┬─────┘    └────────┬──────────┘    └────────┬─────────┘
     │                   │                         │
     └─────────┬─────────┘                         │
               │                                   │
               v                                   │
     ┌─────────────────┐                           │
     │ Lobby Feature   │                           │
     │ (service,       │                           │
     │  notifier, UI)  │                           │
     └────────┬────────┘                           │
              │                                    │
              v                                    │
     ┌─────────────────┐                           │
     │ Game Feature    │◄──────────────────────────┘
     │ (service,       │
     │  notifier, UI,  │
     │  sub-views)     │
     └────────┬────────┘
              │
              v
     ┌─────────────────┐
     │ Router + Guards │
     │ (routes.dart)   │
     └─────────────────┘
```

Work packages should follow this dependency order. Backend changes and infrastructure (auth interceptor, WebSocket, model updates) can be parallelized. Lobby feature depends on infrastructure. Game feature depends on lobby + model updates. Router depends on all features.
