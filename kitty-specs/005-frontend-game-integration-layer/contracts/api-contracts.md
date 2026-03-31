# API Contracts: Frontend Game Integration Layer

**Feature**: 005-frontend-game-integration-layer
**Date**: 2026-03-31

This document defines the REST and WebSocket contracts from the frontend's perspective. All endpoints are relative to `Env.apiUrl` (`http://localhost:8000/api` in dev). WebSocket URLs are relative to `Env.wsUrl` (`ws://localhost:8000` in dev).

---

## REST Endpoints

### Authentication (existing — no changes)

| Method | Path | Auth | Request | Response |
|--------|------|------|---------|----------|
| POST | `/auth/guest/` | No | `{"display_name": str?}` | `{"access": str, "refresh": str, "user": {"id": int, "display_name": str}}` |
| POST | `/auth/token/refresh/` | No | `{"refresh": str}` | `{"access": str, "refresh"?: str}` |

### Lobby Management

| Method | Path | Auth | Request | Response |
|--------|------|------|---------|----------|
| POST | `/lobbies/` | Yes | `{"game_type": "onuw", "settings": {"roles": {...}}?}` | `LobbyResponse` |
| GET | `/lobbies/<code>/` | Yes | — | `LobbyResponse` |
| POST | `/lobbies/<code>/join/` | Yes | — | `LobbyResponse` |
| POST | `/lobbies/<code>/leave/` | Yes | — | `{"detail": str}` |
| POST | `/lobbies/<code>/ready/` | Yes | `{"is_ready": bool?}` | `LobbyResponse` |
| PATCH | `/lobbies/<code>/` | Yes (host) | `{"settings": {"roles": {...}}}` | `LobbyResponse` | **FR-030 NEW** |

#### LobbyResponse

```json
{
  "code": "ABC123",
  "host": {
    "id": 1,
    "username": "player1",
    "display_name": "Alice"
  },
  "game_type": "onuw",
  "status": "waiting",
  "max_players": 10,
  "settings": {
    "roles": {
      "werewolf": 2,
      "seer": 1,
      "robber": 1,
      "troublemaker": 1,
      "villager": 3
    }
  },
  "players": [
    {
      "user": {"id": 1, "username": "player1", "display_name": "Alice"},
      "is_ready": true,
      "joined_at": "2026-03-31T06:00:00Z"
    }
  ],
  "created_at": "2026-03-31T05:55:00Z"
}
```

### Game Management

| Method | Path | Auth | Request | Response |
|--------|------|------|---------|----------|
| POST | `/onuw/lobbies/<code>/start/` | Yes (host) | — | `{"game_id": "uuid", "phase": "night"}` |
| GET | `/onuw/me/current-game/` | Yes | — | `CurrentGameResponse` or `{"game": null}` |
| GET | `/onuw/games/<id>/me/` | Yes | — | `GameMeResponse` |

#### CurrentGameResponse

```json
{
  "game_id": "550e8400-e29b-41d4-a716-446655440000",
  "phase": "night",
  "lobby_code": "ABC123"
}
```

#### GameMeResponse

```json
{
  "game_id": "550e8400-e29b-41d4-a716-446655440000",
  "phase": "night",
  "current_wave": 2,
  "deadline": "2026-03-31T06:05:30Z",
  "your_role": {
    "original_role": "seer",
    "has_acted": false,
    "current_role": null
  },
  "has_voted": false,
  "players": [
    {
      "player_id": 1,
      "display_name": "Alice",
      "has_voted": false
    }
  ],
  "action_prompt": {
    "role_acting_as": "Seer",
    "action_types": ["peek_player", "peek_center"],
    "valid_targets": {
      "peek_player": {"players": [2, 3, 4, 5]},
      "peek_center": {"card_indices": [0, 1, 2]}
    }
  },
  "roles_in_game": [
    {"role": "werewolf", "count": 2},
    {"role": "seer", "count": 1},
    {"role": "robber", "count": 1},
    {"role": "troublemaker", "count": 1},
    {"role": "villager", "count": 3}
  ]
}
```

Notes:
- `your_role.current_role` is `null` during play, populated only in results phase.
- `action_prompt` is `null` when the player has no pending action.
- `has_voted` in the players list is only present during the voting phase.
- `roles_in_game` is **FR-032 NEW**.

### Night Actions

| Method | Path | Auth | Request | Response |
|--------|------|------|---------|----------|
| POST | `/onuw/games/<id>/action/` | Yes | `ActionRequest` | `{"status": "submitted"}` |

#### ActionRequest by type

```json
// peek_player (Seer option A, Doppelganger initial peek)
{"action_type": "peek_player", "targets": {"player_id": 3}}

// peek_center (Seer option B)
{"action_type": "peek_center", "targets": {"card_indices": [0, 2]}}

// swap_with_player (Robber)
{"action_type": "swap_with_player", "targets": {"player_id": 3}}

// swap_with_center (Drunk)
{"action_type": "swap_with_center", "targets": {"card_index": 1}}

// swap_others (Troublemaker)
{"action_type": "swap_others", "targets": {"player1_id": 2, "player2_id": 4}}

// see_team (Werewolf, Mason, Minion) — optionally with center peek for lone Werewolf
{"action_type": "see_team", "targets": {}}
{"action_type": "see_team", "targets": {"center_index": 1}}

// skip (optional action skipped by player)
{"action_type": "skip", "targets": {}}
```

Error responses:
- `400` — Invalid action for current state (retry with different selection)
- `409` — Already acted this wave (treat as success)

### Discussion & Voting

| Method | Path | Auth | Request | Response |
|--------|------|------|---------|----------|
| POST | `/onuw/games/<id>/end-discussion/` | Yes (host) | — | `{"status": "voting_started"}` |
| POST | `/onuw/games/<id>/vote/` | Yes | `{"target_player_id": int}` | `{"status": "submitted"}` |

### Results

| Method | Path | Auth | Request | Response |
|--------|------|------|---------|----------|
| GET | `/onuw/games/<id>/results/` | Yes | — | `ResultsResponse` |

#### ResultsResponse

```json
{
  "winning_teams": ["village"],
  "reason": "Werewolf was eliminated",
  "eliminated_players": [
    {
      "player_id": 3,
      "display_name": "Charlie",
      "role": "werewolf",
      "elimination_reason": "vote"
    },
    {
      "player_id": 5,
      "display_name": "Eve",
      "role": "villager",
      "elimination_reason": "hunter_chain"
    }
  ],
  "players": [
    {
      "player_id": 1,
      "display_name": "Alice",
      "original_role": "seer",
      "final_role": "robber",
      "outcome": "win",
      "vote_target_id": 3
    }
  ],
  "center_cards": {
    "final": ["seer", "villager", "villager"]
  }
}
```

Notes:
- `elimination_reason` is **FR-033 NEW** — distinguishes `"vote"` from `"hunter_chain"`.
- `vote_target_id` is `null` for abstainers.
- Frontend maps `vote_target_id` to display names using the local player list.

---

## WebSocket Contracts

### Lobby WebSocket

**URL**: `ws://<host>/ws/lobby/<code>/?token=<jwt>`
**Direction**: Server → Client only (client sends no messages; all actions via HTTP)
**Group**: `lobby_{code}` (broadcast to all lobby members)

#### Events

##### player_joined
```json
{"type": "player_joined", "username": "bob"}
```
**Frontend action**: Re-fetch full lobby state via `GET /api/lobbies/<code>/` to get complete player data (IDs, ready states). The event carries only a username — insufficient for the player list.

##### player_left
```json
{"type": "player_left", "username": "bob"}
```
**Frontend action**: Re-fetch full lobby state (same reason as player_joined).

##### player_ready
```json
{"type": "player_ready", "username": "bob", "is_ready": true}
```
**Frontend action**: Update the matching player's `isReady` flag in the local lobby state. No re-fetch needed — event has the data.

##### lobby_update
```json
{"type": "lobby_update", "data": {"settings": {"roles": {"werewolf": 2, "seer": 1, ...}}}}
```
**Frontend action**: Update lobby settings (specifically the role configuration). Triggers `RoleTokenList` to re-render with updated roles.

##### game_started (**FR-031 NEW**)
```json
{"type": "game_started", "game_id": "550e8400-e29b-41d4-a716-446655440000"}
```
**Frontend action**: Extract `game_id`, disconnect lobby WebSocket, navigate to `/game/<gameId>`, connect game WebSocket, fetch initial game state via `GET /onuw/games/<id>/me/`.

### Game WebSocket

**URL**: `ws://<host>/ws/game/<game_id>/?token=<jwt>`
**Direction**: Server → Client only
**Groups**:
- `game_{game_id}` — broadcast to all players
- `game_{game_id}_player_{user_id}` — private to individual player

#### Broadcast Events

##### wave_start
```json
{"type": "wave_start", "wave": 2, "deadline": "2026-03-31T06:05:30Z"}
```
**Frontend action**: Update `currentWave` and `deadline` in game state. Players without an action for this wave will receive a separate `wave_waiting` event.

##### wave_complete
```json
{"type": "wave_complete", "wave": 2}
```
**Frontend action**: Clear action prompt/result. Set night sub-view to `waiting` until next `wave_start` or `phase_change`.

##### phase_change
```json
{"type": "phase_change", "phase": "discussion", "deadline": "2026-03-31T06:10:00Z"}
```
**Frontend action**: Update `phase` and `deadline`. Game container transitions to the new phase view. `deadline` is `null` for results phase.

##### vote_submitted
```json
{"type": "vote_submitted", "player_id": 3}
```
**Frontend action**: Mark `player_id` as having voted in `VoteProgress`. Increment vote count display. Do NOT reveal vote target.

##### vote_reveal
```json
{
  "type": "vote_reveal",
  "votes": {"1": 3, "2": 3, "4": 1, "5": null}
}
```
**Frontend action**: Map player IDs to display names using local player list. Compute vote tally. Show votes and tally (not yet elimination data). Start 5-second timeout — if `game_results` doesn't arrive, fall back to `GET /onuw/games/<id>/results/`. `null` value means abstain.

##### game_results
```json
{
  "type": "game_results",
  "data": {
    "winning_teams": ["village"],
    "eliminated_player_ids": [3]
  }
}
```
**Frontend action**: Fetch full results via `GET /onuw/games/<id>/results/`. Render `GameResults` widget with complete data. The WebSocket event is a trigger — the REST endpoint has the full payload.

#### Player-Scoped Events (private channel)

##### action_prompt
```json
{
  "type": "action_prompt",
  "wave": 2,
  "role_acting_as": "Seer",
  "action_types": ["peek_player", "peek_center"],
  "valid_targets": {
    "peek_player": {"players": [2, 3, 4, 5]},
    "peek_center": {"card_indices": [0, 1, 2]}
  }
}
```
**Frontend action**: If `action_types.length > 1`, show `SeerChoiceView`. If `action_types.length == 1`, show `NightActionPrompt` directly. Update `roleActingAs` for the role identity strip (important for Doppelganger follow-ups).

##### action_result
```json
{
  "type": "action_result",
  "wave": 2,
  "revealed_info": {
    "action_type": "peek_player",
    "target_player_id": 3,
    "role": "werewolf"
  }
}
```
**Frontend action**: Show `NightResultView` with the revealed info. Display varies by action type:
- `peek_player`: Show target player name + `RoleCard` face-up
- `peek_center`: Show `RoleCard`(s) for center positions
- `swap_with_player`: Show "You are now the [role]" + `RoleCard`
- `swap_with_center`: Show "Your card was swapped with center"
- `swap_others`: Show "You swapped [P1] and [P2]"
- `see_team`: Show teammate list (may be empty for lone wolf/mason/minion)

##### wave_waiting
```json
{"type": "wave_waiting", "wave": 2}
```
**Frontend action**: Show `NightWaitingView` with atmospheric text and countdown timer.

---

## Frontend-to-Backend Mapping

| Frontend Action | HTTP Method | Endpoint | Triggers WS Event |
|----------------|-------------|----------|--------------------|
| Create lobby | POST | `/lobbies/` | — |
| Join lobby | POST | `/lobbies/<code>/join/` | `player_joined` |
| Leave lobby | POST | `/lobbies/<code>/leave/` | `player_left` |
| Toggle ready | POST | `/lobbies/<code>/ready/` | `player_ready` |
| Update roles | PATCH | `/lobbies/<code>/` | `lobby_update` |
| Start game | POST | `/onuw/lobbies/<code>/start/` | `game_started` |
| Submit night action | POST | `/onuw/games/<id>/action/` | `action_result` (to actor) |
| End discussion | POST | `/onuw/games/<id>/end-discussion/` | `phase_change` |
| Submit vote | POST | `/onuw/games/<id>/vote/` | `vote_submitted` |
| Check active game | GET | `/onuw/me/current-game/` | — |
| Get game state | GET | `/onuw/games/<id>/me/` | — |
| Get full results | GET | `/onuw/games/<id>/results/` | — |
