# Data Model: Server Phase Timers

**Feature**: 004-server-phase-timers
**Date**: 2026-03-26

## Model Changes

### Game (modified)

**File**: `backend/apps/onuw/models.py`

| Field | Type | Nullable | Default | Description |
|-------|------|----------|---------|-------------|
| `phase_deadline` | `DateTimeField` | Yes | `None` | UTC timestamp when current phase auto-transitions. `null` = no active timer (untimed phase or timer disabled). |

**New field only.** No changes to existing fields. No new indexes needed (we only query by `phase_deadline IS NOT NULL` during startup recovery, which is a rare one-time scan).

```python
phase_deadline = models.DateTimeField(
    null=True,
    blank=True,
    help_text="UTC deadline for current phase auto-transition. Null = untimed.",
)
```

### Lobby settings (extended schema)

**File**: `backend/apps/core/models.py` — no model change. The `Lobby.settings` JSONField already accepts arbitrary keys.

**New optional keys in `settings` dict:**

| Key | Type | Range | Default (if absent) | Description |
|-----|------|-------|---------------------|-------------|
| `discussion_seconds` | `int` | 0–600 | 300 | Discussion phase duration. 0 = untimed. |
| `voting_seconds` | `int` | 0–600 | 120 | Voting phase duration. 0 = untimed. |
| `night_wave_seconds` | `int` | 0–600 | 30 | Night wave duration. 0 = untimed. |

**Example lobby settings:**
```json
{
  "roles": {"Werewolf": 2, "Seer": 1, "Villager": 3, "Robber": 1, "Troublemaker": 1},
  "discussion_seconds": 180,
  "voting_seconds": 60,
  "night_wave_seconds": 20
}
```

### Timer Registry (in-memory, not persisted)

**File**: `backend/apps/onuw/timers.py` (new module)

Not a Django model — a module-level dict mapping timer keys to `threading.Timer` instances.

| Component | Type | Description |
|-----------|------|-------------|
| `_registry` | `dict[str, threading.Timer]` | Active timers keyed by `"{game_id}:{phase_type}"` |

**Key format examples:**
- `"a1b2c3d4-...:discussion"` — discussion phase timer
- `"a1b2c3d4-...:voting"` — voting phase timer
- `"a1b2c3d4-...:wave:2"` — night wave 2 timer

**Lifecycle:**
1. Timer created via `schedule(key, delay, callback)` when entering a timed phase
2. Timer cancelled via `cancel(key)` on early transition (host action or all-players-done)
3. Timer auto-removed from registry when callback fires
4. All timers lost on process restart → recovered by `recover_on_startup()`

## State Transitions with Deadlines

### Phase Deadline Lifecycle

```
lobby → night (wave start)
  └─ phase_deadline = now + night_wave_seconds (if > 0)
  └─ timer scheduled: auto-advance-wave

night (wave complete) → night (next wave)
  └─ cancel previous wave timer
  └─ phase_deadline = now + night_wave_seconds (if > 0)
  └─ timer scheduled: auto-advance-wave

night (last wave) → discussion
  └─ cancel wave timer
  └─ phase_deadline = now + discussion_seconds (if > 0, else null)
  └─ timer scheduled: auto-transition-to-voting (if deadline set)

discussion → voting (auto or host)
  └─ cancel discussion timer (if host-initiated)
  └─ phase_deadline = now + voting_seconds (if > 0, else null)
  └─ timer scheduled: auto-reveal-votes (if deadline set)

voting → results (auto, host, or all-voted)
  └─ cancel voting timer
  └─ phase_deadline = null

results (terminal)
  └─ phase_deadline = null (already)
```

### Timer Callback Pseudocode

```python
def _auto_transition_callback(game_id: UUID, expected_phase: str, transition_fn) -> None:
    """Generic auto-transition callback. Runs in a background thread."""
    with transaction.atomic():
        game = Game.objects.select_for_update().get(id=game_id)
        if game.phase != expected_phase:
            return  # already transitioned — no-op (idempotent)
        transition_fn(game)
    _registry.pop(f"{game_id}:{expected_phase}", None)
```

## Validation Rules (Pure Python)

**File**: `backend/apps/onuw/engine/validation.py`

New validation added to `validate_onuw_settings()`:

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
            errors.append(
                f"'{field}' must be an integer between {min_val} and {max_val}."
            )
```

- Timer fields are **optional** — absent means use default.
- `0` is valid — means "no timer."
- Negative values rejected. Floats rejected. Max 600 seconds (10 minutes).

## Migration

```
backend/apps/onuw/migrations/XXXX_add_phase_deadline.py
```

Single operation:
```python
migrations.AddField(
    model_name="game",
    name="phase_deadline",
    field=models.DateTimeField(
        blank=True,
        null=True,
        help_text="UTC deadline for current phase auto-transition. Null = untimed.",
    ),
)
```

Safe to deploy: nullable column, no data backfill needed, existing games unaffected.
