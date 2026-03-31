# Implementation Plan: Frontend Game Integration Layer
*Path: [kitty-specs/005-frontend-game-integration-layer/plan.md](kitty-specs/005-frontend-game-integration-layer/plan.md)*

**Branch**: `main` | **Date**: 2026-03-31 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/kitty-specs/005-frontend-game-integration-layer/spec.md`

## Summary

Build the missing screens (lobby, game container, role reveal, night sub-views, discussion, reconnection overlay), wire existing UI components to the Django backend via authenticated HTTP and WebSocket connections, and deliver a playable end-to-end ONUW game through the Flutter app. The work spans frontend infrastructure (auth interceptor, WebSocket client, state management), seven new screens/views, four small backend additions, and model extensions to existing Freezed types.

## Technical Context

**Language/Version**: Dart ^3.10.4 / Flutter (stable channel) for frontend; Python 3.12 / Django 6.0 for backend additions
**Primary Dependencies**: Riverpod 3.0 (code-gen), GoRouter 17.0, Dio 5.9, Freezed 3.2, web_socket_channel ^3.0.0 (new), flutter_secure_storage 10.0
**Storage**: PostgreSQL (backend), flutter_secure_storage (frontend token/user persistence)
**Testing**: flutter_test + mocktail 1.0 (frontend), pytest 8.x (backend); 80% coverage enforced
**Target Platform**: Web (Chrome) primary, iOS/Android eventually
**Performance Goals**: <500ms game action latency, <2s real-time event propagation, <5s reconnection recovery
**Constraints**: Server-authoritative — no game logic client-side. One WebSocket connection at a time. Phone-sized screens primary.
**Scale/Scope**: 3-10 players per game, ~10 concurrent WebSocket connections per lobby, 7 new screens/views, 4 backend endpoint additions

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| Server-authoritative | PASS | All game logic stays on server. Frontend sends actions via HTTP, receives state via WebSocket. No win condition, role swap, or vote tally computation on client. |
| Hidden information | PASS | API responses are player-scoped via `GameMeSerializer`. Frontend never displays another player's role until results. Vote targets hidden until `vote_reveal`. |
| State machine | PASS | Game phase transitions are server-driven via WebSocket events. Frontend reacts to `phase_change` events, never initiates phase transitions. Night sub-view state machine is display-only. |
| Atomicity | PASS | Backend uses `@atomic` for state transitions. Frontend does not modify game state directly. |
| Determinism | PASS | All randomness is seeded server-side. Frontend does not generate random values for game logic. |
| Separate game apps | PASS | Backend changes (FR-030 through FR-033) stay within existing `apps.core` and `apps.onuw`. No new Django apps. |
| HTTP for state changes, WS for events | PASS | Player actions (night action, vote, leave, ready, start) submitted via REST POST. Real-time updates received via WebSocket. |
| TEST_FIRST directive | PASS | All work packages will follow test-first development. Tests written before implementation. |
| No game logic in widgets | PASS | Widgets display server state, send actions. `RoleConfig` validation is UI convenience (disable start button) — the server re-validates. |
| Design token system | PASS | All new screens use `AppTokens` via `activeThemeProvider`. No hardcoded colors, spacing, or typography. |
| Riverpod code-gen patterns | PASS | New providers use `@riverpod` annotations with code generation, matching existing `AuthNotifier` pattern. |
| Dispose resources | PASS | WebSocket connections, stream subscriptions, and timers disposed via `ref.onDispose`. |

**Post-Phase-1 re-check**: All models use Freezed with `fromJson`. WebSocket event handling follows server-driven model. No hidden information leaks in data model design — `ActionPrompt` and `ActionResult` are player-scoped by the server. Vote progress tracks `hasVoted` booleans without storing targets.

## Project Structure

### Documentation (this feature)

```
kitty-specs/005-frontend-game-integration-layer/
├── plan.md              # This file
├── research.md          # Phase 0 output — 9 research decisions (R1-R9)
├── data-model.md        # Phase 1 output — all Freezed models
├── quickstart.md        # Phase 1 output — setup and dev workflow
├── contracts/
│   └── api-contracts.md # Phase 1 output — REST and WebSocket contracts
└── tasks.md             # Phase 2 output (NOT created by /spec-kitty.plan)
```

### Source Code (repository root)

```
backend/
├── apps/core/
│   ├── views.py                    # FR-030: Add PATCH to LobbyDetailView
│   └── consumers.py                # FR-031: Add game_started handler to LobbyConsumer
├── apps/onuw/
│   ├── serializers.py              # FR-032: Add roles_in_game to GameMeSerializer
│   └── views.py                    # FR-033: Add elimination_reason to results
└── tests/
    ├── unit/core/                  # New tests for FR-030, FR-031
    └── unit/onuw/                  # New tests for FR-032, FR-033

frontend/
├── lib/
│   ├── core/
│   │   ├── api/
│   │   │   ├── api_client.dart          # Existing (unchanged)
│   │   │   ├── auth_interceptor.dart    # NEW — JWT bearer + auto-refresh
│   │   │   └── authenticated_client.dart # NEW — Dio wrapper with interceptor
│   │   ├── config/
│   │   │   └── env.dart                 # MODIFIED — add wsUrl getter
│   │   └── websocket/
│   │       ├── websocket_channel.dart   # NEW — promoted interface + connection state enum
│   │       └── reconnecting_websocket.dart # NEW — production WebSocket with backoff
│   ├── design_system/
│   │   └── models/
│   │       └── game_result.dart         # MODIFIED — nullable VoteResult targets, new PlayerResult/GameResult fields
│   ├── features/
│   │   ├── auth/                        # Existing (unchanged except minor import updates)
│   │   ├── lobby/
│   │   │   ├── data/
│   │   │   │   └── lobby_service.dart       # NEW — HTTP calls for lobby CRUD
│   │   │   ├── domain/
│   │   │   │   ├── lobby_state.dart         # NEW — LobbyPlayer, LobbyState Freezed models
│   │   │   │   └── role_config.dart         # NEW — validation, presets, step sizes
│   │   │   └── presentation/
│   │   │       ├── lobby_notifier.dart      # NEW — AsyncNotifier with WS events
│   │   │       └── lobby_screen.dart        # NEW — lobby UI screen
│   │   └── game/
│   │       ├── data/
│   │       │   └── game_service.dart        # NEW — HTTP calls for game actions
│   │       ├── domain/
│   │       │   ├── game_session_state.dart  # NEW — GameSessionState, YourRole, GamePlayer
│   │       │   ├── night_state.dart         # NEW — ActionPrompt, ActionResult, NightSubView
│   │       │   └── voting_state.dart        # NEW — VoteProgress, VoteRevealData
│   │       └── presentation/
│   │           ├── game_notifier.dart            # NEW — game state machine
│   │           ├── timer_provider.dart           # NEW — deadline-driven countdown
│   │           ├── game_container_screen.dart     # NEW — phase-switching shell
│   │           ├── role_reveal_view.dart          # NEW — card flip animation
│   │           ├── night_waiting_view.dart        # NEW — atmospheric waiting
│   │           ├── night_result_view.dart         # NEW — action result display
│   │           ├── seer_choice_view.dart          # NEW — peek_player vs peek_center
│   │           ├── lone_werewolf_peek_view.dart   # NEW — optional center card peek
│   │           ├── discussion_view.dart           # NEW — timer + host controls
│   │           └── reconnection_overlay.dart      # NEW — WS disconnect overlay
│   └── core/router/
│       └── routes.dart              # MODIFIED — add LobbyRoute, GameRoute, auth redirect
└── test/
    ├── features/
    │   ├── lobby/                   # NEW — lobby service, notifier, screen tests
    │   └── game/                    # NEW — game service, notifier, screen tests
    ├── core/
    │   ├── api/                     # NEW — auth interceptor tests
    │   └── websocket/               # NEW — reconnecting websocket tests
    └── helpers/
        └── mock_websocket.dart      # MODIFIED — interface promoted to lib/
```

**Structure Decision**: Follows the existing `features/{feature}/data-domain-presentation/` pattern established by `features/auth/`. Core infrastructure goes in `core/` (api, websocket, config). New `web_socket_channel` dependency added to `pubspec.yaml`. All other patterns match existing codebase conventions (Riverpod code-gen, Freezed, TypedGoRoute, design tokens).

## Key Research Decisions

Nine architectural decisions were researched and documented in [research.md](research.md):

| # | Decision | Rationale |
|---|----------|-----------|
| R1 | Separate `AuthenticatedClient` with `QueuedInterceptorsWrapper` | Avoids circular dependency with unauthenticated `ApiClient` used for token refresh |
| R2 | `ReconnectingWebSocket` implementing existing `WebSocketChannelInterface` | Test mock compatibility; cross-platform via `web_socket_channel` |
| R3 | Two `AsyncNotifier`s (Lobby + Game) with derived sub-providers | Matches `AuthNotifier` pattern; `AsyncValue` provides loading/error states |
| R4 | Extend GoRouter with typed routes + auth redirect guard | Matches existing `@TypedGoRoute` code-gen pattern |
| R5 | JWT via WebSocket URL query parameter | Browser WebSocket API doesn't support custom headers; backend expects token in scope |
| R6 | Night sub-view state machine (not URL routing) | WebSocket-driven transient states don't map to URL routing |
| R7 | Extend existing Freezed models in-place | Avoids mapping layers; widgets already consume these types |
| R8 | Add `web_socket_channel ^3.0.0` as only new dependency | All other needed packages already in pubspec.yaml |
| R9 | Four targeted backend additions (FR-030 to FR-033) | Small, scoped changes; no architectural modifications |

## Complexity Tracking

No constitution violations requiring justification. All design decisions align with existing patterns and the server-authoritative principle.
