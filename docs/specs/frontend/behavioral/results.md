# Results & Debrief

## Identity

| Field     | Value |
|-----------|-------|
| type      | screen |
| id        | S15 |
| phase     | results |
| route     | /game/:gameId |

This spec covers the Results screen (S15): win/loss announcement, player results table, full autopsy, post-game debrief, and play-again flow. This is the campfire storytelling moment — "I KNEW you were the werewolf!" The screen must support lingering, exploring, and replaying without rushing players to the next game.

---

## Layout

### Headline (first visible)

```
┌─────────────────────────────────────┐
│  [phase bg: AppColors.phaseResults] │
│  [AppParticles.dust]                │
│  [team color wash at 6% opacity]    │
│                                     │
│                                     │
│        VILLAGE WINS!                │  <- AppTextStyles.displayXl
│                                     │     (40dp, Epilogue bold)
│                                     │     Team accent color
│         You Win.                    │  <- AppTextStyles.heading1
│                                     │     (24dp, Epilogue)
│                                     │     AppColors.parchment
│                                     │
│         [scroll indicator]          │  <- Subtle down arrow
│                                     │     AppColors.parchmentMuted
└─────────────────────────────────────┘
```

### Resolution Summary (conditional)

```
┌─────────────────────────────────────┐
│                                     │
│  "Both Werewolves were in the       │  <- AppTextStyles.flavor
│   center. Bob was eliminated.       │     (Libre Baskerville italic)
│   The Minion's cunning prevails."   │     AppColors.parchmentMuted
│                                     │     AppColors.surface card
│                                     │     AppRadius.lg (12dp)
│                                     │     AppSpacing.base (16dp) pad
│                                     │
└─────────────────────────────────────┘
```

**Visibility:** Only rendered when the win condition involves one or more of these triggers:
- Minion special rule (Werewolf team wins with no Werewolves among players)
- Tanner win (Tanner eliminated)
- Tanner blocks Werewolf win
- Hunter chain kill
- Nobody wins
- Any player's team changed due to card swaps (final card differs from original card's team)

**Not rendered** for clean outcomes (e.g., "Village votes out a Werewolf" or "Werewolves survive with no deaths").

### Player Table (scroll down)

```
┌─────────────────────────────────────┐
│                                     │
│  ┌─────────────────────────────┐    │
│  │ ▸ Alice         [Village]  │    │  <- Collapsed row
│  │   Seer → Seer    Won       │    │     Avatar + name + team badge
│  └─────────────────────────────┘    │     Original→Final role
│  ┌─────────────────────────────┐    │     Win/Loss indicator
│  │ ▸ Bob          [Werewolf]  │    │
│  │   Werewolf → Robber  Lost  │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ ▾ Carol        [Village]   │    │  <- Expanded row
│  │   Robber → Werewolf  Lost  │    │
│  │                             │    │
│  │   Voted for: Alice          │    │  <- Expanded detail
│  │   Received: 2 votes         │    │
│  │   Night: Robbed Alice       │    │
│  │   (took Werewolf card)      │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ ▸ Dave         [Village]   │    │
│  │   Villager → Villager Won  │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ ▸ Eve          [Village]   │    │
│  │   Hunter → Hunter   Won    │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  View full night log        │    │  <- Full autopsy link
│  └─────────────────────────────┘    │     AppColors.tallowGold text
│                                     │
└─────────────────────────────────────┘
```

### Player Table — Collapsed Row (eliminated player)

```
┌─────────────────────────────────────┐
│ ▸ Bob          [Village]            │
│   Hunter → Hunter   ⚔ Eliminated   │  <- ⚔ = voted out badge
│   "Fell to the village's judgment"  │  <- AppTextStyles.flavorSmall
│                                     │     AppColors.parchmentMuted
└─────────────────────────────────────┘
```

### Player Table — Collapsed Row (Hunter chain kill)

```
┌─────────────────────────────────────┐
│ ▸ Eve          [Independent]        │
│   Tanner → Tanner   🏹 Eliminated  │  <- 🏹 = Hunter chain badge
│   "Struck by the Hunter's dying aim"│
└─────────────────────────────────────┘
```

### Player Table — Collapsed Row (survived)

```
┌─────────────────────────────────────┐
│ ▸ Alice        [Werewolf]           │
│   Werewolf → Werewolf    Won       │  <- No badge, no flavor line
└─────────────────────────────────────┘
```

### Elimination Method Icons

| Method | Icon Asset | Description | Flavor Text (default persona) |
|--------|-----------|-------------|-------------------------------|
| Voted out | `elim-icon-voted` | Crossed swords or gavel | "Fell to the village's judgment" |
| Voted out (tied) | `elim-icon-tied` | Balanced scales | "Caught in a deadlocked fate" |
| Hunter chain | `elim-icon-hunter` | Crossbow bolt | "Struck by the Hunter's dying aim" |

### Full Autopsy (on demand)

```
┌─────────────────────────────────────┐
│                                     │
│  Night Log                          │  <- AppTextStyles.heading2
│                                     │
│  1. Doppelganger (Carol) peeked     │  <- Chronological log
│     at Dave's card: Villager        │     AppTextStyles.body
│                                     │     Numbered steps
│  2. Werewolves woke up:             │     AppColors.surface cards
│     Bob (Werewolf)                  │     per entry
│     No other Werewolves found.      │
│     Bob peeked center card 2:       │
│     Tanner                          │
│                                     │
│  3. Seer (Alice) peeked at          │
│     Bob's card: Werewolf            │
│                                     │
│  4. Robber (Carol) swapped with     │
│     Bob: Carol got Werewolf,        │
│     Bob got Robber                  │
│                                     │
│  5. Insomniac (Eve) checked card:   │
│     Still Hunter                    │
│                                     │
│  [Back to results]                  │
│                                     │
└─────────────────────────────────────┘
```

### Play-Again / Debrief Footer

```
┌─────────────────────────────────────┐
│                                     │
│  ┌─────────────────────────────┐    │
│  │  Play Again                 │    │  <- HOST: primary CTA
│  └─────────────────────────────┘    │     AppColors.bloodEmber bg
│  ┌─────────────────────────────┐    │     AppGlows.cta pulse
│  │  End Game                   │    │  <- HOST: secondary
│  └─────────────────────────────┘    │     AppColors.surface bg
│                                     │
│  --- OR (non-host) ---              │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  Stay for Rematch           │    │  <- NON-HOST: primary
│  └─────────────────────────────┘    │     AppColors.bloodEmber bg
│  ┌─────────────────────────────┐    │
│  │  Leave Game                 │    │  <- NON-HOST: secondary
│  └─────────────────────────────┘    │     AppColors.surface bg
│                                     │
└─────────────────────────────────────┘
```

---

## Preconditions

- Elimination sequence (M-04 or M-05) has completed
- T-06 (Elimination -> Results) transition has completed
- Server has computed win conditions and sent full results data
- Phase background is `AppColors.phaseResults`
- `AppParticles.dust` is active
- `Ambience.results` is playing

---

## States

### Win/Loss Announcement

| State ID | Trigger | What the user sees | Audio/Haptic |
|----------|---------|-------------------|--------------|
| RESULT-HEADLINE | T-06 (900ms offset), M-06 begins | Team headline appears: "[TEAM] WINS!" in `AppTextStyles.displayXl`, team accent color, scale 0.7->1.0, opacity 0->1, `AppCurves.bounce`. Subtle team color wash (6% opacity) behind headline. | Won: `SoundCues.winFanfare` (S-11), `AppHaptics.winCelebration` (H-08). Lost: `SoundCues.lossSomber` (S-12), `AppHaptics.lossCommiserate` (H-09). |
| RESULT-PERSONAL | M-06 (1000ms) | "You Win." or "You Lose." appears below headline in `AppTextStyles.heading1`, `AppColors.parchment`, opacity 0->1 (`AppCurves.enter`). | None |
| RESULT-SUMMARY | M-06 (1200ms), conditional | Resolution summary card fades in below personal outcome. 1-3 sentences explaining why this team won. `AppTextStyles.flavor` on `AppColors.surface` card. Only appears for non-obvious outcomes. | None |
| RESULT-NARRATOR | M-06 (0ms, concurrent with headline) | Narrator cue fires: NC-RESULT-VILLAGE / NC-RESULT-WEREWOLF / NC-RESULT-TANNER / NC-RESULT-NOBODY. | `AppHaptics.narratorBeat` (H-11), narrator audio |
| RESULT-TABLE-APPEAR | M-06 (1600ms when summary present, 1400ms when absent) | Player results table fades in below headline. Rows collapsed by default. Scroll indicator visible. | None |

**Sound timing intent:** The win/loss audio (`SoundCues.winFanfare` or `SoundCues.lossSomber`) and haptic fire at headline time (offset 0ms), before the personal outcome text ("You Win." / "You Lose.") appears at 1000ms. This is intentional — the sound previews the personal result, creating a brief moment where the player hears their outcome before reading it. The sound is determined by the player's personal outcome (server-computed), not the team headline.

**Multiple winners (Tanner + Village):**

| State ID | Trigger | Display |
|----------|---------|---------|
| RESULT-HEADLINE-DUAL | Both Village and Tanner win | Two-line headline: "VILLAGE WINS!" (`AppColors.teamVillage`) + "TANNER WINS!" (`AppColors.teamIndependent`). Second line appears 200ms after first with `AppCurves.enter`. |
| RESULT-NARRATOR-DUAL | Dual win | NC-RESULT-VILLAGE fires first, then NC-RESULT-TANNER after 200ms pause. |

**No team wins:**

| State ID | Trigger | Display |
|----------|---------|---------|
| RESULT-HEADLINE-NOBODY | Winners list is empty | "NO ONE WINS" in `AppTextStyles.displayXl`, `AppColors.parchmentMuted`. No fanfare. | 
| RESULT-NARRATOR-NOBODY | No winners | NC-RESULT-NOBODY fires. `SoundCues.lossSomber` (S-12) plays for all players. |

**Headline variants by team:**

| Winning Team | Headline | Color | Personal (won) | Personal (lost) |
|-------------|----------|-------|----------------|-----------------|
| Village | VILLAGE WINS! | `AppColors.teamVillage` | You Win. | You Lose. |
| Werewolf | WEREWOLF TEAM WINS! | `AppColors.teamWerewolf` | You Win. | You Lose. |
| Tanner (alone) | TANNER WINS! | `AppColors.teamIndependent` | You Win. | You Lose. |
| Village + Tanner | VILLAGE WINS! / TANNER WINS! | Village / Independent | Per player's team | Per player's team |
| Nobody | NO ONE WINS | `AppColors.parchmentMuted` | You Lose. | You Lose. |

**Minion special rule:** When the Werewolf team wins via the Minion with no Werewolves among players, the headline still reads "WEREWOLF TEAM WINS!" The conditional Resolution Summary (RESULT-SUMMARY) explains the Minion rule. No separate headline variant is needed.

### Player Results Table

| State ID | Trigger | What the user sees | Audio/Haptic |
|----------|---------|-------------------|--------------|
| TABLE-COLLAPSED | Table visible | All rows collapsed. Each shows: avatar, name, team badge, original→final role, Won/Lost indicator. Eliminated player rows also display an elimination method icon-badge (voted out, tied, or Hunter chain) next to the outcome indicator, and a narrative flavor line below the role transition in `AppTextStyles.flavorSmall`. Hint H-10 may appear (first time) pointing to a player row. | None |
| TABLE-ROW-EXPAND | Player taps a row | Row expands to show: vote target, votes received, night action summary. | `AppHaptics.tapLight` (H-01) |
| TABLE-ROW-COLLAPSE | Player taps expanded row header | Row collapses. | `AppHaptics.tapLight` (H-01) |
| TABLE-MULTI-EXPAND | Player taps another row | New row expands. Previous stays expanded. Multiple rows can be open. | `AppHaptics.tapLight` (H-01) |

### Full Autopsy

| State ID | Trigger | What the user sees | Audio/Haptic |
|----------|---------|-------------------|--------------|
| AUTOPSY-LINK | Player scrolls to bottom of table | "View full night log" link in `AppColors.tallowGold`. | None |
| AUTOPSY-OPEN | Player taps link | Bottom sheet slides up (UI-08, 300ms, `AppCurves.enter`) with scrim at `AppOpacity.scrim`. Full chronological night log displayed. | `AppHaptics.tapLight` (H-01) |
| AUTOPSY-SCROLL | Player scrolls log | Standard scroll. Each entry is a numbered step in a `AppColors.surface` card. | None |
| AUTOPSY-CLOSE | Player swipes down or taps scrim | Bottom sheet dismisses (UI-09, 300ms, `AppCurves.exit`). Returns to results table. | None |

### Play-Again & Debrief

| State ID | Trigger | What the user sees | Audio/Haptic |
|----------|---------|-------------------|--------------|
| DEBRIEF-ACTIVE | Results fully loaded | Players can scroll, expand rows, view autopsy, and linger. No timer. No pressure. Host controls visible at bottom. | `Ambience.results` continues |
| PLAY-AGAIN-HOST | Host taps "Play Again" | T-07 transition fires (1000ms). All players in the session return to lobby. | `AppHaptics.tapLight` (H-01), `SoundCues.playAgain` (S-13) |
| END-GAME-HOST | Host taps "End Game" | Confirmation dialog (P-HOST end game confirm pattern). On confirm: session closes, all players return to home screen. | `AppHaptics.tapMedium` (H-02) |
| STAY-PLAYER | Non-host taps "Stay for Rematch" | Player is marked as "staying." Button toggles to "Leaving..." (secondary state). Player waits for host to initiate play-again. | `AppHaptics.tapLight` (H-01) |
| LEAVE-PLAYER | Non-host taps "Leave Game" | Player exits session, returns to home screen. Other players see "{name} left" in a brief toast on the results screen. | `AppHaptics.tapLight` (H-01) |
| HOST-LEFT | Host leaves or disconnects during debrief | All players see overlay: P-ERR "The innkeeper has departed..." / "The host left. This lobby has been closed." "Return to Home" button. | `SoundCues.disconnect` (S-14) |
| PLAYER-LEFT-TOAST | A non-host player leaves | Brief toast: "{name} has left the village." Auto-dismiss 3s. | None |

---

## Transitions

| From State | Condition | To (screen/state) | Animation |
|------------|-----------|-------------------|-----------|
| Elimination (S14) | Elimination sequence complete | RESULT-HEADLINE | T-06 (1500ms). Blood vignette/wash fades out. Background -> `AppColors.phaseResults`. |
| RESULT-TABLE-APPEAR | Table visible | DEBRIEF-ACTIVE | Immediate — debrief begins when table is visible. |
| DEBRIEF-ACTIVE | Host taps "Play Again" | Lobby (S03) | T-07 (1000ms). Results fade out. Lobby UI fades in. |
| DEBRIEF-ACTIVE | Host taps "End Game" + confirms | Home (S02) | Results fade out (400ms). Navigate to home. |
| DEBRIEF-ACTIVE | Non-host taps "Leave Game" | Home (S02) | Results fade out (400ms). Navigate to home. |
| DEBRIEF-ACTIVE | Host disconnects (timeout) | Home (S02) | P-ERR overlay. "Return to Home" navigates to home. |

---

## Interactions

| Element | Event | Result | Haptic | Sound |
|---------|-------|--------|--------|-------|
| Headline area | Scroll down | Reveals player results table below headline | None | None |
| Player row (collapsed) | Tap | Row expands showing vote target, votes received, night action summary | `AppHaptics.tapLight` (H-01) | None |
| Player row (expanded) | Tap header | Row collapses | `AppHaptics.tapLight` (H-01) | None |
| "View full night log" | Tap | Autopsy bottom sheet opens (UI-08) | `AppHaptics.tapLight` (H-01) | None |
| Autopsy bottom sheet | Swipe down or tap scrim | Sheet dismisses (UI-09) | None | None |
| Host "Play Again" | Tap | T-07 fires. Same group returns to lobby with previous role config and timer settings retained. | `AppHaptics.tapLight` (H-01) | `SoundCues.playAgain` (S-13) |
| Host "End Game" | Tap | Confirmation dialog appears (overlay card, UI-10). | `AppHaptics.tapLight` (H-01) | None |
| Host "End Game" confirm | Tap | Session closes. All players navigate to home. | `AppHaptics.tapMedium` (H-02) | None |
| Host "End Game" cancel | Tap | Dialog dismissed (UI-11). Return to debrief. | None | None |
| Non-host "Stay for Rematch" | Tap | Button toggles to "Staying!" with checkmark. Player marked as staying on server. | `AppHaptics.tapLight` (H-01) | None |
| Non-host "Stay" (already staying) | Tap | Toggle off. Button returns to "Stay for Rematch." | `AppHaptics.tapLight` (H-01) | None |
| Non-host "Leave Game" | Tap | Player exits. Returns to home. Others see leave toast. | `AppHaptics.tapLight` (H-01) | None |
| Scroll indicator (down arrow) | — | Not interactive. Fades out after first scroll. | — | — |

**Failure paths:**

| Interaction | Failure | Result |
|-------------|---------|--------|
| Host "Play Again" | Server rejects (session expired) | Toast: "The tavern has closed for the night..." / "Session expired. Create a new game." Navigate to home. |
| Non-host "Stay" | Server offline | Stored client-side. Synced on reconnect. |
| Non-host "Leave" | Server offline | Navigate to home immediately. Server handles cleanup on reconnect. |
| Autopsy data load | Server timeout | Autopsy shows loading shimmer (P-LOADING). Retry on scroll. Fallback: "Night log unavailable." |

---

## Play-Again Flow

### Scenarios

| Scenario | Behavior | Result |
|----------|----------|--------|
| Host taps "Play Again" | T-07 transition. ALL players in the session return to lobby. Previous role configuration and timer settings are retained (same roles pre-selected, same timer preset or custom values on S04b). Player list reflects who is still in the session. | Lobby with same group, same game config. Host can adjust roles and timers before starting. |
| Host leaves during debrief | All remaining players see "The innkeeper has departed..." overlay with "Return to Home" button. Session closes. | All players return to home. No automatic host transfer during debrief (unlike mid-game disconnect where host transfers after timeout). |
| Player taps "Leave Game" | Player exits. Other players see "{name} has left the village" toast. Player count in the session decreases. | If host later taps "Play Again," lobby loads without the departed player. |
| Player declines rematch (leaves before host hits Play Again) | Same as "Leave Game." No special UI. | Lobby shows reduced player count. |
| Partial group rematch | Host taps "Play Again." Some players have left. Lobby loads with remaining players only. | Host sees fewer players. Role config may become invalid (too few players for selected roles). Host must adjust. Validation banners (P-ERR inline) fire if config is invalid. |
| All non-host players leave | Host is alone in session. "Play Again" goes to lobby with just the host. | Same as creating a new game — host shares lobby code to invite new players. |

### Game Config Retention

| Property | Value |
|----------|-------|
| On "Play Again" | Role configuration and timer settings from the previous game are **retained** in the lobby. Same roles pre-selected. Same timer preset (or custom values) pre-loaded on S04b. |
| Validation | If player count changed (players left), the retained role config may be invalid (too many or too few cards). Validation banners appear immediately. Host adjusts. Timer settings remain valid regardless of player count changes. |
| Reset option | Host can manually reset roles to a recommended setup for the current player count. Timer settings can be reset by selecting a preset on S04b. No automatic reset. |

### Stay/Leave Indicator

During debrief, non-host players have a binary state: staying or leaving. This state is displayed to the host.

| Element | Display |
|---------|---------|
| Non-host "Staying" | Button shows "Staying!" with checkmark in `AppColors.moonlitSage`. |
| Non-host "Leave" (after leaving) | Player's row in results table dims. Toast notification. |
| Host view | Host sees a count: "4/5 staying for rematch" below the "Play Again" button. |

---

## Player Results Table Detail

### Collapsed Row

| Column | Content | Style |
|--------|---------|-------|
| Avatar | Player sigil/photo at `AppDimensions.avatarMd` (48dp) | Per art-direction.md avatar states. Eliminated: greyscale + 30% opacity reduction. |
| Name | Player display name | `AppTextStyles.body`, `AppColors.parchment` |
| Team badge | Team name pill | Team accent bg at 8% opacity, team accent text, `AppTextStyles.label`, `AppRadius.sm` (4dp) |
| Role transition | "Original → Final" | `AppTextStyles.bodySmall`, `AppColors.parchmentMuted`. Arrow in `AppColors.outline`. If unchanged, show single role name (no arrow). |
| Outcome | "Won" or "Lost" | `AppColors.moonlitSage` for Won, `AppColors.bloodEmber` for Lost. `AppTextStyles.label`. |
| Expand indicator | ▸ (collapsed) / ▾ (expanded) | `AppColors.parchmentMuted` |

### Expanded Row Detail

| Field | Content | Style |
|-------|---------|-------|
| Voted for | "{player name}" with small avatar | `AppTextStyles.body` |
| Votes received | "{count} votes" | `AppTextStyles.body` |
| Eliminated? | "Eliminated" or "Survived" | `AppColors.bloodEmber` or `AppColors.moonlitSage`, `AppTextStyles.label` |
| Night action summary | Role-specific text (see below) | `AppTextStyles.bodySmall`, `AppColors.parchmentMuted` |

### Night Action Summary by Role

| Role | Summary Text |
|------|-------------|
| Werewolf | "Saw: {teammates}" or "Lone werewolf — peeked center: {role}" or "Lone werewolf — no peek" |
| Minion | "Saw werewolves: {names}" or "No werewolves among players" |
| Mason | "Saw mason: {name}" or "Lone mason" |
| Seer | "Peeked at {player}: {role}" or "Peeked center: {role1}, {role2}" or "No action" |
| Robber | "Robbed {player}: got {role}" or "No action" |
| Troublemaker | "Swapped {playerA} and {playerB}" or "No action" |
| Drunk | "Swapped with center card {N}" |
| Insomniac | "Checked card: still {role}" or "Checked card: now {role}" |
| Doppelganger | "Copied {player}: {role}. {follow-up summary}" |
| Villager / Tanner / Hunter | "No night action" |

**Night action summary rule:** The expanded row's night action summary always describes the action the player performed during their originally dealt role's wave, not the final card's role. A player dealt Villager who ends up holding a Werewolf card (via swap) shows "No night action" — they never woke during the night.

### Row Ordering

| Order | Criterion |
|-------|-----------|
| 1 | Eliminated players first (sorted by elimination order: vote death, then Hunter chain target) |
| 2 | Then surviving players sorted by vote count descending |
| 3 | Within same vote count, alphabetical by name |

---

## Full Autopsy Detail

The autopsy is a complete chronological night log. Every server-side action, now fully disclosed (Tier 3 -> Tier 1).

### Entry Format

Each entry is a numbered card:

```
┌─────────────────────────────────────┐
│  1. Wave 1 — Doppelganger          │  <- AppTextStyles.heading3
│                                     │     Wave + role header
│  Carol peeked at Dave's card:       │  <- AppTextStyles.body
│  Villager                           │
│  Carol is now the Villager          │  <- Team change note
│  (Village team)                     │     (if applicable)
└─────────────────────────────────────┘
```

| Property | Value |
|----------|-------|
| Card background | `AppColors.surface` |
| Card radius | `AppRadius.lg` (12dp) |
| Card shadow | `AppShadows.card` |
| Card padding | `AppSpacing.base` (16dp) |
| Card gap | `AppSpacing.md` (12dp) |
| Header | `AppTextStyles.heading3`, `AppColors.parchment` — "[step]. Wave [N] — [Role]" |
| Body | `AppTextStyles.body`, `AppColors.parchment` — action description |
| Team change | `AppTextStyles.bodySmall`, team accent color — if a swap changed a player's team |

### Autopsy Entries by Action Type

| Action | Entry Text |
|--------|-----------|
| Doppelganger peek | "{Player} peeked at {target}'s card: {role}. {Player} is now the {role} ({team} team)." |
| Doppelganger follow-up | "{Player} (as {copied role}) {action description}" — uses the same text as the real role's entry below |
| Werewolf see_team | "Werewolves woke: {list}." If lone: "{Player} is the lone werewolf." |
| Werewolf lone peek | "{Player} peeked at center card {N}: {role}." |
| Minion see_team | "{Player} (Minion) saw werewolves: {list}." or "No werewolves among players." |
| Mason see_team | "Masons woke: {list}." |
| Seer peek player | "{Player} (Seer) peeked at {target}: {role}." |
| Seer peek center | "{Player} (Seer) peeked at center cards {N1} and {N2}: {role1}, {role2}." |
| Robber swap | "{Player} (Robber) swapped with {target}. {Player} got {role}. {Target} got Robber." |
| Troublemaker swap | "{Player} (Troublemaker) swapped {targetA} and {targetB}." |
| Drunk swap | "{Player} (Drunk) swapped with center card {N}. {Player}'s new card is unknown to them." |
| Insomniac peek | "{Player} (Insomniac) checked their card: {role}." |
| Action skipped | "{Player} ({role}) did not act (timed out)." |

**Autopsy Variants:**
- When zero Werewolves are among players (all Werewolf cards in center), the Werewolf wave autopsy entry reads: "Werewolves woke: no Werewolves among players." The narrator cue still fired for concealment.

**Doppelganger card convention:** The autopsy displays the Doppelganger card as its effective copied role, not as "Doppelganger." When Carol holds the Doppelganger card that copied Robber, swap entries show "Carol got Doppelganger (as Robber)" — making clear both the physical card identity and the effective role. The parenthetical "(as {role})" distinguishes Doppelganger cards from actual role cards throughout the autopsy.

---

## Narrator Cues

| Trigger | Cue ID | Semantic Content | Screen Context | Haptic |
|---------|--------|-----------------|----------------|--------|
| M-06 (0ms) — Village wins | NC-RESULT-VILLAGE | "The Village wins!" | Headline display | `AppHaptics.narratorBeat` (H-11) |
| M-06 (0ms) — Werewolf wins | NC-RESULT-WEREWOLF | "The Werewolves win!" | Headline display | H-11 |
| M-06 (0ms) — Nobody wins | NC-RESULT-NOBODY | "No one wins." | Headline display | H-11 |
| M-06 (+200ms) — Tanner also wins | NC-RESULT-TANNER | "The Tanner wins!" | After team headline (dual win) | H-11 |

---

## Errors

| Error | In-World Headline | Clear Subtitle | Recovery |
|-------|-------------------|----------------|----------|
| Results data load failure | "The dust hasn't settled..." | Failed to load game results. Retrying... | Auto-retry. Show loading shimmer. If 3 failures, show "Return to Home" button. |
| Autopsy data load failure | "The night log is missing..." | Failed to load the full night log. | Toast. Autopsy link shows "Unavailable." Player can still see results table. |
| Play Again — session expired | "The tavern has closed for the night..." | Session expired. Create a new game. | Navigate to home. |
| Host disconnect during debrief | "The innkeeper has departed..." | The host left. This lobby has been closed. | Overlay card with "Return to Home." |
| Player disconnect during debrief | (no game-blocking overlay) | (silent departure) | Debrief is social, not game-critical. Disconnected player's row dims. No game pause. Toast: "{name} has left the village." |

---

## Animation

### M-06: Win/Loss Announcement (2000ms)

| Moment | Offset (ms) | Duration (ms) | Layer | Action | Easing |
|--------|-------------|---------------|-------|--------|--------|
| Team headline appear | 0 | 600 | Headline | `AppTextStyles.displayXl`, team accent color, scale 0.7->1.0, opacity 0->1 | `AppCurves.bounce` |
| Team color wash | 0 | 600 | Background | Team color at 6% opacity, full-screen | `AppCurves.standard` |
| Hold | 600 | 400 | — | Beat | — |
| Personal outcome | 1000 | 400 | Subtitle | "You Win." / "You Lose." in `AppTextStyles.heading1`, opacity 0->1 | `AppCurves.enter` |
| Resolution summary (conditional) | 1200 | 400 | Summary card | Summary card fades in below personal outcome. Only appears for non-obvious outcomes. `AppTextStyles.flavor` on `AppColors.surface` card. | `AppCurves.enter` |
| Results table | 1600 (summary present) / 1400 (absent) | 600 | Table | Player table fades in below | `AppCurves.enter` |

**Dual win (Tanner + Village):** Second headline line appears 200ms after first with `AppCurves.enter`. Total M-06 extends by ~200ms.

**No team wins:** "NO ONE WINS" in `AppColors.parchmentMuted`. No `AppCurves.bounce` — uses `AppCurves.enter` instead (subdued). `SoundCues.lossSomber` plays.

**Reduced motion (M-06):** Headline and personal outcome appear simultaneously with no scale animation. Crossfade over 300ms.

### T-07: Results -> Lobby (1000ms)

| Moment | Offset (ms) | Duration (ms) | Layer | Action | Easing |
|--------|-------------|---------------|-------|--------|--------|
| Results UI out | 0 | 400 | Results UI | Fade out, scale 1.0->0.98 | `AppCurves.exit` |
| Particles out | 0 | 400 | Particles | Fade out | `AppCurves.exit` |
| Ambience crossfade | 0 | 800 | Ambient | `Ambience.results` -> `Ambience.lobby` | Linear |
| Background crossfade | 400 | 600 | Background | -> `AppColors.phaseLobby` | `AppCurves.standard` |
| Lobby UI in | 600 | 400 | Lobby UI | Player list and controls fade in | `AppCurves.enter` |

### Standard UI (within results)

| Moment | Reference | Duration | Easing |
|--------|-----------|----------|--------|
| Row expand | — | 300ms | `AppCurves.standard` |
| Row collapse | — | 200ms | `AppCurves.exit` |
| Autopsy sheet open | UI-08 | 300ms | `AppCurves.enter` |
| Autopsy sheet close | UI-09 | 300ms | `AppCurves.exit` |
| Leave toast appear | UI-15 | 300ms | `AppCurves.enter` |
| Leave toast dismiss | UI-16 | 200ms | `AppCurves.exit` |
| Scroll indicator fade | — | 1000ms after first scroll | `AppCurves.exit` |

---

## Strings

| Key | Default Text | Notes |
|-----|-------------|-------|
| `results.village_wins` | VILLAGE WINS! | Headline |
| `results.werewolf_wins` | WEREWOLF TEAM WINS! | Headline |
| `results.tanner_wins` | TANNER WINS! | Headline (alone or dual) |
| `results.nobody_wins` | NO ONE WINS | Headline |
| `results.you_win` | You Win. | Personal outcome |
| `results.you_lose` | You Lose. | Personal outcome |
| `results.role_unchanged` | {role} | Single role when no swap occurred |
| `results.role_changed` | {original} → {final} | Role transition display |
| `results.won` | Won | Row outcome indicator |
| `results.lost` | Lost | Row outcome indicator |
| `results.voted_for` | Voted for: {player} | Expanded row |
| `results.votes_received` | {count} votes received | Expanded row |
| `results.eliminated` | Eliminated | Expanded row status |
| `results.survived` | Survived | Expanded row status |
| `results.autopsy_link` | View full night log | Autopsy link text |
| `results.autopsy_title` | Night Log | Autopsy sheet title |
| `results.autopsy_back` | Back to results | Autopsy close |
| `results.autopsy_unavailable` | Night log unavailable | Fallback if data fails |
| `results.autopsy_ww_none` | Werewolves woke: no Werewolves among players. | Zero WW among players variant |
| `results.host_play_again` | Play Again | Host CTA |
| `results.host_end_game` | End Game | Host secondary |
| `results.player_stay` | Stay for Rematch | Non-host primary |
| `results.player_staying` | Staying! | Non-host toggled state |
| `results.player_leave` | Leave Game | Non-host secondary |
| `results.staying_count` | {count}/{total} staying for rematch | Host view |
| `results.player_left` | {name} has left the village. | Toast |
| `results.scroll_hint` | Scroll for details | Accessibility hint |
| `results.no_night_action` | No night action | Summary for no-action roles |
| `results.summary_minion_special` | {team} wins through the Minion's cunning. No Werewolves walked among the villagers. | Minion special rule |
| `results.summary_tanner_win` | The Tanner got what they wanted — elimination. Be careful what you wish for. | Tanner eliminated = Tanner wins |
| `results.summary_tanner_blocks` | The Tanner's death shields the Werewolves from victory. | Tanner death blocks WW win |
| `results.summary_hunter_chain` | {eliminated} was the Hunter. {chain_target} was struck down in retaliation. | Hunter chain |
| `results.summary_nobody_wins` | The Minion falls, but no Werewolves were among the villagers. No team claims victory. | Nobody wins |
| `results.summary_swapped_identity` | {player} held the {role} card but was originally dealt {original_role}. | Key swap explanation |
| `results.elim_flavor_voted` | Fell to the village's judgment | Standard vote elimination |
| `results.elim_flavor_tied` | Caught in a deadlocked fate | Tie elimination |
| `results.elim_flavor_hunter` | Struck by the Hunter's dying aim | Hunter chain kill |
| `results.elim_badge_voted` | Eliminated ({count} votes) | Accessible label for badge |
| `results.elim_badge_tied` | Eliminated (tied at {count} votes) | Accessible label |
| `results.elim_badge_hunter` | Eliminated by Hunter chain ({hunter}'s vote target) | Accessible label |

---

## Information Architecture

### What Is Now Public (Tier 3 -> Tier 1)

The results screen is where ALL information is disclosed. The game is over — hidden information no longer serves a purpose.

| Information | Disclosure Level | Display |
|-------------|-----------------|---------|
| Winning team(s) | Tier 1 (immediate) | Headline |
| Personal outcome (win/loss) | Tier 2 -> shown | Below headline |
| All players' original roles | Tier 1 (post-game) | Results table, collapsed row |
| All players' final roles (after swaps) | Tier 1 (post-game) | Results table, collapsed row |
| All vote targets | Tier 1 (already revealed in S13) | Results table, expanded row |
| Vote counts per player | Tier 1 (already revealed in S13) | Results table, expanded row |
| Complete night action log | Tier 3 -> Tier 1 (on demand) | Full autopsy, bottom sheet |
| Doppelganger's copied role | Tier 3 -> Tier 1 | Results table (Doppelganger row shows copied role) |

### What Is NOT Shown

| Information | Reason |
|-------------|--------|
| Game configuration (role selection rationale) | Not stored. Host chose roles in lobby. |
| Discussion content (what players said) | Not tracked by the app. Verbal. |
| Timing data (how long each action took) | Not game-relevant. Not displayed. |

---

## Accessibility

### Win/Loss Announcement

| Requirement | Implementation |
|-------------|---------------|
| Screen reader: headline | `Semantics(liveRegion: assertive, label: "[Team] wins! You [win/lose].")`. Announced after M-06 animation completes. |
| Screen reader: dual win | "Village wins! And Tanner wins! You [win/lose]." |
| Screen reader: nobody wins | "No one wins. You lose." |
| Reduced motion | Headline and outcome appear simultaneously (no scale). Crossfade 300ms. |

### Player Results Table

| Requirement | Implementation |
|-------------|---------------|
| Screen reader: collapsed row | "[Player name]. [Team] team. Was [original role], now [final role]. [Won/Lost]." |
| Screen reader: expand | "Double-tap to expand details." On expand: "Voted for [name]. Received [count] votes. [Night action summary]." |
| Screen reader: eliminated player | Prefix: "Eliminated." |
| Touch targets | Row height 48dp minimum. Expand/collapse tap area is full row width. |
| Color-blind: Won/Lost | Text label ("Won" / "Lost") is the primary indicator. Color (`AppColors.moonlitSage` / `AppColors.bloodEmber`) reinforces but does not carry alone. |
| Color-blind: team badge | Team name text inside badge. Not color-only. |
| Screen reader: elimination badge | Elimination badges must have semantic labels. Screen readers announce the full elimination method (e.g., "Eliminated (3 votes)", "Eliminated by Hunter chain (Bob's vote target)"), not just "Eliminated." Uses accessible label strings (`results.elim_badge_*`). |
| Screen reader: elimination flavor line | Flavor line is decorative for screen readers — mark with `excludeSemantics: true`. |

### Full Autopsy

| Requirement | Implementation |
|-------------|---------------|
| Screen reader: entry | Each entry read as: "[Step number]. [Wave name]. [Action description]." |
| Screen reader: sheet | `Semantics(label: "Full night log. [count] entries.")` on sheet open. |
| Focus management | Focus moves to sheet title on open. Focus returns to "View full night log" link on close. |

### Play-Again Controls

| Requirement | Implementation |
|-------------|---------------|
| Screen reader: host buttons | "Play Again. Double-tap to return group to lobby." / "End Game. Double-tap to close this game session." |
| Screen reader: non-host buttons | "Stay for Rematch. Double-tap to confirm." / "Leave Game. Double-tap to exit." |
| Screen reader: staying toggle | On toggle: "You are staying for the rematch." / "You are no longer staying." |
| Screen reader: leave toast | "{name} has left the village." announced via `liveRegion: polite`. |

### General

| Requirement | Implementation |
|-------------|---------------|
| Dynamic text sizing | Table rows expand vertically for large text. Role transition text wraps. Headline wraps to 2 lines at 200% scale. |
| Contrast | All text on `AppColors.surface`: `AppColors.parchment` (10.8:1). Secondary: `AppColors.parchmentMuted` (4.2:1 large text). |

---

## Open Questions

(none)
