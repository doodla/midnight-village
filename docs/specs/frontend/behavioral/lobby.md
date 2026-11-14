# Lobby

## Identity

| Field     | Value |
|-----------|-------|
| type      | screen |
| id        | S03, S04, S04b |
| phase     | lobby |
| route     | /lobby/:lobbyCode |

This spec covers the Lobby Waiting Room (S03), Role Selection (S04), and Game Settings (S04b). The lobby is the gathering-at-the-tavern moment — warm, social, anticipation building. Players see each other arrive. The host configures the game. The experience bridges the mundane (entering a code, choosing roles, setting the pace) and the theatrical (the game is about to begin).

Host UX is first-class: controls are themed, contextual, and integrated — not bolted-on admin UI.

---

## Layout

### S03: Lobby Waiting Room — Player View

```
┌─────────────────────────────────────┐
│  [phase bg: AppColors.phaseLobby]   │
│  [AppParticles.dust]                │
│                                     │
│        A B C 1 2 3                  │  <- Lobby code
│                                     │     AppTextStyles.codeDisplay
│        Tap to copy                  │     (48dp, Space Grotesk bold,
│                                     │      letter-spacing 10dp)
│                                     │     AppColors.parchment on
│                                     │     AppColors.surface card
│                                     │
│  ┌─────────────────────────────┐    │
│  │ Players (3/10)              │    │  <- Player list header
│  │                             │    │     AppTextStyles.heading3
│  │ ┌─────────────────────┐    │    │
│  │ │ [AVA] Alice  ★ Ready│    │    │  <- Host: ★ badge
│  │ └─────────────────────┘    │    │     AppColors.tallowGold border
│  │ ┌─────────────────────┐    │    │
│  │ │ [AVA] Bob     Ready │    │    │  <- Player: ready state
│  │ └─────────────────────┘    │    │     AppColors.moonlitSage text
│  │ ┌─────────────────────┐    │    │
│  │ │ [AVA] Carol Waiting │    │    │  <- Not ready
│  │ └─────────────────────┘    │    │     AppColors.parchmentMuted
│  │                             │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  ○ Ready  /  ● Ready!      │    │  <- Ready toggle
│  └─────────────────────────────┘    │     AppColors.surface bg
│                                     │
└─────────────────────────────────────┘
```

### S03: Lobby Waiting Room — Host View

```
┌─────────────────────────────────────┐
│  [phase bg: AppColors.phaseLobby]   │
│  [AppParticles.dust]                │
│                                     │
│        A B C 1 2 3                  │  <- Lobby code (same)
│        Tap to copy                  │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ Players (3/10)              │    │
│  │ ┌─────────────────────┐    │    │
│  │ │ [AVA] Alice  ★ Host │    │    │
│  │ └─────────────────────┘    │    │
│  │ ┌─────────────────────┐    │    │
│  │ │ [AVA] Bob     Ready │    │    │
│  │ └─────────────────────┘    │    │
│  │ ┌─────────────────────┐    │    │
│  │ │ [AVA] Carol Waiting │    │    │
│  │ └─────────────────────┘    │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  Configure Roles  ▸        │    │  <- Opens S04
│  └─────────────────────────────┘    │     AppColors.surface card
│                                     │
│  ┌─────────────────────────────┐    │
│  │  Start Game                 │    │  <- Primary CTA
│  └─────────────────────────────┘    │     AppColors.bloodEmber bg
│                                     │     AppGlows.cta pulse (UI-17)
│                                     │     Disabled until valid config
│                                     │     + ≥3 players.
│                                     │     Also accessible via S04b.
└─────────────────────────────────────┘
```

### S04: Role Selection — Host Only

```
┌─────────────────────────────────────┐
│  [phase bg: AppColors.phaseLobby]   │
│                                     │
│  Role Selection                     │  <- AppTextStyles.heading2
│  Select {N} cards ({players} + 3)   │  <- AppTextStyles.bodySmall
│                                     │     AppColors.parchmentMuted
│  ┌─────────────────────────────┐    │
│  │  ⚠ Select 2 more cards     │    │  <- Validation banner
│  └─────────────────────────────┘    │     (P-ERR inline)
│                                     │
│  WEREWOLF TEAM                      │  <- Section header
│  ┌─────────────────────────────┐    │     AppTextStyles.label
│  │ [icon] Werewolf     [ - 2 + ]│   │     AppColors.teamWerewolf
│  │ Sees other werewolves        │    │  <- Role row
│  └─────────────────────────────┘    │     AppColors.surface card
│  ┌─────────────────────────────┐    │     AppRadius.lg (12dp)
│  │ [icon] Minion       [ - 0 + ]│   │
│  │ Sees werewolves (one-way)   │    │
│  └─────────────────────────────┘    │
│                                     │
│  VILLAGE TEAM                       │  <- AppColors.teamVillage
│  ┌─────────────────────────────┐    │
│  │ [icon] Seer         [ - 1 + ]│   │
│  │ Peeks at cards              │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ [icon] Robber       [ - 1 + ]│   │
│  │ Swaps and peeks             │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ [icon] Troublemaker [ - 0 + ]│   │
│  │ Swaps two others            │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ [icon] Drunk        [ - 0 + ]│   │
│  │ Swaps with center           │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ [icon] Insomniac    [ - 0 + ]│   │
│  │ Checks own card             │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ [icon] Mason        [ - 0 + ]│   │  <- Mason: 0 or 2 only
│  │ Sees other masons           │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ [icon] Hunter       [ - 0 + ]│   │
│  │ Kills vote target if dies   │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ [icon] Villager     [ - 2 + ]│   │  <- Max 3
│  │ No night action             │    │
│  └─────────────────────────────┘    │
│                                     │
│  INDEPENDENT                        │  <- AppColors.teamIndependent
│  ┌─────────────────────────────┐    │
│  │ [icon] Tanner       [ - 0 + ]│   │
│  │ Wins if eliminated          │    │
│  └─────────────────────────────┘    │
│                                     │
│  COMPLEX                            │
│  ┌─────────────────────────────┐    │
│  │ [icon] Doppelganger [ - 0 + ]│   │
│  │ Copies another role         │    │
│  └─────────────────────────────┘    │
│                                     │
│  Cards: 6/8 needed                  │  <- Card counter
│                                     │     AppTextStyles.labelLarge
│  ┌─────────────────────────────┐    │
│  │  Next: Game Settings  ▸     │    │  <- Navigates to S04b
│  └─────────────────────────────┘    │     AppColors.bloodEmber bg
│                                     │
└─────────────────────────────────────┘
```

---

### S04b: Game Settings — Host Only

```
┌─────────────────────────────────────┐
│  [phase bg: AppColors.phaseLobby]   │
│                                     │
│  Game Settings                      │  <- AppTextStyles.heading2
│  Choose a pace for your group       │  <- AppTextStyles.bodySmall
│                                     │     AppColors.parchmentMuted
│                                     │
│  ┌─────────┐ ┌─────────┐ ┌────────┐│
│  │ First   │ │ Casual  │ │ Exper- ││  <- Preset selector
│  │  Time   │ │    ●    │ │ ienced ││     AppColors.surface cards
│  └─────────┘ └─────────┘ └────────┘│     AppRadius.lg (12dp)
│                                     │     Selected: AppColors.
│                                     │     tallowGold 2dp border
│                                     │     + AppGlows.selection
│                                     │
│  ┌─────────────────────────────┐    │
│  │  ▸ Customize         [Custom]│   │  <- Expander toggle
│  └─────────────────────────────┘    │     AppColors.surface card
│                                     │     [Custom] badge visible
│                                     │     only when values diverge
│                                     │     from selected preset
│  ┌─────────────────────────────┐    │
│  │                             │    │  <- Expanded: timer sliders
│  │  Discussion       5:00      │    │     AppTextStyles.body label
│  │  ──────●────────────        │    │     AppTextStyles.labelLarge
│  │  3 min           10 min     │    │     value
│  │                             │    │     AppColors.parchmentMuted
│  │  Voting           1:00      │    │     range labels
│  │  ────────●──────────        │    │
│  │  30s              2:00      │    │
│  │                             │    │
│  │  Night Action      0:08     │    │
│  │  ─────●─────────────        │    │
│  │  5s                15s      │    │
│  │                             │    │
│  │  Complex Role Bonus 0:10    │    │
│  │  ────────●──────────        │    │
│  │  0s                15s      │    │
│  │                             │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  Start Game                 │    │  <- Primary CTA
│  └─────────────────────────────┘    │     AppColors.bloodEmber bg
│                                     │     AppGlows.cta pulse (UI-17)
│                                     │     Disabled until valid config
│                                     │     + ≥3 players
└─────────────────────────────────────┘
```

---

## Preconditions

- Player has entered a name (Welcome/Auth complete)
- Player has created or joined a lobby
- Server has confirmed lobby creation and assigned a lobby code
- Phase background is `AppColors.phaseLobby`
- `AppParticles.dust` is active
- `Ambience.lobby` is playing

---

## States

### S03: Lobby Waiting Room

| State ID | Trigger | What the user sees | Audio/Haptic |
|----------|---------|-------------------|--------------|
| LOBBY-EMPTY | Host creates lobby, alone | Lobby code prominent. Player list shows only host. Empty state below list: "The tavern awaits..." / "Share the lobby code to invite players." (P-EMPTY). | `Ambience.lobby` playing |
| LOBBY-PLAYER-JOIN | Server notifies new player joined | Player appears in list with stagger animation (UI-13, 300ms). Player count increments. | `AppHaptics.tapLight` (H-01) |
| LOBBY-PLAYER-LEAVE | Server notifies player left | Player row fades out (200ms, `AppCurves.exit`). List reflows. Player count decrements. | None |
| LOBBY-READY-TOGGLE | Player taps ready toggle | Own ready state toggles. Toggle animates (UI-14, scale 1.0->1.08->1.0, 200ms, `AppCurves.bounce`). Server notified. | `AppHaptics.selectionClick` (H-04) |
| LOBBY-ALL-READY | All players are ready | Visual emphasis on "Start Game" (host) — CTA glow intensifies. Non-host: "Waiting for host to start." | None |
| LOBBY-CODE-COPIED | Player taps lobby code | Code copied to clipboard. Brief "Copied!" toast below code area (auto-dismiss 2s). | `AppHaptics.tapLight` (H-01) |
| LOBBY-CONFIG-OPEN | Host taps "Configure Roles" | Role selection screen (S04) slides in from right or appears as full-screen overlay. | `AppHaptics.tapLight` (H-01) |
| LOBBY-GAME-START | Host taps "Start Game", server confirms | T-01 cinematic (2500ms) fires. All players transition to night phase. | `AppHaptics.phaseShift` (H-06), `SoundCues.gameStart` (S-01) |
| LOBBY-HOST-BADGE | Always visible | Host player row has `AppColors.tallowGold` 2dp border + ★ icon. | None |
| LOBBY-DISCONNECT | Player disconnect | P-DISCONNECT overlay. Not game-blocking in lobby — disconnected player is removed after timeout. No game pause. | `SoundCues.disconnect` (S-14) |
| LOBBY-LOADING | Lobby data loading | Shimmer on player list (P-LOADING). Code placeholder shimmers. | None |
| LOBBY-HINT-HOST | Host first time | Hint H-07: "Choose which roles to include in this game." Points to "Configure Roles." | None |

### S04: Role Selection (Host Only)

| State ID | Trigger | What the user sees | Audio/Haptic |
|----------|---------|-------------------|--------------|
| ROLE-LIST | Host opens role selection | Scrollable list of all roles grouped by team. Each role has icon, name, brief description, count stepper. Current card count vs required shown. | None |
| ROLE-INCREMENT | Host taps + on a role | Count increments (max enforced). Card counter updates. Validation re-evaluated. | `AppHaptics.tapLight` (H-01) |
| ROLE-DECREMENT | Host taps - on a role | Count decrements (min 0 enforced). Card counter updates. Validation re-evaluated. | `AppHaptics.tapLight` (H-01) |
| ROLE-VALID | Card count = player_count + 3, all constraints pass | Validation banner hidden. "Next: Game Settings" button enabled. Card counter in `AppColors.moonlitSage`. | None |
| ROLE-INVALID-COUNT | Card count ≠ player_count + 3 | Validation banner: "Select {N} more cards" or "Remove {N} cards." Card counter in `AppColors.bloodEmber`. "Next: Game Settings" button still enabled (navigates to S04b with invalid config visible). | None |
| ROLE-INVALID-MASON | Mason count is 1 | Validation banner: "Masons are never alone..." / "Masons must be included in pairs (0 or 2)." Mason row highlighted with `AppColors.bloodEmber` border. | None |
| ROLE-INVALID-MULTI | Multiple validation errors | Banners stack. Most severe on top. | None |
| ROLE-DONE | Host taps "Next: Game Settings" | Navigates to Game Settings (S04b). Role config saved to server. | `AppHaptics.tapLight` (H-01) |
| ROLE-HINT | Host first time on role selection | Hint H-07 (if not yet dismissed on lobby). | None |

### S04b: Game Settings (Host Only)

| State ID | Trigger | What the user sees | Audio/Haptic |
|----------|---------|-------------------|--------------|
| SETTINGS-LOADING | Host navigates to S04b | Timer values load from local storage (if prior config exists). Shimmer on preset cards and sliders (P-LOADING) during load. | None |
| SETTINGS-PRESET-SELECTED | Load complete (or default) | One preset card highlighted with `AppColors.tallowGold` 2dp border + `AppGlows.selection`. Customize expander collapsed. Slider values reflect selected preset. "Start Game" CTA enabled if lobby preconditions met. | None |
| SETTINGS-PRESET-CHANGED | Host taps a different preset card | Previous preset border removed. New preset highlighted. All slider values update to new preset's defaults. "Custom" badge hidden. | `AppHaptics.selectionClick` (H-04) |
| SETTINGS-CUSTOMIZE-OPEN | Host taps "Customize" expander | Expander animates open (300ms, `AppCurves.standard`). Four timer sliders revealed with current values. | `AppHaptics.tapLight` (H-01) |
| SETTINGS-CUSTOMIZE-CLOSE | Host taps expanded "Customize" header | Expander collapses (200ms, `AppCurves.exit`). Slider values preserved. | `AppHaptics.tapLight` (H-01) |
| SETTINGS-SLIDER-CHANGED | Host drags a slider | Slider value updates in real time. If new values diverge from any preset, "Custom" badge appears next to preset selector in `AppColors.tallowGold`. | `AppHaptics.selectionClick` (H-04) on release |
| SETTINGS-CUSTOM-MATCH | Host adjusts sliders to match a preset exactly | "Custom" badge hidden. Matching preset card re-highlights automatically. | None |
| SETTINGS-GAME-START | Host taps "Start Game", server confirms | Timer config sent to server alongside role config. T-01 cinematic (2500ms) fires. All players transition to night phase. | `AppHaptics.phaseShift` (H-06), `SoundCues.gameStart` (S-01) |

**Preset defaults:**

| Timer | First Time | Casual | Experienced |
|-------|-----------|--------|-------------|
| Discussion | 8 min | 5 min | 3 min |
| Voting | 90s | 60s | 45s |
| Night Action | 12s | 8s | 5s |
| Complex Role Bonus | 15s | 10s | 5s |

**Slider ranges:**

| Timer | Min | Max | Step |
|-------|-----|-----|------|
| Discussion | 3 min | 10 min | 1 min |
| Voting | 30s | 120s | 15s |
| Night Action | 5s | 15s | 1s |
| Complex Role Bonus | 0s | 15s | 5s |

**Complex Role Bonus applies to:** CAT4 (Seer branching choice) and CAT5 (Doppelganger multi-step) action categories. The bonus time is added to the base Night Action timer for waves containing these roles.

---

## Transitions

| From State | Condition | To (screen/state) | Animation |
|------------|-----------|-------------------|-----------|
| Home (S02) | Player creates lobby | LOBBY-EMPTY | Screen slide in from right (300ms, `AppCurves.enter`) |
| Home (S02) | Player joins lobby | LOBBY-* (with existing players) | Screen slide in from right |
| LOBBY-* | Host taps "Configure Roles" | ROLE-LIST (S04) | Screen slide in from right (300ms, `AppCurves.enter`) |
| ROLE-* | Host taps "Next: Game Settings" | SETTINGS-* (S04b) | Screen slide in from right (300ms, `AppCurves.enter`) |
| SETTINGS-* | Host taps back / swipe back | ROLE-* (S04) | Screen slide out to right (300ms, `AppCurves.exit`) |
| SETTINGS-* | Host taps "Start Game" + server confirms | Night phase (S05) | T-01 cinematic (2500ms) |
| LOBBY-* | Host taps "Start Game" + server confirms | Night phase (S05) | T-01 cinematic (2500ms) |
| LOBBY-* | Host leaves | Home (S02) for host; all others see "innkeeper departed" overlay | Host: slide out. Others: P-ERR overlay. |

---

## Interactions

### S03: Lobby

| Element | Event | Result | Haptic | Sound |
|---------|-------|--------|--------|-------|
| Lobby code card | Tap | Copy code to clipboard. "Copied!" feedback below code (fade in 200ms, auto-dismiss 2s). | `AppHaptics.tapLight` (H-01) | None |
| Ready toggle (not ready) | Tap | Toggle to ready. Toggle visual: fill animates to `AppColors.moonlitSage`, scale pop (UI-14). "Ready" text replaces "Waiting." Server notified. | `AppHaptics.selectionClick` (H-04) | None |
| Ready toggle (ready) | Tap | Toggle to not ready. Toggle visual: fill animates to empty, "Waiting" text. Server notified. | `AppHaptics.selectionClick` (H-04) | None |
| "Configure Roles" (host) | Tap | Navigate to S04 role selection. | `AppHaptics.tapLight` (H-01) | None |
| "Start Game" (host, enabled) | Tap | Server validates config. If valid: T-01 fires. If invalid: toast with specific error. Button disables during validation. | `AppHaptics.tapMedium` (H-02) | `SoundCues.gameStart` (S-01) on success |
| "Start Game" (host, disabled) | Tap | No action. Button visually disabled (`AppOpacity.disabled`, 0.38). Tooltip: reason for disability ("Need at least 3 players" or "Invalid role configuration"). | None | None |
| Player row | — | Not interactive (no tap action on other players). Display only. | — | — |
| Hint H-07 | Tap | Dismiss permanently. | None | None |
| Hint H-08 | Tap | Dismiss permanently. | None | None |

**Start Game preconditions (all must be true for button to enable):**

| Condition | Error if Unmet |
|-----------|---------------|
| ≥ 3 players in lobby | "Need at least 3 players to start" |
| ≤ 10 players in lobby | "Maximum 10 players" |
| Card count = player_count + 3 | "Need {N} role cards ({players} players + 3 center)" |
| Mason count is 0 or 2 | "Masons must be in pairs" |
| At least one role selected | "Select at least one role" |

### S04: Role Selection

| Element | Event | Result | Haptic | Sound |
|---------|-------|--------|--------|-------|
| Role stepper (+) | Tap | Increment role count by 1. Max enforced per role (WW: 2, Villager: 3, Mason: 2, all others: 1). At max, + button disables. Card counter updates. Validation re-evaluated. | `AppHaptics.tapLight` (H-01) | None |
| Role stepper (-) | Tap | Decrement role count by 1. At 0, - button disables. Card counter updates. Validation re-evaluated. | `AppHaptics.tapLight` (H-01) | None |
| Mason stepper (+) at 0 | Tap | Jumps from 0 to 2 (Masons come in pairs). | `AppHaptics.tapLight` (H-01) | None |
| Mason stepper (-) at 2 | Tap | Jumps from 2 to 0 (no single Mason). | `AppHaptics.tapLight` (H-01) | None |
| "Next: Game Settings" | Tap | Navigate to Game Settings (S04b). Config saved to server. Validation banners persist on S04b if config is still invalid. | `AppHaptics.tapLight` (H-01) | None |
| Validation banner | — | Not interactive. Informational. Dismisses when condition resolves. | — | — |
| Role row (card area) | Tap (not on stepper) | Expand/collapse role description for more detail. | `AppHaptics.tapLight` (H-01) | None |

**Failure paths:**

| Interaction | Failure | Result |
|-------------|---------|--------|
| Start Game | Server rejects (race condition, player left between tap and validation) | Toast: "A villager slipped away..." / "Player count changed. Check your configuration." Button re-enables. |
| Start Game | Server timeout | Toast: P-ERR network timeout. Button re-enables. |
| Role config save | Server offline | Config cached client-side. Synced on reconnect. Lobby shows cached config. |
| Stepper at max | Tap + | Button disabled (`AppOpacity.disabled`). No action. |
| Stepper at min | Tap - | Button disabled. No action. |

### S04b: Game Settings

| Element | Event | Result | Haptic | Sound |
|---------|-------|--------|--------|-------|
| Preset card (unselected) | Tap | Selects preset. Border highlights with `AppColors.tallowGold` 2dp + `AppGlows.selection` (UI-04, 200ms). Previous preset deselects (UI-05, 200ms). All slider values update to preset defaults. "Custom" badge hides. Values saved to local storage. | `AppHaptics.selectionClick` (H-04) | None |
| Preset card (selected) | Tap | No action. Already selected. | None | None |
| "Customize" expander (collapsed) | Tap | Expander opens. Slider section height animates from 0 to content height (300ms, `AppCurves.standard`). Content fades in. | `AppHaptics.tapLight` (H-01) | None |
| "Customize" expander (expanded) | Tap | Expander collapses. Height animates to 0 (200ms, `AppCurves.exit`). Content fades out. Slider values preserved. | `AppHaptics.tapLight` (H-01) | None |
| Timer slider | Drag | Value updates in real time. Display shows formatted value (e.g., "5:00", "60s"). If values no longer match any preset, "Custom" badge appears in `AppColors.tallowGold` with `AppTextStyles.label`. If values match a preset exactly, badge hides and that preset re-highlights. Values saved to local storage on release. | `AppHaptics.selectionClick` (H-04) on release | None |
| "Start Game" (enabled) | Tap | Server validates config (roles + timers). If valid: T-01 fires. If invalid: toast with specific error. Button disables during validation. | `AppHaptics.tapMedium` (H-02) | `SoundCues.gameStart` (S-01) on success |
| "Start Game" (disabled) | Tap | No action. Button visually disabled (`AppOpacity.disabled`, 0.38). Tooltip: reason for disability ("Need at least 3 players" or "Invalid role configuration"). | None | None |
| Back navigation | Swipe right or system back | Returns to S04 (Role Selection). Timer config preserved. | None | None |

**Start Game preconditions (all must be true for button to enable):**

Same as S03 lobby Start Game preconditions — the button has moved from S03 to S04b, but the conditions are identical:

| Condition | Error if Unmet |
|-----------|---------------|
| ≥ 3 players in lobby | "Need at least 3 players to start" |
| ≤ 10 players in lobby | "Maximum 10 players" |
| Card count = player_count + 3 | "Need {N} role cards ({players} players + 3 center)" |
| Mason count is 0 or 2 | "Masons must be in pairs" |
| At least one role selected | "Select at least one role" |

**Failure paths:**

| Interaction | Failure | Result |
|-------------|---------|--------|
| Start Game | Server rejects (race condition, player left between tap and validation) | Toast: "A villager slipped away..." / "Player count changed. Check your configuration." Button re-enables. |
| Start Game | Server timeout | Toast: P-ERR network timeout. Button re-enables. |
| Local storage read | Storage unavailable | Defaults to Casual preset. No error shown. |
| Local storage write | Storage full | Values used for current game but not persisted. No error shown. |

---

## Lobby Code Display

| Property | Value |
|----------|-------|
| Format | 6 alphanumeric characters, uppercase. Server-generated. |
| Typography | `AppTextStyles.codeDisplay` (Space Grotesk, 48dp, bold, letter-spacing 10dp) |
| Color | `AppColors.parchment` |
| Container | `AppColors.surface` card, `AppRadius.lg` (12dp), `AppShadows.card`, centered horizontally |
| Padding | `AppSpacing.xl` (24dp) vertical, `AppSpacing.xxl` (32dp) horizontal |
| Copy label | "Tap to copy" in `AppTextStyles.bodySmall`, `AppColors.parchmentMuted`, below code |
| Copy feedback | "Copied!" replaces "Tap to copy" for 2000ms, `AppColors.moonlitSage` text |
| Tap area | Entire card is tappable (well exceeds 48dp minimum) |

---

## Player List

### Row Layout

```
┌─────────────────────────────────────┐
│  [AVA]  Player Name    Ready / Wait │
│  48dp   body text      label text   │
│         parchment      sage / muted │
└─────────────────────────────────────┘
```

| Element | Style |
|---------|-------|
| Container | `AppColors.surface`, `AppRadius.lg` (12dp), `AppShadows.card` |
| Row height | 64dp (avatar 48dp + `AppSpacing.sm` padding top/bottom) |
| Row gap | `AppSpacing.sm` (8dp) |
| Avatar | `AppDimensions.avatarMd` (48dp). Host avatar: `AppColors.tallowGold` 2dp border (per art-direction.md host state). |
| Name | `AppTextStyles.body`, `AppColors.parchment`. Truncate with ellipsis if >60% of row width. |
| Host badge | ★ icon in `AppColors.tallowGold`, `AppDimensions.iconSm` (16dp), before "Host" label |
| Ready state | `AppTextStyles.label`. Ready: "Ready" in `AppColors.moonlitSage`. Not ready: "Waiting" in `AppColors.parchmentMuted`. |
| Join animation | UI-13: opacity 0->1, translateY +8dp->0, 300ms, `AppCurves.enter`. New player appears at bottom of list. |
| Leave animation | Opacity 1->0, 200ms, `AppCurves.exit`. List reflows upward. |

### Player Count

| Element | Style |
|---------|-------|
| Header | "Players ({current}/{max})" in `AppTextStyles.heading3` |
| Current | Actual player count |
| Max | 10 (ONUW max). Future: configurable per game type. |
| Color | `AppColors.parchment` for count. Turns `AppColors.bloodEmber` if at max capacity. |

---

## Role Selection Detail

### Role Row Layout

```
┌─────────────────────────────────────┐
│  [role icon]  Role Name   [ - N + ] │
│   24dp        heading3    stepper   │
│                                     │
│  Brief description text             │  <- AppTextStyles.bodySmall
│                                     │     AppColors.parchmentMuted
└─────────────────────────────────────┘
```

| Element | Style |
|---------|-------|
| Container | `AppColors.surface`, `AppRadius.lg` (12dp), `AppShadows.card` |
| Padding | `AppSpacing.base` (16dp) |
| Role icon | `AppDimensions.iconMd` (24dp), team accent color |
| Role name | `AppTextStyles.heading3`, `AppColors.parchment` |
| Description | `AppTextStyles.bodySmall`, `AppColors.parchmentMuted`. One-line summary. |
| Stepper | `-` and `+` buttons at `AppDimensions.touchTargetMin` (48dp) each. Count between them in `AppTextStyles.labelLarge`. |
| Stepper buttons | `AppColors.surface` bg, `AppColors.outline` border, `AppRadius.md` (8dp). Disabled: `AppOpacity.disabled` (0.38). |
| Gap between rows | `AppSpacing.sm` (8dp) |

### Section Headers

| Section | Label | Color |
|---------|-------|-------|
| Werewolf Team | WEREWOLF TEAM | `AppColors.teamWerewolf` |
| Village Team | VILLAGE TEAM | `AppColors.teamVillage` |
| Independent | INDEPENDENT | `AppColors.teamIndependent` |
| Complex | COMPLEX | `AppColors.parchmentMuted` |

Headers use `AppTextStyles.label`, letter-spacing 1dp, uppercase.

### Role Max Counts

| Role | Max Count | Notes |
|------|-----------|-------|
| Werewolf | 2 | |
| Minion | 1 | |
| Seer | 1 | |
| Robber | 1 | |
| Troublemaker | 1 | |
| Drunk | 1 | |
| Insomniac | 1 | |
| Mason | 2 | Steps in pairs: 0 → 2 → 0. No count of 1. |
| Hunter | 1 | |
| Villager | 3 | |
| Tanner | 1 | |
| Doppelganger | 1 | |

### Card Counter

| Property | Value |
|----------|-------|
| Position | Sticky bottom of role selection, above "Next: Game Settings" button |
| Format | "Cards: {selected}/{required} needed" |
| Required | player_count + 3 |
| Color (valid) | `AppColors.moonlitSage` |
| Color (invalid) | `AppColors.bloodEmber` |
| Typography | `AppTextStyles.labelLarge` |

### Validation Banners

| Validation | In-World Headline | Clear Subtitle | Trigger |
|------------|-------------------|----------------|---------|
| Card count too low | "The cards don't add up..." | Select {N} more role cards ({players} players + 3 center). | selected < required |
| Card count too high | "Too many cards on the table..." | Remove {N} role cards. Need exactly {required}. | selected > required |
| Mason count is 1 | "Masons are never alone..." | Masons must be included in pairs (0 or 2). | mason_count == 1 |
| No roles selected | "An empty table..." | Select at least one role to play. | selected == 0 |

Banners use P-ERR inline variant. `AppColors.surface` card with `AppColors.bloodEmber` left border accent (4dp). Appear at top of role list with `AppDurations.crossfade` (400ms) fade-in. Dismiss when condition resolves.

### Extensibility

The role list is **data-driven, not hardcoded**. Roles are rendered from server-provided role definitions. Adding new roles (future expansions) requires:

1. Server adds role definition to the role registry (name, team, description, icon, max_count, constraints).
2. Role selection UI renders it automatically in the appropriate team section.
3. No frontend code changes required for new roles.

The role list is a scrollable `ListView` with team-section headers, not a fixed grid. This supports any number of roles.

---

## Narrator Cues

No narrator cues fire during the lobby phase. The first narrator cue is NC-OPEN, which fires during the T-01 (Lobby -> Night) transition after the host starts the game.

---

## Errors

| Error | In-World Headline | Clear Subtitle | Recovery |
|-------|-------------------|----------------|----------|
| Lobby creation failed | "The tavern door won't open..." | Failed to create lobby. Try again. | Toast. Player retries from home screen. |
| Lobby join — not found | "The tavern door is barred..." | No lobby found with code {code}. | Inline banner on join screen. Player re-enters code. |
| Lobby join — full | "The village is full..." | This lobby has reached its maximum of {N} players. | Inline banner. Player returns to home. |
| Lobby join — game started | "The night has already fallen..." | This game is in progress. You cannot join mid-game. | Inline banner. Player returns to home. |
| Host left | "The innkeeper has departed..." | The host left. This lobby has been closed. | Overlay card (P-ERR). "Return to Home" button. |
| Player kicked | "You've been shown the door..." | The host removed you from the lobby. | Overlay card. "Return to Home" button. |
| Start game — server reject | "A villager slipped away..." | Player count changed. Check your configuration. | Toast. Button re-enables. Host adjusts. |
| Config save failed | (silent) | (retry) | Client retries silently. Config cached locally. |
| Player disconnect in lobby | (no game-blocking overlay) | (silent removal) | Disconnected player removed from list after timeout. Toast: "{name} left the tavern." Not game-blocking (no game in progress). |

---

## Animation

| Moment | Reference | Duration | Easing | What moves |
|--------|-----------|----------|--------|------------|
| Player join | UI-13 | 300ms | `AppCurves.enter` | New row: opacity 0->1, translateY +8dp->0 |
| Player leave | — | 200ms | `AppCurves.exit` | Row: opacity 1->0. List reflows. |
| Ready toggle | UI-14 | 200ms | `AppCurves.bounce` | Toggle: scale 1.0->1.08->1.0 |
| Code copy feedback | — | 200ms in, 2000ms hold, 200ms out | `AppCurves.enter` / `AppCurves.exit` | "Copied!" text replaces "Tap to copy" |
| Role stepper increment | — | 150ms | `AppCurves.standard` | Count: scale 1.0->1.1->1.0 on change |
| Validation banner appear | — | 400ms | `AppCurves.enter` | Banner: opacity 0->1, pushes content down |
| Validation banner dismiss | — | 400ms | `AppCurves.exit` | Banner: opacity 1->0, content collapses up |
| S04 screen enter | — | 300ms | `AppCurves.enter` | Slide in from right |
| S04 screen exit | — | 300ms | `AppCurves.exit` | Slide out to right |
| S04b screen enter | — | 300ms | `AppCurves.enter` | Slide in from right |
| S04b screen exit | — | 300ms | `AppCurves.exit` | Slide out to right |
| Preset selection change | UI-04/05 | 200ms | `AppCurves.standard` | Previous: glow removed (UI-05). New: glow + border applied (UI-04). |
| Customize expander open | — | 300ms | `AppCurves.standard` | Height 0 -> content height. Content fades in. |
| Customize expander close | — | 200ms | `AppCurves.exit` | Height -> 0. Content fades out. |
| Start Game | T-01 | 2500ms | Per T-01 timeline | Full cinematic transition |
| CTA glow pulse | UI-17 | 3000ms loop | Sinusoidal | `AppGlows.cta` on "Start Game" button |

**Reduced motion:**

| Element | Alternative |
|---------|------------|
| Player join/leave | Instant appear/disappear |
| Ready toggle bounce | Instant state change |
| Role stepper | Instant count update |
| S04 slide | Instant screen swap |
| S04b slide | Instant screen swap |
| Preset selection | Instant border change, no glow animation |
| Customize expander | Instant expand/collapse |
| CTA glow pulse | Static glow at mid-opacity (0.20) |

---

## Strings

### S03: Lobby

| Key | Default Text | Notes |
|-----|-------------|-------|
| `lobby.code_copy_label` | Tap to copy | Below lobby code |
| `lobby.code_copied` | Copied! | After copy |
| `lobby.player_count` | Players ({count}/{max}) | List header |
| `lobby.host_badge` | Host | Host label |
| `lobby.ready` | Ready | Player ready state |
| `lobby.waiting` | Waiting | Player not ready state |
| `lobby.ready_toggle_on` | Ready! | Toggle active state |
| `lobby.ready_toggle_off` | Tap to Ready Up | Toggle inactive state |
| `lobby.configure_roles` | Configure Roles | Host button |
| `lobby.start_game` | Start Game | Host CTA |
| `lobby.start_disabled_players` | Need at least 3 players to start | Disabled reason |
| `lobby.start_disabled_config` | Invalid role configuration | Disabled reason |
| `lobby.empty_headline` | "The tavern awaits..." | Empty state (P-EMPTY) |
| `lobby.empty_subtitle` | Share the lobby code to invite players. | Empty state |
| `lobby.player_joined` | {name} joined the village | Toast (optional) |
| `lobby.player_left` | {name} left the tavern | Toast |

### S04: Role Selection

| Key | Default Text | Notes |
|-----|-------------|-------|
| `roles.title` | Role Selection | Screen title |
| `roles.subtitle` | Select {count} cards ({players} players + 3 center) | Instruction |
| `roles.card_counter` | Cards: {selected}/{required} needed | Bottom counter |
| `roles.card_counter_valid` | Cards: {count}/{count} ✓ | When valid |
| `roles.done` | Next: Game Settings | Navigate to S04b |
| `roles.section_werewolf` | WEREWOLF TEAM | Section header |
| `roles.section_village` | VILLAGE TEAM | Section header |
| `roles.section_independent` | INDEPENDENT | Section header |
| `roles.section_complex` | COMPLEX | Section header |
| `roles.validation_too_few` | Select {count} more role cards | Banner |
| `roles.validation_too_many` | Remove {count} role cards | Banner |
| `roles.validation_mason` | Masons must be included in pairs (0 or 2) | Banner |
| `roles.validation_empty` | Select at least one role to play | Banner |

### S04b: Game Settings

| Key | Default Text | Notes |
|-----|-------------|-------|
| `lobby.settings.title` | Game Settings | Screen title |
| `lobby.settings.subtitle` | Choose a pace for your group | Instruction |
| `lobby.settings.preset_first_time` | First Time | Preset label |
| `lobby.settings.preset_casual` | Casual | Preset label |
| `lobby.settings.preset_experienced` | Experienced | Preset label |
| `lobby.settings.customize` | Customize | Expander label |
| `lobby.settings.custom_badge` | Custom | Badge when values diverge from preset |
| `lobby.settings.timer_discussion` | Discussion | Slider label |
| `lobby.settings.timer_voting` | Voting | Slider label |
| `lobby.settings.timer_night_action` | Night Action | Slider label |
| `lobby.settings.timer_complex_bonus` | Complex Role Bonus | Slider label |
| `lobby.settings.start_game` | Start Game | Primary CTA |
| `lobby.settings.start_disabled_players` | Need at least 3 players to start | Disabled reason |
| `lobby.settings.start_disabled_config` | Invalid role configuration | Disabled reason |

---

## Information Architecture

### Lobby Visibility

| Information | Tier | Visible To | Display |
|-------------|------|-----------|---------|
| Lobby code | 1 (Public) | All in lobby | Hero code display |
| Player list + names | 1 (Public) | All | Player list |
| Ready states | 1 (Public) | All | Per-row indicator |
| Who is host | 1 (Public) | All | Host badge + golden border |
| Player count | 1 (Public) | All | List header |
| Role configuration | 1 (Public) | All (view-only for non-host) | Roles in play shown on lobby. Only host can edit via S04. |
| Role selection controls | Host only | Host | S04 stepper controls |
| Timer configuration (preset + per-phase values) | Host only | Host | S04b preset selector + sliders |
| Start Game button | Host only | Host | S04b bottom |
| Validation errors | Host only | Host | S04 banners + lobby inline |

### Host vs Player

| Element | Player | Host |
|---------|--------|------|
| Lobby code | View + copy | View + copy |
| Player list | View | View + (future: kick player) |
| Ready toggle | Toggle own state | Not shown (host is implicitly ready) |
| Configure Roles | Not shown | Interactive button → S04 |
| Game Settings | Not shown | S04b: preset selector, timer sliders |
| Start Game | Not shown | Interactive CTA on S04b (disabled until valid) |

---

## Accessibility

### S03: Lobby

| Requirement | Implementation |
|-------------|---------------|
| Screen reader: lobby code | `Semantics(label: "Lobby code: {code spelled out letter by letter}. Double-tap to copy.")`. Spelled out because screen readers may not pronounce random character sequences intelligibly. |
| Screen reader: copy confirmation | "Lobby code copied to clipboard." via `liveRegion: assertive`. |
| Screen reader: player join | "{name} joined the village." via `liveRegion: polite`. |
| Screen reader: player leave | "{name} left the tavern." via `liveRegion: polite`. |
| Screen reader: player row | "[Name], [ready/waiting]. [Host indicator if applicable]." |
| Screen reader: ready toggle | "Ready toggle. Currently [ready/waiting]. Double-tap to change." On toggle: "You are now [ready/waiting]." |
| Screen reader: Start Game (host) | "Start Game. [Enabled/Disabled]. [Reason if disabled]." |
| Touch targets | Ready toggle: full row width, 64dp height. Lobby code: full card area. |
| Color-blind: ready state | "Ready" text in `AppColors.moonlitSage` + the word "Ready." "Waiting" in `AppColors.parchmentMuted` + the word "Waiting." Text carries meaning, not color alone. |
| Color-blind: host badge | ★ icon + "Host" text + gold border. Triple redundancy. |

### S04: Role Selection

| Requirement | Implementation |
|-------------|---------------|
| Screen reader: role row | "[Role name]. [Team] team. [Description]. Count: [N]. Minimum 0, maximum [max]. Use minus and plus buttons to adjust." |
| Screen reader: stepper buttons | Minus: "Decrease [role] count. Currently [N]." Plus: "Increase [role] count. Currently [N]." Disabled: "Maximum reached" or "Minimum reached." |
| Screen reader: Mason stepper | "Mason count. Currently [0 or 2]. Masons must be in pairs. Double-tap plus to add 2, minus to remove 2." |
| Screen reader: card counter | "Cards selected: [N] of [required]." Updated on each stepper change via `liveRegion: polite`. |
| Screen reader: validation | Validation banners announced via `liveRegion: assertive` when they appear. |
| Touch targets | Stepper +/- buttons: 48dp each. Role row tap area: full width, 64dp+ height. |
| Color-blind: validation | Banners use `AppColors.bloodEmber` left border + warning text. Not color-only — the text explains the error. |
| Color-blind: card counter | Valid: `AppColors.moonlitSage` + "✓". Invalid: `AppColors.bloodEmber` + count mismatch visible in numbers. |

### S04b: Game Settings

| Requirement | Implementation |
|-------------|---------------|
| Screen reader: page | `Semantics(label: "Game Settings. Choose a pace for your group.")` on page load. |
| Screen reader: preset cards | Each: `Semantics(label: "[Preset name]. [Selected/Not selected]. Double-tap to select.")`. On selection: "[Preset name] selected. Timer values updated." via `liveRegion: polite`. |
| Screen reader: customize expander | `Semantics(label: "Customize timers. [Collapsed/Expanded]. Double-tap to [expand/collapse].")` |
| Screen reader: sliders | Each: `Semantics(label: "[Timer name]. Currently [value]. Minimum [min], maximum [max]. Adjust with swipe.")`. On change: new value announced via `liveRegion: polite`. |
| Screen reader: custom badge | "Custom settings active. Values differ from [preset name] preset." announced via `liveRegion: polite` when badge appears. |
| Screen reader: Start Game | Same as S03 Start Game accessibility. `Semantics(label: "Start Game. [Enabled/Disabled]. [Reason if disabled].")` |
| Touch targets | Preset cards: full card area, minimum 48dp height. Slider track: full width, 48dp touch area. Expander: full width, 48dp height. |
| Color-blind: preset selection | Selected preset has `AppColors.tallowGold` border + `AppGlows.selection` glow + text reinforcement. Not color-only. |
| Color-blind: custom badge | "Custom" text label. Not color-only. |

---

## Open Questions

(none)
