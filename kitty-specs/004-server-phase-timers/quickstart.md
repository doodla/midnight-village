# Quickstart: Server Phase Timers

**Feature**: 004-server-phase-timers
**Date**: 2026-03-26

## Prerequisites

- Python 3.12, PostgreSQL running, `uv` installed
- Backend dev environment working (`just dev` from `backend/`)

## Getting Started

### 1. Apply the migration

```bash
cd backend
uv run python manage.py migrate --settings=config.settings.development
```

This adds the `phase_deadline` field to the `Game` model.

### 2. Run existing tests (verify nothing breaks)

```bash
just test
```

All 367+ existing tests should still pass.

### 3. Test with timers

Create a lobby with timer settings:

```bash
# POST to create lobby (via httpie, curl, or API client)
# Include timer fields in settings:
{
  "game_type": "onuw",
  "settings": {
    "roles": {"Werewolf": 2, "Seer": 1, "Villager": 3, "Robber": 1, "Troublemaker": 1},
    "discussion_seconds": 30,
    "voting_seconds": 15,
    "night_wave_seconds": 10
  }
}
```

Short durations (10-30s) are useful for testing auto-transitions manually.

### 4. Observe auto-transitions

Connect to the game WebSocket and watch for:
```
ws://localhost:8000/ws/game/<game_id>/
```

Events you'll see:
1. `wave_start` with `deadline` → night wave timer
2. `phase_change` with `phase: "discussion"` and `deadline` → discussion timer
3. After N seconds, `phase_change` with `phase: "voting"` and `deadline` → auto-transition!
4. After M seconds, `vote_reveal` and `game_results` → auto-reveal!

### 5. Test no-timer mode

Set `discussion_seconds: 0` in lobby settings. Verify:
- `phase_change` for discussion has `deadline: null`
- Game does NOT auto-transition — host must call `/end-discussion/`

## Key Files to Read

| File | What's There |
|------|-------------|
| `backend/apps/onuw/timers.py` | Timer registry (schedule, cancel, recover) |
| `backend/apps/onuw/services.py` | Phase transitions with deadline logic |
| `backend/apps/onuw/models.py` | `Game.phase_deadline` field |
| `backend/apps/onuw/consumers.py` | WebSocket event shapes with deadline |
| `backend/apps/onuw/engine/validation.py` | Timer settings validation |

## Testing the Timer Module

```bash
# Run just the timer tests
cd backend
uv run pytest tests/onuw/test_timers.py -v
uv run pytest tests/onuw/test_timer_integration.py -v

# Run all ONUW tests
uv run pytest tests/onuw/ -v
```

Timer tests use `unittest.mock.patch` on `threading.Timer` to avoid real delays. Integration tests may use short (1-2s) real timers where needed.

## Common Gotchas

1. **Existing tests fail with timer-related errors**: Ensure test fixtures set `discussion_seconds: 0` (or mock `apps.onuw.timers.schedule`).
2. **Timer fires after test teardown**: Use `timers.cancel_all()` in test fixtures or mock the module.
3. **Race condition in tests**: Use `select_for_update` in auto-transition callbacks. If tests run concurrently against the same game row, they may deadlock — run timer tests with `-p no:parallel`.
