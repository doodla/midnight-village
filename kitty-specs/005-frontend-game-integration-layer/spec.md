# Feature Specification: Frontend Game Integration Layer

**Feature Branch**: `005-frontend-game-integration-layer`
**Created**: 2026-03-29
**Status**: Draft
**Input**: Build the missing screens, wire existing UI components to the Django backend, and deliver a playable end-to-end ONUW game.

## UI Inventory

This feature spans both **new screen construction** and **integration plumbing**. The existing design system provides game-phase widgets but no assembled screens or backend connectivity.

### Existing Components (wire up, do not rebuild)

| Component | What it does | Used in |
|-----------|-------------|---------|
| `NightActionPrompt` | Full night action UI — all 7 action types, internal selection state, confirm/skip | Night phase |
| `VoteSubmission` | Vote target selection, privacy-safe post-vote confirmation | Voting phase |
| `VoteReveal` | Vote tally, per-player vote arrows, elimination outcome | Voting → Results transition |
| `GameResults` | Winning teams, per-player role reveals with swap arrows, play again / return | Results phase |
| `GameTimer` | Countdown from a `Duration`, urgency color at <10s | Night, discussion, voting |
| `PhaseIndicator` | Horizontal stepper for lobby → night → discussion → voting → results | Game container |
| `RoleCard` | Role display (face-up/face-down, normal/small) | Night action results, results |
| `CenterCards` | Center card selection grid (3 positions) | Seer peek-center action |
| `PlayerCircle` | Player grid with tap-to-select and multi-select | Night actions, voting |
| `RoleTokenList` | Compact badges showing which roles are in the game | Lobby, discussion |
| `PlayerAvatar` | Avatar with deterministic color, status indicator | Everywhere |
| `AtmosphericBackground` | Phase-aware background (dark void for night, warm for discussion) | All screens |
| `VillageAppBar` | App bar with brand/back/phase/minimal variants | All screens |
| `PrimaryButton`, `MvCard`, `MvDialog`, `MvTextInput`, `MvScaffold`, `MvLoading`, `MvError` | Core UI primitives | Everywhere |

### New Screens to Build

| Screen | Description | Design direction |
|--------|-------------|-----------------|
| **Lobby screen** | The social gathering space before the game. Lobby code displayed prominently for sharing. Player list with avatars and ready-state toggles. Host sees a start button (disabled until all ready). Roles-in-game summary via `RoleTokenList`. Leave button. Must feel like a candlelit waiting room — warm, anticipatory. | Compose: `AtmosphericBackground` (lobby phase), `VillageAppBar` (brand variant), `PlayerAvatar`, `RoleTokenList`, `PrimaryButton`, `MvTextInput` (for lobby code entry on join flow). New: player list with ready indicators, lobby code display, host controls. |
| **Game container screen** | Phase-switching shell that renders the correct sub-view based on current game phase. Shows `PhaseIndicator` at top, `VillageAppBar` (phase variant), and delegates body to the active phase view. Handles animated transitions between phases. | Compose: `PhaseIndicator`, `VillageAppBar`, `AtmosphericBackground`. New: phase router logic, transition animations between sub-views. |
| **Role reveal view** | Shown at game start before the first night wave. "You are the **Seer**" — dramatic reveal of the player's assigned role with a face-down-to-face-up card flip animation. Brief (3–5 seconds) then auto-advances to night. Sets the tone for the entire game. | Compose: `RoleCard` (animate from face-down to face-up), `AtmosphericBackground` (night). New: flip animation, role name typography, auto-advance timer. |
| **Night waiting view** | Shown to players who have no action in the current wave (or whose wave hasn't arrived yet). "The village sleeps..." with a subtle breathing animation. Timer shows time remaining in the current wave. Must feel immersive — the player is "eyes closed." | Compose: `GameTimer`, `AtmosphericBackground` (night/deep void). New: waiting state UI with atmospheric text and animation. |
| **Discussion phase view** | The most social screen — players are talking in person, the phone shows context. Prominent countdown timer. `RoleTokenList` showing what roles are in play (public info). The host sees an "End Discussion" button. Light, warm atmospheric background. | Compose: `GameTimer`, `RoleTokenList`, `PhaseIndicator`, `AtmosphericBackground` (discussion), `PrimaryButton`. New: discussion layout, host controls. |
| **Reconnection overlay** | Semi-transparent overlay shown when the WebSocket drops. "Reconnecting..." with a spinner. Dismisses automatically when connection is restored. Must not block critical state — if the phase changed while disconnected, the overlay dismisses into the new phase. | Compose: `MvLoading`. New: overlay widget, reconnection state display. |

### Design Constraints

All new screens MUST:
- Use the existing design token system (`AppTokens` via `activeThemeProvider`) — no hardcoded colors, spacing, or typography
- Follow the Firelit Gothic aesthetic established in feature 003 — dark atmospheric backgrounds, warm accent colors, serif typography for dramatic moments
- Use `AtmosphericBackground` with the correct phase parameter for ambient lighting
- Work on phone-sized screens (primary use case: players sitting together, each on their phone)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Join a Lobby and Start a Game (Priority: P1)

A player opens the app, enters a lobby code, joins the lobby, and sees other players arriving in real time. The host starts the game and all players see a dramatic role reveal before entering the night phase.

**Why this priority**: Without lobby join and game start, nothing else works. This is the entry point for every game session. The lobby screen is entirely new UI — no lobby components exist today.

**Independent Test**: Create a guest account, create a lobby, have a second player join by code, toggle ready, start the game — verify both players see their role reveal and then the night phase.

**Acceptance Scenarios**:

1. **Given** an authenticated player on the home screen, **When** they enter a valid lobby code and tap join, **Then** they see the lobby screen with the current player list, each player's ready state, and the lobby code displayed prominently.
2. **Given** a player in a lobby, **When** another player joins, **Then** the lobby screen updates in real time (via WebSocket `player_joined` event) without a manual refresh.
3. **Given** a player in a lobby, **When** they toggle their ready state, **Then** all players see the updated ready status in real time via `player_ready` event.
4. **Given** the host with all players ready, **When** the host taps start, **Then** the host's start POST returns a game ID. All players learn the game has started via a lobby WebSocket event. If the WebSocket notification is missed (e.g., brief disconnect), the app falls back to polling `GET /api/onuw/me/current-game/`. All players see a role reveal animation ("You are the Seer") and transition to the night phase.
5. **Given** an unauthenticated player, **When** they attempt any lobby action, **Then** they are redirected to the auth screen.
6. **Given** the host, **When** they view the lobby, **Then** they see a start control that is disabled until all players are ready.

---

### User Story 2 - Play Through the Night Phase (Priority: P1)

During the night phase, the game container screen shows the `PhaseIndicator` at night stage. Players who have an action this wave see the `NightActionPrompt`. Players who don't have an action see the night waiting view ("The village sleeps..."). After submitting an action, players see their result briefly, then return to waiting until the next wave or phase transition.

**Why this priority**: The night phase is the core mechanic. The `NightActionPrompt` widget already exists — the work here is the game container, waiting view, and wiring actions to the API.

**Independent Test**: Start a 5-player game with Werewolf, Seer, Robber, Troublemaker, and Villager. Verify the Seer gets an action prompt, submits a peek, sees the result, and the game advances to discussion.

**Acceptance Scenarios**:

1. **Given** a game in the night phase, **When** a player's wave is active and they have an action, **Then** the game container renders the `NightActionPrompt` with the correct action type for their role.
2. **Given** the Seer whose prompt includes two action types (`peek_player` and `peek_center`), **When** their wave starts, **Then** the app presents a choice between "Look at one player's card" and "Look at two center cards" before showing the corresponding selection UI.
3. **Given** a lone Werewolf (no other Werewolves among players), **When** their wave starts, **Then** after seeing they have no teammates, they are offered an optional center card peek (one card). They may acknowledge without peeking (skip the peek).
4. **Given** a player with an optional action (Seer, Robber, Troublemaker, lone Werewolf), **When** their prompt is shown, **Then** they see a "Skip" option alongside the confirm button. Given a player with a mandatory action (Drunk, Doppelganger initial peek), **When** their prompt is shown, **Then** no skip option is available.
5. **Given** a player submits a night action, **When** the server responds with an `action_result` event containing `revealed_info`, **Then** the app displays the result: the Seer sees the peeked role(s) via `RoleCard`, the Robber sees their new role, the Insomniac sees their current card, Werewolves/Masons/Minion see a teammate list. The result is shown until the wave completes.
6. **Given** the Doppelganger, **When** their wave starts, **Then** the app presents a peek-player prompt (mandatory). After submitting, the `action_result` reveals the copied role. If the copied role has an immediate follow-up action (Seer, Robber, Troublemaker, Drunk), the app presents a second prompt for that action within the same wave. If the copied role acts in a later wave (Werewolf, Mason, Minion, Insomniac), the Doppelganger returns to waiting and is re-prompted when that wave arrives. For Doppelganger-as-Insomniac (wave 4 follow-up), the result is a self-peek showing the player's current card — which may differ from the copied role if swapped. The display should clearly communicate "This is your current card."
7. **Given** the Minion, **When** the see-team result shows no Werewolves among players (all Werewolf cards in center), **Then** the result display shows an appropriate message ("No werewolves among players") rather than an empty teammate list with misleading context.
8. **Given** a player with no action this wave (Villager), **When** a wave is active, **Then** they see the night waiting view with atmospheric text and a `GameTimer` countdown.
8. **Given** a wave completes, **When** the server broadcasts `wave_complete`, **Then** the game container advances to the next wave's view or transitions to discussion.
9. **Given** a player who does not act before the wave timer expires, **When** the server auto-advances, **Then** the player's action is skipped and the game proceeds.

---

### User Story 3 - Discuss and Vote (Priority: P1)

After the night phase, the game container transitions to the discussion phase view — a warm-lit screen with a prominent countdown timer, the roles in play (`RoleTokenList`), and host controls. When discussion ends, the container transitions to the `VoteSubmission` widget. After all votes, the `VoteReveal` widget shows results.

**Why this priority**: Discussion and voting are how the game resolves. The `VoteSubmission` and `VoteReveal` widgets exist — the work is the discussion view, phase transitions, and API wiring.

**Independent Test**: Reach the discussion phase, verify the countdown timer matches the server deadline, wait for voting, submit a vote, verify the vote reveal shows all players' targets.

**Acceptance Scenarios**:

1. **Given** the game transitions to discussion, **When** the `phase_change` event arrives with a deadline, **Then** the game container shows the discussion phase view with `GameTimer` counting down and `RoleTokenList` showing roles in play.
2. **Given** the discussion phase, **When** the host taps "End Discussion", **Then** a confirmation dialog asks "End discussion early? Players are still talking." If confirmed, a POST to `/api/onuw/games/<id>/end-discussion/` is sent. If cancelled, nothing happens.
3. **Given** the discussion timer expires, **When** the server transitions to voting, **Then** the game container transitions to show `VoteSubmission` with selectable player targets.
4. **Given** a player in the voting phase, **When** they select a target and confirm, **Then** the app sends a POST to `/api/onuw/games/<id>/vote/` and `VoteSubmission` shows the privacy-safe confirmation.
5. **Given** the voting phase, **When** the server broadcasts `vote_submitted` events, **Then** the app shows a vote progress indicator ("3 of 5 voted") without revealing who voted for whom. Each player's voted status is visible (checkmark or similar).
6. **Given** all votes are in (or the voting timer expires), **When** the server broadcasts `vote_reveal` (containing vote pairs only, no elimination data), **Then** the app enriches the raw vote IDs with player names from its local player list, computes the vote tally, and renders `VoteReveal` initially with votes and tally but no elimination info. When the `game_results` event arrives shortly after (containing eliminated player IDs), the `VoteReveal` updates to show eliminations. This two-step render avoids blocking on the second event.

---

### User Story 4 - See Game Results (Priority: P1)

After voting resolution, the game container transitions to the results phase. The `GameResults` widget shows who won, who was eliminated, all role reveals, and vote targets. Players can return to the home screen.

**Why this priority**: Results are the payoff. The `GameResults` widget exists — the work is wiring it to real data and providing navigation out.

**Independent Test**: Complete a full game through voting, verify the results screen shows winning team(s), eliminated players, original and final roles for all players, and vote targets.

**Acceptance Scenarios**:

1. **Given** the game transitions to results, **When** the `game_results` WebSocket event arrives (which contains only winning teams and eliminated player IDs), **Then** the app fetches the full results from `GET /api/onuw/games/<id>/results/` to obtain per-player role data, vote targets, and outcome details, and renders the `GameResults` widget.
2. **Given** the results screen, **When** a player views it, **Then** they see each player's original role, final role (if swapped), vote target, and whether they won or lost.
3. **Given** a game where no werewolves are among players and no one is eliminated, **When** the results screen is shown, **Then** the village wins and the results display explains "No werewolves were among the players — village wins by keeping the peace."
4. **Given** a game where no werewolves are among players and a non-Minion player is eliminated with no Minion in play, **When** the results screen is shown, **Then** no team wins and the results display shows "Nobody wins."
5. **Given** the Hunter is eliminated, **When** the results screen is shown, **Then** the player killed by the Hunter's chain ability is visually distinguished from vote-eliminated players (e.g., "Eliminated by Hunter" label) so players understand why a player with few or zero votes died.
6. **Given** the results screen, **When** a player taps "Return to Lobby" or "Play Again", **Then** they navigate back to the home screen.

---

### User Story 5 - Reconnect Mid-Game (Priority: P2)

A player who closes the app or loses connection mid-game can reopen the app and resume from where they left off. The reconnection overlay shows while re-establishing the WebSocket, then dismisses into the correct phase view.

**Why this priority**: Mobile players frequently switch apps or lose signal. Without reconnection, a single dropped connection ruins the game for everyone.

**Independent Test**: Start a game, force-close the app during discussion phase, reopen, verify the player sees the reconnection overlay briefly, then the discussion screen with the correct remaining time on the timer.

**Acceptance Scenarios**:

1. **Given** a player reopens the app, **When** they have an active game, **Then** the app calls `GET /api/onuw/me/current-game/` and navigates directly to the game container at the correct phase.
2. **Given** a reconnected player in a timed phase, **When** the `/me/` endpoint returns a deadline, **Then** the timer shows the correct remaining time (deadline minus now).
3. **Given** a reconnected player during the night phase, **When** their wave has already passed, **Then** they see the night waiting view for the current wave.
4. **Given** a WebSocket disconnection mid-game, **When** the connection drops, **Then** the reconnection overlay appears. When the connection is restored, the overlay dismisses and the player resumes receiving events.

---

### User Story 6 - Create a Lobby (Priority: P2)

A player can create a new lobby from the home screen. The app navigates to the lobby screen showing the generated code and the host as the first player. The host waits for others to join.

**Why this priority**: Slightly lower priority than joining because only the host needs this flow.

**Independent Test**: Create a lobby, verify the lobby code is displayed, verify the host sees themselves in the player list.

**Acceptance Scenarios**:

1. **Given** an authenticated player, **When** they tap "Create Lobby", **Then** the app sends a POST to `/api/lobbies/` and navigates to the lobby screen showing the generated code.
2. **Given** the lobby screen, **When** the host views it, **Then** they see the lobby code prominently (for sharing), themselves in the player list, and a start button (disabled until all ready).
3. **Given** the lobby, **When** the host taps start with not all players ready, **Then** the start button remains disabled.

---

### User Story 7 - Configure Roles Before Starting (Priority: P2)

The host selects which roles to include in the game before starting. The lobby screen offers preset recommended setups by player count (from the official rules) and allows manual adjustment with +/- controls per role. The total card count is validated (must equal player count + 3) and Masons must be 0 or 2.

**Why this priority**: Without this, every game uses the same roles. Configuration is what gives ONUW its replayability. P2 because a hardcoded default setup is playable — just less fun.

**Independent Test**: Create a lobby with 5 players, select the "Intermediate" preset (Werewolf, Werewolf, Seer, Robber, Troublemaker, Drunk, Insomniac, Villager), start the game, verify the roles in play match the selection.

**Acceptance Scenarios**:

1. **Given** the host on the lobby screen, **When** they view the role configuration area, **Then** they see a list of all 12 v1 roles with the current count for each and +/- controls.
2. **Given** the host, **When** they select a recommended preset for their player count, **Then** the role counts auto-populate to match the preset.
3. **Given** the host with an invalid configuration (total cards != player count + 3), **When** they attempt to start, **Then** the start button is disabled and a validation message explains the issue.
4. **Given** the host sets Mason count to 1, **When** they view the configuration, **Then** a validation message explains Masons must be used in pairs (0 or 2).
5. **Given** the host with a valid configuration, **When** they start the game, **Then** the role settings are sent to the backend and the game uses the selected roles.
6. **Given** a non-host player in the lobby, **When** the host changes role configuration, **Then** all players see the updated `RoleTokenList` in real time.

---

### Edge Cases

- What happens when the WebSocket connection drops mid-game? The reconnection overlay appears, the app attempts automatic reconnection with exponential backoff, and on success re-fetches game state via the `/me/` endpoint.
- What happens when a player's JWT token expires during a game? The auth interceptor automatically refreshes the token using the stored refresh token. If refresh fails, redirect to auth screen.
- What happens when a player submits an action but the server returns 409 (already acted)? Treat as success — the action was already recorded.
- What happens when the server returns 400 for a night action? Display the validation error and let the player retry with a different selection.
- What happens when a player opens the app with no active game? The `/me/current-game/` endpoint returns null; the app shows the home screen.
- What happens when the host leaves the lobby? The lobby is deleted — all players receive a `lobby_update` event and return to the home screen.
- What happens during role reveal if the player backgrounds the app? The role reveal auto-advances on a timer; if they return after it's passed, they go straight to the night phase.
- What happens when a player disconnects mid-game? Other players see a disconnected indicator (wifi-off badge via `PlayerDisplay.status = disconnected`) on that player's avatar during all phases. During night, a disconnected player's action is auto-skipped by the server timer. During voting, their vote is skipped (abstain). The disconnected player can reconnect at any time via the reconnection flow (US5).
- What happens if the host ends discussion and the timer simultaneously expires? The server handles this via `select_for_update` — only one transition fires. The client treats any `phase_change` to voting as authoritative regardless of source.

## Requirements *(mandatory)*

### Functional Requirements

**Infrastructure**

- **FR-001**: The app MUST add a JWT bearer token to all authenticated API requests via a Dio interceptor.
- **FR-002**: The app MUST automatically refresh expired access tokens using the stored refresh token, and redirect to the auth screen if refresh fails.
- **FR-003**: The app MUST establish a WebSocket connection to `ws://<host>/ws/lobby/<code>/` when viewing a lobby and `ws://<host>/ws/game/<game_id>/` when in an active game.
- **FR-004**: The app MUST detect WebSocket disconnection and attempt automatic reconnection with exponential backoff.
- **FR-005**: The app MUST call `GET /api/onuw/me/current-game/` on startup to resume an active game session.

**State Management**

- **FR-006**: The app MUST maintain a Riverpod provider for lobby state (players, ready states, lobby code, host flag) that updates from both HTTP responses and WebSocket events.
- **FR-007**: The app MUST maintain a Riverpod provider for game state (phase, wave, deadline, role, action prompt, players, results) that updates from both HTTP responses and WebSocket events.

**Screens (new UI)**

- **FR-008**: The app MUST provide a lobby screen showing: lobby code (prominent, shareable), player list with ready-state indicators, host start button (disabled until all ready), leave button, role configuration (host only), and `RoleTokenList` summary visible to all players.
- **FR-009**: The app MUST provide a game container screen that renders the correct sub-view based on the current game phase, with animated transitions between phases and a `PhaseIndicator` showing progress.
- **FR-010**: The app MUST show a role reveal view at game start — the player's assigned role with a card-flip animation — before transitioning to the first night wave.
- **FR-011**: The app MUST show a night waiting view with atmospheric text and a countdown timer when a player has no action in the current wave.
- **FR-012**: The app MUST show a discussion phase view with a prominent countdown timer, `RoleTokenList` of roles in play, and host "End Discussion" control.
- **FR-013**: The app MUST show a reconnection overlay when the WebSocket disconnects, dismissing automatically when connection is restored.

**Actions & API**

- **FR-014**: The app MUST submit night actions via POST to `/api/onuw/games/<id>/action/` with the correct `action_type` and `targets` payload.
- **FR-015**: The app MUST submit votes via POST to `/api/onuw/games/<id>/vote/` with the target player ID.
- **FR-016**: The app MUST handle lobby CRUD — create (POST `/api/lobbies/`), join (POST `/api/lobbies/<code>/join/`), leave (POST `/api/lobbies/<code>/leave/`), ready (POST `/api/lobbies/<code>/ready/`), and start (POST `/api/onuw/lobbies/<code>/start/`).
- **FR-017**: The app MUST display countdown timers driven by the server-provided deadline (not client-side duration), computed as `deadline - DateTime.now()`.
- **FR-020**: The host MUST be able to configure roles in the lobby — selecting from 12 v1 roles with +/- count controls, choosing from recommended presets by player count, with client-side validation (total = player count + 3, Masons 0 or 2).
- **FR-021**: For roles with multiple action types (Seer: peek_player or peek_center), the app MUST present the choice before showing the selection UI for the chosen action type.
- **FR-022**: After a player submits a night action, the app MUST display the `action_result` revealed information (peeked roles, new role, teammate list) using appropriate UI until the wave completes.
- **FR-023**: The Doppelganger's multi-step night flow MUST be handled — first prompt (peek player), result display (copied role), then conditional second prompt if the copied role has an immediate action.
- **FR-026**: The lone Werewolf's compound interaction MUST be handled — first display the empty teammate list, then offer an optional 1-center-card picker. The entire flow submits as a single `see_team` action with an optional `center_index` target. The player may skip the center peek.
- **FR-024**: The app MUST fetch full game results from `GET /api/onuw/games/<id>/results/` when the results phase begins, since the `game_results` WebSocket event contains only summary data.
- **FR-025**: During the voting phase, the app MUST show vote progress (how many players have voted) updated via `vote_submitted` WebSocket events, without revealing vote targets.

**Routing & Security**

- **FR-018**: The app MUST route between home, lobby, game, and results screens using GoRouter with auth guards.
- **FR-019**: The app MUST never display another player's role, night action data, or vote target before the results phase.

### Key Entities

- **AuthState**: Tracks authentication status (unauthenticated, loading, authenticated with tokens, error). Already exists — extended with token interceptor integration.
- **LobbyState**: Lobby code, player list with ready states, host status, settings. New Riverpod AsyncNotifier.
- **GameState**: Game ID, current phase, current wave, deadline, player's role info, action prompt, player list, results. New Riverpod AsyncNotifier.
- **WebSocketConnection**: Manages a single active WebSocket channel (lobby or game), handles connect/disconnect/reconnect lifecycle. New class with Riverpod StreamProvider for events.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A player can create a guest account, join a lobby, see a role reveal, play a complete ONUW game (night → discussion → voting → results), and see who won — entirely through the app.
- **SC-002**: Real-time updates (player joins, ready toggles, phase changes, vote submissions) appear within 2 seconds of the server event.
- **SC-003**: A player who closes and reopens the app mid-game resumes at the correct phase with the correct timer within 5 seconds.
- **SC-004**: Token refresh happens transparently — no player-visible interruption during normal gameplay.
- **SC-005**: All existing frontend tests continue to pass.
- **SC-006**: New integration tests verify the lobby join → game start → role reveal → night action → discussion → vote → results flow.
- **SC-007**: All new screens use the design token system — no hardcoded colors, spacing, or typography values.

## Assumptions

- The backend API contract is mostly stable. The following backend changes are prerequisites for this feature:
  - **PATCH `/api/lobbies/<code>/`** endpoint to update lobby settings (currently only settable at creation). Required for US7 role configuration.
  - **`game_started` handler** on `LobbyConsumer` to dispatch the `game.started` event to WebSocket clients. Currently the event is sent but no handler exists to forward it.
  - **Roles-in-game data** exposed via `GameMeSerializer` (e.g., a `roles_in_game` field). Currently `game.settings["roles"]` is not serialized. Required for FR-012 (`RoleTokenList` in discussion phase). Alternative: the frontend caches the lobby's role config before game start.
- The `web_socket_channel` Dart package is the WebSocket client (already in pubspec.yaml or will be added).
- Timer display uses the server-provided UTC deadline, not client-side duration tracking, to avoid clock drift.
- The app connects to one WebSocket at a time — lobby WebSocket while in lobby, game WebSocket while in game. No simultaneous connections needed.
- The app supports only one active game per user at a time, matching the backend constraint.
- Role configuration offers preset recommended setups and manual +/- controls. Advanced features like custom role creation, saved configurations, or role descriptions/tooltips are out of scope.
- The role reveal animation is a brief interstitial (3–5 seconds), not a full screen the player interacts with.

## Reference Documents

- `backend/apps/core/urls.py` — Auth and lobby API endpoints
- `backend/apps/onuw/urls.py` — Game API endpoints
- `backend/apps/core/consumers.py` — LobbyConsumer WebSocket events (`player_joined`, `player_left`, `player_ready`, `lobby_update`)
- `backend/apps/onuw/consumers.py` — GameConsumer WebSocket events (`wave_start`, `action_prompt`, `action_result`, `wave_complete`, `phase_change`, `vote_submitted`, `vote_reveal`, `game_results`)
- `backend/apps/onuw/serializers.py` — Response shapes for game state
- `frontend/lib/design_system/components/game/` — Existing game UI components to wire up
- `frontend/lib/design_system/models/` — Existing Freezed models (`PlayerDisplay`, `GameResult`, `NightActionSelection`, `RoleId`, `GamePhase`)
- `frontend/lib/features/auth/` — Existing auth infrastructure to extend
- `frontend/lib/core/api/api_client.dart` — Existing HTTP client to add interceptor to
- `frontend/lib/core/router/routes.dart` — Existing router to expand
