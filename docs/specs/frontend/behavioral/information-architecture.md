# Information Architecture

## Identity

| Field     | Value |
|-----------|-------|
| type      | pattern |
| id        | P-01 |
| phase     | all |
| route     | n/a (cross-cutting pattern) |

This document defines what information each player and the host sees across every game phase, how hidden information is protected, how information flows between phases, and how the UI handles role-specific information variance. It is the authoritative reference for information visibility decisions in all screen specs.

---

## Preconditions

- A game exists on the server with assigned roles, center cards, and a player list
- The client has an authenticated WebSocket connection scoped to a single player
- The server enforces player-scoped responses — the client never requests "all data," only "my data"

---

## Information Tiers

All game information falls into exactly one of three tiers. Every piece of data in the UI must be classifiable here.

### Tier 1: Public Information (known to all players)

| Data | Source | When Visible | Citation |
|------|--------|-------------|----------|
| Which roles are in the game (role tokens) | Server, game config | Lobby through Results | overview.md: "Place one token for each role in the game face-up in the center. All players can see which roles are potentially in play." |
| Number of players | Server, player list | Lobby through Results | overview.md: "3–10 players" |
| Number of center cards | Fixed: always 3 | Lobby through Results | overview.md: "plus 3 extras placed face-down in the center of the table" |
| Current game phase | Server, state machine | Always | overview.md: "SETUP → NIGHT → DISCUSSION → VOTING → RESOLUTION" |
| Phase timers (remaining time) | Server, broadcast | During timed phases (Discussion, Voting, Night waves) | — |
| Player names and avatars | Server, player list | Lobby through Results | — |
| Who is the host | Server, lobby config | Lobby through Results | — |
| Player ready states | Server, lobby | Lobby only | — |
| Vote submission status ("X/Y have chosen") | Server, voting phase | Voting phase only | overview.md: "Votes are simultaneous — no player sees others' votes before committing." The *count* of submissions is public; the *targets* are not. |
| Vote results (who voted for whom) | Server, resolution | After simultaneous reveal at end of Voting | voting-and-resolution.md: "Once all votes are collected (or the timer expires), all votes are revealed simultaneously to all players" |
| Who was eliminated | Server, resolution | Resolution/Results | voting-and-resolution.md: "Dead players flip their cards face-up." |
| Eliminated players' roles | Server, resolution | Resolution/Results | voting-and-resolution.md: "Reveal roles. Dead players flip their cards face-up." |
| Winning team(s) | Server, resolution | Results | — |
| Night wave progress (which wave is active) | Server, night phase | Night phase only (dot indicator) | — |
| Lobby code | Server, lobby | Lobby only | — |

### Tier 2: Player-Scoped Information (known to one player only)

| Data | Who Sees It | When Visible | Reveal Timing | Citation |
|------|-------------|-------------|---------------|----------|
| Own original role (from setup peek) | The player dealt that card | Role Reveal through Results | Shown on role reveal card flip | overview.md: "Each player secretly looks at their own card, memorizes it" |
| Night action results (what they learned) | The player who performed the action | Night phase through Results | Shown immediately after action resolves | Per-role specs in roles.md |
| Werewolf teammates | Each Werewolf player | Night phase (Wave 2) | Shown during Werewolf wake | roles.md: "All Werewolves open their eyes simultaneously and see each other." |
| Minion's knowledge of Werewolves | Minion only | Night phase (Wave 2) | Shown during Minion wake | roles.md: "The Minion sees which players are Werewolves. This is one-directional." |
| Mason partner(s) | Each Mason player | Night phase (Wave 2) | Shown during Mason wake | roles.md: "Both Masons open their eyes simultaneously and see each other." |
| Seer peek result | Seer only | Night phase (Wave 3) | After Seer selects target(s) | roles.md: "The Seer chooses one of two options: Look at one other player's card [or] Look at two center cards" |
| Robber's new card | Robber only | Night phase (Wave 3) | After Robber selects target | roles.md: "The Robber swaps their own card with that player's card, then views their new card" |
| Insomniac's current card | Insomniac only | Night phase (Wave 4) | After all Wave 3 swaps resolve | roles.md: "The Insomniac opens their eyes and looks at their own card to see if it changed" |
| Doppelganger's copied role | Doppelganger only | Night phase (Wave 1) | After Doppelganger peeks target | doppelganger.md: "She looks at one other player's card. She becomes that role." |
| Doppelganger's follow-up action results | Doppelganger only | Night phase (Wave 1, 2, or 4 depending on copied role) | After follow-up resolves | doppelganger.md interaction matrix |
| Own current vote selection | Voting player | Voting phase | Immediately on selection (tap-to-reveal protected) | vision brief: "Tap-to-reveal for your own current selection (in-person guardrail)." |
| Own personal outcome (win/loss) | Each player | Results phase | After team result headline | — |

### Tier 3: Server-Only Information (never sent to any client until authorized)

| Data | Authorized Disclosure | Citation |
|------|----------------------|----------|
| All card assignments (original deal) | Never during game; optionally in full autopsy at Results | overview.md: "Private Information (known only to the server) — All card assignments (original and current)" |
| Center card identities | Only to roles that peek center (Seer option B, lone Werewolf, Doppelganger-as-Seer) | overview.md: "Center card identities" listed under Private Information |
| Complete night action log | Only in full autopsy at Results | overview.md: "Night action log (who did what)" listed under Private Information |
| Each player's current role (after swaps) | Only via authorized peek actions during Night; fully revealed at Results | overview.md: "Each player's current role" listed under Private Information |
| Other players' vote targets | Never during Voting; revealed simultaneously at end of Voting | voting-and-resolution.md: "Votes are hidden from all players until all votes are in" |
| Who the Robber robbed / Troublemaker swapped / Drunk swapped with | Only to the acting player; detail available in full autopsy | — |
| Doppelganger's copied role identity | Only to the Doppelganger player; resolved at Results for the full table | doppelganger.md: "The copy is tracked by the server" |

---

## States

These are the information visibility states that the system moves through. Each state defines which tier of information is available to each persona (host, active player, passive player).

| State ID | Trigger | What the user sees | Audio/Haptic |
|----------|---------|-------------------|--------------|
| IA-LOBBY | Game created, players joining | Tier 1: lobby code, player list, ready states, roles in play. Host also sees role config controls (S04) and timer configuration (S04b: preset selector + per-phase sliders). Timer preset and per-phase values are host-only during setup. No Tier 2 or Tier 3 data exists yet. | `Ambience.lobby` |
| IA-ROLE-REVEAL | Night phase begins, cards dealt | Tier 1: phase indicator, wave progress. Tier 2: own role card (tap-to-reveal protected, face-down until player taps). | `SoundCues.waxSealBreak` on flip, `AppHaptics.dramaticReveal` |
| IA-NIGHT-ACTIVE | Player's wave is called, player has an action | Tier 1: wave indicator, timer. Tier 2: night action prompt, action targets, action results after submission. | Per-wave narrator cue, `AppHaptics.narratorBeat` |
| IA-NIGHT-WAITING | Player has no action this wave, or wave is not theirs | Tier 1: wave indicator, timer. Tier 2: none new (prior night results are NOT displayed on the waiting screen; see `night-waiting.md`). Fidget interactions active. | Fidget sounds/haptics on interaction |
| IA-NIGHT-RESULT | Player's action has resolved | Tier 1: wave indicator. Tier 2: action result displayed (card peek, swap confirmation, teammate list). Tap-to-reveal protected. | `SoundCues.cardPeek`, `AppHaptics.tapMedium` |
| IA-DISCUSSION | All night waves complete | Tier 1: timer (color-ramping), roles in play list. Tier 2: role reminder (tap-to-reveal), night results (tap-to-reveal). No new info from server. | `Ambience.discussion`, timer warning sounds |
| IA-VOTING | Discussion ends | Tier 1: player grid, vote counter ("X/Y have chosen"), timer. Tier 2: own current selection (tap-to-reveal). Other players show checkmark (voted) or empty (not yet voted). | `Ambience.voting`, `AppHaptics.selectionClick` on vote change |
| IA-VOTE-REVEAL | Voting timer expires or host ends voting | Tier 1: all vote targets revealed simultaneously (progressive tally build). Tier 2: none new. | `SoundCues.tallyTick` per vote, `AppHaptics.tallyTick` |
| IA-ELIMINATION | Vote tally complete | Tier 1: eliminated player name + revealed role. Hunter chain if applicable. "No one dies" variant. | `SoundCues.eliminationReveal` or `SoundCues.noElimination` |
| IA-RESULTS | Elimination sequence complete | Tier 1: winning team, all eliminated players' roles. Tier 2: personal win/loss. Progressive disclosure: player table -> full autopsy (Tier 3 data: complete night log, all original/final roles). | `SoundCues.winFanfare`/`SoundCues.lossSomber` |

---

## Transitions

| From State | Condition | To State | Animation |
|------------|-----------|----------|-----------|
| IA-LOBBY | Host starts game, server confirms | IA-ROLE-REVEAL | T-01 (Lobby -> Night, 2500ms cinematic) |
| IA-ROLE-REVEAL | Player taps card to reveal | IA-NIGHT-WAITING or IA-NIGHT-ACTIVE | M-01 card flip (600ms), then wave content loads after role reveal hold |
| IA-NIGHT-WAITING | Player's wave is called and player has an action | IA-NIGHT-ACTIVE | T-08 wave transition (800ms) |
| IA-NIGHT-ACTIVE | Player submits action or timer expires | IA-NIGHT-RESULT | Card peek animation (M-02, 600ms) or confirmation feedback |
| IA-NIGHT-RESULT | Wave completes, next wave begins | IA-NIGHT-WAITING or IA-NIGHT-ACTIVE | T-08 wave transition (800ms) |
| IA-NIGHT-WAITING | All waves complete | IA-DISCUSSION | T-02 (Night -> Discussion, 2500ms cinematic) |
| IA-NIGHT-ACTIVE | All waves complete (player was last active) | IA-DISCUSSION | T-02 |
| IA-DISCUSSION | Timer expires or host ends early | IA-VOTING | T-03 (Discussion -> Voting, 2000ms) |
| IA-VOTING | Timer expires or host ends voting | IA-VOTE-REVEAL | T-04 (Voting -> Vote Reveal, 1200ms) |
| IA-VOTE-REVEAL | Tally build complete | IA-ELIMINATION | T-05 (Vote Reveal -> Elimination, 1500ms) |
| IA-ELIMINATION | Elimination sequence complete | IA-RESULTS | T-06 (Elimination -> Results, 1500ms) |
| IA-RESULTS | Host or player taps "Play Again" | IA-LOBBY | T-07 (Results -> Lobby, 1000ms) |

---

## Interactions

| Element | Event | Result | Haptic | Sound |
|---------|-------|--------|--------|-------|
| Role card (face-down) | Tap | Card flips to reveal role (Tier 2 data disclosed). Irreversible. | `AppHaptics.dramaticReveal` | `SoundCues.waxSealBreak` |
| Role reminder (Discussion) | Tap | Shows own original role for 3 seconds, then auto-hides (UI-21/UI-22). Tap-to-reveal guardrail. | `AppHaptics.tapLight` | none |
| Night result reminder | Tap | Shows night action result for 3 seconds, then auto-hides. Tap-to-reveal guardrail. | `AppHaptics.tapLight` | none |
| Vote selection reminder (Voting) | Tap | Shows current vote target for 3 seconds, then auto-hides. Tap-to-reveal guardrail. | `AppHaptics.tapLight` | none |
| Night action target (player grid) | Tap | Selects player as action target. Selection is fluid — tap another to change. Selection glow (UI-04). | `AppHaptics.selectionClick` | none |
| Night action target (center card) | Tap | Selects center card as peek/swap target. Selection glow (UI-04). | `AppHaptics.selectionClick` | none |
| Vote target (player grid) | Tap | Selects player as vote target. Fluid — tap another to change. Selection glow (UI-04). Other players see checkmark appear (no target info). | `AppHaptics.selectionClick` | none |
| "End Discussion" (host only) | Tap | Triggers T-03 transition. Finalizes discussion timer. | `AppHaptics.tapMedium` | `SoundCues.votingStart` |
| "End Voting" (host only) | Tap | Triggers T-04 transition. Locks all current selections as final votes. | `AppHaptics.tapMedium` | `SoundCues.votesLocked` |
| Roles in play (collapsible list) | Tap header | Expands/collapses the list of roles in the current game. Public info (Tier 1). | `AppHaptics.tapLight` | none |
| Results table (collapsed rows) | Tap row | Expands row to show player's original role -> final role, vote target. Progressive disclosure of Tier 1 data (post-game). | `AppHaptics.tapLight` | none |
| Full autopsy link | Tap | Opens complete night log (Tier 3 data, now disclosed). Every swap, every peek, chronological. | `AppHaptics.tapLight` | none |
| Night waiting fidget (embers) | Tap | Burst of ember particles from tap point (F-01). No game-relevant information. | `AppHaptics.fidgetResponse` | `SoundCues.fidgetEmber` |
| Night waiting fidget (smoke) | Drag | Smoke trail follows finger (F-02). No game-relevant information. | `AppHaptics.fidgetResponse` | `SoundCues.fidgetSmoke` |

---

## Information Flow Across Phases

How information gained in one phase carries into the next. This is critical for the tap-to-reveal system — players accumulate private knowledge across phases and need to reference it without exposing it.

### Night -> Discussion

| Information Gained at Night | Available During Discussion | Display Method |
|-----------------------------|---------------------------|----------------|
| Own original role | Yes — tap-to-reveal role reminder card | Hidden by default, revealed on tap for 3s |
| Werewolf teammate identities | Yes — player must remember (no explicit UI reminder) | Not redisplayed. The player saw it during Wave 2. Memory-based. |
| Minion's knowledge of Werewolves | Yes — player must remember | Not redisplayed. Memory-based. |
| Mason partner identity | Yes — player must remember | Not redisplayed. Memory-based. |
| Seer peek result | Yes — tap-to-reveal night result card | Shows "You saw: [Player] is [Role]" or "Center cards: [Role], [Role]" |
| Robber's new role | Yes — tap-to-reveal night result card | Shows "You took [Player]'s card: [Role]" |
| Troublemaker swap targets | Yes — tap-to-reveal night result card | Shows "You swapped [Player A] and [Player B]" (no role info — swap was blind) |
| Drunk swap target | Yes — tap-to-reveal night result card | Shows "You swapped with center card [position]" (no role info — swap was blind) |
| Insomniac's current card | Yes — tap-to-reveal night result card | Shows "Your card is now: [Role]" |
| Doppelganger copied role | Yes — tap-to-reveal night result card | Shows "You copied [Player]: [Role]" plus follow-up result if applicable |
| No night action (Villager, Hunter, Tanner) | N/A — no information gained | Same tap-to-reveal card as every other role; revealed text is "You slept through the night." Maintains layout parity. |

**Design rationale:** Team-identification information (Werewolf, Mason, Minion) is NOT re-shown as a reminder because it reveals critical strategic information if seen by another player glancing at the phone. The player is expected to remember their teammates. Peek-type information (Seer, Robber, Insomniac, Doppelganger) IS available via tap-to-reveal because it can be complex (card names, multiple targets) and forgetting it degrades the game experience.

### Discussion -> Voting

| Information | Available During Voting | Display Method |
|-------------|------------------------|----------------|
| Own original role | No — not displayed on the Voting screen (see `day-phase.md`) | — |
| Night action results | Yes — tap-to-reveal night result | Same as Discussion |
| Discussion claims (verbal) | Not tracked by the app | Players talk in person; the app does not record claims |

### Voting -> Results

| Information | Available During Results | Display Method |
|-------------|------------------------|----------------|
| All prior Tier 2 info | Yes | Integrated into results table context |
| Vote targets (all players) | Yes — Tier 1 after reveal | Vote tally build (M-03) then results table |
| Eliminated player(s) and roles | Yes — Tier 1 after reveal | Elimination announcement (M-04/M-05) |
| Winning team(s) | Yes — Tier 1 | Win/loss announcement (M-06) |
| All players' original + final roles | Yes — Tier 1 (post-game) | Results table, progressive disclosure |
| Complete night log | Yes — Tier 3 (now disclosed) | Full autopsy, on-demand |

---

## Role-Specific Night Information Variance

Different roles produce wildly different night experiences. The UI must handle all categories through a composable action framework, not per-role screens.

### Category 1: No Night Action

| Roles | Night Experience | Information Gained |
|-------|-----------------|-------------------|
| Villager, Tanner, Hunter | Never called during any wave. Full night spent in waiting state. | None beyond their original role card. |

**UI:** Night waiting layer only. Wave indicator shows progress. Fidget interactions active. No action prompt ever appears. During discussion and voting phases, these roles see the same night results tap-to-reveal card as every other role (revealed text: "You slept through the night."), maintaining layout parity with roles that have night results to display.

**Citation:** roles.md — Villager: "The Villager never wakes during the night." Hunter: "The Hunter never wakes during the night." Tanner: "The Tanner never wakes during the night."

### Category 2: Auto-Reveal (Information, No Player Choice)

| Role | Night Experience | Information Gained | Action Type |
|------|-----------------|-------------------|-------------|
| Werewolf (multiple) | Opens eyes in Wave 2, sees other Werewolves | Teammate identities | `see_team` |
| Minion | Opens eyes in Wave 2, sees Werewolf thumbs | Werewolf identities (one-way) | `see_team` |
| Mason | Opens eyes in Wave 2, sees other Mason(s) | Mason partner identity | `see_team` |
| Insomniac | Opens eyes in Wave 4, sees own current card | Own current role | `peek_player` (self) |

**UI:** Information displayed automatically when the wave is called. No player selection required. Show teammate/partner avatars highlighted, or card revealed automatically. Brief hold (wave timer), then close eyes (return to waiting).

**Citation:** roles.md — Werewolf: "All Werewolves open their eyes simultaneously and see each other." Minion: "Werewolves (eyes closed) extend thumbs. Minion sees Werewolf identities." Mason: "Both Masons open their eyes simultaneously and see each other." Insomniac: "The Insomniac opens their eyes and looks at their own card."

### Category 3: Simple Choice (One Selection)

| Role | Night Experience | Player Choice | Information Gained | Action Type |
|------|-----------------|--------------|-------------------|-------------|
| Robber | Wave 3: select one other player | Which player to rob | Their new card (the one taken) | `swap_with_player` |
| Troublemaker | Wave 3: select two other players | Which two players to swap | None (swap is blind) | `swap_others` |
| Drunk | Wave 3: select one center card | Which center card to take | None (swap is blind) | `swap_with_center` |
| Werewolf (lone) | Wave 2: optionally select one center card | Which center card to peek (optional) | One center card identity | `peek_center` |

**UI:** Player grid or center card slots with selection glow. Fluid selection — tap to select, tap another to change; the selection is changeable until the player taps Confirm or the timer expires with a valid selection. Robber sees result card flip after swap. Troublemaker and Drunk see confirmation only (no card reveal).

**Citation:** roles.md — Robber: "You may exchange your card with another player's card, and then view your new card." Troublemaker: "You may exchange cards between two other players." Drunk: "Exchange your card with a card from the center." (Note: Drunk is mandatory; Robber and Troublemaker are optional per onuw/night-phase.md action optionality table.)

### Category 4: Branching Choice (Choose Action Type, Then Target)

| Role | Night Experience | First Choice | Second Choice | Information Gained | Action Type |
|------|-----------------|-------------|--------------|-------------------|-------------|
| Seer | Wave 3: choose peek type, then target(s) | Peek one player OR peek two center cards | Player selection OR center card selection | One player's role OR two center card roles | `peek_player` or `peek_center` |

**UI:** First screen: choice between "View a player's card" and "View two center cards." Second screen: player grid (option A) or center card slots (option B). Result: card flip reveal(s). Both choices and result are within the Seer's wave timer.

**Citation:** roles.md — Seer: "The Seer chooses one of two options: Look at one other player's card [or] Look at two center cards."

### Category 5: Multi-Step (Peek, Then Conditional Follow-Up)

| Role | Night Experience | Step 1 | Step 2 (Conditional) | Citation |
|------|-----------------|--------|---------------------|----------|
| Doppelganger | Wave 1: peek one player's card, then perform copied role's action | Select a player, see their role | Depends on copied role — could be any of Categories 1-4 above | doppelganger.md: "She looks at one other player's card. She becomes that role." |

**UI:** Step 1: player grid, select one player, card flip reveals their role. Step 2: action framework renders the appropriate action UI for the copied role (if the copied role has an immediate action). For Wave 2 roles (Werewolf, Mason, Minion), Doppelganger's follow-up happens later in Wave 2. For Insomniac, follow-up happens in Wave 4.

**Timing considerations:** The Doppelganger may need extra time since they perform two sequential actions. The wave timer for Wave 1 should account for this.

**Citation:** onuw/night-phase.md: "The Doppelganger may need extra time since they must peek first and then potentially perform a follow-up action."

---

## Host vs Player Information Divergence

The host is a player who also has administrative controls. The host has NO additional game information — they see only their own role and actions like any other player. The difference is purely in control surfaces.

| Phase | Player Sees | Host Additionally Sees |
|-------|-------------|----------------------|
| Lobby | Player list, ready states, lobby code, roles in play | Role configuration controls (stepper to add/remove roles) on S04, timer configuration (preset selector + per-phase sliders) on S04b, "Start Game" button on S04b (enabled when all constraints met), validation banners for invalid configs. During gameplay, the active timer value is Tier 1 (visible to all), but the configured presets and slider ranges are not. |
| Night | Own night experience (per role category above) | No additional night info. Host is a normal player during night. |
| Discussion | Timer, role reminder (tap-to-reveal), roles in play | "End Discussion Early" button (contextual, themed, `AppColors.surface` card with `AppColors.parchment` text) |
| Voting | Player grid, own selection, vote counter, timer | "End Voting Now" button (same contextual treatment). Ends voting, locks all current selections. |
| Vote Reveal | Vote tally build | No additional controls |
| Elimination | Elimination announcement | No additional controls |
| Results | Win/loss, results table, full autopsy | "Play Again" button (returns group to lobby), "End Game" button |

**Critical constraint:** The host MUST NOT see any other player's role, night action, or vote target before the authorized reveal moment. The host has power over timing (advance phases early) but zero additional information.

**Citation:** CLAUDE.md core principle: "Hidden information — Server knows everything, but API responses are player-scoped. A player ONLY sees what their role allows. NEVER leak another player's secret info."

---

## Tap-to-Reveal Guardrail System

In-person play means other players can see your phone screen. Sensitive information must be actively requested and auto-concealed.

### What Is Protected

| Protected Information | Screen(s) | Default State | Reveal Gesture | Reveal Duration | Auto-Hide |
|----------------------|-----------|---------------|---------------|----------------|-----------|
| Own role card (after initial reveal) | Discussion | Hidden — shows card back | Tap role reminder area | 3000ms | Yes (UI-22: 200ms fade out) |
| Night action results | Discussion, Voting | Hidden — shows "Tap to recall" label | Tap night result area | 3000ms | Yes |
| Current vote selection | Voting | Hidden — shows neutral "You've voted" checkmark | Tap vote reminder area | 3000ms | Yes |

**Duration variant:** Doppelganger multi-result tap-to-reveal extends auto-hide from 3000ms to **5000ms** to accommodate reading two stacked results (copy + follow-up).

### What Is NOT Protected (Always Visible)

| Unprotected Information | Reason |
|------------------------|--------|
| Roles in play list | Public Tier 1 info — all players know this |
| Player names and avatars | Public Tier 1 info |
| Timer | Public Tier 1 info |
| Vote counter ("X/Y have chosen") | Public Tier 1 info — counts, not targets |
| Night waiting fidget effects | Not game-relevant |
| Results table (after game) | All info is disclosed post-game |
| Phase indicators | Public Tier 1 info |

### Guardrail Behavior

| Property | Value |
|----------|-------|
| Reveal animation | UI-21: opacity 0.0 -> 1.0 over `AppDurations.fast` (200ms), `AppCurves.enter` |
| Conceal animation | UI-22: opacity 1.0 -> 0.0 over `AppDurations.fast` (200ms), `AppCurves.exit` |
| Auto-hide timeout | 3000ms from reveal start |
| Re-reveal | Tap again after auto-hide to re-reveal. No cooldown. |
| Dismiss early | Tap again while revealed to immediately hide (triggers UI-22) |
| Multiple reveals | Only one protected element visible at a time. Revealing element B auto-hides element A. |
| Screen sleep | Protected info auto-hides if the app goes to background or screen locks |

---

## Errors

| Error | In-World Headline | Clear Subtitle | Recovery | Information Tier Impact |
|-------|-------------------|----------------|----------|------------------------|
| Player disconnects mid-game | "A villager has wandered into the fog..." | *[Name] disconnected. Game paused.* | T-09 disconnect overlay. All interaction disabled. Wait for reconnect or host drops player. | No info changes. Tier 2 data for disconnected player remains server-side. |
| Player reconnects | "They have returned!" | *[Name] reconnected.* | T-09 dismiss. State catch-up — player receives their current Tier 2 state for the active phase. | Reconnected player receives: current phase, own role, any unviewed night results, current vote selection if voting. |
| Server connection lost | "The spirits are restless..." | *Connection lost. Reconnecting...* | Auto-retry with exponential backoff. Loading candle animation. | No new Tier 1/2 data until reconnected. Cached state remains visible. |
| Invalid lobby code | "The tavern door is barred..." | *No lobby with that code.* | Return to join screen. | No game info to protect — pre-game error. |
| Lobby full | "The village is full..." | *This lobby has reached capacity.* | Return to home screen. | No game info to protect — pre-game error. |
| Vote timeout (no selection) | None (silent) | Vote counted as abstention (not counted). | Player sees "You did not vote" in results. | voting-and-resolution.md: "If a player does not submit a vote before the timer expires, their vote is skipped." |
| Night action timeout | None (silent) | Action skipped. Logged as "skip" on server. | Player sees "Action skipped" in night result area. | onuw/night-phase.md: "If a player does not submit an action before the timer expires, their action is skipped." |

---

## Animation

Animation choreography is defined in `sound-and-motion.md`. This document references those definitions by ID for information-relevant moments only.

| Moment | Reference | What Information Appears | Duration |
|--------|-----------|------------------------|----------|
| Role card flip | M-01 | Tier 2: own role identity | 600ms (`AppDurations.theatrical`) |
| Night action card peek | M-02 | Tier 2: target's role identity | 600ms + 400ms hold |
| Vote tally build | M-03 | Tier 1: all vote targets (progressive) | 6000ms (`AppDurations.voteBuild`) |
| Elimination reveal | M-04 | Tier 1: eliminated player's role | 2000ms per player |
| No elimination | M-05 | Tier 1: "No one was eliminated" | 1800ms |
| Win/loss announcement | M-06 | Tier 1: winning team. Tier 2: personal outcome. | 2000ms |
| Tap-to-reveal show | UI-21 | Tier 2: recalled private info | 200ms in, 3000ms hold, 200ms out |
| Phase transition overlay | T-01 through T-07 | Tier 1: new phase indicator | Per-transition (1000-2500ms) |

---

## Strings

| Key | Default Text | Notes |
|-----|-------------|-------|
| `info.tapToRevealRole` | "Tap to view your role" | Tap-to-reveal prompt, Discussion |
| `info.tapToRecallResult` | "Tap to recall" | Tap-to-reveal prompt for night result |
| `info.tapToViewVote` | "Tap to view your vote" | Tap-to-reveal prompt for vote selection |
| `info.votedIndicator` | "You've voted" | Neutral indicator shown when vote is concealed |
| `info.noVoteWarning` | "You did not vote" | Results, if player timed out during voting |
| `info.actionSkipped` | "Action skipped" | Night result area if action timed out |
| `info.voteCount` | "{count}/{total} have chosen" | Voting phase, public vote counter |
| `info.rolesInPlay` | "Roles in play" | Collapsible header for role token list |
| `info.nightResultSeerPlayer` | "You saw: {player} is {role}" | Seer peek result (option A) |
| `info.nightResultSeerCenter` | "Center cards: {role1}, {role2}" | Seer peek result (option B) |
| `info.nightResultRobber` | "You took {player}'s card: {role}" | Robber swap result |
| `info.nightResultTroublemaker` | "You swapped {playerA} and {playerB}" | Troublemaker swap result (no role info) |
| `info.nightResultDrunk` | "You swapped with center card {position}" | Drunk swap result (no role info) |
| `info.nightResultInsomniac` | "Your card is now: {role}" | Insomniac self-peek result |
| `info.nightResultDoppelgangerCopy` | "You copied {player}: {role}" | Doppelganger initial peek result |
| `info.nightResultWerewolfTeam` | "Your fellow werewolves: {players}" | Werewolf see_team result (empty if lone) |
| `info.nightResultWerewolfLone` | "You are the lone werewolf" | Lone werewolf indicator |
| `info.nightResultWerewolfLonePeek` | "Center card: {role}" | Lone werewolf center peek result |
| `info.nightResultMasonTeam` | "Your fellow mason: {player}" | Mason see_team result |
| `info.nightResultMasonLone` | "You are the lone mason" | Lone mason (other in center) |
| `info.nightResultMinionTeam` | "The werewolves are: {players}" | Minion see_team result |
| `info.nightResultMinionNoWerewolves` | "There are no werewolves among players" | Minion result when all WW in center |
| `info.noOneEliminated` | "No one was eliminated" | Elimination phase, no-death variant |
| `info.eliminated` | "{player} was eliminated" | Elimination announcement |
| `info.eliminatedRole` | "{player} was the {role}" | Role reveal after elimination |
| `info.hunterChain` | "The Hunter takes aim..." | Narrator text before Hunter chain kill |
| `info.teamWins` | "{team} WINS!" | Result headline |
| `info.youWin` | "You Win." | Personal outcome (positive) |
| `info.youLose` | "You Lose." | Personal outcome (negative) |
| `info.noOneWins` | "NO ONE WINS" | Result when no team wins |
| `info.fullAutopsy` | "View full night log" | Link to complete night log in Results |

---

## Information Architecture Per Screen

Summary of information tiers visible on each major screen, for quick reference by screen spec authors.

### Pre-Game Screens

| Screen | Tier 1 (Public) | Tier 2 (Player-Scoped) | Tier 3 (Server-Only) | Host-Extra |
|--------|-----------------|----------------------|---------------------|------------|
| Welcome/Auth | None (no game yet) | Player name (input) | — | — |
| Home | Online player count | Player name | — | — |
| Lobby | Player list, ready states, lobby code, roles in play | — | — | Role config, Start Game, validation |

### Game Screens

| Screen | Tier 1 (Public) | Tier 2 (Player-Scoped) | Tier 3 (Server-Only) | Host-Extra | Tap-to-Reveal |
|--------|-----------------|----------------------|---------------------|------------|---------------|
| Role Reveal | Phase indicator | Own role (after card flip) | — | — | Card flip is the reveal gesture |
| Night (Active) | Wave indicator, timer | Action prompt, action result | — | — | Action result auto-displayed |
| Night (Waiting) | Wave indicator, timer | — (prior night results not displayed) | — | — | None |
| Discussion | Timer, roles in play | Own role, night results | — | End Discussion | Role + night results: tap-to-reveal |
| Voting | Timer, player grid, vote counter | Own vote selection | — | End Voting | Vote selection: tap-to-reveal |
| Vote Reveal | Full vote tally | — | — | — | None (all public) |
| Elimination | Eliminated player + role | — | — | — | None (all public) |
| Results (headline) | Winning team(s) | Personal win/loss | — | Play Again, End Game | None |
| Results (table) | All players' original -> final roles, vote targets | Personal outcome highlighted | — | — | None (post-game) |
| Results (autopsy) | — | — | Complete night log (now disclosed) | — | None (on-demand Tier 3) |

---

## Edge Cases

### No Werewolves Among Players

All Werewolf cards are in the center. Minion (if present) sees an empty Werewolf list.

| Affected Information | Handling | Citation |
|---------------------|----------|----------|
| Minion's see_team result | Show: "There are no werewolves among players." (`info.nightResultMinionNoWerewolves`) | roles.md: "If no Werewolves are among players (all in center): an empty list." |
| Win condition (no one dies) | Village wins. Display "VILLAGE WINS!" | voting-and-resolution.md: "No Werewolves among players... No one dies: Village wins." |
| Win condition (Minion present, non-Minion dies) | Werewolf team (Minion) wins. Display "WEREWOLF TEAM WINS!" | voting-and-resolution.md: "Minion wins if a non-Minion player dies." |
| Win condition (only Minion dies) | No team wins. Display "NO ONE WINS." | voting-and-resolution.md: "If only the Minion dies, no team wins cleanly." |

### Tanner Elimination Interactions

| Scenario | Display | Citation |
|----------|---------|----------|
| Only Tanner dies, Werewolves survive | "TANNER WINS!" (Tanner-specific headline, `AppColors.teamIndependent`). Werewolf team does NOT win. | voting-and-resolution.md: "If the Tanner dies and no Werewolves die, the Werewolves do not win." |
| Tanner + Werewolf both die (tie) | "VILLAGE WINS! TANNER WINS!" (dual headline). Both teams win. | voting-and-resolution.md: "At least one Werewolf player dies, Tanner also dies: Village wins AND Tanner wins." |
| Doppelganger-as-Tanner dies | Same as Tanner death — Doppelganger wins as Tanner. | doppelganger.md: "Doppelganger-as-Tanner wins only if the Doppelganger is eliminated." |

### Hunter Chain Kill

| Step | Information Revealed | Display | Citation |
|------|---------------------|---------|----------|
| Hunter dies from vote | Hunter's role revealed (Tier 1) | Standard elimination announcement (M-04) | voting-and-resolution.md: "If the Hunter dies, the player the Hunter voted for also dies." |
| Chain kill announced | "The Hunter takes aim..." narrator text | 400ms narrator overlay after 600ms pause | sound-and-motion.md M-04 Hunter chain variant |
| Chain target dies | Chain target's role revealed (Tier 1) | Second M-04 elimination sequence | voting-and-resolution.md: "regardless of how many votes that target received" |
| Doppelganger-as-Hunter dies | Same chain — Doppelganger's vote target also dies | Same display. The ability follows the copied role. | doppelganger.md: "if the Doppelganger-as-Hunter is eliminated, the player the Doppelganger voted for is also eliminated." |
| Chain does NOT recurse | If Hunter kills a Doppelganger-as-Hunter, no further chain. | Only one chain kill. | voting-and-resolution.md: "Hunter chain kills do not recurse." |

### Lone Werewolf Center Peek

| Step | Information | Display | Citation |
|------|------------|---------|----------|
| Single Werewolf wakes, sees no teammates | "You are the lone werewolf" message. | Auto-display in Wave 2. | roles.md: "Lone Werewolf rule: If only one Werewolf is among the players..." |
| Optional center card peek | Player may tap one center card to peek. | Center card slots displayed with selection glow. Card flip (M-02) on selection. | roles.md: "the lone Werewolf may look at one center card. This is optional." |
| Player declines peek | No additional information. Timer expires, wave advances. | "Action skipped" if timer expires. | onuw/night-phase.md: Lone Werewolf peek is optional. |

### Doppelganger Edge Cases

| Scenario | Information Flow | Display | Citation |
|----------|-----------------|---------|----------|
| Doppelganger copies Wave 3 role (Seer/Robber/Troublemaker/Drunk) | Doppelganger performs follow-up immediately in Wave 1. Real role holder acts normally in Wave 3. | Two-step UI in Wave 1: peek result, then immediate follow-up action. | doppelganger.md: "the Doppelganger performs that action immediately during the Doppelganger phase, before any other role wakes." |
| Doppelganger copies Wave 2 role (Werewolf/Mason/Minion) | Doppelganger wakes again in Wave 2 during that role's call. | Wave 1: peek result + team change notification. Wave 2: auto-reveal (see teammates). | doppelganger.md: "The Doppelganger closes her eyes and wakes again when that role is called in Wave 2." |
| Doppelganger copies Insomniac | Follow-up in Wave 4 after real Insomniac. | Wave 1: peek result. Wave 4: self-peek auto-reveal. | doppelganger.md: "Doppelganger-as-Insomniac peeks her own card to see if it changed." |
| Doppelganger copies no-action role (Villager/Tanner/Hunter) | No follow-up. Team may change (Tanner -> Independent). | Wave 1: peek result only. | doppelganger.md: "No follow-up. Doppelganger closes eyes." |
| Doppelganger is robbed (Robber takes Doppelganger card) | Robber now holds Doppelganger card (carries copied role's team). Original Doppelganger now holds Robber card (Village team). | Robber sees "Doppelganger" as their new card. Resolution uses copied role for card team. | doppelganger.md: "The doppelganger_copied_role is a property of the card, not the player — it follows the card." |

### Tie Vote

| Scenario | Information Revealed | Display | Citation |
|----------|---------------------|---------|----------|
| Two+ players tied for most votes (each >= 2) | All tied players' roles revealed | Tied bars pulse simultaneously in tally build. Sequential elimination announcements (M-04) with 400ms gap. | voting-and-resolution.md: "If there is a tie for the most votes (and the tied count is >= 2), all tied players die." |
| Everyone gets 1 vote (no one >= 2) | No roles revealed (no one dies) | No-elimination sequence (M-05). | voting-and-resolution.md: "If no player has more than 1 vote, no one dies." |
| One player has 1 vote (highest, but < 2) | No roles revealed (no one dies) | No-elimination sequence (M-05). | voting-and-resolution.md: "The minimum vote threshold is 2." |

### Multiple Winners

| Scenario | Headline Display | Personal Outcome |
|----------|-----------------|------------------|
| Village wins only | "VILLAGE WINS!" in `AppColors.teamVillage` | Village team: "You Win." / Werewolf team: "You Lose." |
| Werewolf team wins only | "WEREWOLF TEAM WINS!" in `AppColors.teamWerewolf` | Werewolf team (incl Minion): "You Win." / Village team: "You Lose." |
| Tanner wins only | "TANNER WINS!" in `AppColors.teamIndependent` | Tanner: "You Win." / Everyone else: "You Lose." |
| Village + Tanner both win | Two lines: "VILLAGE WINS!" + "TANNER WINS!" | Village team: "You Win." / Tanner: "You Win." / Werewolf team: "You Lose." |
| No team wins | "NO ONE WINS" in `AppColors.parchmentMuted` | Everyone: "You Lose." |

---

## Accessibility

### Screen Reader Labels

| Element | Semantic Label | Notes |
|---------|---------------|-------|
| Role card (face-down) | "Your role card, face down. Double tap to reveal." | Must not leak role before flip. |
| Role card (face-up) | "Your role: [Role name], [Team] team." | After flip. |
| Night action result (hidden) | "Night action result. Double tap to view." | Tap-to-reveal. |
| Night action result (revealed) | "[Result text]. Auto-hides in [seconds] seconds." | Time remaining announced. |
| Vote target (selected) | "[Player name], selected as your vote target." | Selection state announced. |
| Vote target (not selected) | "[Player name]. Double tap to vote for." | Available target. |
| Vote counter | "[Count] of [total] players have voted." | Updated on each submission. |
| Timer | "[Minutes]:[Seconds] remaining." | Announced every 30 seconds and at warning/critical thresholds. |
| Wave indicator | "Night wave [current] of [total]. [Active role] phase." | Updated on wave transition. |

### Contrast

All information display follows the contrast ratios defined in `design-tokens.md`:
- Primary text (`AppColors.parchment` on `AppColors.surface`): 10.8:1 (exceeds AAA)
- Secondary text (`AppColors.parchmentMuted` on `AppColors.surface`): 4.2:1 (meets AA Large)
- All critical game information (role names, timer, vote counts) uses primary text contrast

### Reduced Motion

All information-revealing animations have reduced-motion alternatives defined in `sound-and-motion.md`. Reduced motion never eliminates information — it eliminates the animation, replacing it with instant appearance or simple crossfade.

### Color-Blind Safety

Team identification NEVER relies solely on color. Every team indicator includes:
- Team color accent (primary signal for sighted users)
- Team name text label (redundant signal)
- Distinct iconography per team (wolf icon for Werewolf team, shield for Village, skull for Independent)

---

## Rule Verification

Every game mechanic referenced in this document is traceable to the authoritative game specs.

| Claim in This Spec | Source Document | Specific Rule |
|--------------------|----------------|---------------|
| 3 center cards always | overview.md | "plus 3 extras placed face-down in the center of the table" |
| Player's team = card in front of them after swaps | overview.md | "A player's team is determined by the card currently in front of them at the end of the night, not the card they started with." |
| Votes are simultaneous, no peek before commit | voting-and-resolution.md | "Votes are cast at the same instant — no player sees another's vote before committing" |
| Minimum 2 votes to die | voting-and-resolution.md | "The minimum vote threshold is 2. A player must receive at least 2 votes to be eliminated." |
| Tied players all die | voting-and-resolution.md | "If there is a tie for the most votes (and the tied count is >= 2), all tied players die." |
| Hunter chain kills vote target | voting-and-resolution.md | "If the Hunter dies, the player the Hunter voted for also dies, regardless of how many votes that target received." |
| Hunter ability follows the card | voting-and-resolution.md | "The Hunter ability belongs to the card position, not the original player." |
| Hunter chain does not recurse | voting-and-resolution.md | "Hunter chain kills do not recurse." |
| Tanner death blocks Werewolf win | voting-and-resolution.md | "If the Tanner dies and no Werewolves die, the Werewolves do not win." |
| Tanner + Werewolf both die = both win | voting-and-resolution.md | "At least one Werewolf player dies, Tanner also dies: Village wins AND Tanner wins." |
| Seer peek is optional | onuw/night-phase.md | "Seer: Optional — 'You may look at...'" |
| Robber swap is optional | onuw/night-phase.md | "Robber: Optional — 'You may exchange...'" |
| Troublemaker swap is optional | onuw/night-phase.md | "Troublemaker: Optional — 'You may exchange...'" |
| Drunk swap is mandatory | onuw/night-phase.md | "Drunk: Mandatory — 'Exchange your card...' (no 'may')" |
| Doppelganger follow-up is mandatory | onuw/night-phase.md | "Doppelganger follow-up: Mandatory — 'Do it now' (imperative)" |
| Lone Werewolf center peek is optional | roles.md | "the lone Werewolf may look at one center card. This is optional." |
| Doppelganger copies immediately in Wave 1 for Wave 3 roles | doppelganger.md | "the Doppelganger performs that action immediately during the Doppelganger phase" |
| Doppelganger-as-Insomniac wakes after real Insomniac | onuw/night-phase.md | "Doppelganger-as-Insomniac wakes second, peeks own card" |
| Minion sees Werewolves one-way | roles.md | "This is one-directional — Werewolves do not know who the Minion is." |
| Werewolves and Masons don't see each other (same wave) | roles.md | "Masons and Werewolves are in the same wave but do not see each other" |
| No one dies if Minion is only death, no WW in play | voting-and-resolution.md | "If only the Minion dies, no team wins cleanly." |
| Server never leaks private info | CLAUDE.md | Core Principle #2: "A player ONLY sees what their role allows. NEVER leak another player's secret info." |
| Players cannot show cards during discussion | overview.md | "Players may never show their card to anyone" |
| Players cannot look at cards during discussion | overview.md | "Players may never look at any card" |
| Vote skip on timeout | voting-and-resolution.md | "If a player does not submit a vote before the timer expires, their vote is skipped" |
| Night action skip on timeout | onuw/night-phase.md | "If a player does not submit an action before the timer expires, their action is skipped" |

---

## Open Questions

(none)
