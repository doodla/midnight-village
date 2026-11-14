# Day Phase

## Identity

| Field     | Value |
|-----------|-------|
| type      | screen |
| id        | S11, S12 |
| phase     | discussion, voting |
| route     | /game/:gameId |

This spec covers the Discussion screen (S11) and the Voting screen (S12). These two screens share a common principle: **the phone is a mood lamp and cheat sheet, not the center of attention.** During discussion, players talk face-to-face. During voting, the phone enables a private, fluid selection. In both cases the screen sets atmosphere and provides reference — it never demands focus.

---

## Layout

### S11: Discussion

```
┌─────────────────────────────────────┐
│  [phase bg: AppColors.phaseDiscussion]│
│  [AppParticles.embers + dust]       │
│                                     │
│                                     │
│              4:32                    │  <- AppTextStyles.timerDisplay
│                                     │     (56dp, Space Grotesk bold)
│                                     │     Color: timer ramp
│                                     │     (gold→amber→red→fast red)
│                                     │
│  ┌─────────────────────────────┐    │
│  │ [card back icon] Tap to     │    │  <- Role reminder
│  │ remember your role           │    │     Tap-to-reveal (P-REVEAL)
│  └─────────────────────────────┘    │     AppColors.surfaceInset
│                                     │     Dashed AppColors.outlineSubtle
│  ┌─────────────────────────────┐    │
│  │ [eye icon] Tap to recall    │    │  <- Night results reminder
│  │ what you learned             │    │     Tap-to-reveal (P-REVEAL)
│  └─────────────────────────────┘    │     Same treatment
│                                     │
│  ┌─────────────────────────────┐    │
│  │ ▸ Roles in play (8)        │    │  <- Collapsible list
│  └─────────────────────────────┘    │     AppColors.surface
│                                     │
│  ┌─────────────────────────────┐    │
│  │  End Discussion             │    │  <- HOST ONLY (P-HOST)
│  └─────────────────────────────┘    │     AppColors.bloodEmber bg
│                                     │     AppGlows.cta pulse
└─────────────────────────────────────┘
```

**Roles in play (expanded):**

```
┌─────────────────────────────────────┐
│ ▾ Roles in play (8)                │
│                                     │
│  Werewolf ×2    Seer               │  <- 2-column pill grid
│  Robber         Troublemaker        │     AppTextStyles.label
│  Drunk          Insomniac           │     AppColors.surface bg
│  Villager ×2                        │     AppRadius.sm (4dp) pills
│                                     │
└─────────────────────────────────────┘
```

**Tablet:** Timer enlarges. Content centered within `AppDimensions.maxContentWidth` (480dp). Additional breathing room above timer (`AppSpacing.xxxxxxl`, 80dp).

**Landscape:** Timer shifts to left half. Role reminder + roles list on right half.

### Night Results Card Variants

The second card in the discussion layout varies by role category:

**Standard (roles with night results):** Tap-to-reveal card showing night action results. Auto-hide: 3000ms.

**No-action roles (Villager, Hunter, Tanner):** The same tap-to-reveal card as every other role. Revealed text: "You slept through the night." Auto-hide: 3000ms. Every player sees an identical closed card, so the layout never reveals who had a night action.

**Doppelganger (multi-result):** Tap-to-reveal card showing both peek result and follow-up result stacked vertically with a subtle 1dp `AppColors.outlineSubtle` divider between them. Auto-hide: **5000ms** (extended from 3000ms to allow reading both results).

```
┌─────────────────────────────────────┐
│                                     │
│  You copied Bob: Robber             │  <- Result 1
│                                     │     AppTextStyles.body
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─       │  <- AppColors.outlineSubtle
│                                     │     1dp dashed divider
│  You stole Carol's card: Werewolf   │  <- Result 2
│                                     │     AppTextStyles.body
└─────────────────────────────────────┘
```

---

### S12: Voting — 4-Player Variant

```
┌─────────────────────────────────────┐
│  [phase bg: AppColors.phaseVoting]  │
│  [AppParticles.embers + dust + fog] │
│  [pressure overlay: 0-8% darken]    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ Vote for a player     2:15 │    │  <- Header: instruction + timer
│  └─────────────────────────────┘    │     AppTextStyles.timerCompact
│                                     │
│    ┌──────────┐   ┌──────────┐     │
│    │  [AVA]   │   │  [AVA]   │     │  <- 2-column player grid
│    │  Alice   │   │  Bob     │     │     AppDimensions.avatarMd (48dp)
│    │          │   │    ✓     │     │     ✓ = has voted (blind)
│    └──────────┘   └──────────┘     │     AppGlows.selection on
│    ┌──────────┐                     │     player's own selection
│    │  [AVA]   │                     │
│    │  Carol   │                     │  <- 3 other players
│    │          │                     │     (self excluded)
│    └──────────┘                     │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ [eye icon] Tap to see vote │    │  <- Own vote: tap-to-reveal
│  └─────────────────────────────┘    │     (P-REVEAL)
│                                     │
│  3/4 have chosen                    │  <- Vote counter
│                                     │     AppTextStyles.label
│                                     │     AppColors.parchmentMuted
│                                     │
│  ┌─────────────────────────────┐    │
│  │  End Voting                 │    │  <- HOST ONLY (P-HOST)
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

### S12: Voting — 12-Player Variant

```
┌─────────────────────────────────────┐
│  [phase bg + pressure overlay]      │
│  [particles intensifying]           │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ Vote for a player     1:48 │    │
│  └─────────────────────────────┘    │
│                                     │
│  ┌──────┐ ┌──────┐ ┌──────┐       │
│  │ AVA  │ │ AVA  │ │ AVA  │       │  <- 3-column grid
│  │ Name │ │ Name │ │ Name │       │     for 6+ players
│  │      │ │  ✓   │ │  ✓   │       │     Scrollable if >9
│  └──────┘ └──────┘ └──────┘       │
│  ┌──────┐ ┌──────┐ ┌──────┐       │
│  │ AVA  │ │ AVA  │ │ AVA  │       │
│  │ Name │ │ Name │ │ Name │       │
│  │  ✓   │ │      │ │  ✓   │       │
│  └──────┘ └──────┘ └──────┘       │
│  ┌──────┐ ┌──────┐ ┌──────┐       │
│  │ AVA  │ │ AVA  │ │ AVA  │       │
│  │ Name │ │ Name │ │ Name │       │
│  │  ✓   │ │      │ │  ✓   │       │
│  └──────┘ └──────┘ └──────┘       │
│  ┌──────┐ ┌──────┐                 │  <- 11 other players
│  │ AVA  │ │ AVA  │                 │
│  │ Name │ │ Name │                 │
│  │  ✓   │ │  ✓   │                 │
│  └──────┘ └──────┘                 │
│                                     │
│  ┌──────────────────────────┐      │
│  │ [eye] Tap to see vote    │      │
│  └──────────────────────────┘      │
│  9/12 have chosen                   │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  End Voting                 │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

**Grid scaling rules:** Same as night-actions.md player selection grid.

| Player Count (others) | Columns | Notes |
|-----------------------|---------|-------|
| 2-4 | 2 | Comfortable spacing |
| 5-9 | 3 | Standard grid |
| 10-19 | 4 | Compact grid, avatars shrink to `AppDimensions.avatarSm` (32dp) if needed |
| 20+ | 4, scrollable | Future Mafia support |

**Tablet:** Grid expands to 4 columns at 5+ players. Larger avatars. Content within `AppDimensions.maxContentWidth` (480dp).

---

## Preconditions

### S11: Discussion

- All night waves complete
- T-02 (Night -> Discussion) cinematic has completed
- NC-DAWN narrator cue has played
- Phase background is `AppColors.phaseDiscussion`
- `AppParticles.embers` and `AppParticles.dust` are active
- `Ambience.discussion` is playing
- Discussion timer is running (host-configured via S04b Game Settings; defaults: First Time 8 min, Casual 5 min, Experienced 3 min; range: 3-10 minutes)

### S12: Voting

- Discussion timer has expired OR host ended discussion early
- T-03 (Discussion -> Voting) transition has completed
- NC-VOTE-START narrator cue has played
- Phase background is `AppColors.phaseVoting`
- `AppParticles.embers`, `AppParticles.dust`, and `AppParticles.fog` are active
- `Ambience.voting` is playing
- Voting timer is running (host-configured via S04b Game Settings; defaults: First Time 90s, Casual 60s, Experienced 45s; range: 30-120 seconds)

---

## States

### S11: Discussion States

| State ID | Trigger | What the user sees | Audio/Haptic |
|----------|---------|-------------------|--------------|
| DISC-ACTIVE | T-02 complete | Hero timer counting down. Role reminder (tap-to-reveal, hidden). Night results reminder (tap-to-reveal, hidden). Roles in play (collapsed). Particles and atmosphere active. Hint H-04 may appear (first time) pointing to role reminder area. | `Ambience.discussion` playing |
| DISC-TIMER-NORMAL | Timer > 50% remaining | Timer in `AppColors.timerNormal` (Tallow Gold). Steady, no pulse. | None |
| DISC-TIMER-WARNING | Timer crosses 50% | Timer color crossfades to `AppColors.timerWarning` (Ember Amber) over 400ms (UI-18). | None |
| DISC-TIMER-URGENT | Timer crosses 25% | Timer color crossfades to `AppColors.timerUrgent` (Blood Ember). Slow pulse begins: 2s cycle, opacity 0.8-1.0 (UI-19). | None |
| DISC-TIMER-CRITICAL | Timer crosses 10% | Timer color crossfades to `AppColors.timerCritical` (Bloodmoon Red). Fast pulse: 0.8s cycle, opacity 0.7-1.0 (UI-20). | `SoundCues.timerWarning` (S-19, plays once at threshold) |
| DISC-NARRATOR-WARN | Timer crosses 25% (concurrent with DISC-TIMER-URGENT) | NC-DISC-WARN narrator cue fires (optional vocalization by persona). | `AppHaptics.narratorBeat` (H-11), narrator audio (if persona vocalizes) |
| DISC-ROLE-REVEALED | Player taps role reminder | Own role card content visible for 3s (UI-21 appear, UI-22 auto-hide). | None |
| DISC-RESULT-REVEALED | Player taps night results reminder | Night action results visible for 3s (UI-21 appear, UI-22 auto-hide). | None |
| DISC-ROLES-EXPANDED | Player taps "Roles in play" | Collapsible list expands showing all role names with counts. | `AppHaptics.tapLight` (H-01) |
| DISC-ROLES-COLLAPSED | Player taps expanded header | List collapses. | `AppHaptics.tapLight` (H-01) |
| DISC-HOST-ADVANCE | Host taps "End Discussion" | T-03 transition fires immediately. Timer stops. All players transition to voting. | `AppHaptics.tapMedium` (H-02), per T-03 timeline |
| DISC-TIMER-EXPIRED | Timer reaches 0:00 | T-03 transition fires. All players transition to voting. | Per T-03 timeline |
| DISC-DISCONNECT | Player disconnect detected | P-DISCONNECT overlay (T-09). Timer pauses. | `SoundCues.disconnect` (S-14), `AppHaptics.tapMedium` (H-02) |
| DISC-LOADING | Discussion data loading | Shimmer on timer area, placeholder for role reminder (P-LOADING). | None |

### S12: Voting States

| State ID | Trigger | What the user sees | Audio/Haptic |
|----------|---------|-------------------|--------------|
| VOTE-READY | T-03 complete | Player grid displayed. No selection yet. Timer counting down. Vote counter: "0/N have chosen." Hint H-05 may appear (first time). | `Ambience.voting` playing |
| VOTE-SELECTED | Player taps a target | Target gets `AppGlows.selection` glow (UI-04, 200ms). Checkmark appears on target. Own entry in vote counter increments. Tap-to-reveal "see your vote" area activates. | `AppHaptics.selectionClick` (H-04) |
| VOTE-CHANGED | Player taps different target | Previous glow removed (UI-05, 200ms). New glow applied (UI-04, 200ms). Checkmark moves. | `AppHaptics.selectionClick` (H-04) |
| VOTE-DESELECTED | Player taps current selection | Glow removed. Checkmark removed. Counter decrements. Tap-to-reveal deactivates. | `AppHaptics.selectionClick` (H-04) |
| VOTE-OTHER-VOTED | Server notifies another player voted | That player's card shows checkmark badge (no target info — blind). Vote counter increments. Counter pulses (UI-25, 200ms, `AppCurves.bounce`). | None |
| VOTE-OTHER-CHANGED | Server notifies another player changed vote | No visible change (they already had a checkmark). | None |
| VOTE-VOTE-REVEALED | Player taps "see your vote" | Own selected target name visible for 3s (UI-21 appear, UI-22 auto-hide). | None |
| VOTE-TIMER-NORMAL | Timer > 50% | Timer in `AppColors.timerNormal`. No pressure effects. | None |
| VOTE-TIMER-WARNING | Timer crosses 50% | Timer crossfades to `AppColors.timerWarning` (UI-18). | None |
| VOTE-TIMER-URGENT | Timer crosses 25% | Timer to `AppColors.timerUrgent`. Slow pulse (UI-19). | None |
| VOTE-TIMER-CRITICAL | Timer crosses 10% | Timer to `AppColors.timerCritical`. Fast pulse (UI-20). | `SoundCues.timerWarning` (S-19, once) |
| VOTE-PRESSURE-BUILDING | Final 30% of timer | Background darkens: overlay opacity 0.0->0.08 (UI-26, linear). Particle count +50%, speed +30% (UI-27, linear). | None |
| VOTE-ALL-IN | All players have submitted a vote | Vote counter shows "N/N have chosen." Host "End Voting" button gains emphasis. | None |
| VOTE-HOST-ADVANCE | Host taps "End Voting" | All current selections locked. T-04 transition fires. | `AppHaptics.tapMedium` (H-02), `SoundCues.votesLocked` (S-06) |
| VOTE-TIMER-EXPIRED | Timer reaches 0:00 | All current selections locked. Players without selection: vote skipped. T-04 transition fires. | `SoundCues.votesLocked` (S-06), `AppHaptics.confirmationPulse` (H-05) -- Note: H-05 intentionally replaces T-04's default H-02 for timer-expiry. The confirmation pulse signals "your vote was auto-submitted," which is more meaningful to the player than a generic phase-shift tap. Host-advance (VOTE-HOST-ADVANCE) uses H-02 per T-04 since the host initiated the action deliberately. |
| VOTE-DISCONNECT | Disconnect detected | P-DISCONNECT overlay (T-09). Timer pauses. Selections preserved. | `SoundCues.disconnect` (S-14), `AppHaptics.tapMedium` (H-02) |
| VOTE-LOADING | Voting data loading | Shimmer on grid area (P-LOADING). Timer placeholder. | None |

---

## Transitions

| From State | Condition | To (screen/state) | Animation |
|------------|-----------|-------------------|-----------|
| Night (any) | All waves complete | DISC-ACTIVE | T-02 cinematic (2500ms). NC-DAWN narrator. |
| DISC-ACTIVE | Timer expires | VOTE-READY | T-03 (2000ms). NC-VOTE-START narrator. |
| DISC-ACTIVE | Host taps "End Discussion" | VOTE-READY | T-03 (2000ms). NC-VOTE-START narrator. |
| VOTE-READY / any VOTE-* | Timer expires or host ends voting | Vote Reveal (S13) | T-04 (1200ms). All selections locked. |
| Any state | Disconnect detected | *-DISCONNECT | T-09 overlay (600ms in). |
| *-DISCONNECT | Reconnect | Previous state | T-09 dismiss (600ms out). Timer resumes. |

---

## Interactions

### S11: Discussion

| Element | Event | Result | Haptic | Sound |
|---------|-------|--------|--------|-------|
| Role reminder (hidden) | Tap | Own role revealed for 3s (UI-21/22). Only one reveal at a time — revealing role hides night results if visible. | None | None |
| Night results (hidden) | Tap | Night action results revealed for 3s (UI-21/22). Hides role if visible. | None | None |
| Role reminder / results (visible) | Tap | Hide immediately (UI-22). | None | None |
| "Roles in play" header | Tap | Toggle expand/collapse. Expanded list shows role names with counts in 2-column pill layout. | `AppHaptics.tapLight` (H-01) | None |
| Host "End Discussion" button | Tap | Fires T-03 transition. Button disables immediately to prevent double-tap. No confirmation dialog. | `AppHaptics.tapMedium` (H-02) | Per T-03 |
| Timer | — | Not interactive. Display only. | — | — |

**Failure paths:**

| Interaction | Failure | Result |
|-------------|---------|--------|
| Tap role reminder | No role data cached | Toast: "Something stirs in the darkness..." / "Failed to load role data." Retry on next tap. |
| Host "End Discussion" | Server rejects (already transitioning) | Button stays disabled. Transition proceeds from timer expiry. |

### S12: Voting

| Element | Event | Result | Haptic | Sound |
|---------|-------|--------|--------|-------|
| Player avatar (not selected) | Tap | Select as vote target. `AppGlows.selection` (UI-04). Own checkmark appears in other players' views. | `AppHaptics.selectionClick` (H-04) | None |
| Player avatar (already selected) | Tap | Deselect. Glow removed (UI-05). Own checkmark removed from other players' views. | `AppHaptics.selectionClick` (H-04) | None |
| Player avatar (other target selected) | Tap | Switch target. Previous glow removed, new glow applied. Checkmark moves in other players' views. | `AppHaptics.selectionClick` (H-04) | None |
| "Tap to see your vote" (hidden) | Tap | Own vote target name + avatar shown for 3s (UI-21/22). | None | None |
| Vote reveal (visible) | Tap | Hide immediately (UI-22). | None | None |
| Host "End Voting" button | Tap | Locks all current selections. Fires T-04. Button disables immediately. No confirmation. | `AppHaptics.tapMedium` (H-02) | `SoundCues.votesLocked` (S-06) |
| Hint H-05 | Tap (hint or target or elsewhere) | Dismiss permanently. | None | None |
| Hint H-06 | Tap | Dismiss permanently. | None | None |

**Failure paths:**

| Interaction | Failure | Result |
|-------------|---------|--------|
| Tap vote target | Self (impossible) | Self is never rendered in the voting grid. Cannot occur. |
| Tap vote target | Server offline | Selection stored client-side. Synced on reconnect. If voting ends before reconnect, client-side selection is final. |
| Tap vote target | Server rejects (invalid player) | Toast: P-ERR pattern. Selection reverts. |
| Host "End Voting" | Server rejects | Button re-enables. Player informed via toast. |

---

## Narrator Cues

| Trigger | Cue ID | Semantic Content | Screen Context | Haptic |
|---------|--------|-----------------|----------------|--------|
| T-02 cinematic (800ms offset) | NC-DAWN | "Everyone, wake up! Discuss." | Plays during night->discussion transition. Timer starts after transition completes. | `AppHaptics.narratorBeat` (H-11) |
| Discussion timer crosses 25% | NC-DISC-WARN | "Time is running out..." | Optional vocalization by narrator persona. Timer color ramp provides visual equivalent. | `AppHaptics.narratorBeat` (H-11) if vocalized |
| T-03 transition (400ms offset) | NC-VOTE-START | "Time to vote." | Plays during discussion->voting transition. Voting grid appears after transition. | `AppHaptics.narratorBeat` (H-11) |

---

## Errors

| Error | In-World Headline | Clear Subtitle | Recovery |
|-------|-------------------|----------------|----------|
| Player disconnect (discussion) | "A villager has wandered into the fog..." | {name} disconnected. Game paused. | P-DISCONNECT overlay. Discussion timer pauses. |
| Player disconnect (voting) | "A villager has wandered into the fog..." | {name} disconnected. Game paused. | P-DISCONNECT overlay. Voting timer pauses. Selections preserved. |
| Own connection lost | "The spirits are restless..." | Connection lost. Reconnecting... | P-DISCONNECT overlay (self). Client-side selection preserved. |
| Vote submission failed | "The spirits reject your offering..." | Vote could not be recorded. Try again. | Toast (P-ERR). Selection reverts to previous. Timer continues. |
| Role data load failure | "Something stirs in the darkness..." | Failed to load role data. | Toast. Tap-to-reveal shows "unavailable" instead of role. |
| Timer sync failure | (no visible error) | (silent recovery) | Client resyncs timer with server on next heartbeat. No user-facing error unless drift > 5s, then toast: "Resynchronizing..." |

---

## Animation

All animations reference `sound-and-motion.md` by ID.

### S11: Discussion

| Moment | Reference | Duration | Easing | What moves |
|--------|-----------|----------|--------|------------|
| Discussion UI appear | T-02 (2200ms offset) | 300ms | `AppCurves.enter` | Timer, reminders, roles list fade in |
| Timer color shift (each threshold) | UI-18 | 400ms | `AppCurves.standard` | Timer text color crossfades to next ramp color |
| Timer pulse (urgent) | UI-19 | 2000ms loop | Sinusoidal | Timer opacity 0.8-1.0 |
| Timer pulse (critical) | UI-20 | 800ms loop | Sinusoidal | Timer opacity 0.7-1.0 |
| Tap-to-reveal (show) | UI-21 | 200ms | `AppCurves.enter` | Hidden content opacity 0->1 |
| Tap-to-reveal (hide) | UI-22 | 200ms | `AppCurves.exit` | Visible content opacity 1->0 |
| Roles list expand | — | 300ms | `AppCurves.standard` | Height animates from 0 to content height. Content fades in. |
| Roles list collapse | — | 200ms | `AppCurves.exit` | Height animates to 0. Content fades out. |

### S12: Voting

| Moment | Reference | Duration | Easing | What moves |
|--------|-----------|----------|--------|------------|
| Voting UI appear | T-03 (1400ms offset) | 600ms | `AppCurves.enter` | Player cards stagger in at 50ms/card (UI-13) |
| Selection glow appear | UI-04 | 200ms | `AppCurves.standard` | `AppGlows.selection` on selected target |
| Selection glow remove | UI-05 | 200ms | `AppCurves.standard` | Glow fades from previous target |
| Checkmark appear (other player voted) | — | 200ms | `AppCurves.enter` | Checkmark badge fades in on player card |
| Vote counter increment | UI-25 | 200ms | `AppCurves.bounce` | Counter text scale 1.0->1.15->1.0 |
| Timer color shifts | UI-18 | 400ms | `AppCurves.standard` | Same as discussion |
| Timer pulses | UI-19/20 | 2000ms/800ms | Sinusoidal | Same as discussion |
| Pressure: background darken | UI-26 | Over final 30% of timer | Linear | Overlay opacity 0.0->0.08 |
| Pressure: particle intensify | UI-27 | Over final 30% of timer | Linear | Particle count ×1.5, speed ×1.3 |
| Vote lock (timer expires / host ends) | T-04 (0ms offset) | 300ms | `AppCurves.bounce` | Selection indicators pulse scale 1.0->1.1->1.0 |

**Reduced motion:**

| Element | Alternative |
|---------|------------|
| Timer pulse | Timer uses static color at the current ramp stage. No opacity animation. |
| Player card stagger | All cards appear simultaneously. No stagger. |
| Selection glow | Appears instantly. No 200ms animation. |
| Vote counter bounce | Counter updates instantly. No scale animation. |
| Pressure effects | Background darken still applies (static visual, not animated). Particle intensification skipped. |
| Vote lock pulse | No scale animation. Indicator changes to "locked" icon instantly. |

---

## Strings

### S11: Discussion

| Key | Default Text | Notes |
|-----|-------------|-------|
| `discussion.role_reminder` | Tap to remember your role | Tap-to-reveal placeholder |
| `discussion.night_results` | Tap to recall what you learned | Tap-to-reveal placeholder |
| `discussion.roles_header` | Roles in play ({count}) | Collapsible list header |
| `discussion.no_action_result` | You slept through the night. | Revealed text for no-action roles (Villager, Hunter, Tanner) |
| `discussion.host_end` | End Discussion | Host control button |

### S12: Voting

| Key | Default Text | Notes |
|-----|-------------|-------|
| `voting.instruction` | Vote for a player | Header instruction |
| `voting.vote_counter` | {count}/{total} have chosen | Vote submission counter |
| `voting.see_vote` | Tap to see your vote | Tap-to-reveal placeholder |
| `voting.no_selection` | You have not voted | Shown in tap-to-reveal when no selection |
| `voting.your_vote` | Your vote: {player} | Shown in tap-to-reveal with selection |
| `voting.host_end` | End Voting | Host control button |
| `voting.vote_skipped` | You did not vote | Results, if player timed out |
| `voting.locked` | Votes locked | Shown briefly at lock moment |

---

## Information Architecture

### S11: Discussion

| Information | Tier | Visible | Display |
|-------------|------|---------|---------|
| Discussion timer | 1 (Public) | All | Hero timer, center screen. Duration is host-configured (S04b). |
| Roles in play | 1 (Public) | All | Collapsible list |
| Own original role | 2 (Player-Scoped) | Self | Tap-to-reveal (P-REVEAL). 3s auto-hide. |
| Own night results | 2 (Player-Scoped) | Self | Tap-to-reveal. 3s auto-hide. |
| Other players' roles | 3 (Server-Only) | Nobody | Never available. |
| Other players' night results | 3 (Server-Only) | Nobody | Never available. |

**Phone-as-mood-lamp principle:** The discussion screen is intentionally sparse. The hero timer dominates. Reference info (role, results, roles list) is tucked away behind taps and collapses. The phone should recede while players talk face-to-face.

### S12: Voting

| Information | Tier | Visible | Display |
|-------------|------|---------|---------|
| Voting timer | 1 (Public) | All | Compact timer in header. Duration is host-configured (S04b). |
| Player list (who is in the game) | 1 (Public) | All | Player grid |
| Vote submission status (who has voted) | 1 (Public) | All | Checkmark badge per player + counter |
| Own vote target | 2 (Player-Scoped) | Self | Tap-to-reveal. Selection glow visible on own screen only. |
| Other players' vote targets | 3 (Server-Only) | Nobody | Never available until T-04 vote reveal. |
| Own role (for reference) | 2 (Player-Scoped) | Self | NOT displayed on voting screen (available on discussion screen). Players should have memorized their role. |

**Blind voting:** Other players see THAT you have voted (checkmark) but not WHO you voted for. The checkmark is a binary status indicator, not a directional indicator. It appears on the voter's card in the grid, not on the target's card.

### Host vs Player

| Element | Player | Host |
|---------|--------|------|
| Discussion timer | View only | View + "End Discussion" button (P-HOST) |
| Voting grid | Interactive (select/change) | Interactive + "End Voting" button (P-HOST) |
| Role reminder | Available | Available (host is a normal player for info) |
| Night results | Available | Available |

---

## Accessibility

### S11: Discussion

| Requirement | Implementation |
|-------------|---------------|
| Screen reader: timer | `Semantics(liveRegion: true)`. Announced at entry: "[minutes]:[seconds] remaining for discussion." Updates at 50% (`polite`), 25% (`assertive`, "Time is running low"), 10% (`assertive`). |
| Screen reader: role reminder | `Semantics(label: "Your role is hidden. Double-tap to reveal for 3 seconds.")`. On reveal: role name, team, description announced. |
| Screen reader: night results | `Semantics(label: "Night action result hidden. Double-tap to reveal for 3 seconds.")`. On reveal: result text announced. |
| Screen reader: roles list | `Semantics(label: "Roles in play, {count} roles. Double-tap to expand.")`. Expanded: each role announced. |
| Screen reader: host button | `Semantics(label: "End Discussion. Double-tap to start voting immediately.")`. |
| Reduced motion | Timer color changes are instant (no crossfade). No pulse animation. |
| Color-blind: timer ramp | Timer states distinguished by pulse behavior (none, slow 2s, fast 0.8s) in addition to color. Critical state also has `SoundCues.timerWarning` audio. |
| Touch targets | Role reminder and night results areas meet 48dp minimum. Roles list header meets 48dp. |

### S12: Voting

| Requirement | Implementation |
|-------------|---------------|
| Screen reader: grid | `Semantics(role: grid)`. Each cell: "[Player name], [voted/not yet voted]. Double-tap to vote for [name]." |
| Screen reader: selection | On vote: "Voted for [Player name]." announced via `liveRegion`. On change: "Changed vote to [Player name]." |
| Screen reader: deselection | "Vote removed." |
| Screen reader: vote counter | `Semantics(liveRegion: polite)`. "[count] of [total] have voted." Updated on each submission. |
| Screen reader: timer | Same threshold announcement pattern as discussion. |
| Screen reader: pressure effects | "Voting ends soon." announced at the 30% threshold when pressure effects begin. |
| Screen reader: vote lock | "Votes are locked." announced when voting ends. |
| Screen reader: own vote reveal | `Semantics(label: "Your vote is hidden. Double-tap to reveal for 3 seconds.")`. On reveal: "Your vote: [Player name]." |
| Minimum touch targets | Avatars at `AppDimensions.avatarMd` (48dp). At 10+ players (32dp visual), hit area padded to 48dp. |
| Color-blind: voted indicator | Checkmark icon (✓) is the voted indicator, not color. Unvoted players have no icon — it is presence/absence, not color difference. |
| Color-blind: selection glow | `AppGlows.selection` (gold glow) is paired with a visible ring border (1dp `AppColors.tallowGold`). Not glow alone. |
| Color-blind: pressure effects | Background darken is perceptible regardless of color vision. Particle intensification is atmospheric, not informational. |
| Dynamic text sizing | Player names truncate with ellipsis at 2× scale. Grid layout adapts row height. |

---

## Open Questions

(none)
