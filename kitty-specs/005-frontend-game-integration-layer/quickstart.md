# Quickstart: Frontend Game Integration Layer

**Feature**: 005-frontend-game-integration-layer
**Date**: 2026-03-31

## Prerequisites

- Flutter SDK (stable channel, Dart ^3.10.4)
- Backend running locally (`docker compose up` or `just run` from `backend/`)
- PostgreSQL and Redis running (via Docker Compose)

## Setup

### 1. Add the WebSocket dependency

```bash
cd frontend
flutter pub add web_socket_channel
```

This is the only new package. All other dependencies (Dio, Riverpod, Freezed, GoRouter, mocktail) are already in `pubspec.yaml`.

### 2. Run code generation

After adding any `@riverpod` or `@freezed` annotations:

```bash
cd frontend
just gen        # one-time generation
just watch      # or watch mode during development
```

Forgetting this causes analyzer errors on `*.g.dart` files that look like real bugs but are just stale codegen.

### 3. Start the backend

```bash
cd backend
just run        # starts Daphne ASGI + PostgreSQL + Redis
```

The backend must be running for WebSocket connections and API calls. Dev API URL: `http://localhost:8000/api`. Dev WebSocket URL: `ws://localhost:8000`.

### 4. Run the frontend

```bash
cd frontend
just run        # Chrome on port 3000
```

## Development Workflow

### Adding new Freezed models

1. Create the model in the appropriate `domain/` directory
2. Add `part '<filename>.freezed.dart';` and `part '<filename>.g.dart';` (if using JSON serialization)
3. Run `just gen` from `frontend/`
4. Commit the generated files

### Adding new Riverpod providers

1. Add `@riverpod` or `@Riverpod(keepAlive: true)` annotation
2. Add `part '<filename>.g.dart';`
3. Run `just gen` from `frontend/`
4. Reference via the generated `<name>Provider` constant

### Adding new routes

1. Add a `@TypedGoRoute` class in `routes.dart`
2. Run `just gen` to regenerate `routes.g.dart`
3. The route becomes available via the typed `.go()` extension

## Quality Gates

```bash
cd frontend
just test       # All tests must pass
just analyze    # Dart static analysis must pass
```

From the repo root:
```bash
just check      # Lint + format-check + typecheck for both backend and frontend
just test       # All tests for both backend and frontend
```

Both must pass before committing (enforced by pre-commit hooks).

## Key Files to Start With

| Order | File | Why |
|-------|------|-----|
| 1 | `core/api/auth_interceptor.dart` | Foundation — all authenticated requests depend on this |
| 2 | `core/api/authenticated_client.dart` | Wraps Dio with the interceptor |
| 3 | `core/websocket/websocket_channel.dart` | Promote `WebSocketChannelInterface` from test, add production impl |
| 4 | `core/websocket/reconnecting_websocket.dart` | Exponential backoff reconnection |
| 5 | `core/config/env.dart` | Add `wsUrl` getter |
| 6 | `features/lobby/domain/lobby_state.dart` | Freezed models for lobby |
| 7 | `features/lobby/data/lobby_service.dart` | HTTP calls for lobby CRUD |
| 8 | `features/lobby/presentation/lobby_notifier.dart` | State management with WS events |
| 9 | `features/lobby/presentation/lobby_screen.dart` | Lobby UI |
| 10 | `features/game/domain/game_session_state.dart` | Freezed models for game |
| 11 | `features/game/data/game_service.dart` | HTTP calls for game actions |
| 12 | `features/game/presentation/game_notifier.dart` | Game state machine |
| 13 | `features/game/presentation/game_container_screen.dart` | Phase router |
| 14 | Sub-views (role reveal, night, discussion, voting, results) | Wire existing widgets |
| 15 | Backend changes (FR-030 through FR-033) | 4 small backend additions |

## Testing Strategy

### Unit tests
- All new services (lobby, game) — mock `AuthenticatedClient` with `MockHttpClient`
- All new notifiers — mock services, inject `MockWebSocketChannel` via provider overrides
- Role config validation — pure logic, no mocks needed
- Timer provider — use `fake_async` for deterministic time control

### Widget tests
- New screens — use `pumpAuthenticated` / `pumpWithGameState` from `test_harness.dart`
- Verify design token usage — no hardcoded colors/spacing
- Test phase transitions — inject WebSocket events via `MockWebSocketChannel.addServerEvent()`

### Integration tests
- End-to-end flow: create guest → create lobby → join → start → night → discussion → vote → results
- Requires running backend

### Existing test helpers
- `test/helpers/test_harness.dart` — `pumpAuthenticated()`, `pumpWithGameState()`
- `test/helpers/mock_websocket.dart` — `MockWebSocketChannel`, `WebSocketChannelInterface`
- `test/helpers/mock_http_client.dart` — `MockHttpClient` with `when().thenReturn()` API
- `test/helpers/timer_control.dart` — timer control for fake_async tests
- `test/design_system/test_helpers/pump_with_tokens.dart` — theme-aware widget pumping

## Architecture Notes

### Server-authoritative principle
The frontend is a thin display layer. All game logic runs on the server. The frontend:
- Sends player actions via HTTP POST
- Receives state updates via WebSocket events
- Never computes win conditions, role swaps, vote tallies, or phase transitions
- Treats server responses as the source of truth

### One WebSocket at a time
The app maintains at most one WebSocket connection:
- Lobby WebSocket while viewing a lobby
- Game WebSocket while in an active game
- Transition: `game_started` → close lobby WS → open game WS

### Hidden information
The frontend must never display:
- Another player's role (until results phase)
- Another player's night action or result
- Who voted for whom (until `vote_reveal` event)
- The player's own current role if it changed (until results phase — they only know their original role)
