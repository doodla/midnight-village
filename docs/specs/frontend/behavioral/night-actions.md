# Night Phase

## Identity

| Field     | Value |
|-----------|-------|
| type      | screen |
| id        | S05, S06, S07, S08, S10 |
| phase     | night |
| route     | /game/:gameId |

This spec covers the complete night phase experience: Role Reveal (S05), Night Actions by role category (S06-S08), and Night Results (S10). Night Waiting (S09) is specified separately in `night-waiting.md`.

The night phase is the most complex screen in the game. It must handle 5 categories of role experience through a composable action framework, not per-role screen design.

---

## Layout

### S05: Role Reveal

```
┌─────────────────────────────────────┐
│  [phase bg: AppColors.phaseNight]   │
│  [AppGlows.candle center]           │
│  [AppParticles.embers + fog + dust] │
│                                     │
│                                     │
│         ┌───────────────┐           │
│         │               │           │
│         │  ┌─────────┐  │           │
│         │  │  CARD    │  │           │  <- 240dp x 320dp (phone)
│         │  │  BACK    │  │           │     3:4 aspect ratio
│         │  │  (wax    │  │           │     AppRadius.xxl (24dp)
│         │  │  seal)   │  │           │     AppShadows.overlay
│         │  │         │  │           │
│         │  └─────────┘  │           │
│         │               │           │
│         └───────────────┘           │
│                                     │
│     "Tap to reveal your role"       │  <- AppTextStyles.body
│                                     │     AppColors.parchmentMuted
│                                     │
└─────────────────────────────────────┘
```

**After flip (card front):**

```
┌─────────────────────────────────────┐
│  [phase bg + candle glow + particles]│
│                                     │
│         ┌───────────────┐           │
│         │ ┌───────────┐ │           │
│         │ │           │ │           │
│         │ │  ROLE ART │ │           │  <- Top 60% of card
│         │ │ (portrait)│ │           │     Per art-direction.md
│         │ │           │ │           │
│         │ ├───────────┤ │           │
│         │ │ Role Name │ │           │  <- AppTextStyles.heading1
│         │ │ [Team]    │ │           │  <- Team badge pill
│         │ │ Desc text │ │           │  <- AppTextStyles.bodySmall
│         │ └───────────┘ │           │
│         └───────────────┘           │
│           [team glow]               │  <- AppGlows.teamVillage /
│                                     │     teamWerewolf / teamIndep
│                                     │
└─────────────────────────────────────┘
```

**Tablet:** Card scales to max 300dp width / 400dp height per art-direction.md. Additional breathing room (`AppSpacing.xxxxl`, 48dp) above and below card. Content centered within `AppDimensions.maxContentWidth` (480dp).

**Landscape:** Card repositioned to left half of screen. Right half reserved for role info text (name, team, description) to avoid scrolling.

---

### S06-S08: Night Action — Player Selection Grid

**4-player variant:**

```
┌─────────────────────────────────────┐
│  [phase bg + candle glow + particles]│
│                                     │
│  ┌─────────────────────────────┐    │
│  │ [Role icon] Role Name       │    │  <- Role info strip
│  │ [Action instruction]        │    │     AppColors.surface
│  └─────────────────────────────┘    │     AppRadius.lg (12dp)
│                                     │
│    ┌──────┐   ┌──────┐             │
│    │ AVA  │   │ AVA  │             │  <- 2-column grid
│    │ Name │   │ Name │             │     AppDimensions.avatarMd
│    └──────┘   └──────┘             │     (48dp) avatars
│    ┌──────┐                         │     AppSpacing.md (12dp) gap
│    │ AVA  │                         │
│    │ Name │                         │  <- 3 other players
│    └──────┘                         │     (self excluded)
│                                     │
│  ┌─────────────────────────────┐    │
│  │  Wave ● ● ○ ○   Timer 0:07 │    │  <- Wave dots + timer
│  └─────────────────────────────┘    │     AppTextStyles.timerCompact
└─────────────────────────────────────┘
```

**12-player variant:**

```
┌─────────────────────────────────────┐
│  [phase bg + candle glow + particles]│
│                                     │
│  ┌─────────────────────────────┐    │
│  │ [Role icon] Role Name       │    │
│  │ [Action instruction]        │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌──────┐ ┌──────┐ ┌──────┐       │
│  │ AVA  │ │ AVA  │ │ AVA  │       │  <- 3-column grid
│  │ Name │ │ Name │ │ Name │       │     for 6+ players
│  └──────┘ └──────┘ └──────┘       │     AppDimensions.avatarMd
│  ┌──────┐ ┌──────┐ ┌──────┐       │     (48dp) avatars
│  │ AVA  │ │ AVA  │ │ AVA  │       │     Scrollable if >9
│  │ Name │ │ Name │ │ Name │       │
│  └──────┘ └──────┘ └──────┘       │
│  ┌──────┐ ┌──────┐ ┌──────┐       │
│  │ AVA  │ │ AVA  │ │ AVA  │       │
│  │ Name │ │ Name │ │ Name │       │
│  └──────┘ └──────┘ └──────┘       │
│  ┌──────┐ ┌──────┐                 │  <- 11 other players
│  │ AVA  │ │ AVA  │                 │
│  │ Name │ │ Name │                 │
│  └──────┘ └──────┘                 │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  Wave ● ● ● ○   Timer 0:07 │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

**Grid scaling rules:**

| Player Count (others) | Columns | Notes |
|-----------------------|---------|-------|
| 2-4 | 2 | Comfortable spacing |
| 5-9 | 3 | Standard grid |
| 10-19 | 4 | Compact grid, avatars shrink to `AppDimensions.avatarSm` (32dp) if needed |
| 20+ | 4, scrollable | Future Mafia support |

**Tablet:** Grid expands to 4 columns at 5+ players. Larger avatars (`AppDimensions.avatarLg`, 64dp). Content within `AppDimensions.maxContentWidth` (480dp).

---

### S06-S08: Night Action — Center Card Selection

```
┌─────────────────────────────────────┐
│  [phase bg + candle glow + particles]│
│                                     │
│  ┌─────────────────────────────┐    │
│  │ [Role icon] Role Name       │    │
│  │ [Action instruction]        │    │
│  └─────────────────────────────┘    │
│                                     │
│                                     │
│    ┌────────┐ ┌────────┐ ┌────────┐│
│    │ CARD   │ │ CARD   │ │ CARD   ││  <- 3 center cards
│    │ BACK   │ │ BACK   │ │ BACK   ││     80dp x 107dp each
│    │  (1)   │ │  (2)   │ │  (3)   ││     (3:4 ratio, smaller)
│    └────────┘ └────────┘ └────────┘│     AppRadius.lg (12dp)
│                                     │     Face-down card back
│                                     │     pattern (per art-dir)
│                                     │
│  ┌─────────────────────────────┐    │
│  │  Wave ● ● ○ ○   Timer 0:07 │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

---

### S06-S08: Night Action — Seer Choice (Branching)

```
┌─────────────────────────────────────┐
│  [phase bg + candle glow + particles]│
│                                     │
│  ┌─────────────────────────────┐    │
│  │ [Seer icon] Seer            │    │
│  │ Choose your vision           │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │                             │    │
│  │  [Eye icon]                 │    │  <- Option A card
│  │  View a player's card       │    │     AppColors.surface
│  │                             │    │     AppRadius.lg (12dp)
│  └─────────────────────────────┘    │     AppSpacing.md gap
│                                     │
│  ┌─────────────────────────────┐    │
│  │                             │    │
│  │  [Cards icon]               │    │  <- Option B card
│  │  View two center cards      │    │     Same treatment
│  │                             │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  Wave ● ● ○ ○   Timer 0:07 │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

After choosing Option A, renders the player selection grid. After choosing Option B, renders the center card selection (player selects 2 of 3 cards).

---

### S06-S08: Night Action — Auto-Reveal (Category 2)

```
┌─────────────────────────────────────┐
│  [phase bg + candle glow + particles]│
│                                     │
│  ┌─────────────────────────────┐    │
│  │ [Role icon] Role Name       │    │
│  │ [Information text]           │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │                             │    │
│  │  Your fellow werewolves:    │    │  <- Auto-reveal info
│  │                             │    │     AppColors.surface card
│  │  ┌──────┐  ┌──────┐        │    │     Highlighted avatars
│  │  │ AVA  │  │ AVA  │        │    │     with AppGlows.selection
│  │  │ Name │  │ Name │        │    │
│  │  └──────┘  └──────┘        │    │
│  │                             │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  Wave ● ● ○ ○   Timer 0:07 │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

**Variants:** Werewolves see teammate list. Masons see partner. Minion sees Werewolf list. Insomniac sees own card. Lone Werewolf sees "You are the lone werewolf" + optional center peek UI.

---

### S10: Night Result (Peek/Swap Result)

```
┌─────────────────────────────────────┐
│  [phase bg + candle glow + particles]│
│                                     │
│  ┌─────────────────────────────┐    │
│  │ [Role icon] Role Name       │    │
│  │ Result:                      │    │
│  └─────────────────────────────┘    │
│                                     │
│         ┌───────────────┐           │
│         │               │           │
│         │  PEEKED CARD  │           │  <- 120dp x 160dp
│         │  (face up)    │           │     AppRadius.xxl (24dp)
│         │  [Role icon]  │           │     Team accent border
│         │  [Role name]  │           │     AppGlows.vision
│         │               │           │
│         └───────────────┘           │
│                                     │
│     "You saw: Alice is Seer"        │  <- AppTextStyles.body
│                                     │     AppColors.parchment
│                                     │
│  ┌─────────────────────────────┐    │
│  │  Wave ● ● ● ○   Timer 0:05 │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

**Tablet / Landscape:** Same adaptations as Role Reveal — card centered within max content width, additional breathing room.

---

## Preconditions

- Server has confirmed game creation and dealt roles
- T-01 (Lobby -> Night) cinematic transition has completed
- Player has an authenticated WebSocket connection
- Phase background is `AppColors.phaseNight`
- `AppGlows.candle` is active
- `AppParticles.embers`, `AppParticles.fog`, and `AppParticles.dust` are active
- `Ambience.night` is playing

**Wake call rule:** The server sends wake notifications based on the player's originally dealt role, not the card currently in their position. A player who was dealt Seer but now holds a Werewolf card (via Robber swap) wakes during the Seer's wave, not the Werewolf wave. A player who receives a Werewolf card via swap does NOT wake during the Werewolf wave.

---

## States

### S05: Role Reveal States

| State ID | Trigger | What the user sees | Audio/Haptic |
|----------|---------|-------------------|--------------|
| S05-ENTRY | T-01 complete | Card slides in from bottom face-down (M-01 Phase 1). "Tap to reveal your role" prompt below card. | None (T-01 sound is finishing) |
| S05-FACE-DOWN | M-01 Phase 1 complete | Card centered, face-down showing card back pattern (quatrefoil + wax seal). Prompt visible. Hint H-01 may appear (first time). | None |
| S05-FLIPPING | Player taps card | 3D Y-axis rotation, card back -> card front (M-01 Phase 2, 600ms). Vision glow intensifies. | `AppHaptics.dramaticReveal` (H-07), `SoundCues.waxSealBreak` (S-04) |
| S05-REVEALED | Flip complete | Card face-up showing role art, name, team badge, description. Team glow active. Team accent border. | None (haptic/sound fired at flip start) |
| S05-HOLD | 2000ms after reveal | Card persists. Player absorbs role info. | None |
| S05-TRANSITION | Hold complete or player taps to proceed | Card fades/scales out. Transition to first night wave content. | None |

### S06-S08: Night Action States by Role Category

#### Category 1: No Night Action (Villager, Tanner, Hunter)

| State ID | Trigger | What the user sees | Audio/Haptic |
|----------|---------|-------------------|--------------|
| CAT1-WAITING | Role reveal hold complete | Night waiting screen (see `night-waiting.md`). Wave indicator shows progress. Player never receives an action prompt. | Fidget sounds on interaction |

#### Category 2: Auto-Reveal (Werewolves, Masons, Minion, Insomniac)

| State ID | Trigger | What the user sees | Audio/Haptic |
|----------|---------|-------------------|--------------|
| CAT2-WAITING | Role reveal hold complete | Night waiting screen until their wave is called | Fidget sounds |
| CAT2-WAKE | Server sends wave activation for player's role | Wave transition (T-08, 800ms). Narrator cue plays. Information auto-displayed: teammate list (WW/Mason/Minion) or own card (Insomniac). | `AppHaptics.narratorBeat` (H-11), narrator audio |
| CAT2-VIEWING | Auto-reveal content displayed | Teammate avatars highlighted with `AppGlows.selection`, or card displayed. Timer counting down for wave. | None |
| CAT2-CLOSE | Wave timer expires or server advances | Content fades out (UI-01, 400ms). Return to night waiting. Narrator close cue plays. | `AppHaptics.narratorBeat` (H-11), narrator audio |

**Werewolf (multiple):** CAT2-VIEWING shows all Werewolf player avatars with names highlighted. Includes Doppelganger-as-Werewolf if applicable.

**Werewolf (lone):** CAT2-VIEWING shows "You are the lone werewolf" message + center card peek option (transitions to CAT3 Simple Choice for the optional peek).

**Minion:** CAT2-VIEWING shows Werewolf player avatars (one-way info display). If no Werewolves among players, shows `info.nightResultMinionNoWerewolves`.

**Mason:** CAT2-VIEWING shows Mason partner avatar. Lone Mason sees no partner — deduces other Mason is in center.

**Insomniac:** CAT2-VIEWING shows own current card with card flip animation (M-02). If unchanged, shows Insomniac. If changed (Robber/Troublemaker swapped), shows new role.

#### Category 3: Simple Choice (Robber, Troublemaker, Drunk, Lone Werewolf)

| State ID | Trigger | What the user sees | Audio/Haptic |
|----------|---------|-------------------|--------------|
| CAT3-WAITING | Role reveal hold complete | Night waiting screen until wave called | Fidget sounds |
| CAT3-WAKE | Server sends wave activation | Wave transition (T-08). Narrator wake cue. Action prompt appears with role info strip + target selection UI. | `AppHaptics.narratorBeat` (H-11), narrator audio |
| CAT3-SELECTING | Action prompt displayed | Player grid (Robber, Troublemaker) or center card slots (Drunk, lone WW). Fluid target selection — tap to highlight, tap another to change (P-FLUID night action model). Confirm button appears after valid selection. Timer counting down. Hint H-03 may appear (first time). | `AppHaptics.selectionClick` (H-04) on each selection change |
| CAT3-SELECTING-2 | First target selected (Troublemaker only) | First target has selection glow. Player must select a second target. "Select second player" instruction updates. Confirm button not yet visible (requires both targets). | `AppHaptics.selectionClick` (H-04) |
| CAT3-SUBMITTED | Player taps Confirm button, or timer expires with valid selection (auto-execute per P-FLUID) | Selection glow persists. Confirmation indicator replaces Confirm button. For Robber: card peek result (M-02). For Troublemaker/Drunk: blind confirmation text. | `AppHaptics.confirmationPulse` (H-05) |
| CAT3-RESULT | Server returns action result | Robber: peeked card flip (M-02, 600ms) showing new role + slide animation from target to self. Troublemaker: "You swapped [A] and [B]" text. Drunk: "You swapped with center card [N]" text. Lone WW: peeked center card flip (M-02). | Robber/Lone WW: `AppHaptics.tapMedium` (H-02), `SoundCues.cardPeek` (S-05). TM/Drunk: `AppHaptics.confirmationPulse` (H-05). |
| CAT3-TIMEOUT | Wave timer expires with no selection | Action skipped. "The moment has passed..." toast (P-ERR). Night result shows `info.actionSkipped`. | None |
| CAT3-CLOSE | Result viewed or wave timer expires | Content fades out (UI-01). Return to waiting. Narrator close cue. | `AppHaptics.narratorBeat` (H-11), narrator audio |

**Robber card slide:** After the Robber's peek card flip, the peeked card animates from the target's grid position to the player's position (300ms, `AppCurves.dramatic`) to visually represent the swap. Per sound-and-motion.md M-02 Robber note.

**Troublemaker two-target selection:** Player selects first target (glow applied), then second target (both glowed). Both selections are fluid until timer expires. Deselecting one target returns to single-selection state.

**Drunk mandatory action:** If timer expires without selection, action is skipped as a timeout (not a legitimate choice). Server logs as timeout. See P-ERR `action.timeout` toast.

#### Category 4: Branching Choice — Seer

| State ID | Trigger | What the user sees | Audio/Haptic |
|----------|---------|-------------------|--------------|
| CAT4-WAITING | Role reveal hold complete | Night waiting screen until Wave 3 called | Fidget sounds |
| CAT4-WAKE | Server sends Wave 3 activation for Seer | Wave transition (T-08). Narrator wake cue (NC-W3-SEER-WAKE). Choice screen: "View a player's card" vs "View two center cards." Hint H-02 may appear (first time). | `AppHaptics.narratorBeat` (H-11), narrator audio |
| CAT4-CHOOSING | Choice screen displayed | Two option cards. Tap to select branch. Fluid — can switch between options before target selection. Timer running. | `AppHaptics.selectionClick` (H-04) |
| CAT4-OPTION-A | Player chose "View a player's card" | Player selection grid appears (same as CAT3). Select one player. Confirm button appears after selection (P-FLUID night action model). | `AppHaptics.selectionClick` (H-04) |
| CAT4-OPTION-B | Player chose "View two center cards" | Center card selection UI appears. Select 2 of 3 center cards. First card gets selection glow, then second. Confirm button appears after both cards selected (P-FLUID night action model). | `AppHaptics.selectionClick` (H-04) |
| CAT4-SUBMITTED | Player taps Confirm button, or timer expires with valid selection (auto-execute per P-FLUID) | Selection glow persists. Confirmation indicator replaces Confirm button. Server returns peek result. | `AppHaptics.confirmationPulse` (H-05) |
| CAT4-RESULT-A | Server returns player peek | Single card flip (M-02, 600ms) revealing target player's role. Result text: `info.nightResultSeerPlayer`. | `AppHaptics.tapMedium` (H-02), `SoundCues.cardPeek` (S-05) |
| CAT4-RESULT-B | Server returns center peek | Two cards flip simultaneously (M-02, 600ms each, parallel). Result text: `info.nightResultSeerCenter`. | `AppHaptics.tapMedium` (H-02), `SoundCues.cardPeek` (S-05) |
| CAT4-TIMEOUT | Timer expires with no action | Action skipped (optional action — legitimate skip). No error toast. Night result shows `info.actionSkipped`. | None |
| CAT4-CLOSE | Result viewed or timer expires | Content fades out. Return to waiting. Narrator close cue (NC-W3-SEER-CLOSE). | `AppHaptics.narratorBeat` (H-11), narrator audio |

#### Category 5: Multi-Step — Doppelganger

| State ID | Trigger | What the user sees | Audio/Haptic |
|----------|---------|-------------------|--------------|
| CAT5-WAKE | Wave 1 begins (Doppelganger always first) | Wave transition. Narrator wake cue (NC-W1-WAKE). Player selection grid for initial peek. | `AppHaptics.narratorBeat` (H-11), narrator audio |
| CAT5-PEEK-SELECT | Peek grid displayed | Player grid (all other players). Select one player to copy. Fluid target selection with Confirm button (P-FLUID night action model). Timer running (extended for Doppelganger). | `AppHaptics.selectionClick` (H-04) |
| CAT5-PEEK-RESULT | Player selected, server returns copied role | Card flip (M-02, 600ms) revealing target's role. Result text: `info.nightResultDoppelgangerCopy`. Team indicator updates if team changed. Role info strip updates to show "Doppelganger (as {copied_role})" with the Doppelganger icon morphing into the copied role icon in a continuous fluid loop. | `AppHaptics.tapMedium` (H-02), `SoundCues.cardPeek` (S-05) |
| CAT5-FOLLOWUP-IMMEDIATE | Copied role has immediate action (Seer, Robber, TM, Drunk) | After brief hold (600ms), follow-up action UI renders. Role info strip shows "Doppelganger (as {copied_role})" with morphing icon loop and the copied role's action instruction text. Seer: CAT4 choice screen. Robber: CAT3 player grid (swap+peek). TM: CAT3 two-player grid (blind swap). Drunk: CAT3 center card selection (blind swap). All follow-up target selections use the P-FLUID night action model (tap to select, Confirm to execute). | Follows the respective CAT3/CAT4 audio patterns |
| CAT5-TEAM-CHANGE | Doppelganger follow-up result reveals a card that changes the player's team (e.g., stealing a Werewolf card) | Theatrical team-change moment (M-07): candle glow tints to new team color, team glow pulse across screen, role info strip border transitions to new team accent. Settles back to normal night atmosphere over 800ms. Brief text flash: "You are now on the {team} team" in team accent color, `AppTextStyles.heading3`, 1500ms display. | `AppHaptics.dramaticReveal` (H-07) |
| CAT5-FOLLOWUP-WAVE2 | Copied role participates in Wave 2 (Werewolf, Mason, Minion) | Doppelganger closes eyes (returns to waiting). Re-wakes during the appropriate Wave 2 call alongside real role holders. Enters CAT2-WAKE state for that role. | Per CAT2 audio |
| CAT5-FOLLOWUP-WAVE4 | Copied role is Insomniac | Doppelganger closes eyes. Re-wakes after real Insomniac in Wave 4 (NC-W4-DOPPEL-INS-WAKE). Sees own current card (M-02 flip). | `AppHaptics.narratorBeat` (H-11), narrator audio |
| CAT5-FOLLOWUP-NONE | Copied role has no action (Villager, Tanner, Hunter) | No follow-up. Brief hold on peek result, then return to waiting. | None |
| CAT5-MINION-SUB | Copied Minion AND Minion is in game setup | Special Minion sub-script fires (NC-W1-MINION-SUB). If Doppelganger actually copied Minion: Werewolf identification UI (same as Minion CAT2-VIEWING). If not: waiting screen (concealment). | `AppHaptics.narratorBeat` (H-11), narrator audio |
| CAT5-TIMEOUT | Timer expires before initial peek | Initial peek skipped. Doppelganger has no copied role — remains Village team with no follow-up. | Toast: P-ERR `action.timeout` |

**Doppelganger Icon Morph Animation**

When the Doppelganger performs a follow-up action, the role icon in the info strip continuously morphs between the Doppelganger icon and the copied role's icon. This is a fluid loop (not a one-time transition):
- Cycle duration: 3000ms
- Easing: `AppCurves.standard`
- Morph: crossfade with slight scale pulse (1.0 → 1.05 → 1.0)
- Runs for the duration of the follow-up action screen
- Reduced motion: static split icon showing both (Doppelganger on left half, copied role on right half, diagonal split)

---

## Transitions

| From State | Condition | To (screen/state) | Animation |
|------------|-----------|-------------------|-----------|
| Lobby | Host starts game | S05-ENTRY | T-01 cinematic (2500ms) |
| S05-FACE-DOWN | Player taps card | S05-FLIPPING | M-01 Phase 2 (600ms card flip) |
| S05-FLIPPING | Flip complete | S05-REVEALED | M-01 Phase 3 (400ms settle) |
| S05-REVEALED | 2000ms hold or tap | S05-TRANSITION | Card fade out: opacity 1->0, scale 1.0->0.95, 400ms, `AppCurves.exit` |
| S05-TRANSITION | Card removed | CAT1/2/3/4/5-WAITING (or CAT5-WAKE for Doppelganger) | UI-01 crossfade (400ms) to night waiting or first action |
| Any CAT*-WAITING | Player's wave is called | CAT*-WAKE | T-08 wave transition (800ms) |
| Any CAT*-CLOSE | Next role in same wave (e.g., Seer->Robber within W3) | CAT*-WAITING then next CAT*-WAKE | T-08 wave transition (800ms) between each role call |
| Any CAT*-CLOSE | Wave complete, more waves remain | Night waiting (see `night-waiting.md`) | T-08 wave transition (800ms) |
| Any CAT*-CLOSE | All waves complete | Discussion phase | T-02 cinematic (2500ms). NC-DAWN narrator cue. |
| Night waiting | All waves complete | Discussion phase | T-02 cinematic (2500ms) |

---

## Interactions

### S05: Role Reveal

| Element | Event | Result | Haptic | Sound |
|---------|-------|--------|--------|-------|
| Face-down card | Tap | Card flips to face-up (M-01 Phase 2). Irreversible. "Tap to reveal" prompt fades out (200ms, `AppCurves.exit`). | `AppHaptics.dramaticReveal` (H-07) | `SoundCues.waxSealBreak` (S-04) |
| Face-down card | No tap (passive wait) | Card stays face-down. No timeout — player reveals at their own pace. | None | None |
| Face-up card | Tap (after reveal) | Dismiss card, proceed to night waiting / first action. | `AppHaptics.tapLight` (H-01) | None |
| Onboarding hint H-01 | Tap (hint or elsewhere) | Dismiss hint permanently. | None | None |

### S06-S08: Night Actions

| Element | Event | Result | Haptic | Sound |
|---------|-------|--------|--------|-------|
| Player avatar (grid target) | Tap | Select as action target. `AppGlows.selection` glow appears (UI-04, 200ms). Previous selection removed if any (UI-05, 200ms). | `AppHaptics.selectionClick` (H-04) | None |
| Player avatar (already selected) | Tap | Deselect. Glow removed (UI-05). Return to no-selection state. | `AppHaptics.selectionClick` (H-04) | None |
| Center card (face-down) | Tap | Select as peek/swap target. `AppGlows.selection` glow appears. | `AppHaptics.selectionClick` (H-04) | None |
| Center card (already selected) | Tap | Deselect. Glow removed. | `AppHaptics.selectionClick` (H-04) | None |
| Seer option A card | Tap | Select "View a player's card." Card gets selection glow. Player grid loads. | `AppHaptics.selectionClick` (H-04) | None |
| Seer option B card | Tap | Select "View two center cards." Card gets selection glow. Center card UI loads. | `AppHaptics.selectionClick` (H-04) | None |
| Seer (after choosing option) | Tap other option | Switch to other option. Previous selection cleared. New UI loads. Fluid per P-FLUID. | `AppHaptics.selectionClick` (H-04) | None |
| Confirm button | Tap | Submit current selection to server. Button replaced by confirmation indicator. Server returns result (if peek action). | `AppHaptics.confirmationPulse` (H-05) | Action-specific (see states) |
| Selection (server rejects) | Server error | Toast: "The spirits reject your offering..." / "Invalid target. Choose again." Selection reverts. Confirm button reappears on valid reselection. | None | None |
| Peeked card (face-up result) | Display only | Card holds face-up until wave ends or player dismisses. Not interactive. | None | None |
| Wave timer | Expires | Current selection auto-executes (same as tapping Confirm). If no selection, action is skipped per role optionality rules. | `AppHaptics.confirmationPulse` (H-05) if selection exists | None |
| Role info strip | Tap | Expand/collapse role description text. | `AppHaptics.tapLight` (H-01) | None |
| Onboarding hints H-02, H-03 | Tap | Dismiss permanently. | None | None |

**Failure paths:**

| Interaction | Failure | Result |
|-------------|---------|--------|
| Tap player target | Server offline | Selection queued client-side. Retried on reconnect. If game pauses (P-DISCONNECT), selection preserved. |
| Tap player target | Invalid target (self) | Silently ignored. Self is never rendered in the action grid. |
| Troublemaker selects same player twice | Validation | Second tap on same player deselects them. Must select two distinct players. |
| Seer center peek selects 3 cards | Validation | Third tap on unselected card replaces the earliest selection. Max 2. |
| Action submission | Network timeout | Retry with exponential backoff. If wave timer expires during retry, action is skipped. |

---

## Narrator Cues

All narrator cue IDs reference `narrator-cues.md`. This table maps cues to their night phase screen context.

| Trigger | Cue ID | Semantic Content | Screen Context | Haptic |
|---------|--------|-----------------|----------------|--------|
| T-01 cinematic (800ms offset) | NC-OPEN | "Everyone, close your eyes." | Plays during lobby->night transition. No screen interaction. | `AppHaptics.narratorBeat` (H-11) |
| Wave 1 begins | NC-W1-WAKE | Doppelganger wake + action instruction | CAT5-WAKE state activates for Doppelganger player. Others see waiting screen. | H-11 |
| Doppelganger action complete | NC-W1-CLOSE | Doppelganger close eyes | Doppelganger returns to waiting. | H-11 |
| Minion in game, after NC-W1-CLOSE | NC-W1-MINION-SUB | Doppelganger-Minion identification | CAT5-MINION-SUB for Doppelganger (if copied Minion). Others: waiting. | H-11 |
| After identification window | NC-W1-MINION-END | Thumbs away, close eyes | All return to waiting. | H-11 |
| Wave 2 — Werewolves | NC-W2-WW-WAKE | Werewolves wake and identify | CAT2-WAKE for Werewolf players (incl. Doppelganger-as-WW). | H-11 |
| After WW wake | NC-W2-WW-LONE | Lone Werewolf may peek center | Always plays (concealment). Lone WW sees center peek UI. | H-11 |
| WW action complete | NC-W2-WW-CLOSE | Werewolves close eyes | CAT2-CLOSE. Return to waiting. | H-11 |
| Wave 2 — Minion | NC-W2-MIN-WAKE | Minion wake, WW extend thumbs | CAT2-WAKE for Minion. | H-11 |
| Minion identification complete | NC-W2-MIN-CLOSE | Thumbs away, Minion close eyes | CAT2-CLOSE. | H-11 |
| Wave 2 — Masons | NC-W2-MASON-WAKE | Masons wake and identify | CAT2-WAKE for Mason players (incl. Doppelganger-as-Mason). | H-11 |
| Mason identification complete | NC-W2-MASON-CLOSE | Masons close eyes | CAT2-CLOSE. | H-11 |
| Wave 3 — Seer | NC-W3-SEER-WAKE | Seer wake, choose peek | CAT4-WAKE for Seer. | H-11 |
| Seer action complete | NC-W3-SEER-CLOSE | Seer close eyes | CAT4-CLOSE. | H-11 |
| Wave 3 — Robber | NC-W3-ROB-WAKE | Robber wake, may swap | CAT3-WAKE for Robber. | H-11 |
| Robber action complete | NC-W3-ROB-CLOSE | Robber close eyes | CAT3-CLOSE. | H-11 |
| Wave 3 — Troublemaker | NC-W3-TM-WAKE | TM wake, may swap others | CAT3-WAKE for TM. | H-11 |
| TM action complete | NC-W3-TM-CLOSE | TM close eyes | CAT3-CLOSE. | H-11 |
| Wave 3 — Drunk | NC-W3-DRUNK-WAKE | Drunk wake, must swap with center | CAT3-WAKE for Drunk. | H-11 |
| Drunk action complete | NC-W3-DRUNK-CLOSE | Drunk close eyes | CAT3-CLOSE. | H-11 |
| Wave 4 — Insomniac | NC-W4-INS-WAKE | Insomniac wake, look at own card | CAT2-WAKE for Insomniac. | H-11 |
| Insomniac viewing complete | NC-W4-INS-CLOSE | Insomniac close eyes | CAT2-CLOSE. | H-11 |
| Wave 4 — Doppelganger-as-Insomniac | NC-W4-DOPPEL-INS-WAKE | Doppelganger-Insomniac wake | CAT5-FOLLOWUP-WAVE4 for Doppelganger (if copied Insomniac). Others: waiting (concealment). | H-11 |
| Doppelganger-Insomniac viewing complete | NC-W4-DOPPEL-INS-CLOSE | Doppelganger close eyes | Return to waiting. Last night cue. | H-11 |
| All waves complete | NC-DAWN | "Everyone, wake up! Discuss." | Plays during T-02 (Night->Discussion) cinematic. All players transition out of night. | H-11 |

**Concealment principle:** All narrator cues for roles in the game setup play regardless of whether the role card ended up with a player or in the center. The server controls each player's UI independently. The audio is a shared broadcast.

---

## Errors

| Error | In-World Headline | Clear Subtitle | Recovery |
|-------|-------------------|----------------|----------|
| Player disconnects during night | "A villager has wandered into the fog..." | {name} disconnected. Game paused. | P-DISCONNECT overlay. All timers freeze. Resume on reconnect. |
| Own connection lost during night | "The spirits are restless..." | Connection lost. Reconnecting... | P-DISCONNECT overlay (self). Selection state preserved client-side. On reconnect, server sends current night state. |
| Night action server error | "Something stirs in the darkness..." | Something went wrong. Try again. | Toast (P-ERR). Action retried automatically. If persistent, action skipped on wave timeout. |
| Night action timeout (optional) | (no error shown) | (silent skip) | Action skipped as legitimate choice. Night result shows `info.actionSkipped`. |
| Night action timeout (mandatory — Drunk) | "The moment has passed..." | Your action was not submitted in time. It has been skipped. | Toast (P-ERR). Action skipped as timeout (not legitimate). Server logs as timeout. |
| Invalid target submitted | "The spirits reject your offering..." | Invalid target. Choose again. | Toast (P-ERR). Selection reverts to previous state. Timer continues. |
| Wave data load failure | "The darkness deepens..." | Failed to load night action. Retrying... | Auto-retry. If failed after 3 attempts, action skipped on wave timeout. |

---

## Animation

All animations reference `sound-and-motion.md` by ID. No values redefined here.

### Role Reveal (S05)

| Moment | Reference | Duration | Easing | What moves |
|--------|-----------|----------|--------|------------|
| Card entry (slide up) | M-01 Phase 1 | 400ms | `AppCurves.enter` | Card: translateY(+200dp)->0, opacity 0->1, scale 0.85->1.0 |
| Card shadow entry | M-01 Phase 1 | 400ms | `AppCurves.enter` | `AppShadows.overlay` fades in |
| "Tap to reveal" prompt | M-01 Phase 1 | 300ms (200ms offset) | `AppCurves.enter` | Opacity 0->1 |
| Card flip first half | M-01 Phase 2 | 300ms | `AppCurves.dramatic` | 3D Y-axis 0deg->90deg |
| Content swap | M-01 Phase 2 | instant | -- | At 90deg: card back -> card front |
| Card flip second half | M-01 Phase 2 | 300ms | `AppCurves.dramatic` | 3D Y-axis 90deg->0deg |
| Border color transition | M-01 Phase 2 | 300ms | `AppCurves.standard` | Border -> team accent color |
| Vision glow intensify | M-01 Phase 2 | 150ms (150ms offset) | `AppCurves.standard` | `AppGlows.vision` opacity 0.12->0.20 |
| Team glow appear | M-01 Phase 3 | 400ms | `AppCurves.standard` | Team glow fades in around card |
| Vision glow settle | M-01 Phase 3 | 300ms | `AppCurves.standard` | `AppGlows.vision` opacity 0.20->0.12 |
| Role info fade in | M-01 Phase 3 | 200ms (200ms offset) | `AppCurves.enter` | Role name + team badge opacity 0->1 |

**Reduced motion (M-01):** Card appears face-down instantly (no slide). On tap, card cross-fades front/back over 300ms (no 3D rotation). Team glow appears instantly.

### Night Action Card Peek (S10)

| Moment | Reference | Duration | Easing | What moves |
|--------|-----------|----------|--------|------------|
| Card flip (first half) | M-02 | 300ms | `AppCurves.dramatic` | Target card 3D Y-axis 0deg->90deg |
| Vision glow appear | M-02 | 300ms | `AppCurves.standard` | `AppGlows.vision` on peeked card |
| Content swap | M-02 | instant | -- | Face-down -> face-up |
| Card flip (second half) | M-02 | 300ms | `AppCurves.dramatic` | 3D Y-axis 90deg->0deg |
| Robber card slide | M-02 (Robber) | 300ms | `AppCurves.dramatic` | Card slides from target position to player position |
| Seer dual card flip | M-02 (Seer B) | 600ms | `AppCurves.dramatic` | Two center cards flip simultaneously |

**Reduced motion (M-02):** Instant crossfade reveal (200ms). No 3D rotation.

### Wave Transitions

| Moment | Reference | Duration | Easing |
|--------|-----------|----------|--------|
| Content fade out | T-08 | 300ms | `AppCurves.exit` |
| Wave dot update | T-08 | 300ms | `AppCurves.standard` |
| New content fade in | T-08 | 500ms (300ms offset) | `AppCurves.enter` |

### Standard UI Motion (within night phase)

| Moment | Reference | Duration | Easing |
|--------|-----------|----------|--------|
| Selection glow appear | UI-04 | 200ms | `AppCurves.standard` |
| Selection glow remove | UI-05 | 200ms | `AppCurves.standard` |
| Sub-state crossfade | UI-01 | 400ms | `AppCurves.standard` |
| Player card stagger entry | UI-13 | 300ms + 50ms/card | `AppCurves.enter` |
| Wave dot fill | UI-23 | 300ms | `AppCurves.standard` |
| Wave dot active pulse | UI-24 | 2000ms loop | sinusoidal |

---

## Strings

### Role Reveal (S05)

| Key | Default Text | Notes |
|-----|-------------|-------|
| `night.reveal.prompt` | Tap to reveal your role | Below face-down card |
| `night.reveal.team_village` | Village | Team badge text |
| `night.reveal.team_werewolf` | Werewolf | Team badge text |
| `night.reveal.team_independent` | Independent | Team badge text |

### Night Action Prompts (S06-S08)

| Key | Default Text | Notes |
|-----|-------------|-------|
| `night.action.seer_choice` | Choose your vision | Seer choice screen header |
| `night.action.seer_option_a` | View a player's card | Seer option A |
| `night.action.seer_option_b` | View two center cards | Seer option B |
| `night.action.robber_prompt` | Choose a player to rob | Robber action instruction |
| `night.action.troublemaker_prompt` | Choose two players to swap | TM action instruction |
| `night.action.troublemaker_second` | Select second player | TM after first selection |
| `night.action.drunk_prompt` | Choose a center card to swap with | Drunk action instruction |
| `night.action.werewolf_lone_prompt` | You may peek at one center card | Lone WW optional peek |
| `night.action.doppelganger_prompt` | Choose a player to copy | Doppelganger initial peek |
| `night.action.doppelganger_followup` | Now perform your new role's action | Doppelganger follow-up |
| `night.action.select_player` | Tap a player to select them | Generic player selection |
| `night.action.select_center` | Tap a center card to select it | Generic center selection |
| `night.action.confirm` | Confirm | Night action confirm button label |

### Night Results (S10)

All night result strings are defined in `information-architecture.md` under the `info.*` prefix. Referenced here for completeness:

| Key | Default Text | Notes |
|-----|-------------|-------|
| `info.nightResultSeerPlayer` | You saw: {player} is {role} | Seer peek result (option A) |
| `info.nightResultSeerCenter` | Center cards: {role1}, {role2} | Seer peek result (option B) |
| `info.nightResultRobber` | You took {player}'s card: {role} | Robber swap result |
| `info.nightResultTroublemaker` | You swapped {playerA} and {playerB} | TM blind swap result |
| `info.nightResultDrunk` | You swapped with center card {position} | Drunk blind swap result |
| `info.nightResultInsomniac` | Your card is now: {role} | Insomniac self-peek |
| `info.nightResultDoppelgangerCopy` | You copied {player}: {role} | Doppelganger initial peek |
| `info.nightResultWerewolfTeam` | Your fellow werewolves: {players} | WW see_team |
| `info.nightResultWerewolfLone` | You are the lone werewolf | Lone WW indicator |
| `info.nightResultWerewolfLonePeek` | Center card: {role} | Lone WW peek result |
| `info.nightResultMasonTeam` | Your fellow mason: {player} | Mason see_team |
| `info.nightResultMasonLone` | You are the lone mason | Lone Mason |
| `info.nightResultMinionTeam` | The werewolves are: {players} | Minion see_team |
| `info.nightResultMinionNoWerewolves` | There are no werewolves among players | Minion, all WW in center |
| `info.actionSkipped` | Action skipped | Timeout result |

### Wave Indicator

| Key | Default Text | Notes |
|-----|-------------|-------|
| `night.wave.label` | Wave {current} of {total} | Accessibility label |
| `night.wave.active` | {role} phase | Accessibility: which role is active |

---

## Information Architecture

Per `information-architecture.md`, the night phase manages Tier 1 (public) and Tier 2 (player-scoped) information:

### What Each Player Sees

| Information | Tier | Visible To | Display |
|-------------|------|-----------|---------|
| Current game phase (night) | 1 | All | Phase background, particles |
| Wave progress (dot indicator) | 1 | All | Wave dots: filled = complete, pulsing = active, empty = upcoming |
| Wave timer | 1 | All | `AppTextStyles.timerCompact` in wave footer. Base duration is host-configured via S04b Night Action timer (defaults: First Time 12s, Casual 8s, Experienced 5s; range: 5-15s). Waves containing CAT4 (Seer branching choice) or CAT5 (Doppelganger multi-step) roles add the host-configured Complex Role Bonus (defaults: First Time 15s, Casual 10s, Experienced 5s; range: 0-15s). |
| Roles in play | 1 | All | Not displayed during night (available on discussion/voting screens) |
| Own original role | 2 | Self | Role reveal card (S05). Tap-to-reveal after reveal hold. |
| Night action prompt | 2 | Active player for current wave | Action UI appears only for the player whose wave is called |
| Night action result | 2 | Acting player | Peek result, swap confirmation. Tap-to-reveal in subsequent phases. |
| Other players' actions | 3 (server-only) | Nobody | Never shown. Never hinted. No timing side-channels. |

### Concealment Invariant

**Every player's visible screen state during the night must be indistinguishable between "I have an action this wave" and "I am waiting this wave" to an outside observer.**

This is enforced by:
1. Night waiting fidget interactions (see `night-waiting.md`) ensure all phones show activity.
2. Narrator cues play for all roles in the game setup (concealment principle from `narrator-cues.md`).
3. Wave transitions look the same for all players (T-08 animation plays for everyone).
4. No sound or haptic from action UIs leaks to indicate a specific player is acting (fidget sounds on waiting provide cover noise).
5. **Wave timing floor:** The server MUST enforce a minimum wave duration of **8 seconds** regardless of how quickly actions are submitted. If a wave has only one actor and they submit in 2 seconds, the wave still runs for at least 8 seconds. This serves concealment: it prevents timing side-channels from fast-completing single-actor waves. The host-configured "Night Action" timer (from S04b Game Settings) sets the MAXIMUM wave duration. The 8-second floor applies even if all actors in the wave submit instantly, regardless of host config.

**Concealment Timing Constraint:** The server holds a minimum of **5 seconds** between wake and close cues for every role call, even when no player has an active action for that role. This prevents timing-based deduction of which roles have active players. A wave containing Seer, Robber, Troublemaker, and Drunk — where only the Seer has an active player — still takes at least 20 seconds (4 role calls x 5 seconds minimum each).

### Host During Night

The host has NO additional information or controls during the night. The host is a normal player. The "Next Wave" host control (P-HOST) appears only when all expected actions for the current wave have been submitted — it is a convenience for advancing past completed waves, not an information advantage.

---

## Accessibility

### Role Reveal (S05)

| Requirement | Implementation |
|-------------|---------------|
| Screen reader: card entry | `Semantics(role: button, label: "Your role card has arrived. Double-tap to reveal your secret role.")` — must NOT leak role. |
| Screen reader: card flip announcement | Fires at the END of the flip animation (or crossfade), not at the start. Sound (`SoundCues.waxSealBreak`) and haptic (`AppHaptics.dramaticReveal`) still fire at tap time to preserve the tactile moment. |
| Screen reader: card face-up | `Semantics(liveRegion: true)`. Card becomes a static container post-flip. Role name, team, and description are separate semantic children so users can re-read each field independently. Full announcement: "Your role is [Role Name]. [Team Name] team. [Role description]." |
| Screen reader: team badge | `Semantics(label: "[Team Name] team")` on the team badge pill. Redundant with flip announcement but navigable independently. |
| Reduced motion: card flip | Cross-fade front/back over 300ms instead of 3D rotation. Per M-01 reduced motion. Team glow appears instantly. |
| Minimum touch target | Card is 240dp x 320dp — exceeds `AppDimensions.touchTargetMin` (48dp). |
| Team identification (color-blind) | Team badge uses text label ("Village", "Werewolf", "Independent") + team icon + team color. Never color alone. |

### Night Actions (S06-S08)

**Player grid navigation:**

| Property | Value |
|----------|-------|
| Grid semantics | `Semantics(role: grid)` on the container. Each player cell is a `gridcell`. |
| Navigation mode | Row-by-row (left-to-right, top-to-bottom). 2-column grid on phone, 3-column on tablet. |
| Cell label (unselected) | "[Player Name], not selected. Double tap to select as target." |
| Cell label (selected) | "[Player Name], selected." |
| Selection announcement | On select: "Selected [Player Name]." On deselect (switching): "Deselected [Previous Name]. Selected [New Name]." Both via `liveRegion`. |
| Multi-select (Troublemaker) | Label includes count: "[Name], selected, 1 of 2". Prompt reads: "Select two players to swap. [N] of 2 selected." |
| Minimum touch target | Avatars at `AppDimensions.avatarMd` (48dp) meet minimum. At 10+ players (32dp avatars), hit area padded to 48dp. |

**Center card selection:**

| Property | Value |
|----------|-------|
| Slot labels | "Center card 1, not selected", "Center card 2, not selected", "Center card 3, not selected" |
| Selection announcement | "Selected center card [N]." |
| Seer two-card select | "Center card [N], selected, 1 of 2" — same multi-select pattern as Troublemaker. |

**Seer choice UI:**

| Property | Value |
|----------|-------|
| Choice semantics | Two options presented as a `radiogroup`: "Peek one player's card" and "Peek two center cards" |
| Selected state | "[Option text], selected" — then the corresponding target grid appears |
| Prompt | "Choose your Seer action. Option 1: Peek one player's card. Option 2: Peek two center cards." |

**Timer accessibility:**

| Behavior | Specification |
|----------|--------------|
| Initial announcement | "You have [N] seconds to complete your action." — on wave start |
| 50% remaining | "[N] seconds remaining." — `liveRegion: polite` |
| 25% remaining | "[N] seconds remaining, time is running low." — `liveRegion: assertive` |
| 10% remaining | "[N] seconds remaining." — `liveRegion: assertive` |
| Timer expiry (selection made) | "Time's up. Your action has been submitted." |
| Timer expiry (no selection) | "Time's up. Action skipped." |
| Continuous reading | Timer is NOT announced every second. Only at thresholds. Continuous reading would drown out other content. |
| Threshold sync | Announcement thresholds match the visual timer color ramp (50%, 25%, 10%) so audio and visual changes are synchronized. |

**Reduced motion:**

| Element | Reduced Motion Alternative |
|---------|--------------------------|
| Card peek (M-02) | Instant crossfade (200ms) instead of 3D flip. |
| Selection glow (UI-04) | Glow appears instantly (no 200ms animation). |
| Wave transition (T-08) | Instant content swap. Wave indicator updates without animation. |

### Night Waiting Concealment (Accessibility)

The concealment invariant ("all players look busy") is inherently visual. For screen reader users, concealment is maintained through consistent haptic and audio presence — all phones produce occasional sounds and haptic taps regardless of whether the player has an active night action.

| Element | Alternative for Screen Reader Users |
|---------|-------------------------------------|
| Fidget interactions (F-01, F-02, F-03) | Accessible via double-tap on fidget zone. Screen reader users hear `SoundCues.fidgetEmber`/`SoundCues.fidgetSmoke` and feel `AppHaptics.fidgetResponse`. The haptic/audio IS the fidget for them. |
| Wave progress | "Night phase, wave [N] of [total] in progress" — announced on wave change via `liveRegion: assertive`. |
| Haptic concealment | Fidget haptic/audio responses are indistinguishable from night action confirmation haptics to other people in the room. Imperfect but acceptable for v1. |

### Night Results (S10)

**Screen reader announcements per role (fires after flip animation / crossfade completes):**

| Scenario | Announcement |
|----------|-------------|
| Seer peeks player | "You peeked at [Player Name]'s card. They are the [Role Name]." |
| Seer peeks two center | "Center card 1 is the [Role]. Center card 2 is the [Role]." |
| Robber swaps | "You swapped cards with [Player Name]. Your new role is [Role Name]." Then if team changed: "[Team Name] team." |
| Doppelganger initial peek | "You looked at [Player Name]'s card. They are the [Role Name]. You are now the [Role Name]." |
| Doppelganger follow-up | Per the copied role's announcement pattern above. |
| Werewolf (see teammates) | "Your fellow Werewolf is [Name]." or "Your fellow Werewolves are [Name] and [Name]." or "You are the lone Werewolf. You may peek at one center card." |
| Mason (see partner) | "Your fellow Mason is [Player Name]." or "You are the lone Mason." |
| Minion (see Werewolves) | "The Werewolves are [Name] and [Name]." or "There are no Werewolves among the players." |
| Insomniac (see own card) | "Your card is still [Role Name]." or "Your card has changed. You are now the [Role Name]." |
| Lone Werewolf peek | "Center card [N] is the [Role Name]." |
| Drunk (blind swap) | "You swapped your card with center card [N]. You don't know your new role." |
| Troublemaker (blind swap) | "You swapped [Player Name]'s card with [Player Name]'s card." |

**Timing:** Haptic (`AppHaptics.tapMedium`) and sound (`SoundCues.cardPeek`) fire at the START of the animation (same as sighted users). Screen reader announcement fires at the END.

### Color-Blind Safety

Every color-coded state in the night phase has a non-color redundant signal. No additional measures needed.

| Element | Color Signal | Redundant Signal |
|---------|-------------|-----------------|
| Team on role reveal | Team accent color (gold/red/grey) | Text team name on badge pill + team icon |
| Team glow on reveal | Team glow color | Atmospheric only — badge text carries the information |
| Selected target in grid | `AppGlows.selection` (gold glow) | Visible checkmark icon in `AppColors.tallowGold` |
| Wave progress dots | `AppColors.tallowGold` for active | Active: scale pulse (UI-24). Complete: filled. Inactive: outline only. Shape + animation encode state. |
| Seer choice selection | `AppGlows.selection` on card | Radio-button filled circle indicator (selected) vs empty circle (unselected) |

### General Night Phase

| Requirement | Implementation |
|-------------|---------------|
| Focus management | On wave transition, focus moves to the first interactive element of new wave content (or descriptive label for auto-reveal). |
| Touch target size | All interactive elements (avatars, cards, buttons) meet 48dp minimum. |
| Contrast | All text uses `AppColors.parchment` (10.8:1 vs `AppColors.surface`) or `AppColors.parchmentMuted` (4.2:1, large text only). |
| Dynamic text sizing | Role info strip, action prompts, and result text support up to 200% text scale. Layout reflows vertically if needed. |

---

## Rule Verification

Every game mechanic represented in this screen spec is traceable to the authoritative game specs. Citations provided by game-designer with file paths and verbatim quotes.

### Wake Order & Wave System

| Claim | Source | Verbatim Citation |
|-------|--------|-------------------|
| Canonical wake order (W1-W4, steps 1-10) | `docs/specs/onuw/night-phase.md`, Wake Order table | Steps 1-10: Doppelganger(W1), Werewolves(W2), Minion(W2), Masons(W2), Seer(W3), Robber(W3), TM(W3), Drunk(W3), Insomniac(W4), Doppelganger-as-Insomniac(W4) |
| Wave 2 ordering mechanically irrelevant | `docs/specs/onuw/night-phase.md`, Wave 2 | "No cards are moved or swapped. Players only gain information about who shares their team. Since no state changes occur, the ordering within Wave 2 is mechanically irrelevant — the narrator calls them in the order shown for thematic consistency only." |
| Wave 3 order is strict and canonical | `docs/specs/onuw/night-phase.md`, Wave 3 | "This is the critical wave. Actions here modify game state (swap cards). The order within Wave 3 is strict and canonical: `Seer → Robber → Troublemaker → Drunk`" |
| Each Wave 3 role acts on state after all preceding roles | `docs/specs/onuw/night-phase.md`, Wave 3 | "Each role acts on the current state after all preceding roles in this wave have resolved." |

### Action Optionality

| Claim | Source | Verbatim Citation |
|-------|--------|-------------------|
| Seer optional ("may") | `docs/specs/onuw/night-phase.md`, Action Optionality table | "Seer: Optional — 'You may look at...' — Can choose not to peek" |
| Robber optional ("may") | `docs/specs/onuw/night-phase.md`, Action Optionality table | "Robber: Optional — 'You may exchange...' — Can choose not to swap" |
| Troublemaker optional ("may") | `docs/specs/onuw/night-phase.md`, Action Optionality table | "Troublemaker: Optional — 'You may exchange...' — Can choose not to swap" |
| Drunk mandatory (no "may") | `docs/specs/onuw/night-phase.md`, Action Optionality table | "Drunk: Mandatory — 'Exchange your card...' (no 'may') — Must swap with center" |
| Lone Werewolf optional | `docs/specs/onuw/roles.md`, Werewolf | "the lone Werewolf may look at one center card. This is optional — they can choose not to peek" |
| Doppelganger initial peek mandatory | `docs/specs/onuw/night-phase.md`, Action Optionality table | "Doppelganger initial peek: Mandatory — 'Wake up and look at...' — Must look at a card" |
| Doppelganger follow-up mandatory (base game) | `docs/specs/onuw/night-phase.md`, Action Optionality table | "Doppelganger follow-up: Mandatory — 'Do it now' (imperative) — Must perform copied action" |
| Doppelganger follow-up ambiguity noted | `docs/specs/onuw/night-phase.md`, Action Optionality note | "The base game narrator script uses imperative language ('do it now')... However, the Daybreak expansion rulebook uses 'may' for analogous Doppelganger follow-ups... This spec treats the follow-up as mandatory per the base game text." |

### Doppelganger Timing

| Claim | Source | Verbatim Citation |
|-------|--------|-------------------|
| Wave 3 copies execute immediately in Wave 1 | `docs/specs/onuw/night-phase.md`, Wave 1 | "If the copied role has an immediate action (Seer, Robber, Troublemaker, Drunk): The Doppelganger performs that action immediately during the Doppelganger phase, still in Wave 1." |
| Doppelganger-as-Seer immediate | `docs/specs/onuw/doppelganger.md`, Copies Seer | "Immediately (still in the Doppelganger phase), the Doppelganger performs the Seer action" |
| Doppelganger-as-Robber immediate | `docs/specs/onuw/doppelganger.md`, Copies Robber | "Immediately, the Doppelganger performs the Robber action" |
| Wave 2 copies participate in Wave 2 call | `docs/specs/onuw/night-phase.md`, Wave 1 | "If the copied role acts in Wave 2 (Werewolf, Mason, Minion): The Doppelganger closes her eyes and wakes again when that role is called in Wave 2." |
| Doppelganger-as-WW wakes with Werewolves | `docs/specs/onuw/doppelganger.md`, Copies Werewolf | "In Wave 2 (Werewolf call): Doppelganger opens eyes along with real Werewolves. All Werewolves see each other (including Doppelganger-as-Werewolf)." |
| Doppelganger-as-Minion special script | `docs/specs/onuw/doppelganger.md`, Copies Minion | "If you are now a Minion, keep your eyes open. Otherwise, close them. Werewolves, stick out your thumb so the Doppelganger-Minion can see who you are." |
| Doppelganger-as-Insomniac after real Insomniac | `docs/specs/onuw/night-phase.md`, Wave 4 | "Insomniac wakes first, peeks own card. Doppelganger-as-Insomniac wakes second, peeks own card." |
| Doppelganger-as-WW-lone may peek center | `docs/specs/onuw/doppelganger.md`, Copies Werewolf | "the Doppelganger is the lone Werewolf and may peek one center card" |

### Information Scoping

| Claim | Source | Verbatim Citation |
|-------|--------|-------------------|
| Robber sees NEW card after swap | `docs/specs/onuw/roles.md`, Robber | "The Robber swaps their own card with that player's card, then views their new card (the one they just took)." |
| Seer sees pre-swap state | `docs/specs/onuw/night-phase.md`, Wave 3 | "Seer peeks at the pre-swap state (sees cards before any Wave 3 swaps)" |
| Insomniac sees post-swap state | `docs/specs/onuw/roles.md`, Insomniac | "Acts in Wave 4, after all Wave 3 swaps have resolved." |
| Troublemaker swap is blind | `docs/specs/onuw/roles.md`, Troublemaker | "The Troublemaker does not look at either card." / "What the player sees: Nothing — the swap is blind." |
| Drunk swap is blind | `docs/specs/onuw/roles.md`, Drunk | "The Drunk does not view their new card." / "What the player sees: Nothing — the swap is blind." |
| Minion sees Werewolves one-way | `docs/specs/onuw/roles.md`, Minion | "This is one-directional — Werewolves do not know who the Minion is." |
| WW and Masons don't see each other | `docs/specs/onuw/roles.md`, Mason | "Masons and Werewolves are in the same wave but do not see each other" |
| WW cards in center don't count for play | `docs/specs/onuw/roles.md`, Werewolf | "Werewolf cards in the center do not count as 'Werewolves in play' for win conditions — only player-held Werewolf cards matter" |

### Timer & Timeout

| Claim | Source | Verbatim Citation |
|-------|--------|-------------------|
| Timeout on optional action = skip | `docs/specs/onuw/night-phase.md`, Timer Model | "If a player does not submit an action before the timer expires, their action is skipped (logged as 'skip', no state change)" |
| Timeout on mandatory action = graceful degradation | `docs/specs/onuw/night-phase.md`, Action Optionality | "Mandatory actions should be enforced — the client must submit a valid action before the timer expires. If a mandatory action times out, it is still skipped (graceful degradation) but this is a timeout, not a legitimate choice." |

### Cross-Cutting

| Claim | Source | Verbatim Citation |
|-------|--------|-------------------|
| Narrator cues play for all roles in setup (concealment) | `narrator-cues.md`, Concealment Principle | "Narrator cues play for ALL roles selected in the game setup, regardless of whether a role card ended up with a player or in the center." |
| Server never leaks private info | `CLAUDE.md`, Core Principle #2 | "A player ONLY sees what their role allows. NEVER leak another player's secret info." |

---

## Open Questions

(none)
