# Implementation Plan: Frontend Game Integration Layer
*Path: kitty-specs/005-frontend-game-integration-layer/plan.md*

**Branch**: `main` | **Date**: 2026-03-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/kitty-specs/005-frontend-game-integration-layer/spec.md`

## Summary

Build the frontend integration layer that connects existing design system components to the Django backend, delivering a playable end-to-end ONUW game. This involves: a JWT auth interceptor, WebSocket connectivity with reconnection, Riverpod state management for lobby and game lifecycles, 7 new screens/views, minor updates to existing models and widgets, and 4 small backend additions (lobby PATCH, game_started handler, roles_in_game serialization, elimination_reason in results).

## Technical Context

**Language/Version**: Dart SDK ^3.10.4, Flutter (stable)
**Primary Dependencies**: Riverpod 3.0 (code-gen), GoRouter 17.0, Dio 5.9, Freezed 3.2, web_socket_channel (to add)
**Storage**: flutter_secure_storage (tokens), in-memory Riverpod state
**Testing**: flutter_test + mocktail 1.0, 80% coverage target
**Target Platform**: Web (Chrome) for development; iOS/Android eventually
**Project Type**: Web application (monorepo: `backend/` + `frontend/`)
**Performance Goals**: <500ms game actions, real-time WebSocket updates within 2s, reconnection within 5s
**Constraints**: Phone-sized screens primary, server-authoritative, no client-side game logic
**Scale/Scope**: 3–10 players per game, ~10 concurrent WebSocket connections per lobby, 7 new screens, 2 new feature modules

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| Server-authoritative | PASS | All game logic stays on server. Frontend submits actions via HTTP POST, displays server-broadcast results. No win-condition computation, role resolution, or vote tallying client-side. |
| Hidden information | PASS | Frontend displays only `your_role.original_role` during play. Other players' roles, actions, and vote targets never displayed before results phase. WebSocket events are player-scoped by the backend. |
| State machine | PASS | Game container switches views based on server-driven `phase_change` events. Client never initiates phase transitions — only the host's "End Discussion" triggers a server POST, and the server decides the transition. |
| Atomicity | PASS (backend) | Frontend is display-only for state transitions. Backend `@atomic` decorators ensure all-or-nothing. |
| Determinism | PASS (backend) | No randomness generated client-side. All random decisions (role assignment, etc.) are server-side with seeded RNG. |
| Separate game apps | PASS | Frontend mirrors backend separation: `features/lobby/` (core) and `features/game/` (ONUW). No premature cross-game abstraction. |
| HTTP for state changes, WS for events | PASS | All player actions (create lobby, join, ready, start, night action, vote, end discussion) use HTTP POST. WebSocket is receive-only for events (player_joined, phase_change, action_result, etc.). |

**Frontend-specific constitution checks:**

| Check | Status | Evidence |
|-------|--------|----------|
| No game logic in widgets | PASS | Widgets display server state and fire callbacks. Vote tallying uses server-provided data. |
| Design tokens only | PASS | All new screens use `AppTokens` via `activeThemeProvider`. No hardcoded colors/spacing/typography. |
| Riverpod code-gen | PASS | All new providers use `@riverpod` annotations. No ad-hoc StatefulWidgets for game state. |
| Dispose resources | PASS | WebSocket connections, stream subscriptions, and timer controllers disposed via Riverpod lifecycle (`ref.onDispose`). |
| AsyncValue patterns | PASS | Loading/error states handled with Riverpod's `AsyncValue.when()` pattern throughout. |
| Platform-aware | PASS | Using `web_socket_channel` for cross-platform WebSocket. No platform-specific APIs. |

## Project Structure

### Documentation (this feature)

```
kitty-specs/005-frontend-game-integration-layer/
├── plan.md              # This file
├── research.md          # Phase 0: Design decisions and research findings
├── data-model.md        # Phase 1: All Freezed models and Riverpod providers
├── quickstart.md        # Phase 1: Development setup guide
├── contracts/           # Phase 1: API contracts
│   └── api-contracts.md # Frontend-facing REST + WebSocket surface
└── tasks.md             # Phase 2 (/spec-kitty.tasks — NOT created by /spec-kitty.plan)
```

### Source Code (repository root)

```
frontend/lib/
├── core/
│   ├── api/
│   │   ├── api_client.dart              # Existing — no changes
│   │   ├── api_exception.dart           # Existing — add ConflictException (409)
│   │   ├── authenticated_client.dart    # NEW — Dio wrapper with AuthInterceptor
│   │   ├── auth_interceptor.dart        # NEW — JWT bearer + auto-refresh
│   │   └── logging_interceptor.dart     # Existing — no changes
│   ├── websocket/
│   │   ├── websocket_channel.dart       # NEW — WebSocketChannelInterface (promote from test) + production impl
│   │   └── reconnecting_websocket.dart  # NEW — exponential backoff reconnection wrapper
│   ├── router/
│   │   ├── app_router.dart              # Existing — add auth redirect guard
│   │   └── routes.dart                  # Existing — add LobbyRoute, GameRoute
│   ├── config/
│   │   └── env.dart                     # Existing — add wsUrl getter
│   ├── logging/                         # Existing — no changes
│   └── storage/                         # Existing — no changes
├── design_system/
│   ├── components/game/
│   │   └── night_action_prompt.dart     # Existing — fix empty-state text for Mason/Minion
│   └── models/
│       ├── game_result.dart             # Existing — add voteTarget, centerCards, eliminationReason
│       ├── night_action.dart            # Existing — no changes
│       ├── player_display.dart          # Existing — no changes
│       ├── game_phase.dart              # Existing — no changes
│       └── role.dart                    # Existing — no changes
├── features/
│   ├── auth/                            # Existing — wire interceptor into provider graph
│   ├── lobby/                           # NEW feature module
│   │   ├── data/
│   │   │   ├── lobby_service.dart       # HTTP API calls (create, join, leave, ready, start, patch settings)
│   │   │   └── lobby_repository.dart    # Coordinates service + WebSocket events
│   │   ├── domain/
│   │   │   ├── lobby_state.dart         # Freezed: LobbyState, LobbyPlayer
│   │   │   └── role_config.dart         # Role count map, validation, recommended presets
│   │   └── presentation/
│   │       ├── lobby_notifier.dart      # Riverpod AsyncNotifier
│   │       ├── lobby_screen.dart        # Lobby UI (player list, code, host controls)
│   │       └── role_config_panel.dart   # Role selection with presets and +/- controls
│   └── game/                            # NEW feature module
│       ├── data/
│       │   ├── game_service.dart        # HTTP API calls (me, action, vote, end-discussion, results)
│       │   └── game_repository.dart     # Coordinates service + WebSocket events
│       ├── domain/
│       │   ├── game_session_state.dart  # Freezed: GameSessionState (phase, wave, deadline, role, players)
│       │   ├── night_state.dart         # ActionPrompt, ActionResult, WaveInfo
│       │   └── voting_state.dart        # VoteProgress, VoteRevealData
│       └── presentation/
│           ├── game_notifier.dart       # Riverpod AsyncNotifier — central game state machine
│           ├── timer_provider.dart      # Deadline-based countdown provider
│           ├── game_container_screen.dart # Phase router with animated transitions
│           ├── role_reveal_view.dart    # Card-flip animation, auto-advance
│           ├── night_waiting_view.dart  # "The village sleeps..." atmospheric
│           ├── night_result_view.dart   # Peek results, swap confirmations
│           ├── seer_choice_view.dart    # peek_player vs peek_center choice
│           ├── discussion_view.dart     # Timer, RoleTokenList, host controls
│           ├── voting_view.dart         # Wires VoteSubmission + vote progress + VoteReveal
│           ├── results_view.dart        # Wires GameResults with full data
│           └── reconnection_overlay.dart # Semi-transparent overlay on WS disconnect

backend/
├── apps/core/
│   ├── views.py                         # Add PATCH /api/lobbies/<code>/ (FR-030)
│   └── consumers.py                     # Add game_started handler to LobbyConsumer (FR-031)
└── apps/onuw/
    ├── serializers.py                   # Add roles_in_game to GameMeSerializer (FR-032)
    └── views.py                         # Add elimination_reason to results (FR-033)
```

**Structure Decision**: Follows the existing monorepo layout. Frontend uses the established `features/{name}/data/domain/presentation/` pattern from `features/auth/`. Core infrastructure (`api/`, `websocket/`, `router/`) lives in `core/`. Two new feature modules (`lobby/`, `game/`) mirror the backend's `apps.core` and `apps.onuw` separation.

## Complexity Tracking

No constitution violations to justify. All patterns align with existing codebase conventions.
