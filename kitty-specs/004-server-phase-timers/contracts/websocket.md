# WebSocket Event Contract Changes: Server Phase Timers

**Feature**: 004-server-phase-timers
**Date**: 2026-03-26

## Modified Events

### `phase_change` (broadcast to all players)

**Current shape:**
```json
{
  "type": "phase_change",
  "phase": "discussion"
}
```

**New shape:**
```json
{
  "type": "phase_change",
  "phase": "discussion",
  "deadline": "2026-03-26T08:20:00Z"
}
```

| Field | Type | Nullable | Description |
|-------|------|----------|-------------|
| `phase` | `string` | No | New phase name (`"night"`, `"discussion"`, `"voting"`, `"results"`) |
| `deadline` | `string` (ISO 8601) | Yes | UTC timestamp when this phase auto-transitions. `null` for untimed phases. |

**When `deadline` is `null`:**
- Phase is `results` (terminal, no transition)
- Timer is disabled (`*_seconds: 0` in settings)
- Phase is `lobby` (no `phase_change` event emitted for lobby)

**Client behavior**: On receiving `phase_change`, if `deadline` is non-null, start a local countdown: `remaining = deadline - DateTime.now().toUtc()`. Display as `MM:SS`. When reaching 0, wait for next server event (do NOT transition client-side).

---

### `wave_start` (broadcast to all players)

**Current shape:**
```json
{
  "type": "wave_start",
  "wave": 2
}
```

**New shape:**
```json
{
  "type": "wave_start",
  "wave": 2,
  "deadline": "2026-03-26T08:10:30Z"
}
```

| Field | Type | Nullable | Description |
|-------|------|----------|-------------|
| `wave` | `int` | No | Wave number (1-4) |
| `deadline` | `string` (ISO 8601) | Yes | UTC timestamp when this wave auto-advances. `null` if `night_wave_seconds: 0`. |

---

## Unchanged Events

These events are NOT modified:

| Event | Reason |
|-------|--------|
| `action_prompt` | Player-scoped night action prompt — no timer info needed (wave deadline is in `wave_start`) |
| `action_result` | Night action result — no timer relevance |
| `wave_complete` | Wave completed — deadline already expired or cancelled |
| `wave_waiting` | Player waiting — deadline is in `wave_start` |
| `vote_submitted` | Vote acknowledgment — deadline is in `phase_change` |
| `vote_reveal` | Votes revealed — deadline already expired or cancelled |
| `game_results` | Terminal phase — no timer |
| `game_started` | Fires before night phase — night timers come via `wave_start` |

## Consumer Changes

**File**: `backend/apps/onuw/consumers.py`

### `phase_change` handler

```python
async def phase_change(self, event):
    """Broadcast: the game phase has changed."""
    await self.send_json(
        {
            "type": "phase_change",
            "phase": event["phase"],
            "deadline": event.get("deadline"),  # NEW: ISO 8601 or null
        }
    )
```

### `wave_start` handler

```python
async def wave_start(self, event):
    """Broadcast: a new wave has started."""
    await self.send_json(
        {
            "type": "wave_start",
            "wave": event["wave"],
            "deadline": event.get("deadline"),  # NEW: ISO 8601 or null
        }
    )
```

## Service Layer Changes (event emission)

All `channel_layer.group_send` calls for `phase.change` and `wave.start` events must include the `deadline` field.

### `transition_to_discussion` (services.py)

```python
# Before
{"type": "phase.change", "phase": "discussion"}

# After
{"type": "phase.change", "phase": "discussion", "deadline": game.phase_deadline.isoformat() if game.phase_deadline else None}
```

### `transition_to_voting` (services.py)

```python
# Before
{"type": "phase.change", "phase": "voting"}

# After
{"type": "phase.change", "phase": "voting", "deadline": game.phase_deadline.isoformat() if game.phase_deadline else None}
```

### `send_wave_prompts` (services.py)

```python
# Before
{"type": "wave.start", "wave": wave}

# After
{"type": "wave.start", "wave": wave, "deadline": game.phase_deadline.isoformat() if game.phase_deadline else None}
```

### `reveal_votes` → results phase change

The `game.results` broadcast and phase transition to results sets `phase_deadline = None`. No deadline in the results events.
