# Feature Specification: Server Phase Timers

**Feature Branch**: `004-server-phase-timers`
**Created**: 2026-03-26
**Status**: Draft
**Input**: Add server-driven configurable timers for discussion and voting phases.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Discussion Timer Auto-Transitions to Voting (Priority: P1)

When the game enters the discussion phase, the server sets a deadline. The frontend receives the deadline timestamp in the phase change event and counts down locally for a smooth UI. When the deadline passes, the server automatically transitions to voting — no host action required. The host can still end discussion early.

**Why this priority**: The discussion timer is the most visible timer in the game. Without it, the host must manually end discussion, which breaks the flow and makes the game feel unpolished.

**Independent Test**: Start a game, reach discussion phase, wait for the timer to expire, verify the game automatically transitions to voting.

**Acceptance Scenarios**:

1. **Given** a game transitions to the discussion phase, **When** the `phase_change` event is broadcast, **Then** it includes a `deadline` field with an ISO 8601 timestamp equal to now + the configured discussion duration.
2. **Given** the discussion deadline has passed, **When** the server's background task fires, **Then** the game transitions to voting and a `phase_change` event with `phase: "voting"` is broadcast.
3. **Given** the host calls `/end-discussion/` before the deadline, **When** the transition occurs, **Then** the scheduled auto-transition task is cancelled and does not fire.
4. **Given** a lobby with `discussion_seconds: 180` in settings, **When** the game starts and reaches discussion, **Then** the deadline is 180 seconds from the phase start.

---

### User Story 2 - Voting Timer Auto-Reveals Votes (Priority: P1)

When the game enters the voting phase, the server sets a deadline. Players vote within the time limit. When the deadline passes, the server automatically reveals votes (marking non-voters as abstaining) — no host action required. Votes still auto-reveal early if all players vote before the deadline.

**Why this priority**: Equally critical as the discussion timer. Without it, the game stalls if a player goes AFK during voting.

**Independent Test**: Start a game, reach voting phase, let the timer expire with some players not having voted, verify votes are revealed with abstentions.

**Acceptance Scenarios**:

1. **Given** a game transitions to the voting phase, **When** the `phase_change` event is broadcast, **Then** it includes a `deadline` field with an ISO 8601 timestamp equal to now + the configured voting duration.
2. **Given** the voting deadline has passed with some players not having voted, **When** the server's background task fires, **Then** non-voters are marked as abstaining, votes are revealed, elimination is computed, and the game transitions to results.
3. **Given** all players submit votes before the deadline, **When** the last vote is submitted, **Then** votes are revealed immediately and the scheduled auto-transition task is cancelled.
4. **Given** the host calls `/reveal-votes/` before the deadline, **When** the reveal occurs, **Then** the scheduled task is cancelled.

---

### User Story 3 - Timer Durations Are Configurable Per Lobby (Priority: P2)

The host configures discussion and voting timer durations when creating or updating the lobby. Sensible defaults are provided. The settings are validated and stored alongside role configuration.

**Why this priority**: Different groups prefer different pacing. Configurable timers let casual groups use long timers and experienced groups use short ones.

**Independent Test**: Create a lobby with custom timer durations, start a game, verify the deadlines match the configured values.

**Acceptance Scenarios**:

1. **Given** a lobby created with `settings: { "roles": {...}, "discussion_seconds": 300, "voting_seconds": 120 }`, **When** the game starts and reaches discussion, **Then** the deadline is 300 seconds from phase start.
2. **Given** a lobby created without timer settings, **When** the game starts, **Then** default durations are used (discussion: 300 seconds, voting: 120 seconds).
3. **Given** a lobby with `discussion_seconds: 0`, **When** the game starts, **Then** the discussion phase has no deadline (`deadline` is `null` in the event) and the host must manually end discussion.
4. **Given** a lobby with `discussion_seconds: -5`, **When** the lobby is created, **Then** validation rejects the value.

---

### User Story 4 - Night Wave Timers Auto-Skip Inactive Players (Priority: P2)

Each night wave has a deadline. When the deadline passes, any player who hasn't submitted their action is marked as skipped. The wave advances automatically. The host can still force-advance.

**Why this priority**: Prevents the game from stalling if a player disconnects during the night phase. Lower priority than discussion/voting because night waves are shorter and the host already has a force-advance button.

**Independent Test**: Start a game, reach a night wave where a player has an action, let the timer expire without submitting, verify the action is skipped and the wave advances.

**Acceptance Scenarios**:

1. **Given** a night wave starts, **When** the `wave_start` event is broadcast, **Then** it includes a `deadline` field.
2. **Given** a wave deadline passes with a player who hasn't acted, **When** the background task fires, **Then** that player's action is recorded as `action_type: "skip"` and the wave advances.
3. **Given** all players in a wave submit before the deadline, **When** the last action is submitted, **Then** the wave advances immediately and the scheduled task is cancelled.
4. **Given** the host calls `/advance-wave/` before the deadline, **When** the advance occurs, **Then** the scheduled task is cancelled.

---

### User Story 5 - Deadline Visible on Reconnection (Priority: P2)

A player who disconnects and reconnects mid-phase sees the current deadline in their game state, allowing the client to resume the countdown from the correct remaining time.

**Why this priority**: Without this, reconnected players see no timer or an incorrect timer. Important for UX but not a day-one blocker.

**Independent Test**: Start a game in discussion phase, disconnect a player, reconnect, verify the `/me/` endpoint includes the current deadline.

**Acceptance Scenarios**:

1. **Given** a game is in the discussion phase with a deadline, **When** a player calls `GET /api/onuw/games/<id>/me/`, **Then** the response includes `"deadline": "<ISO 8601 timestamp>"`.
2. **Given** a game is in the results phase (no active timer), **When** a player calls the `/me/` endpoint, **Then** `deadline` is `null`.

---

### Edge Cases

- What happens if the server restarts while a timer is running? The background task is lost. On startup, the server should check for games in timed phases past their deadline and transition them immediately.
- What happens if the deadline fires but the game has already transitioned (e.g., host ended discussion 1ms before)? The background task must re-check the current phase before acting. If the phase has already changed, it's a no-op.
- What happens if two auto-transition tasks fire concurrently (race condition)? Use `select_for_update` on the Game row to serialize transitions. The second task finds the game already transitioned and exits.
- What happens if the configured duration is very short (e.g., 5 seconds)? Allow it — some groups play speed rounds.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The `phase_change` WebSocket event MUST include a `deadline` field containing an ISO 8601 UTC timestamp when the phase is timed, or `null` when untimed.
- **FR-002**: The `wave_start` WebSocket event MUST include a `deadline` field for night waves.
- **FR-003**: The server MUST schedule a background task when entering a timed phase that auto-transitions the game when the deadline passes.
- **FR-004**: The background task MUST be cancelled when the phase transitions early (host action or all-players-done).
- **FR-005**: The background task MUST be idempotent — if the game has already transitioned, the task is a no-op.
- **FR-006**: The Game model MUST store the active deadline so it can be returned on reconnection via the `/me/` endpoint.
- **FR-007**: Lobby settings MUST accept optional `discussion_seconds`, `voting_seconds`, and `night_wave_seconds` fields with validation (non-negative integers, reasonable maximum of 600 seconds).
- **FR-008**: Default timer durations MUST be: discussion 300s, voting 120s, night wave 30s.
- **FR-009**: A duration of 0 MUST mean "no timer" (host controls the transition manually, as today).
- **FR-010**: The `/me/` endpoint response MUST include the current `deadline` field when in a timed phase.
- **FR-011**: Phase auto-transitions MUST use `select_for_update` to prevent race conditions between concurrent task executions.
- **FR-012**: All existing tests MUST continue to pass. Tests that assert on `phase_change` event shape MUST be updated to account for the new `deadline` field.
- **FR-013**: On server startup, games in timed phases past their deadline MUST be detected and transitioned immediately.

### Key Entities

- **Game** (extended): Gains a `phase_deadline` field (nullable DateTimeField) storing the current phase's expiry timestamp.
- **Lobby settings** (extended): The `settings` JSONField gains optional `discussion_seconds`, `voting_seconds`, and `night_wave_seconds` keys alongside the existing `roles` key.
- **Background task**: A scheduled `threading.Timer` (in-process, no external dependencies) that fires at the deadline and calls the appropriate transition function. Managed by a timer registry in `apps/onuw/timers.py`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Discussion phase auto-transitions to voting when the deadline expires, without any client or host action.
- **SC-002**: Voting phase auto-reveals votes when the deadline expires, with non-voters marked as abstaining.
- **SC-003**: Night waves auto-advance when the deadline expires, with non-actors marked as skipped.
- **SC-004**: `phase_change` and `wave_start` events include a `deadline` field that clients can use for local countdown.
- **SC-005**: Reconnecting players receive the current deadline from the `/me/` endpoint.
- **SC-006**: Early transitions (host action, all-players-done) cancel the scheduled task — no double-transition occurs.
- **SC-007**: `just check` and `just test` pass with zero failures.
- **SC-008**: Timer durations are configurable per lobby with sensible defaults.

## Assumptions

- The background task mechanism is `threading.Timer` with an in-process registry — no external dependencies like Celery are needed. This was chosen for simplicity given the expected scale (~10 concurrent lobbies).
- The deadline is a single UTC timestamp, not a duration. The client computes remaining time as `deadline - now`. This avoids clock-sync issues as long as both client and server use UTC.
- Timer precision of ~1 second is acceptable. The task scheduler does not need sub-second accuracy.
- The night wave timer is shorter (default 30s) because night actions are simple tap-to-select interactions, not group discussion.
- Setting `discussion_seconds: 0` effectively restores the current behavior (host manually ends discussion). This is the backward-compatible default for existing tests.

## Reference Documents

- `backend/apps/onuw/services.py` — Phase transition functions that need deadline integration
- `backend/apps/onuw/models.py` — Game model that needs `phase_deadline` field
- `backend/apps/onuw/views.py` — Views for end-discussion, reveal-votes, advance-wave that need task cancellation
- `docs/stitch/screen-inventory.md` — Frontend timer requirements per screen
