# Feature Specification: Frontend Game Integration Layer

**Feature Branch**: `005-frontend-game-integration-layer`
**Created**: 2026-03-29
**Status**: Draft
**Input**: Bridge existing Flutter UI components to existing Django backend APIs for a playable end-to-end ONUW game.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Join a Lobby and Start a Game (Priority: P1)

A player opens the app, enters a lobby code, joins the lobby, and sees other players arriving in real time. The host starts the game and all players transition to the night phase together.

**Why this priority**: Without lobby join and game start, nothing else works. This is the entry point for every game session.

**Independent Test**: Create a guest account, create a lobby, have a second player join by code, toggle ready, start the game — verify both players see the night phase begin.

**Acceptance Scenarios**:

1. **Given** an authenticated player on the home screen, **When** they enter a valid lobby code and tap join, **Then** they see the lobby screen with the current player list.
2. **Given** a player in a lobby, **When** another player joins, **Then** the lobby screen updates in real time (via WebSocket `player_joined` event) without a manual refresh.
3. **Given** a player in a lobby, **When** they toggle their ready state, **Then** all players see the updated ready status in real time.
4. **Given** the host with all players ready, **When** the host taps start, **Then** all players receive a `game.started` event and navigate to the game screen showing the night phase.
5. **Given** an unauthenticated player, **When** they attempt any lobby action, **Then** they are redirected to the auth screen.

---

### User Story 2 - Play Through the Night Phase (Priority: P1)

During the night phase, a player sees their role, receives action prompts when it's their wave, submits their action (or waits), and sees the result of their action. The phase advances automatically through waves.

**Why this priority**: The night phase is the core mechanic that makes ONUW unique. Without it, the game can't function.

**Independent Test**: Start a 5-player game with Werewolf, Seer, Robber, Troublemaker, and Villager. Verify the Seer gets an action prompt, submits a peek, sees the result, and the game advances to discussion.

**Acceptance Scenarios**:

1. **Given** a game in the night phase, **When** a player's wave is active and they have an action, **Then** they see the `NightActionPrompt` widget with the correct action type for their role.
2. **Given** a player with a peek action (Seer), **When** they select a target and confirm, **Then** the app sends a POST to `/api/onuw/games/<id>/action/` and displays the revealed role.
3. **Given** a player with no action this wave (Villager), **When** a wave is active, **Then** they see a waiting screen with a timer countdown.
4. **Given** a wave completes, **When** the server broadcasts `wave_complete`, **Then** the game advances to the next wave or transitions to discussion.
5. **Given** a player who does not act before the wave timer expires, **When** the server auto-advances, **Then** the player's action is skipped and the game proceeds.

---

### User Story 3 - Discuss and Vote (Priority: P1)

After the night phase, all players enter discussion with a countdown timer. When discussion ends (timer or host), players vote simultaneously. Votes are hidden until all are in (or timer expires), then revealed.

**Why this priority**: Discussion and voting are how the game resolves. Without them, there's no game outcome.

**Independent Test**: Reach the discussion phase, verify the countdown timer matches the server deadline, wait for voting, submit a vote, verify the vote reveal shows all players' targets.

**Acceptance Scenarios**:

1. **Given** the game transitions to discussion, **When** the `phase_change` event arrives with a deadline, **Then** the app shows the `GameTimer` counting down from the deadline.
2. **Given** the discussion timer expires, **When** the server transitions to voting, **Then** the app shows the `VoteSubmission` widget with selectable player targets.
3. **Given** a player in the voting phase, **When** they select a target and confirm, **Then** the app sends a POST to `/api/onuw/games/<id>/vote/` and shows a confirmation screen (no target name, for privacy).
4. **Given** all votes are in, **When** the server broadcasts `vote_reveal`, **Then** the app shows the `VoteReveal` widget displaying who voted for whom.
5. **Given** the host ends discussion early, **When** the `phase_change` event arrives, **Then** the app immediately transitions to the voting UI.

---

### User Story 4 - See Game Results (Priority: P1)

After voting resolution, all players see the game results: who won, who was eliminated, all role reveals (original and final), and vote targets.

**Why this priority**: Results are the payoff — without them, players don't know who won.

**Independent Test**: Complete a full game through voting, verify the results screen shows winning team(s), eliminated players, original and final roles for all players, and vote targets.

**Acceptance Scenarios**:

1. **Given** the game transitions to results, **When** the `game_results` event arrives, **Then** the app shows the `GameResults` widget with winning team(s), eliminated players, and full role reveals.
2. **Given** the results screen, **When** a player views it, **Then** they see each player's original role, final role (if swapped), vote target, and whether they won or lost.
3. **Given** the results screen, **When** a player taps "back to lobby" or "new game", **Then** they return to the home screen.

---

### User Story 5 - Reconnect Mid-Game (Priority: P2)

A player who closes the app or loses connection mid-game can reopen the app and resume from where they left off — correct phase, correct timer, correct state.

**Why this priority**: Mobile players frequently switch apps or lose signal. Without reconnection, a single dropped connection ruins the game for everyone.

**Independent Test**: Start a game, force-close the app during discussion phase, reopen, verify the player sees the discussion screen with the correct remaining time on the timer.

**Acceptance Scenarios**:

1. **Given** a player reopens the app, **When** they have an active game, **Then** the app calls `GET /api/onuw/me/current-game/` and navigates directly to the game screen.
2. **Given** a reconnected player in a timed phase, **When** the `/me/` endpoint returns a deadline, **Then** the timer shows the correct remaining time (deadline minus now).
3. **Given** a reconnected player during the night phase, **When** their wave has already passed, **Then** they see the waiting state for the current wave.
4. **Given** a reconnected WebSocket, **When** the connection is re-established, **Then** the player resumes receiving real-time events without missing state transitions.

---

### User Story 6 - Create a Lobby (Priority: P2)

A player can create a new lobby, configure role selections and timer settings, and share the lobby code with friends.

**Why this priority**: Slightly lower priority than joining because only the host needs this flow, and the backend already handles lobby creation.

**Independent Test**: Create a lobby, verify the lobby code is displayed, verify the host sees themselves in the player list.

**Acceptance Scenarios**:

1. **Given** an authenticated player, **When** they tap "Create Lobby", **Then** the app sends a POST to `/api/lobbies/` and navigates to the lobby screen showing the generated code.
2. **Given** the lobby screen, **When** the host views it, **Then** they see the lobby code prominently (for sharing), the player list, and a start button (disabled until all ready).
3. **Given** the lobby screen, **When** the host taps start with not all players ready, **Then** the start button is disabled or shows a clear message.

---

### Edge Cases

- What happens when the WebSocket connection drops mid-game? The app should detect the disconnection, show a "reconnecting" indicator, attempt automatic reconnection, and re-fetch game state on success.
- What happens when a player's JWT token expires during a game? The auth interceptor should automatically refresh the token using the stored refresh token. If refresh fails, redirect to the auth screen.
- What happens when a player submits an action but the server returns 409 (already acted)? The app should treat this as a success — the action was already recorded.
- What happens when the server returns 400 for a night action? The app should display the validation error and let the player retry with a different selection.
- What happens when a player opens the app with no active game? The `/me/current-game/` endpoint returns null; the app shows the home screen.
- What happens when the host leaves the lobby? The lobby is deleted — all players receive a `lobby_update` event and should be returned to the home screen.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST add a JWT bearer token to all authenticated API requests via a Dio interceptor.
- **FR-002**: The app MUST automatically refresh expired access tokens using the stored refresh token, and redirect to the auth screen if refresh fails.
- **FR-003**: The app MUST establish a WebSocket connection to `ws://<host>/ws/lobby/<code>/` when viewing a lobby and `ws://<host>/ws/game/<game_id>/` when in an active game.
- **FR-004**: The app MUST maintain a Riverpod provider for lobby state (players, ready states, lobby code) that updates from both HTTP responses and WebSocket events.
- **FR-005**: The app MUST maintain a Riverpod provider for game state (phase, wave, deadline, role, action prompt, players, results) that updates from both HTTP responses and WebSocket events.
- **FR-006**: The app MUST render the correct UI component for the current game phase — night action prompt, waiting screen, discussion timer, vote submission, vote reveal, or game results.
- **FR-007**: The app MUST submit night actions via POST to `/api/onuw/games/<id>/action/` with the correct `action_type` and `targets` payload.
- **FR-008**: The app MUST submit votes via POST to `/api/onuw/games/<id>/vote/` with the target player ID.
- **FR-009**: The app MUST display countdown timers driven by the server-provided deadline (not client-side duration), computed as `deadline - DateTime.now()`.
- **FR-010**: The app MUST detect WebSocket disconnection and attempt automatic reconnection with exponential backoff.
- **FR-011**: The app MUST call `GET /api/onuw/me/current-game/` on startup to resume an active game session.
- **FR-012**: The app MUST route between home, lobby, game, and results screens using GoRouter with auth guards.
- **FR-013**: The app MUST never display another player's role, night action data, or vote target before the results phase.
- **FR-014**: The app MUST handle lobby CRUD — create (POST `/api/lobbies/`), join (POST `/api/lobbies/<code>/join/`), leave (POST `/api/lobbies/<code>/leave/`), ready (POST `/api/lobbies/<code>/ready/`), and start (POST `/api/onuw/lobbies/<code>/start/`).

### Key Entities

- **AuthState**: Tracks authentication status (unauthenticated, loading, authenticated with tokens, error). Already exists — extended with token interceptor integration.
- **LobbyState**: Lobby code, player list with ready states, host status, settings. New Riverpod AsyncNotifier.
- **GameState**: Game ID, current phase, current wave, deadline, player's role info, action prompt, player list, results. New Riverpod AsyncNotifier.
- **WebSocketConnection**: Manages a single active WebSocket channel (lobby or game), handles connect/disconnect/reconnect lifecycle. New class with Riverpod StreamProvider for events.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A player can create a guest account, join a lobby, play a complete ONUW game (night → discussion → voting → results), and see who won — entirely through the app.
- **SC-002**: Real-time updates (player joins, ready toggles, phase changes, vote submissions) appear within 2 seconds of the server event.
- **SC-003**: A player who closes and reopens the app mid-game resumes at the correct phase with the correct timer.
- **SC-004**: Token refresh happens transparently — no player-visible interruption during normal gameplay.
- **SC-005**: All existing frontend tests continue to pass.
- **SC-006**: New integration tests verify the lobby join → game start → night action → vote → results flow.

## Assumptions

- The backend API contract is stable — all endpoints and WebSocket events documented in the backend codebase are the source of truth. No backend changes are needed for this feature.
- The `web_socket_channel` Dart package is the WebSocket client (already in pubspec.yaml or will be added).
- Timer display uses the server-provided UTC deadline, not client-side duration tracking, to avoid clock drift.
- The app connects to one WebSocket at a time — lobby WebSocket while in lobby, game WebSocket while in game. No simultaneous connections needed.
- The app supports only one active game per user at a time, matching the backend constraint.
- Role configuration UI (selecting which roles to include in a game) is out of scope for this feature — the lobby uses default or pre-configured role sets. Role configuration can be a separate feature.

## Reference Documents

- `backend/apps/core/urls.py` — Auth and lobby API endpoints
- `backend/apps/onuw/urls.py` — Game API endpoints
- `backend/apps/core/consumers.py` — LobbyConsumer WebSocket events
- `backend/apps/onuw/consumers.py` — GameConsumer WebSocket events
- `backend/apps/onuw/serializers.py` — Response shapes for game state
- `frontend/lib/design_system/components/game/` — Existing game UI components to wire up
- `frontend/lib/features/auth/` — Existing auth infrastructure to extend
- `frontend/lib/core/api/api_client.dart` — Existing HTTP client to add interceptor to
- `frontend/lib/core/router/routes.dart` — Existing router to expand
