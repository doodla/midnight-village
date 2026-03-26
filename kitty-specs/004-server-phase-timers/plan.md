# Implementation Plan: Server Phase Timers

**Branch**: `004-server-phase-timers` | **Date**: 2026-03-26 | **Spec**: [kitty-specs/004-server-phase-timers/spec.md](spec.md)
**Input**: Add server-driven configurable timers for discussion, voting, and night wave phases with automatic transitions.

## Summary

Add server-side phase timers that automatically transition games when deadlines expire. The server schedules background tasks (via `threading.Timer`) when entering timed phases. Deadlines are stored on the `Game` model and broadcast in WebSocket events so clients can display countdowns. Early transitions (host action or all-players-done) cancel scheduled tasks. A startup recovery sweep handles server restarts.

## Technical Context

**Language/Version**: Python 3.12
**Primary Dependencies**: Django 5.x, Django REST Framework, Django Channels 4.x, Daphne (ASGI)
**Storage**: PostgreSQL, InMemoryChannelLayer (dev/test)
**Testing**: pytest 8.x with strict markers (unit, integration, contract), 80% coverage enforced
**Target Platform**: Linux server (Docker), web/iOS/Android clients
**Project Type**: Web application (Django backend + Flutter frontend, backend-only for this feature)
**Performance Goals**: <500ms for phase transitions, ~1s timer precision acceptable
**Constraints**: No new infrastructure dependencies (no Celery), server-authoritative, all state changes atomic
**Scale/Scope**: ~10 concurrent lobbies, 3-10 players per game

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| Server-authoritative | PASS | All timer logic server-side. Clients receive deadlines, compute countdown locally. |
| Hidden information | PASS | Deadlines are public game state — no information leak. |
| State machine | PASS | Auto-transitions use existing `validate_phase_transition()`. Invalid transitions rejected. |
| Atomicity | PASS | Timer callbacks use `transaction.atomic()` + `select_for_update`. |
| Determinism | PASS | Timer durations come from game settings (seeded at game creation). Timer firing time is non-deterministic but outcomes are deterministic (idempotent callbacks). |
| Separate game apps | PASS | Timer module lives in `apps/onuw/`. No cross-app coupling. |
| ONUW engine pure Python | PASS | Validation extensions in `engine/validation.py` remain pure Python. Timer scheduling is in Django-aware service layer. |
| 80% test coverage | PASS | Timer module testable via mocking. All new code tested. |
| No over-engineering | PASS | `threading.Timer` is simplest viable mechanism. No Celery, no job queue. |

**Post-Phase 1 re-check**: All principles still satisfied. The `timers.py` module is Django-aware (imports models) but the engine validation remains pure Python.

## Project Structure

### Documentation (this feature)

```
kitty-specs/004-server-phase-timers/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0: timer mechanism research
├── data-model.md        # Phase 1: model & state changes
├── quickstart.md        # Phase 1: dev getting-started
├── contracts/           # Phase 1: API & WebSocket event contracts
│   ├── rest-api.md      # REST endpoint changes
│   └── websocket.md     # WebSocket event shape changes
└── tasks.md             # Phase 2: work packages (NOT created by /spec-kitty.plan)
```

### Source Code (repository root)

```
backend/
├── apps/onuw/
│   ├── models.py          # MODIFIED: Add phase_deadline field to Game
│   ├── services.py        # MODIFIED: Integrate deadline computation + timer scheduling
│   ├── timers.py          # NEW: Timer registry (schedule, cancel, startup recovery)
│   ├── consumers.py       # MODIFIED: Pass deadline in phase_change and wave_start events
│   ├── serializers.py     # MODIFIED: Add deadline to GameMeSerializer
│   ├── views.py           # MODIFIED: Cancel timers on host-initiated transitions
│   ├── apps.py            # MODIFIED: Startup recovery in AppConfig.ready()
│   └── engine/
│       └── validation.py  # MODIFIED: Validate timer settings (pure Python)
├── tests/onuw/
│   ├── test_timers.py              # NEW: Timer registry unit tests
│   ├── test_timer_integration.py   # NEW: Phase auto-transition integration tests
│   └── (existing test files)       # MODIFIED: Account for deadline field in events
└── config/settings/
    └── (no changes needed)
```

**Structure Decision**: All new code lives within the existing `apps/onuw/` app. One new module (`timers.py`) and two new test files. No new Django apps, no new infrastructure.

## Complexity Tracking

*No constitution violations requiring justification.*

## Design Decisions

### D1: Timer Mechanism — `threading.Timer` + registry

See [research.md](research.md) R1 for full analysis. `threading.Timer` chosen over Celery (not configured, overkill), asyncio (services are sync), and APScheduler (unnecessary dependency).

**Registry key format**: `"{game_id}:discussion"`, `"{game_id}:voting"`, `"{game_id}:wave:{wave_number}"`

### D2: Race Conditions — `select_for_update` in callbacks

See [research.md](research.md) R2. Timer callbacks acquire a row lock on the Game before checking phase. If the phase already changed (host beat the timer), the callback is a no-op.

### D3: Startup Recovery — `AppConfig.ready()` sweep

See [research.md](research.md) R3. On startup, query games in timed phases with deadlines. Past-due games transition immediately; future-deadline games get rescheduled.

### D4: Backward Compatibility

See [research.md](research.md) R5. Timer defaults (300/120/30) apply when settings keys are present. Existing tests that don't set timer values: mock `timers.schedule` or explicitly set `*_seconds: 0` in fixtures.

### D5: Timer Settings Source

Timer durations are read from `game.settings` (copied from lobby settings at game start). This means:
- Changing lobby settings after game start does NOT affect the running game.
- The `game.settings` dict is the single source of truth for timer durations.

Helper to extract durations:
```python
def get_timer_seconds(game: Game, key: str, default: int) -> int:
    return game.settings.get(key, default)
```

## Change Impact Summary

| File | Change Type | Scope |
|------|------------|-------|
| `apps/onuw/models.py` | Modify | Add `phase_deadline` DateTimeField (nullable) |
| `apps/onuw/timers.py` | New | Timer registry: `schedule()`, `cancel()`, `recover_on_startup()` |
| `apps/onuw/services.py` | Modify | Compute deadlines, schedule/cancel timers in transition functions |
| `apps/onuw/consumers.py` | Modify | Pass `deadline` in `phase_change` and `wave_start` events |
| `apps/onuw/serializers.py` | Modify | Add `deadline` field to `GameMeSerializer` |
| `apps/onuw/views.py` | Modify | Cancel timers in `EndDiscussionView`, `ForceRevealView`, `WaveAdvanceView` |
| `apps/onuw/apps.py` | Modify | Add startup recovery call in `ready()` |
| `apps/onuw/engine/validation.py` | Modify | Validate `discussion_seconds`, `voting_seconds`, `night_wave_seconds` |
| `tests/onuw/test_timers.py` | New | Timer registry unit tests |
| `tests/onuw/test_timer_integration.py` | New | Auto-transition integration tests |
| Existing test files | Modify | Account for `deadline` field in phase_change events |

## Migration Plan

1. **Database migration**: Add `phase_deadline` to `Game` model. Single `ALTER TABLE` — safe, nullable column, no data migration needed.
2. **Backward-compatible deploy**: The migration adds a nullable field. Existing games continue to work. The timer system only activates for games started after the code deploys.
3. **Existing test updates**: Tests that assert exact shapes of `phase_change` events need updating to include the `deadline` field. Use `@pytest.fixture` to set `discussion_seconds: 0` where timers are unwanted.
