# Research: Server Phase Timers

**Feature**: 004-server-phase-timers
**Date**: 2026-03-26
**Status**: Complete

## R1: Background Task Mechanism for Phase Auto-Transition

### Decision: `threading.Timer` with module-level registry

### Rationale

The spec lists three candidates: Celery, Django Channels delayed send, and `threading.Timer`. After auditing the codebase:

- **Celery is not configured.** The project has no `celery.py`, no `CELERY_*` settings, and no broker URL. Adding Celery would introduce: a new process (worker), a hard Redis dependency for the broker (dev/test currently use `InMemoryChannelLayer`), `celery[redis]` package, app configuration boilerplate, and test complexity (need `celery.contrib.pytest` or mocking). This is significant new infrastructure for what amounts to "call a function after N seconds."

- **Django Channels has no built-in delayed-send.** There is no `channel_layer.send_delayed()` API. One could build it atop `asyncio.call_later` in the ASGI event loop, but that couples the timer to the async runtime and makes it harder to call from synchronous Django views (which is where all game transitions currently happen via `services.py`).

- **`threading.Timer`** is stdlib, zero-dependency, and works from synchronous code. Cancellation is a single `.cancel()` call. The main drawback — timers are lost on process restart — is mitigated by a startup recovery sweep (see R3).

### Implementation sketch

```python
# backend/apps/onuw/timers.py
import threading
from typing import Callable

_registry: dict[str, threading.Timer] = {}  # key = "{game_id}:{phase_or_wave}"

def schedule(key: str, delay_seconds: float, callback: Callable[[], None]) -> None:
    cancel(key)  # cancel any existing timer for this key
    timer = threading.Timer(delay_seconds, callback)
    timer.daemon = True
    timer.start()
    _registry[key] = timer

def cancel(key: str) -> None:
    timer = _registry.pop(key, None)
    if timer is not None:
        timer.cancel()
```

### Alternatives considered

| Option | Pros | Cons | Verdict |
|--------|------|------|---------|
| Celery | Production-grade, retries, monitoring | Not configured, heavy for "delay N seconds", new process | Rejected for MVP |
| asyncio.call_later | No threads, native to ASGI | Services are sync; bridging is fragile; couples to event loop | Rejected |
| APScheduler | Lightweight scheduler | New dependency, overkill | Rejected |
| threading.Timer | Zero deps, simple, cancellable | Lost on restart | **Chosen** + startup recovery |

---

## R2: Race Condition Prevention Strategy

### Decision: `select_for_update` on Game row inside auto-transition callback

### Rationale

Two race conditions are possible:
1. **Timer fires while host manually transitions.** Both paths call `transition_to_voting()` or `reveal_votes()` concurrently.
2. **Timer fires twice** (edge case if `schedule()` is called twice rapidly).

The existing codebase already uses `transaction.atomic()` for all state mutations but does not use `select_for_update`. Adding `select_for_update` in the timer callback serializes access:

```python
def _auto_transition_discussion(game_id: uuid.UUID) -> None:
    with transaction.atomic():
        game = Game.objects.select_for_update().get(id=game_id)
        if game.phase != Phase.DISCUSSION:
            return  # already transitioned — no-op
        transition_to_voting(game)
```

The host's manual transition (via `EndDiscussionView`) does NOT need `select_for_update` because it already holds the request thread. The timer callback is the only concurrent path, so locking there is sufficient.

### Alternatives considered

- **Optimistic locking with version field**: More complex, requires retry logic. `select_for_update` is simpler and PostgreSQL-native.
- **Redis distributed lock**: Overkill — we're single-process for MVP.

---

## R3: Startup Recovery for Lost Timers

### Decision: `AppConfig.ready()` sweep

### Rationale

When the server restarts, all `threading.Timer` instances are lost. Games that were in timed phases may be past their deadline. On startup:

1. Query for games in `DISCUSSION`, `VOTING`, or `NIGHT` phases with `phase_deadline IS NOT NULL`.
2. For each:
   - If `phase_deadline <= now`: transition immediately.
   - If `phase_deadline > now`: reschedule a timer for the remaining time.

This runs in `OnuwConfig.ready()` (the ONUW app's `AppConfig`). It is safe to call synchronously because `ready()` runs after all models are loaded.

### Edge cases

- **Multiple Daphne workers**: Each worker runs `ready()`. The `select_for_update` in the transition callback prevents double-transitions. Only one worker will successfully transition; others will see the phase already changed and no-op.
- **No games in flight**: The query returns empty. No work done.

---

## R4: Deadline Representation

### Decision: UTC `DateTimeField` on `Game` model, transmitted as ISO 8601 string

### Rationale

The spec says: "The deadline is a single UTC timestamp, not a duration. The client computes remaining time as `deadline - now`."

- `DateTimeField(null=True, blank=True)` on `Game` — nullable because not all phases have deadlines (lobby, results, or discussion with `discussion_seconds=0`).
- Serialized as ISO 8601 string (`2026-03-26T08:15:00Z`) in WebSocket events and REST responses.
- The client computes `deadline - DateTime.now().toUtc()` for the countdown. Clock skew of a few seconds is acceptable per spec ("~1 second precision is acceptable").

### Alternatives considered

- **Storing duration + start time**: Requires two fields and client-side computation of deadline. Worse for reconnection (client needs both values). Rejected.
- **Separate deadline model/table**: Over-normalized for a single field. Rejected.

---

## R5: Backward Compatibility with `discussion_seconds: 0`

### Decision: `0` means "no timer" — existing behavior preserved

### Rationale

The spec requires: "A duration of 0 MUST mean 'no timer' (host controls the transition manually, as today)."

Current behavior: no `discussion_seconds` in settings → host must manually call `/end-discussion/`. This maps to `discussion_seconds: 0` (or absent).

**Default values** (when keys are absent from lobby settings):
- `discussion_seconds`: 300 (5 minutes)
- `voting_seconds`: 120 (2 minutes)
- `night_wave_seconds`: 30

**Explicit 0**: No timer scheduled, `phase_deadline` set to `null`, host controls manually.

This ensures existing tests that don't set timer values get the default behavior. Tests that explicitly test the "no timer" path can set `discussion_seconds: 0`.

**Important**: Many existing tests create games without timer settings. When defaults are introduced (300s, 120s, 30s), these tests will suddenly have active timers that fire background threads. To prevent test flakiness:
- Timer defaults should only apply when the setting key is present OR we need a clear strategy for test isolation.
- Recommended: existing tests that don't set timer values should get `0` (no timer) to preserve current behavior. New tests explicitly opt into timers.
- Alternative: set defaults to 0 and require explicit configuration for timers. The spec says defaults are 300/120/30 — this conflicts with backward compat.
- Resolution: Apply defaults (300/120/30) in production. In tests, either mock the timer module or set `discussion_seconds: 0` in test fixtures. The `timers.schedule()` function can be easily mocked with `unittest.mock.patch`.

---

## R6: Timer Settings Validation

### Decision: Extend `validate_onuw_settings()` in `engine/validation.py`

### Rationale

The validation module is pure Python (no Django imports). Timer settings validation fits naturally here:

```python
TIMER_FIELDS = {
    "discussion_seconds": (0, 600),
    "voting_seconds": (0, 600),
    "night_wave_seconds": (0, 600),
}

for field, (min_val, max_val) in TIMER_FIELDS.items():
    value = settings.get(field)
    if value is not None:
        if not isinstance(value, int) or value < min_val or value > max_val:
            errors.append(f"'{field}' must be an integer between {min_val} and {max_val}.")
```

This keeps the pure-Python engine boundary intact. The validation runs at lobby creation/update time AND at game start time (existing flow already calls `validate_onuw_settings()`).
