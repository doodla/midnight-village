# Cross-Cutting Behavioral Patterns

## Identity

| Field     | Value |
|-----------|-------|
| type      | pattern |
| id        | P-CROSS |
| phase     | all |

This document defines behavioral patterns that apply across all screens and phases. Screen specs reference these patterns by ID rather than re-specifying the behavior. If a screen spec contradicts this document, this document wins unless the screen spec explicitly overrides with a rationale.

---

## 1. Error Patterns

### P-ERR: In-World Error Model

All errors follow a two-layer structure: a **thematic headline** in `AppTextStyles.flavor` (Libre Baskerville italic) that stays in the Firelit Gothic world, paired with a **clear subtitle** in `AppTextStyles.body` that removes all ambiguity about what happened and what the player can do.

Error containers use `AppColors.surface` background, `AppRadius.lg` (12dp) corners, `AppShadows.card`, and 1dp `AppColors.outline` border. Internal padding: `AppSpacing.base` (16dp).

#### Error Display Variants

| Variant | When | Container | Behavior |
|---------|------|-----------|----------|
| Toast | Transient issues (network blip, validation rejection) | Slides down from top (UI-15, UI-16 from sound-and-motion.md). Auto-dismiss after 4000ms. | Player can swipe to dismiss early. |
| Inline banner | Persistent context errors (invalid role config, lobby full) | Static card within content flow, no auto-dismiss. | Dismiss when the error condition resolves. |
| Overlay card | Game-blocking issues (disconnect, server error) | Centered modal card with scrim at `AppOpacity.scrim`. | Cannot be dismissed by player -- resolves when condition clears or player takes recovery action. |

#### Error String Catalog

| Error | In-World Headline | Clear Subtitle | Variant | Recovery |
|-------|-------------------|----------------|---------|----------|
| Connection lost | "The spirits are restless..." | Connection lost. Reconnecting... | Overlay card | Automatic reconnect with retry (see P-DISCONNECT). |
| Player disconnected | "A villager has wandered into the fog..." | [Name] disconnected. Waiting for them to return. | Overlay card | Game pauses. Resolves on reconnect or host ends game. |
| Lobby not found | "The tavern door is barred..." | No lobby found with code [CODE]. | Inline banner | Player re-enters code. |
| Lobby full | "The village is full..." | This lobby has reached its maximum of [N] players. | Inline banner | Player waits or finds another lobby. |
| Invalid role config | "The cards don't add up..." | Select exactly [N] role cards ([player_count] players + 3 center). | Inline banner | Host adjusts role selection. Invalid state highlighted. |
| Mason count error | "Masons are never alone..." | Masons must be included in pairs (0 or 2). | Inline banner | Host adds or removes the second Mason. |
| Game already started | "The night has already fallen..." | This game is in progress. You cannot join mid-game. | Inline banner | Player returns to home screen. |
| Server error | "Something stirs in the darkness..." | Something went wrong. Try again. | Toast | Player retries action. If persistent, show overlay with "Return to Home" button. |
| Action timeout | "The moment has passed..." | Your action was not submitted in time. It has been skipped. | Toast | Informational only. Game continues. |
| Network timeout | "The fog grows thick..." | Request timed out. Check your connection and try again. | Toast | Player retries. If repeated, escalate to overlay card. |
| Host left lobby | "The innkeeper has departed..." | The host left. This lobby has been closed. | Overlay card | "Return to Home" button. |
| Kicked from lobby | "You've been shown the door..." | The host removed you from the lobby. | Overlay card | "Return to Home" button. |
| Name too short | "The spirits require a proper name..." | Name must be at least 2 characters. | Inline banner | Player adds characters. Banner dismisses when name ≥2 chars. |

#### Error Animation

All error animations reference `sound-and-motion.md`:

| Moment | Reference | Notes |
|--------|-----------|-------|
| Toast appear | UI-15 | `AppDurations.standard` (300ms), slides from top, `AppCurves.enter` |
| Toast dismiss | UI-16 | `AppDurations.fast` (200ms), slides up, `AppCurves.exit` |
| Overlay card appear | UI-10 | `AppDurations.standard` (300ms), scale 0.95->1.0 + fade in, `AppCurves.enter`, scrim at `AppOpacity.scrim` |
| Overlay card dismiss | UI-11 | `AppDurations.fast` (200ms), scale 1.0->0.95 + fade out, `AppCurves.exit` |
| Inline banner appear | -- | `AppDurations.crossfade` (400ms), opacity 0->1, `AppCurves.enter`. Pushes content below it down. |
| Inline banner dismiss | -- | `AppDurations.crossfade` (400ms), opacity 1->0, `AppCurves.exit`. Content above collapses. |

#### Error Accessibility

- All error text must be announced by screen readers when it appears. Use `Semantics(liveRegion: true)`.
- Thematic headlines are decorative for screen readers -- the clear subtitle carries the semantic meaning. Mark headlines with `Semantics(excludeSemantics: true)` and give the subtitle the full accessible label.
- Error overlay cards must trap focus. Tab navigation stays within the overlay until it is resolved.
- Toast auto-dismiss timer pauses when the player interacts with the toast (touch or focus).

---

## 2. Disconnect & Pause Flow

### P-DISCONNECT: Player Disconnection

Disconnect detection and game-pausing is the primary mechanism for preserving fairness in a game built on hidden information. If a player's phone drops, the game must halt for all players.

#### Detection

- WebSocket heartbeat every 5s (unchanged).
- **Immediate pause** on first missed heartbeat response -- no stale/confirmed distinction.
- Server broadcasts disconnect event immediately.

#### Pause Behavior (Non-Host Disconnect)

When the server broadcasts a non-host disconnect:

1. **All players** see the disconnect overlay (T-09 from sound-and-motion.md).
2. **All timers freeze.** Night wave timer, discussion timer, voting timer -- all pause at their current value.
3. **All interactions disable.** Players cannot submit actions, change votes, or advance phases while paused.
4. **Ambient audio ducks** to 30% volume (per T-09 timeline).
5. **The game state is preserved** atomically on the server. No partial state mutations occur during pause.

Resolution paths:

1. **Player reconnects** -- game resumes (see Reconnection below).
2. **Host taps "End Game"** -- game ends for everyone.

#### Reconnection

When the disconnected player's client reconnects:

1. Server validates session and sends full current game state.
2. Server broadcasts reconnect event.
3. **All players** see the reconnect dismissal animation (T-09 out timeline).
4. **Timers resume** from where they paused.
5. **Interactions re-enable.**
6. **The reconnected player** sees a brief "Welcome back" toast (variant: toast, headline: "You have returned.", subtitle: "Game resumed.") that auto-dismisses in 2000ms.

#### Host Disconnect

When the host disconnects, a different flow activates:

1. All players see a **host-disconnect screen** (not the standard T-09 overlay -- this is a full-screen replacement):
   - 5-minute candle countdown: a tall candle illustration that visually melts/burns down over 5 minutes.
   - Timer displayed below candle in `AppTextStyles.timerCompact`.
   - "The innkeeper has stepped away..." in `AppTextStyles.flavor`, `AppColors.parchmentMuted`.
   - "Game will end if they don't return" in `AppTextStyles.bodySmall`.

2. If host reconnects:
   - "The innkeeper has returned!" message (800ms).
   - Game resumes from where it paused.

3. If 5-minute countdown expires:
   - "The candle has gone out..." in `AppTextStyles.flavor`.
   - "The game has ended." in `AppTextStyles.body`.
   - All players return to home after 3 seconds.
   - No win/loss is recorded.

#### Multiple Disconnects

If more than one player disconnects simultaneously, the overlay shows all disconnected player names in a list. The game resumes only when all disconnected players reconnect or the host ends the game.

#### Disconnect Overlay Layout

```
┌─────────────────────────────────────┐
│         [scrim at 60% opacity]      │
│                                     │
│   ┌─────────────────────────────┐   │
│   │                             │   │
│   │  "A villager has wandered   │   │
│   │   into the fog..."          │   │  <- AppTextStyles.flavor
│   │                             │   │
│   │  [Disconnected Avatar] Name │   │  <- Avatar at 50% opacity
│   │                             │   │     (per art-direction.md
│   │  {name} disconnected.       │   │      disconnected state)
│   │  Waiting for them to return.│   │
│   │                             │   │
│   │  ┌─────────────────────┐    │   │
│   │  │     End Game        │    │   │  <- Host only
│   │  └─────────────────────┘    │   │
│   │                             │   │
│   └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```

#### Host Disconnect Screen Layout

```
┌─────────────────────────────────────┐
│  [scrim at 60% opacity over game]   │
│                                     │
│     "The innkeeper has stepped      │  <- AppTextStyles.flavor
│      away..."                       │
│                                     │
│         ┌─────┐                     │
│         │     │                     │  <- Candle illustration
│         │ ░░░ │                     │     Burns down over 5 min
│         │ ░░░ │                     │     Ember particles at tip
│         │ ░░░ │                     │
│         │█████│                     │
│         └──┬──┘                     │
│           4:32                      │  <- AppTextStyles.timerCompact
│                                     │
│                                     │
└─────────────────────────────────────┘
```

#### Strings

| Key | Default Text | Notes |
|-----|-------------|-------|
| `disconnect.headline` | "A villager has wandered into the fog..." | Flavor text |
| `disconnect.subtitle` | {name} disconnected. Waiting for them to return. | |
| `disconnect.host_away` | "The innkeeper has stepped away..." | Host disconnect headline |
| `disconnect.host_away_subtitle` | Game will end if they don't return. | Below candle |
| `disconnect.host_returned` | "The innkeeper has returned!" | Host reconnect |
| `disconnect.candle_expired` | "The candle has gone out..." | 5-min timeout |
| `disconnect.game_ended` | The game has ended. | After candle expiry |
| `disconnect.end_game_button` | End Game | Host's option during non-host disconnect |
| `reconnect.headline` | "They have returned!" | |
| `reconnect.toast_headline` | "You have returned." | Shown to reconnected player |
| `reconnect.toast_subtitle` | Game resumed. | |
| `disconnect.host_left` | "The innkeeper has departed..." | |
| `disconnect.host_left_subtitle` | The host left. This lobby has been closed. | |
| `disconnect.multiple` | {count} villagers have wandered into the fog... | When 2+ disconnect |

---

## 3. Fluid Interaction Model

### P-FLUID: Fluid Until Finalized

**Core rule:** Nothing is permanent until the host or the timer says so.

All player selections -- votes, night action targets, ready states -- are **mutable** until the phase ends. There is no "confirm and lock" step. The player's current selection is their submission when the phase finalizes.

#### How It Works

| Phase | Selection Type | Mutable Until | Finalization Trigger |
|-------|---------------|---------------|---------------------|
| Lobby | Ready/unready toggle | Game start | Host presses "Start Game" |
| Night action | Target selection (player or center card) | Wave timer expires or host advances | Timer expiry or all expected actions submitted |
| Voting | Vote target | Voting timer expires or host ends voting | Timer expiry or host advance |

#### Visual Feedback for Fluid Selections

| State | Visual Treatment | Haptic |
|-------|-----------------|--------|
| No selection | All options at default state. No highlight. | -- |
| Selection made | Selected element gets `AppGlows.selection` glow (UI-04, 200ms appear). Checkmark badge appears on selected element. | `AppHaptics.selectionClick` (H-04) |
| Selection changed | Previous selection glow removed (UI-05, 200ms). New selection glow applied (UI-04, 200ms). Checkmark moves. | `AppHaptics.selectionClick` (H-04) |
| Phase finalizes | Selection locks. Glow persists. "Submitted" indicator replaces checkmark. | `AppHaptics.confirmationPulse` (H-05) |

#### Blind Voting

During voting, players can see **that** other players have made a selection, but not **whom** they selected:

| Information | Visible? | Display |
|-------------|----------|---------|
| "Player X has chosen" | Yes | Checkmark badge on Player X's entry in the player list |
| "Player X voted for Player Y" | No | Hidden until vote reveal |
| "4/6 have chosen" | Yes | Vote counter in `AppTextStyles.label` |
| Your own current selection | Tap-to-reveal (see P-REVEAL) | Hidden by default, revealed on tap for 3s |

#### Deselection

Players can deselect by tapping their current selection a second time. This returns them to the "no selection" state. In voting, this means they will have no vote if the timer expires (equivalent to abstaining, which the digital implementation allows as a timeout behavior).

#### Edge Cases

| Scenario | Behavior |
|----------|----------|
| Player makes no selection before timer expires | Action is skipped. Logged as `"skip"`. For voting, vote is not counted. |
| Host ends phase while player is mid-selection | Current selection at the moment of host advance is the final selection. If no selection was made, it is a skip. |
| Player's device goes to sleep during selection | WebSocket heartbeat detects inactivity. First missed heartbeat triggers immediate game pause. If the player wakes the device and reconnects, selection state is preserved client-side. |
| Server rejects a selection (e.g., invalid target) | Toast error: "The spirits reject your offering..." / "Invalid target. Choose again." Selection reverts to previous state. |

#### Night Action Target Selection

Night actions that involve targeting (selecting players or center cards) use **fluid target selection with soft confirm**:

| Step | Behavior |
|------|----------|
| Tap a player/card | Highlighted as current target (`AppGlows.selection`). No submission yet. |
| Tap a different player/card | Selection moves to new target (fluid, no penalty). Previous glow removed. |
| Valid selection complete | Confirm button appears below target area. For multi-target actions (Troublemaker: 2 players, Seer center peek: 2 cards), Confirm appears after all targets are selected. |
| Tap "Confirm" button | Action executes. Server processes action, results revealed (if any). |
| Timer expires WITH a selection | Auto-executes the current selection (same auto-resolve as voting). |
| Timer expires WITHOUT a selection | Timeout/skip (follows existing optionality rules per role — see `night-actions.md`). |

**Which roles use target selection:** Seer (peek player or 2 center cards), Robber (swap with player), Troublemaker (swap two players), Drunk (swap with center card), lone Werewolf (peek center card).

**Auto-resolve roles (no selection step):** Werewolf see team, Mason see team, Minion see Werewolves, Insomniac peek self. Information displays automatically — no target selection, no Confirm button.

#### Confirm Button Visual Treatment

| Property | Value |
|----------|-------|
| Appears | After a valid selection is made (all required targets selected) |
| Position | Below target selection area, above wave indicator. Centered. |
| Style | `AppColors.bloodEmber` background, `AppColors.parchment` text, `AppTextStyles.labelLarge`, `AppRadius.md` (8dp) |
| Glow | `AppGlows.cta` pulse (UI-17) — same as host advance buttons |
| Touch target | Meets `AppDimensions.touchTargetMin` (48dp) |
| Animation | Fades in with `AppDurations.fast` (200ms), `AppCurves.enter` when selection completes. Remains visible while selection is valid. |
| Disappears | On action submission (replaced by confirmation indicator), or if player deselects to invalid state |

---

## 4. Host Phase Controls

### P-HOST: Host Advance Controls

The host has contextual controls to advance timed phases early. These controls appear only when relevant, are themed to match the Firelit Gothic aesthetic (not admin-panel style), and are positioned consistently.

#### Control Inventory

| Phase | Control Label | Action | Precondition |
|-------|--------------|--------|-------------|
| Discussion | "End Discussion" | Ends discussion timer, transitions to voting (T-03) | Discussion timer is running |
| Voting | "End Voting" | Finalizes all current selections, transitions to vote reveal (T-04) | Voting timer is running |
| Night (per wave) | "Next Wave" | Advances to next wave when all expected actions are submitted | All active players in current wave have submitted actions or skipped |
| Results / Debrief | "Play Again" | Returns group to lobby (T-07) | Results are displayed |
| Results / Debrief | "End Game" | Closes the game session, returns all players to home | Results are displayed |

#### Visual Treatment

Host controls are rendered as a floating action bar at the bottom of the host's screen, above the standard content but below any overlays.

```
┌─────────────────────────────────────┐
│                                     │
│        [phase content area]         │
│                                     │
│                                     │
├─────────────────────────────────────┤
│  ┌─────────────────────────────┐    │
│  │  [Host control button]      │    │  <- AppColors.surface bg
│  └─────────────────────────────┘    │     AppRadius.md (8dp)
│                                     │     AppShadows.elevated
└─────────────────────────────────────┘
```

| Property | Value |
|----------|-------|
| Background | `AppColors.surface` |
| Border | 1dp `AppColors.outline` |
| Corner radius | `AppRadius.md` (8dp) |
| Shadow | `AppShadows.elevated` |
| Button style | `AppColors.bloodEmber` background, `AppColors.parchment` text, `AppTextStyles.labelLarge` |
| CTA glow | `AppGlows.cta` pulse (UI-17) on the primary action button |
| Padding | `AppSpacing.md` (12dp) internal, `AppSpacing.base` (16dp) from screen edges |
| Position | Bottom of screen, above safe area inset |

#### Non-Host Players

Non-host players do not see host controls. The space occupied by host controls on the host's screen is absent on non-host screens -- content does not shift or leave a gap.

#### Confirmation

Advancing a phase is a one-tap action. No confirmation dialog. The host pressed the button intentionally -- requiring confirmation would slow the social rhythm of the game.

**Exception:** "End Game" requires a confirmation dialog because it is destructive and irreversible. Dialog follows the overlay card pattern (UI-10, UI-11).

#### Strings

| Key | Default Text | Notes |
|-----|-------------|-------|
| `host.end_discussion` | End Discussion | |
| `host.end_voting` | End Voting | |
| `host.next_wave` | Next Wave | |
| `host.play_again` | Play Again | |
| `host.end_game` | End Game | Destructive action |
| `host.end_game_confirm.title` | "Closing time at the tavern..." | Flavor |
| `host.end_game_confirm.subtitle` | End this game session? All players will return to the home screen. | |
| `host.end_game_confirm.confirm` | End Game | |
| `host.end_game_confirm.cancel` | Keep Playing | |

---

## 5. Tap-to-Reveal Guardrails

### P-REVEAL: Hidden Information Display

In-person play requires that sensitive information (your role, your night results, your current vote) is not persistently visible on screen. Someone glancing at your phone should not learn your secrets. The tap-to-reveal pattern hides sensitive content behind a tap interaction.

#### Behavior

1. Sensitive content is hidden by default: replaced with a themed placeholder (e.g., a face-down card icon, or a "tap to reveal" label).
2. Player taps the hidden element.
3. Content reveals with animation UI-21 (`AppDurations.fast`, 200ms, `AppCurves.enter`).
4. Content auto-hides after **3000ms** with animation UI-22 (`AppDurations.fast`, 200ms, `AppCurves.exit`).
5. Player can tap again to hide immediately (before the 3s timeout).

#### Where Tap-to-Reveal Applies

| Screen | Hidden Content | Placeholder Display |
|--------|---------------|-------------------|
| Discussion | Role reminder card | Face-down card icon with "Tap to remember your role" in `AppTextStyles.bodySmall`, `AppColors.parchmentMuted` |
| Discussion | Night action results | "Tap to recall what you learned" in `AppTextStyles.bodySmall`, `AppColors.parchmentMuted` |
| Voting | Your current vote selection | "Tap to see your vote" in `AppTextStyles.bodySmall`, `AppColors.parchmentMuted`. Visible only after a selection is made. |

#### Visual Treatment

Hidden state: `AppColors.surfaceInset` background, dashed 1dp `AppColors.outlineSubtle` border, `AppRadius.md` (8dp).

Revealed state: `AppColors.surface` background, solid 1dp `AppColors.outline` border, `AppRadius.md` (8dp), content visible.

#### Accessibility

- The hidden placeholder must have an accessible label: "Your role is hidden. Double-tap to reveal for 3 seconds."
- When revealed, announce the content to screen readers.
- Auto-hide timer pauses while the element has screen reader focus.

#### Strings

| Key | Default Text | Notes |
|-----|-------------|-------|
| `reveal.role_placeholder` | Tap to remember your role | |
| `reveal.night_results_placeholder` | Tap to recall what you learned | |
| `reveal.vote_placeholder` | Tap to see your vote | |
| `reveal.a11y_hint` | Double-tap to reveal for 3 seconds | Screen reader hint |

---

## 6. Onboarding Hints

### P-ONBOARD: Contextual First-Time Hints

No tutorial game. No heavy onboarding flow. Instead, the app uses contextual hints that appear the first time a player encounters a key interaction. Hints disappear permanently after the player has seen them once (persisted to local storage).

#### Hint Trigger Rules

| Rule | Detail |
|------|--------|
| Display | First time the target interaction is available on-screen |
| Persistence | Once dismissed (tap or interaction), never shown again for this player (stored in local preferences) |
| Position | Tooltip pointing to the target element, using `AppColors.surfaceElevated` + `AppShadows.elevated` |
| Animation | UI-06 appear (200ms, `AppCurves.enter`), UI-07 dismiss (100ms, `AppCurves.exit`) |
| Dismiss trigger | Player taps the hint, taps the target element, or taps anywhere else on screen |
| Max per screen | 1 hint at a time. If multiple hints would fire on the same screen, show only the highest-priority one. The others fire on subsequent visits. |

#### Hint Catalog

| ID | Screen | Target Element | Hint Text | Priority |
|----|--------|---------------|-----------|----------|
| H-01 | Role Reveal | Face-down card | "Tap the card to reveal your secret role" | 1 |
| H-02 | Night Action (Seer) | Action choice buttons | "Choose: peek at one player's card, or two center cards" | 1 |
| H-03 | Night Action (selection) | Player grid / center cards | "Tap a player to select them" | 2 |
| H-04 | Discussion | Role reminder area | "Tap here to peek at your role" | 3 |
| H-05 | Voting | Player grid | "Tap a player to vote for them. You can change your mind." | 1 |
| H-06 | Voting | Vote counter | "Your vote is private until the reveal" | 2 |
| H-07 | Lobby (host) | Role picker | "Choose which roles to include in this game" | 1 |
| H-08 | Lobby (host) | Start game button | "Start when all players are ready" | 2 |
| H-09 | Night Waiting | Fidget area | "Touch the screen to play with the fire" | 3 |
| H-10 | Results | Player table | "Tap a player to see what happened during the night" | 2 |

#### Visual Treatment

```
         ┌──────────────────────────┐
         │  Hint text here          │  <- AppTextStyles.bodySmall
         │                          │     AppColors.parchment on
         └─────────┬────────────────┘     AppColors.surfaceElevated
                   ▼                      AppShadows.elevated
            [target element]              AppRadius.sm (4dp)
                                          Padding: AppSpacing.sm (8dp)
```

Arrow pointer: 8dp equilateral triangle in `AppColors.surfaceElevated`, positioned to point at the target element's center. Arrow position adapts (top, bottom, left, right) based on available screen space.

#### Strings

| Key | Default Text |
|-----|-------------|
| `hint.role_reveal_tap` | Tap the card to reveal your secret role |
| `hint.seer_choice` | Choose: peek at one player's card, or two center cards |
| `hint.night_select` | Tap a player to select them |
| `hint.discussion_role` | Tap here to peek at your role |
| `hint.voting_select` | Tap a player to vote for them. You can change your mind. |
| `hint.voting_private` | Your vote is private until the reveal |
| `hint.host_roles` | Choose which roles to include in this game |
| `hint.host_start` | Start when all players are ready |
| `hint.fidget` | Touch the screen to play with the fire |
| `hint.results_table` | Tap a player to see what happened during the night |

---

## 7. Loading, Empty, and Reconnecting States

### P-LOADING: Atmospheric Loading States

Loading states maintain the Firelit Gothic atmosphere. No spinners, no progress bars, no sterile skeleton screens. Loading uses a shimmer effect on `AppColors.surface` placeholder shapes (UI-12: 1500ms opacity loop between 0.05 and 0.15, `AppCurves.standard`).

#### Loading Patterns by Context

| Context | Placeholder Shape | Particle Effects | Notes |
|---------|------------------|-----------------|-------|
| Screen loading (full) | 2-3 `AppColors.surface` rounded rectangles stacked vertically (`AppRadius.lg`, full content width, heights: 120dp, 80dp, 80dp). All shimmer. | Phase-appropriate particles active. | Content fades in over placeholder with `AppDurations.crossfade` (400ms). |
| Player grid loading | Grid of circular placeholders at `AppDimensions.avatarMd` (48dp). Number matches expected player count. All shimmer. | Active. | Players appear with stagger animation UI-13 as they load. |
| Card loading | Single card-shaped placeholder at role card dimensions (240dp x 320dp), `AppRadius.xxl` (24dp). Shimmer. | Active. | Card content fades in over placeholder. |
| Action result loading | Inline placeholder within action area. Single rounded rectangle, shimmer. | Active. | Result content replaces placeholder. |

#### Accessibility for Loading

- All loading placeholders must be announced: `Semantics(label: "Loading...")`.
- When content replaces a loading placeholder, announce the new content.

### P-EMPTY: Empty States

Empty states occur when a screen has no content to show (no players in lobby, no game history). Each empty state has a thematic illustration concept and a clear call-to-action.

| Screen | Empty Condition | Illustration Concept | Headline | Subtitle | CTA |
|--------|----------------|---------------------|----------|----------|-----|
| Lobby player list | Host is alone | Single candle on an empty table | "The tavern awaits..." | Share the lobby code to invite players. | [Copy Code] button |
| Game history | No past games | Closed book with dust | "No tales yet told..." | Play your first game to see your history here. | [Create Game] button |
| Night action results | Action was skipped/timed out | Extinguished candle | "The moment passed..." | You did not act in time. | None (informational) |

#### Empty State Layout

```
┌─────────────────────────────────────┐
│                                     │
│                                     │
│         [illustration area]         │  <- 80dp x 80dp, centered
│         (icon or simple graphic)    │     AppColors.parchmentMuted
│                                     │
│         "Headline text"             │  <- AppTextStyles.heading3
│                                     │     AppColors.parchment
│         Subtitle text               │  <- AppTextStyles.body
│                                     │     AppColors.parchmentMuted
│         ┌───────────────┐           │
│         │  [CTA Button] │           │  <- If applicable
│         └───────────────┘           │
│                                     │
└─────────────────────────────────────┘
```

### P-RECONNECTING: Client Reconnection State

Distinct from the game-pausing disconnect overlay (P-DISCONNECT). This is the **local** reconnection indicator that appears on the disconnected player's own device while they attempt to reconnect. Under the new model, the server broadcasts a disconnect event immediately on first missed heartbeat, so the game pauses for all players right away. This local indicator shows the disconnected player that their device is attempting to restore the connection.

| State | Visual | Trigger |
|-------|--------|---------|
| Healthy | No indicator | Normal WebSocket heartbeat |
| Disconnected | Full disconnect overlay (P-DISCONNECT, T-09) for all players; reconnecting player sees local reconnection card with "The spirits are restless..." and loading shimmer (UI-12) | 1 missed heartbeat (5s, server-confirmed) |

The game pauses immediately for all players on any disconnect. There is no intermediate "unstable" or "reconnecting" local-only state.

#### Strings

| Key | Default Text |
|-----|-------------|
| `loading.generic` | Loading... |
| `empty.lobby_headline` | "The tavern awaits..." |
| `empty.lobby_subtitle` | Share the lobby code to invite players. |
| `empty.history_headline` | "No tales yet told..." |
| `empty.history_subtitle` | Play your first game to see your history here. |
| `empty.action_skipped_headline` | "The moment passed..." |
| `empty.action_skipped_subtitle` | You did not act in time. |
| `reconnecting.label` | Reconnecting... |

---

## 8. Remote Play Considerations

### P-REMOTE: Adaptations for Non-Colocated Play

The primary experience is in-person (same room). However, players may also play remotely via video call. The spec must account for this without compromising the in-person experience.

#### What Changes for Remote Play

| Concern | In-Person | Remote | Spec Impact |
|---------|-----------|--------|-------------|
| Discussion | Players talk face-to-face | Players use external voice/video (Zoom, FaceTime) | No in-app voice. Discussion screen unchanged. |
| Tap-to-reveal necessity | High -- someone might glance at your phone | Low -- no one can see your phone | Tap-to-reveal stays as default. Players can optionally disable it (future setting). |
| Night waiting concealment | Critical -- everyone must look busy | Less important -- no one can see each other's phones | Fidget interactions still active (good for fun), but concealment invariant is less load-bearing. |
| Lobby code sharing | Say it out loud / show phone | Copy and paste via chat | Tap-to-copy on lobby code is essential. |
| Audio overlap | Narrator audio plays in the room via all phones | Narrator audio plays through each player's device independently, overlapping with video call audio | Players should mute narrator audio or use headphones. Future: single-device narrator mode. |
| Timer visibility | Glanceable from across the table | Must check own phone | Timer is prominent on all relevant screens (already specified). |

#### Remote Play Feature Flags (Future)

These are not v1 features. They are documented here so screen specs can note where they would apply.

| Flag | Effect |
|------|--------|
| `remote.disableTapToReveal` | Sensitive info shown persistently (no tap-to-reveal). |
| `remote.singleNarrator` | Only host device plays narrator audio. Others show text only. |
| `remote.showTimerOnAllPhases` | Display a small persistent timer on phases that normally hide it. |

#### Invariant for Screen Specs

Every screen spec must work correctly in both colocated and remote modes **without feature flags**. Remote play adaptations are progressive enhancements, not requirements. The default experience assumes in-person play.

---

## Preconditions

These patterns are globally active. No preconditions beyond:

- App is running and authenticated (player has entered a name).
- For P-HOST controls: player must have `isHost: true` for the current game session.
- For P-DISCONNECT: an active game session must exist.

---

## States

Cross-cutting states that any screen may enter:

| State ID | Trigger | What the user sees | Audio/Haptic |
|----------|---------|-------------------|--------------|
| loading | Screen data not yet available | Shimmer placeholders (P-LOADING). Phase particles active. | Ambient soundscape for current phase plays normally. |
| empty | Screen data loaded but no items | Empty state illustration + headline + subtitle (P-EMPTY). | Ambient soundscape plays normally. |
| error-toast | Transient error condition | Toast slides from top. Auto-dismiss 4s. | None. |
| error-banner | Persistent context error | Inline banner in content flow. | None. |
| error-overlay | Game-blocking error | Centered modal card with scrim. All interactions disabled. | `SoundCues.disconnect` if connection-related. |
| disconnected | Server confirms player disconnect | Full-screen disconnect overlay (T-09). All timers frozen. All interactions disabled. | `SoundCues.disconnect`, `AppHaptics.tapMedium`. Ambient ducks to 30%. |
| reconnecting-local | Own connection unstable (1-2 missed heartbeats) | Amber dot + optional banner. Game continues normally. | None. |
| reconnected | Disconnected player returns | "They have returned!" overlay dismissal (T-09 out). Timers resume. | `SoundCues.reconnect`, `AppHaptics.confirmationPulse`. Ambient restores. |
| hint-visible | First-time interaction available | Tooltip pointing to target element. Max 1 at a time. | None. |
| reveal-visible | Player tapped a tap-to-reveal element | Hidden content visible. Auto-hides after 3s. | None. |
| host-controls-visible | Host is viewing a phase with advance controls | Floating action bar at bottom. | None. |

---

## Interactions

| Element | Event | Result | Haptic | Sound |
|---------|-------|--------|--------|-------|
| Error toast | Swipe up | Dismiss toast early (UI-16) | None | None |
| Error overlay "Return to Home" | Tap | Navigate to home screen. Close game session if applicable. | `AppHaptics.tapLight` | None |
| Disconnect overlay "Drop Player" | Tap | Show confirmation dialog. On confirm, drop player and resume game. | `AppHaptics.tapMedium` | None |
| Tap-to-reveal placeholder | Tap | Reveal hidden content (UI-21). Start 3s auto-hide timer. | None | None |
| Tap-to-reveal (visible) | Tap | Hide content immediately (UI-22). | None | None |
| Onboarding hint | Tap (on hint or target or elsewhere) | Dismiss hint permanently (UI-07). Persist to local storage. | None | None |
| Fluid selection (any phase) | Tap target | Apply selection glow (UI-04). Show checkmark. | `AppHaptics.selectionClick` | None |
| Fluid selection (change) | Tap different target | Remove previous glow (UI-05). Apply new glow (UI-04). | `AppHaptics.selectionClick` | None |
| Fluid selection (deselect) | Tap current selection | Remove glow (UI-05). Return to no-selection state. | `AppHaptics.selectionClick` | None |
| Night action Confirm button | Tap | Submit current target selection. Button replaced by confirmation indicator. | `AppHaptics.confirmationPulse` | None |
| Host advance button | Tap | Execute phase advance. Button disables immediately to prevent double-tap. | `AppHaptics.tapMedium` | Phase-appropriate transition sound |
| Host "End Game" button | Tap | Show confirmation dialog (overlay card). | `AppHaptics.tapLight` | None |
| Host "End Game" confirm | Tap | Close game session. All players navigate to home. | `AppHaptics.tapMedium` | None |
| Reconnecting indicator (amber dot) | -- | Not interactive. Informational only. | -- | -- |
| Loading placeholder | -- | Not interactive. | -- | -- |

---

## Errors

Covered exhaustively in section 1 (P-ERR). All error scenarios are enumerated in the Error String Catalog table.

---

## Animation

All animations reference `sound-and-motion.md` by ID. No values are re-specified here.

| Pattern | Key Animation References |
|---------|------------------------|
| P-ERR | UI-15, UI-16 (toast), UI-10, UI-11 (overlay), `AppDurations.crossfade` (banner) |
| P-DISCONNECT | T-09 (disconnect overlay in/out) |
| P-FLUID | UI-04, UI-05 (selection glow), UI-17 (Confirm button CTA glow), `AppDurations.fast` (Confirm appear) |
| P-REVEAL | UI-21, UI-22 (tap-to-reveal show/hide) |
| P-ONBOARD | UI-06, UI-07 (tooltip show/hide) |
| P-LOADING | UI-12 (shimmer), UI-13 (stagger) |
| P-HOST | UI-17 (CTA glow pulse) |

---

## Strings

All strings are catalogued per-section above. Summary of key prefixes:

| Prefix | Coverage |
|--------|----------|
| `disconnect.*` | All disconnect/reconnect text |
| `error.*` | Reserved for error-specific strings not covered by named errors |
| `reveal.*` | Tap-to-reveal placeholders and a11y hints |
| `hint.*` | All onboarding hint text |
| `loading.*` | Loading indicator text |
| `empty.*` | Empty state headlines and subtitles |
| `night.action.*` | Night action confirm button (see `night-actions.md`) |
| `host.*` | Host control labels and confirmations |
| `reconnecting.*` | Local reconnection indicator |

---

## Information Architecture

| Information | Who Sees It | Notes |
|-------------|-------------|-------|
| Error headlines (flavor) | All players experiencing the error | Decorative. Screen readers skip. |
| Error subtitles (clear) | All players experiencing the error | Semantic. Screen readers announce. |
| Disconnect notification | All players in the game session | Game-blocking -- all players must know. |
| Host controls | Host only | Non-host screens have no gap or placeholder for controls. |
| Onboarding hints | The individual player, first time only | Persisted per-player in local storage. Not synced across devices. |
| Tap-to-reveal content | The individual player | Content is player-scoped from the server. No other player's data is ever present client-side. |
| Vote selection (blind voting) | Own selection: tap-to-reveal. Others: checkmark only. | Selection targets are never transmitted to other clients until the reveal phase. |
| Reconnection indicator (local) | The affected player only | Other players are not notified unless full disconnect threshold is reached. |

---

## Accessibility

### Across All Patterns

| Requirement | Implementation |
|-------------|---------------|
| Screen reader announcements for dynamic state changes | All error appearances, loading-to-content transitions, disconnect/reconnect events use `Semantics(liveRegion: true)`. |
| Focus trapping on overlays | Error overlay cards and disconnect overlay trap focus within the overlay. Tab does not escape to background content. |
| Reduced motion | All animations have static alternatives (per `sound-and-motion.md` reduced motion notes). Tap-to-reveal still functions but without animation. |
| Color-blind safety | Error states do not rely solely on color. All errors have text content. Disconnect status uses text labels in addition to the amber dot. |
| Touch targets | All interactive elements (dismiss, CTA buttons, tap-to-reveal areas) meet `AppDimensions.touchTargetMin` (48dp) minimum. |
| Auto-hide timers | Toast 4s and tap-to-reveal 3s timers pause when the element has assistive technology focus. |
| Hint positioning | Tooltips avoid screen edges. On small screens, hints reflow to fit within safe area. |

---

## Open Questions

(none)
