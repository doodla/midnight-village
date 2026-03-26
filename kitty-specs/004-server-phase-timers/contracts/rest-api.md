# REST API Contract Changes: Server Phase Timers

**Feature**: 004-server-phase-timers
**Date**: 2026-03-26

## Modified Endpoints

### GET `/api/onuw/games/<game_id>/me/` — Game State (Player-Scoped)

**Change**: Add `deadline` field to response.

**Current response shape:**
```json
{
  "game_id": "uuid",
  "phase": "discussion",
  "current_wave": 0,
  "your_role": { "original_role": "Seer", "current_role": "Seer", "has_acted": false, "night_action_data": {} },
  "has_voted": false,
  "players": [{"player_id": 1, "display_name": "Alice"}, ...],
  "action_prompt": null
}
```

**New response shape:**
```json
{
  "game_id": "uuid",
  "phase": "discussion",
  "current_wave": 0,
  "deadline": "2026-03-26T08:20:00Z",
  "your_role": { "original_role": "Seer", "current_role": "Seer", "has_acted": false, "night_action_data": {} },
  "has_voted": false,
  "players": [{"player_id": 1, "display_name": "Alice"}, ...],
  "action_prompt": null
}
```

| Field | Type | Nullable | Description |
|-------|------|----------|-------------|
| `deadline` | `string` (ISO 8601) | Yes | UTC timestamp when current phase auto-transitions. `null` when phase is untimed (lobby, results, or timer disabled with `*_seconds: 0`). |

**Reconnection**: This is the primary mechanism for reconnecting clients to resume countdown timers. Client computes `remaining = deadline - DateTime.now().toUtc()`.

---

### POST `/api/onuw/lobbies/<code>/start/` — Start Game

**Change**: No response shape change. The game settings (including timer durations) are already copied from lobby settings to `game.settings` at start time.

**Behavioral change**: After `start_night_phase(game)`, if `night_wave_seconds > 0`, a timer is scheduled for the first wave.

---

### POST `/api/onuw/games/<game_id>/end-discussion/` — End Discussion

**Change**: No response shape change.

**Behavioral change**: Now cancels the discussion auto-transition timer (if one was scheduled).

---

### POST `/api/onuw/games/<game_id>/reveal-votes/` — Force Reveal Votes

**Change**: No response shape change.

**Behavioral change**: Now cancels the voting auto-transition timer (if one was scheduled).

---

### POST `/api/onuw/games/<game_id>/advance-wave/` — Force Advance Wave

**Change**: No response shape change.

**Behavioral change**: Now cancels the wave auto-advance timer (if one was scheduled).

---

### POST `/api/onuw/games/<game_id>/vote/` — Submit Vote

**Change**: No response shape change.

**Behavioral change**: When all players have voted (triggering auto-reveal), the voting timer is cancelled.

---

### POST `/api/onuw/games/<game_id>/action/` — Submit Night Action

**Change**: No response shape change.

**Behavioral change**: When all wave actors have submitted (triggering auto-advance), the wave timer is cancelled.

---

## Lobby Settings Validation

### POST/PATCH Lobby Settings

Timer settings are validated as part of lobby settings validation. New optional fields:

| Field | Type | Range | Default | Description |
|-------|------|-------|---------|-------------|
| `discussion_seconds` | `int` | 0–600 | 300 | Discussion phase duration in seconds |
| `voting_seconds` | `int` | 0–600 | 120 | Voting phase duration in seconds |
| `night_wave_seconds` | `int` | 0–600 | 30 | Night wave duration in seconds |

**Validation errors** (400 Bad Request):
```json
{"detail": ["'discussion_seconds' must be an integer between 0 and 600."]}
```

**Example valid settings:**
```json
{
  "roles": {"Werewolf": 2, "Seer": 1, "Villager": 3, "Robber": 1, "Troublemaker": 1},
  "discussion_seconds": 180,
  "voting_seconds": 60,
  "night_wave_seconds": 20
}
```
