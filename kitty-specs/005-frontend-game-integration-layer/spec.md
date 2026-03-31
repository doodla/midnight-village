# Feature Specification: Frontend Game Integration Layer

**Feature Branch**: `005-frontend-game-integration-layer`
**Created**: 2026-03-29
**Status**: Draft
**Input**: Build the missing screens, wire existing UI components to the Django backend, and deliver a playable end-to-end ONUW game.

## UI Inventory

This feature spans both **new screen construction** and **integration plumbing**. The existing design system provides game-phase widgets but no assembled screens or backend connectivity.

### Existing Components (wire up, do not rebuild)

| Component | What it does | Limitations / gaps | Used in |
|-----------|-------------|-------------------|---------|
| `NightActionPrompt` | Night action **submission** only — takes a single `NightActionType`, renders selection UI, fires `onActionSubmitted(NightActionSelection)`. Manages selection state internally. Shows `_RoleIdentityStrip` at top with role name + small `RoleCard`. | No result display state (submission only). No multi-action-type choice (takes one `actionType`). `_SeeTeamAction` has no center card picker for lone Werewolf. `_PeekCenterAction` hardcodes "Choose 2 center cards" and validates `length == 2`. `_SeeTeamAction` shows misleading text for empty Mason ("These are your fellow masons") and empty Minion ("These are the werewolves") teammate lists — only lone Werewolf has special empty-state handling. | Night phase (action selection step only) |
| `VoteSubmission` | Vote target selection via `PlayerCircle`, privacy-safe post-vote confirmation via `isLocked` flag. Takes `players`, `timeRemaining`, `onVoteSubmitted`, `isLocked`. | No vote progress indicator (who has voted). The `isLocked` state shows generic "Vote submitted" — no count of remaining voters. | Voting phase |
| `VoteReveal` | Vote tally and elimination outcome. Takes `List<VoteResult>` (with names), pre-computed `Map<String, int>` tally, and `List<String>` eliminatedPlayerIds. | When `eliminatedPlayerIds` is empty, shows "No one was eliminated!" — there is no "loading/resolving" state. If rendered before elimination data arrives, the message is misleading. Either don't render until data arrives, or modify the widget to accept a nullable elimination list. | Voting → Results transition |
| `GameResults` | Winning teams (`_WinAnnouncement`), per-player role reveals (`_PlayerResultRow` with role swap arrows), play again / return buttons. Takes `GameResult`. | `PlayerResult` model has no `voteTargetName` — per-player vote targets not displayed. No center cards section. No elimination reason (vote vs Hunter chain) — just "(eliminated)". `_WinAnnouncement` handles empty teams ("Nobody wins!") and multiple winners correctly. `_buildRoleLabel` handles Doppelganger and swapped roles correctly. | Results phase |
| `GameTimer` | Displays a `Duration` in MM:SS or bare seconds. Urgency color at <=10s. | Stateless — no internal tick. Parent must provide updated `Duration` every second (e.g., via a Riverpod timer provider computing `deadline - now`). | Night, discussion, voting |
| `PhaseIndicator` | Horizontal stepper for all 5 phases with past/current/future styling. | None — works as-is. | Game container |
| `RoleCard` | Role display. `roleId: null` = face-down (card back). `small: true` = compact variant. | None — works as-is. | Night results, role reveal, results |
| `CenterCards` | Row of face-down center cards with tap-to-select. Takes `cardCount`, `maxSelections` (1 or 2), `onSelectionChanged`. | Already supports `maxSelections: 1` — usable for lone Werewolf directly. The hardcoded "2 cards" issue is in `_PeekCenterAction` (NightActionPrompt's wrapper), not in `CenterCards` itself. | Seer peek-center, lone Werewolf peek, Drunk swap |
| `PlayerCircle` | Player avatar grid with selection. Handles current-player exclusion, max-selections cap, eliminated/disconnected status badges. Adaptive layout for 3–10 players. | None — works as-is. | Night actions, voting |
| `RoleTokenList` | Compact role badges showing which roles are in the game. Takes `List<RoleId>`. | None — works as-is. | Lobby, discussion |
| `PlayerAvatar` | Circular avatar with initials, deterministic color, status indicators (eliminated X overlay, disconnected wifi-off badge, current-player person badge, selected checkmark). | None — works as-is. | Everywhere |
| `AtmosphericBackground` | Phase-aware background gradient. | None — works as-is. | All screens |
| `VillageAppBar` | App bar with brand/back/phase/minimal variants. | None — works as-is. | All screens |
| `PrimaryButton`, `MvCard`, `MvDialog`, `MvTextInput`, `MvScaffold`, `MvLoading`, `MvError` | Core UI primitives. | None — work as-is. | Everywhere |

### New Screens to Build

| Screen | Description | Design direction |
|--------|-------------|-----------------|
| **Lobby screen** | The social gathering space before the game. Lobby code displayed prominently for sharing. Player list with avatars and ready-state toggles. Host sees a start button (disabled until all ready). Roles-in-game summary via `RoleTokenList`. Leave button. Must feel like a candlelit waiting room — warm, anticipatory. | Compose: `AtmosphericBackground` (lobby phase), `VillageAppBar` (brand variant), `PlayerAvatar`, `RoleTokenList`, `PrimaryButton`, `MvTextInput` (for lobby code entry on join flow). New: player list with ready indicators, lobby code display, host controls. |
| **Game container screen** | Phase-switching shell that renders the correct sub-view based on current game phase. Shows `PhaseIndicator` at top, `VillageAppBar` (phase variant), and delegates body to the active phase view. Handles animated transitions between phases. | Compose: `PhaseIndicator`, `VillageAppBar`, `AtmosphericBackground`. New: phase router logic, transition animations between sub-views. |
| **Role reveal view** | Shown at game start before the first night wave. "You are the **Seer**" — dramatic reveal of the player's assigned role with a face-down-to-face-up card flip animation. Brief (4 seconds) then auto-advances to night. Sets the tone for the entire game. | Compose: `RoleCard` (animate from face-down to face-up), `AtmosphericBackground` (night). New: flip animation, role name typography, auto-advance timer. |
| **Night action result view** | Shown after a player submits their action and before the wave completes. Displays what was revealed: peeked role(s) via `RoleCard`, new role after swap, teammate list, or swap confirmation. `NightActionPrompt` has no result state — this is a separate view that receives `action_result.revealed_info` and renders the appropriate display. | Compose: `RoleCard`, `AtmosphericBackground` (night), `GameTimer`. New: result display per action type (peek result, swap confirmation, teammate reveal). |
| **Seer action choice view** | Shown before `NightActionPrompt` when the Seer (or Doppelganger-as-Seer) needs to choose between peek_player and peek_center. Two buttons: "Look at one player's card" / "Look at two center cards." After choosing, the game container renders `NightActionPrompt` with the selected action type. | Compose: `PrimaryButton`, `AtmosphericBackground` (night), `_RoleIdentityStrip` pattern from `NightActionPrompt`. New: choice screen layout. |
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

### User Story 1 - Create a Lobby (Priority: P1)

A player creates a new lobby from the home screen. The app navigates to the lobby screen showing the generated code and the host as the first player. The host waits for others to join.

**Why this priority**: The host flow is the first thing that happens — someone must create a lobby before anyone can join. The lobby screen is entirely new UI.

**Independent Test**: Create a lobby, verify the lobby code is displayed, verify the host sees themselves in the player list.

**Acceptance Scenarios**:

1. **Given** an authenticated player, **When** they tap "Create Lobby", **Then** the app sends a POST to `/api/lobbies/` and navigates to the lobby screen showing the generated code.
2. **Given** the lobby screen, **When** the host views it, **Then** they see the lobby code prominently (for sharing), themselves in the player list, and a start button (disabled until all ready).
3. **Given** the lobby, **When** the host taps start with not all players ready, **Then** the start button remains disabled.
4. **Given** an unauthenticated player, **When** they attempt any lobby action, **Then** they are redirected to the auth screen.

---

### User Story 2 - Configure Roles Before Starting (Priority: P1)

The host selects which roles to include in the game before starting. The lobby screen offers preset recommended setups by player count (from the official rules) and allows manual adjustment with +/- controls per role. The total card count is validated (must equal player count + 3). Roles that require pairs (Masons) increment/decrement by 2.

**Why this priority**: Without this, every game uses the same roles. Configuration is what gives ONUW its replayability and is part of the core lobby setup flow.

**Independent Test**: Create a lobby with 5 players, select the "Intermediate" preset (Werewolf, Werewolf, Seer, Robber, Troublemaker, Drunk, Insomniac, Villager), start the game, verify the roles in play match the selection.

**Acceptance Scenarios**:

1. **Given** the host on the lobby screen, **When** they view the role configuration area, **Then** they see a list of all 12 v1 roles with the current count for each and +/- controls.
2. **Given** the host, **When** they select a recommended preset for their player count, **Then** the role counts auto-populate to match the preset.
3. **Given** the host with an invalid configuration (total cards != player count + 3), **When** they attempt to start, **Then** the start button is disabled and a validation message explains the issue.
4. **Given** the host taps "+" on Mason, **When** the count updates, **Then** it jumps from 0 to 2 (not 1). Tapping "-" jumps from 2 to 0. The Mason control never allows a count of 1.
5. **Given** the host with a valid configuration, **When** they start the game, **Then** the role settings are sent to the backend and the game uses the selected roles.
6. **Given** a non-host player in the lobby, **When** the host changes role configuration, **Then** all players see the updated `RoleTokenList` in real time.

---

### User Story 3 - Join a Lobby and Start a Game (Priority: P1)

A player opens the app, enters a lobby code, joins the lobby, and sees other players arriving in real time. The host starts the game and all players see a dramatic role reveal before entering the night phase.

**Why this priority**: Without lobby join and game start, no one can play. This is the entry point for every non-host player.

**Independent Test**: Create a guest account, create a lobby, have a second player join by code, toggle ready, start the game — verify both players see their role reveal and then the night phase.

**Acceptance Scenarios**:

1. **Given** an authenticated player on the home screen, **When** they enter a valid lobby code and tap join, **Then** they see the lobby screen with the current player list, each player's ready state, and the lobby code displayed prominently.
2. **Given** a player in a lobby, **When** another player joins, **Then** the lobby screen updates in real time (via WebSocket `player_joined` event) without a manual refresh.
3. **Given** a player in a lobby, **When** they toggle their ready state, **Then** all players see the updated ready status in real time via `player_ready` event.
4. **Given** the host with all players ready, **When** the host taps start, **Then** the host's start POST returns a game ID. All players learn the game has started via a lobby WebSocket event. If the WebSocket notification is missed (e.g., brief disconnect), the app falls back to polling `GET /api/onuw/me/current-game/`. All players see a role reveal animation ("You are the Seer") and transition to the night phase.
5. **Given** the host, **When** they view the lobby, **Then** they see a start control that is disabled until all players are ready.
6. **Given** a non-host player in the lobby, **When** they tap "Leave", **Then** a POST to `/api/lobbies/<code>/leave/` is sent and they return to the home screen. Other players see the departure in real time via the `player_left` event.
7. **Given** a lobby WebSocket event (`player_joined` or `player_left`) that carries only a username, **When** the event is received, **Then** the app re-fetches the full lobby state from `GET /api/lobbies/<code>/` to get complete player data (IDs, ready states).

---

### User Story 4 - Play Through the Night Phase (Priority: P1)

During the night phase, the game container screen shows the `PhaseIndicator` at night stage. Players who have an action this wave see the `NightActionPrompt`. Players who don't have an action see the night waiting view ("The village sleeps..."). After submitting an action, players see their result briefly, then return to waiting until the next wave or phase transition.

**Why this priority**: The night phase is the core mechanic. The `NightActionPrompt` widget already exists — the work here is the game container, waiting view, and wiring actions to the API.

**Independent Test**: Start a 5-player game with Werewolf, Seer, Robber, Troublemaker, and Villager. Verify the Seer gets an action prompt, submits a peek, sees the result, and the game advances to discussion.

**Acceptance Scenarios**:

1. **Given** a game in the night phase, **When** a player's wave is active and they have an action, **Then** the game container renders the `NightActionPrompt` with the correct action type for their role.
2. **Given** the Seer whose prompt includes two action types (`peek_player` and `peek_center`), **When** their wave starts, **Then** the game container first renders the Seer action choice view (two buttons). After the player picks, the game container renders `NightActionPrompt` with the chosen single action type.
3. **Given** a lone Werewolf (no other Werewolves among players), **When** their wave starts, **Then** `NightActionPrompt` shows the `seeTeam` view with the empty-teammate message. After acknowledging, the game container transitions to a 1-center-card picker (not handled by `NightActionPrompt` — this is a separate view or a parameterized `CenterCards` with `maxSelections: 1`). The player may skip the center peek instead.
4. **Given** a player with an optional action (Seer, Robber, Troublemaker, lone Werewolf), **When** their prompt is shown, **Then** they see a "Skip" option alongside the confirm button. Given a player with a mandatory action (Drunk, Doppelganger initial peek), **When** their prompt is shown, **Then** no skip option is available.
5. **Given** a player submits a night action, **When** the server responds with an `action_result` event containing `revealed_info`, **Then** the game container replaces `NightActionPrompt` with the night action result view (a separate view — `NightActionPrompt` has no result state). The result view shows until the wave completes. Specifically: the Seer sees the peeked role(s) via `RoleCard`; the Robber sees their new role card; the Insomniac sees their current card (which may differ from Insomniac if they were swapped — the display should say "Your card is now: [role]"); Werewolves/Masons/Minion see a teammate list; the Troublemaker and Drunk see a confirmation that the swap occurred (no role revealed).
6. **Given** the Doppelganger, **When** their wave starts, **Then** the app presents a peek-player prompt (mandatory). After submitting, the `action_result` reveals the copied role. If the copied role has an immediate follow-up action (Seer, Robber, Troublemaker, Drunk), the app presents a second prompt for that action within the same wave — this follow-up is always mandatory (no skip button), per the official optionality table in `night-phase.md` ("Doppelganger follow-up: Mandatory — Do it now"). If the copied role acts in a later wave (Werewolf, Mason, Minion, Insomniac), the Doppelganger returns to waiting and is re-prompted when that wave arrives. For Doppelganger-as-Insomniac (wave 4 follow-up), the result is a self-peek showing the player's current card — which may differ from the copied role if swapped. The display should clearly communicate "This is your current card." For Doppelganger-as-Minion with no Werewolves in play, the same "No werewolves among players" message applies.
6a. **Given** the Insomniac, **When** their wave starts, **Then** the backend sends an `action_prompt` with action type `peek_player` (self-targeted). The Insomniac has no choice to make — the app auto-submits the self-peek action, then immediately displays the result via the night action result view showing their current card. If the card changed (e.g., swapped to Werewolf by Robber), the display says "Your card is now: [role]."
7. **Given** the Minion or lone Mason, **When** the see-team result shows an empty teammate list (no Werewolves for Minion, no other Mason for lone Mason), **Then** the result display shows an appropriate message ("No werewolves among players" for Minion, "No other Masons among players" for Mason). Note: the existing `_SeeTeamAction` widget currently shows misleading text for these cases ("These are the werewolves" / "These are your fellow masons" above an empty list) — the widget needs updating to handle empty states per role.
8. **Given** a Doppelganger-as-Werewolf and a real Werewolf in the game, **When** the Werewolf wave starts, **Then** the real Werewolf sees the Doppelganger player in their teammate list, and the Doppelganger sees the real Werewolf. Same applies for Doppelganger-as-Mason with real Masons.
9. **Given** a player with no action this wave (Villager), **When** a `wave_waiting` event is received, **Then** they see the night waiting view with atmospheric text and a `GameTimer` countdown.
10. **Given** a wave completes, **When** the server broadcasts `wave_complete`, **Then** the game container advances to the next wave's view or transitions to discussion.
11. **Given** a player who does not act before the wave timer expires, **When** the server auto-advances, **Then** the player's action is skipped and the game proceeds.

---

### User Story 5 - Discuss and Vote (Priority: P1)

After the night phase, the game container transitions to the discussion phase view — a warm-lit screen with a prominent countdown timer, the roles in play (`RoleTokenList`), and host controls. When discussion ends, the container transitions to the `VoteSubmission` widget. After all votes, the `VoteReveal` widget shows results.

**Why this priority**: Discussion and voting are how the game resolves. The `VoteSubmission` and `VoteReveal` widgets exist — the work is the discussion view, phase transitions, and API wiring.

**Independent Test**: Reach the discussion phase, verify the countdown timer matches the server deadline, wait for voting, submit a vote, verify the vote reveal shows all players' targets.

**Acceptance Scenarios**:

1. **Given** the game transitions to discussion, **When** the `phase_change` event arrives with a deadline, **Then** the game container shows the discussion phase view with `GameTimer` counting down and `RoleTokenList` showing roles in play.
2. **Given** the discussion phase, **When** the host taps "End Discussion", **Then** a confirmation dialog asks "End discussion early? Players are still talking." If confirmed, a POST to `/api/onuw/games/<id>/end-discussion/` is sent. If cancelled, nothing happens.
3. **Given** the discussion timer expires, **When** the server transitions to voting, **Then** the game container transitions to show `VoteSubmission` with selectable player targets.
4. **Given** a player in the voting phase, **When** they select a target and confirm, **Then** the app sends a POST to `/api/onuw/games/<id>/vote/` and `VoteSubmission` shows the privacy-safe confirmation.
5. **Given** the voting phase, **When** the server broadcasts `vote_submitted` events, **Then** the app shows a vote progress indicator ("3 of 5 voted") without revealing who voted for whom. Each player's voted status is visible (checkmark or similar).
6. **Given** all votes are in (or the voting timer expires), **When** the server broadcasts `vote_reveal` (containing vote pairs only, no elimination data), **Then** the app enriches the raw vote IDs with player names from its local player list and computes the vote tally. The game container first shows the votes and tally only (not yet `VoteReveal`, since that widget shows "No one was eliminated!" when given an empty list — which would be misleading). When the `game_results` event arrives shortly after with eliminated player IDs, the game container renders the full `VoteReveal` with votes, tally, and elimination data. Players who abstained (disconnected or timed out) show "Abstained" instead of a vote target. If `game_results` is not received within 5 seconds of `vote_reveal`, the app falls back to fetching results via `GET /api/onuw/games/<id>/results/`.

---

### User Story 6 - See Game Results (Priority: P1)

After voting resolution, the game container transitions to the results phase. The `GameResults` widget shows who won, who was eliminated, all role reveals, and vote targets. Players can return to the home screen.

**Why this priority**: Results are the payoff. The `GameResults` widget exists — the work is wiring it to real data and providing navigation out.

**Independent Test**: Complete a full game through voting, verify the results screen shows winning team(s), eliminated players, original and final roles for all players, and vote targets.

**Acceptance Scenarios**:

1. **Given** the game transitions to results, **When** the `game_results` WebSocket event arrives (which contains only winning teams and eliminated player IDs), **Then** the app fetches the full results from `GET /api/onuw/games/<id>/results/` to obtain per-player role data, vote targets, and outcome details, and renders the `GameResults` widget.
2. **Given** the results screen, **When** a player views it, **Then** they see each player's original role, final role (if swapped), vote target, and whether they won or lost.
3. **Given** a game where no werewolves are among players and no one is eliminated, **When** the results screen is shown, **Then** the village wins and the results display explains "No werewolves were among the players — village wins by keeping the peace."
4. **Given** a game where no werewolves are among players and a non-Minion player is eliminated with no Minion in play, **When** the results screen is shown, **Then** no team wins and the results display shows "Nobody wins."
5. **Given** the Hunter (or Doppelganger-as-Hunter) is eliminated, **When** the results screen is shown, **Then** the player killed by the Hunter's chain ability is visually distinguished from vote-eliminated players (e.g., "Eliminated by Hunter" label) so players understand why a player with few or zero votes died. (Requires the backend results endpoint to include elimination reason per player — see Assumptions.)
6. **Given** no werewolves are among players but a Minion is, and a non-Minion player is eliminated, **When** the results screen is shown, **Then** the Werewolf team (Minion) wins and the results explain this unusual outcome.
7. **Given** only the Tanner (or Doppelganger-as-Tanner) is eliminated and Werewolves survive, **When** the results screen is shown, **Then** the Tanner wins and the Werewolf team does NOT win. The `_WinAnnouncement` shows "Tanner wins!" and the `_PlayerResultRow` shows "Doppelganger (as Tanner)" for the Doppelganger case.
8. **Given** both the Tanner and a Werewolf are eliminated (e.g., tied vote), **When** the results screen is shown, **Then** both the Tanner and the Village win. The results display multiple winning teams.
9. **Given** the results screen, **When** a player views it, **Then** they also see the final center card identities (what roles were in the center), since this helps explain game outcomes (e.g., confirming werewolves were in the center).
10. **Given** the results screen, **When** a player taps "Return to Lobby" or "Play Again", **Then** they navigate back to the home screen.

---

### User Story 7 - Reconnect Mid-Game (Priority: P2)

A player who closes the app or loses connection mid-game can reopen the app and resume from where they left off. The reconnection overlay shows while re-establishing the WebSocket, then dismisses into the correct phase view.

**Why this priority**: Mobile players frequently switch apps or lose signal. Without reconnection, a single dropped connection ruins the game for everyone.

**Independent Test**: Start a game, force-close the app during discussion phase, reopen, verify the player sees the reconnection overlay briefly, then the discussion screen with the correct remaining time on the timer.

**Acceptance Scenarios**:

1. **Given** a player reopens the app, **When** they have an active game, **Then** the app calls `GET /api/onuw/me/current-game/` and navigates directly to the game container at the correct phase.
2. **Given** a reconnected player in a timed phase, **When** the `/me/` endpoint returns a deadline, **Then** the timer shows the correct remaining time (deadline minus now).
3. **Given** a reconnected player during the night phase, **When** their wave has already passed, **Then** they see the night waiting view for the current wave.
4. **Given** a WebSocket disconnection mid-game, **When** the connection drops, **Then** the reconnection overlay appears. When the connection is restored, the overlay dismisses and the player resumes receiving events.
5. **Given** a reconnected player during the night phase who already submitted their action this wave, **When** the `/me/` endpoint returns `has_acted: true` with no action prompt, **Then** they see the night waiting view (not their previous action result — the result was a one-time WebSocket event).
6. **Given** a reconnected player during the voting phase who has already voted, **When** the `/me/` endpoint returns `has_voted: true`, **Then** they see the `VoteSubmission` locked view with vote progress updated from the per-player `has_voted` flags in the players list.

---

### Edge Cases

- What happens when the WebSocket connection drops mid-game? The reconnection overlay appears, the app attempts automatic reconnection with exponential backoff, and on success re-fetches game state via the `/me/` endpoint.
- What happens when a player's JWT token expires during a game? The auth interceptor automatically refreshes the token using the stored refresh token. If refresh fails, redirect to auth screen.
- What happens when a player submits an action but the server returns 409 (already acted)? Treat as success — the action was already recorded. This applies to both night actions (POST to `/action/`) and votes (POST to `/vote/`).
- What happens when the server returns 400 for a night action? Display the validation error and let the player retry with a different selection.
- What happens when a player opens the app with no active game? The `/me/current-game/` endpoint returns null; the app shows the home screen.
- What happens when the host leaves the lobby? The lobby is deleted — all players receive a `lobby_update` event and return to the home screen.
- What happens during role reveal if the player backgrounds the app? The role reveal auto-advances on a timer; if they return after it's passed, they go straight to the night phase.
- What happens when a player disconnects mid-game? Other players see a disconnected indicator (wifi-off badge via `PlayerDisplay.status = disconnected`) on that player's avatar during all phases. During night, a disconnected player's action is auto-skipped by the server timer. During voting, their vote is skipped (abstain). The disconnected player can reconnect at any time via the reconnection flow (US7).
- What happens if the host ends discussion and the timer simultaneously expires? The server handles this via `select_for_update` — only one transition fires. The client treats any `phase_change` to voting as authoritative regardless of source.
- What happens when the host ends discussion early for non-host players? The phase transition is immediate (server-driven). Non-host players see the discussion view replaced by the voting view. No pre-warning is needed — in the physical game, the countdown ending is equally abrupt. The confirmation dialog on the host side prevents accidental early ends.
- What happens if all players disconnect during a game? The server auto-skips all actions and votes via timers, advancing through phases to results with no eliminations. A reconnecting player lands on the results screen showing a completed game. This is mechanically correct — no special handling needed beyond the standard reconnection flow.

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
- **FR-010**: The app MUST show a role reveal view at game start — the player's assigned role (from the initial `GET /games/<id>/me/` response's `your_role.original_role`) with a card-flip animation — before transitioning to the first night wave.
- **FR-011**: The app MUST show a night waiting view with atmospheric text and a countdown timer when a player has no action in the current wave.
- **FR-012**: The app MUST show a discussion phase view with a prominent countdown timer, `RoleTokenList` of roles in play, and host "End Discussion" control.
- **FR-013**: The app MUST show a reconnection overlay when the WebSocket disconnects, dismissing automatically when connection is restored.

**Actions & API**

- **FR-014**: The app MUST submit night actions via POST to `/api/onuw/games/<id>/action/` with the correct `action_type` and `targets` payload.
- **FR-015**: The app MUST submit votes via POST to `/api/onuw/games/<id>/vote/` with the target player ID.
- **FR-016**: The app MUST handle lobby CRUD — create (POST `/api/lobbies/`), join (POST `/api/lobbies/<code>/join/`), leave (POST `/api/lobbies/<code>/leave/`), ready (POST `/api/lobbies/<code>/ready/`), and start (POST `/api/onuw/lobbies/<code>/start/`).
- **FR-017**: The app MUST display countdown timers driven by the server-provided deadline (not client-side duration), computed as `deadline - DateTime.now()`.
- **FR-020**: The host MUST be able to configure roles in the lobby — selecting from 12 v1 roles with +/- count controls, choosing from recommended presets by player count, with client-side validation (total = player count + 3). Paired roles (Masons) MUST increment/decrement by 2, making an invalid count of 1 impossible.
- **FR-021**: For roles with multiple action types (Seer: peek_player or peek_center), the app MUST present a pre-action choice screen (e.g., two buttons: "Look at one player's card" / "Look at two center cards") before rendering the `NightActionPrompt` with the chosen action type. This also applies to Doppelganger-as-Seer.
- **FR-022**: After a player submits a night action, the app MUST display the `action_result` revealed information (peeked roles, new role, teammate list) using appropriate UI until the wave completes.
- **FR-023**: The Doppelganger's multi-step night flow MUST be handled — first prompt (peek player), result display (copied role), then conditional second prompt if the copied role has an immediate action. During follow-up prompts, the role identity strip should show the copied role name (from the `action_prompt.role_acting_as` field), not "Doppelganger."
- **FR-026**: The lone Werewolf's compound interaction MUST be handled — first display the empty teammate list via `NightActionPrompt`'s `seeTeam` path, then transition to an optional 1-center-card picker. The `CenterCards` widget already supports `maxSelections: 1` — use it directly (not through `_PeekCenterAction` which hardcodes 2). The entire flow submits as a single `see_team` action with an optional `center_index` target. The player may skip the center peek.
- **FR-024**: The app MUST fetch full game results from `GET /api/onuw/games/<id>/results/` when the results phase begins, since the `game_results` WebSocket event contains only summary data. Vote target IDs from the response MUST be mapped to display names using the local player list for the `GameResults` widget.
- **FR-025**: During the voting phase, the app MUST show vote progress (how many players have voted) updated via `vote_submitted` WebSocket events, without revealing vote targets.
- **FR-027**: Upon receiving the `game_started` event on the lobby WebSocket, the app MUST: extract the game ID, disconnect the lobby WebSocket, connect the game WebSocket at `ws://<host>/ws/game/<game_id>/`, and fetch initial game state via `GET /games/<id>/me/`. If the game WebSocket connection fails, the app retries with exponential backoff while showing the reconnection overlay.
- **FR-028**: The `PlayerResult` model MUST include vote target data (ID and display name) so the results screen can show per-player vote targets. Players who abstained display "Did not vote" instead of a target name. The `VoteResult` model MUST support nullable `targetId`/`targetName` fields (currently `required String`) to represent abstainers in vote reveal. The `GameResult` model MUST include a `centerCards` field (list of role names) for US6 AS9.
- **FR-029**: The lobby MUST validate player count (3–10) before allowing game start. If the count is out of range, the start button is disabled with a message explaining the minimum or maximum.

**Routing & Security**

- **FR-018**: The app MUST route between home, lobby, game, and results screens using GoRouter with auth guards.
- **FR-019**: The app MUST never display another player's role, night action data, or vote target before the results phase.

**Backend (required changes to the existing Django backend)**

- **FR-030**: The backend MUST provide a `PATCH /api/lobbies/<code>/` endpoint that allows the host to update lobby settings (specifically the `roles` configuration) after creation. Non-host players MUST receive a 403. The endpoint MUST validate settings the same way `GameStartView` does. After a successful update, the endpoint MUST broadcast a `lobby_update` event to the lobby WebSocket group containing the updated settings, so non-host players see role changes in real time (US2 AS6). Required for US2 (role configuration in the lobby).
- **FR-031**: The `LobbyConsumer` MUST have a `game_started` handler that forwards the `game.started` event to all connected WebSocket clients. Currently the `GameStartView` broadcasts this event to the lobby channel group, but no handler exists on `LobbyConsumer` to dispatch it. Without this, non-host players have no real-time notification that the game started. Required for US3 AS4.
- **FR-032**: The `GameMeSerializer` MUST include a `roles_in_game` field containing the list of role names and counts from the game's settings. Currently `game.settings["roles"]` is not serialized. Required for FR-012 (showing `RoleTokenList` in the discussion phase). The frontend will also cache this at game start, but having it in the serializer supports reconnection (US7).
- **FR-033**: The results endpoint (`GET /api/onuw/games/<id>/results/`) MUST include per-player `elimination_reason` distinguishing vote elimination from Hunter chain kills (e.g., `"vote"` vs `"hunter_chain"`). Currently `eliminated_players` is a flat list of IDs with no reason. Required for US6 AS5 (Hunter chain kill display).

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
- **SC-008**: All existing backend tests continue to pass after FR-030 through FR-033. New backend tests cover the lobby PATCH endpoint, `game_started` handler, `roles_in_game` serialization, and `elimination_reason` in results.

## Assumptions

- The backend is mostly complete but requires 4 changes (FR-030 through FR-033). These are small, scoped additions — not architectural changes. All existing backend tests must continue to pass.
- The existing `PlayerResult` Freezed model needs a `voteTargetName` field (or equivalent) to display vote targets in the results screen per US6 AS2. The backend results endpoint already provides `vote_target_id` per player — this is a frontend model change, covered by FR-028.
- The `web_socket_channel` Dart package is the WebSocket client (already in pubspec.yaml or will be added).
- Timer display uses the server-provided UTC deadline, not client-side duration tracking, to avoid clock drift.
- The app connects to one WebSocket at a time — lobby WebSocket while in lobby, game WebSocket while in game. No simultaneous connections needed.
- The app supports only one active game per user at a time, matching the backend constraint.
- Role configuration offers preset recommended setups and manual +/- controls. Advanced features like custom role creation, saved configurations, or role descriptions/tooltips are out of scope.
- Timer configuration UI (discussion/voting/night wave durations) is out of scope — the backend defaults (300s discussion, 120s voting, 30s night wave) are used. The backend already supports configurable timers; a host-facing UI for adjusting them can be a separate feature.
- The role reveal animation is a brief interstitial (4 seconds), not a full screen the player interacts with.

## Reference Documents

- `backend/apps/core/urls.py` — Auth and lobby API endpoints
- `backend/apps/onuw/urls.py` — Game API endpoints
- `backend/apps/core/consumers.py` — LobbyConsumer WebSocket events (`player_joined`, `player_left`, `player_ready`, `lobby_update`)
- `backend/apps/onuw/consumers.py` — GameConsumer WebSocket events (`wave_start`, `wave_waiting`, `action_prompt`, `action_result`, `wave_complete`, `phase_change`, `vote_submitted`, `vote_reveal`, `game_results`)
- `backend/apps/onuw/serializers.py` — Response shapes for game state
- `frontend/lib/design_system/components/game/` — Existing game UI components to wire up
- `frontend/lib/design_system/models/` — Existing Freezed models (`PlayerDisplay`, `GameResult`, `NightActionSelection`, `RoleId`, `GamePhase`)
- `frontend/lib/features/auth/` — Existing auth infrastructure to extend
- `frontend/lib/core/api/api_client.dart` — Existing HTTP client to add interceptor to
- `frontend/lib/core/router/routes.dart` — Existing router to expand
