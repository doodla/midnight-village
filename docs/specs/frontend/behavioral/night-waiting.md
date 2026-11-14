# Night Waiting

## Identity

| Field     | Value |
|-----------|-------|
| type      | screen |
| id        | S09 |
| phase     | night |
| route     | /game/:gameId |

This spec defines the night waiting screen — what every player sees when they are not actively performing a night action. Its primary purpose is **concealment**: ensuring that an outside observer cannot determine which player is currently acting by looking at phone screens.

---

## Concealment Invariant

**Every visible state of the night waiting screen must be indistinguishable between a player who has a night action in the current wave and a player who does not. No visual, interactive, or timing difference may reveal whether the current player is active or waiting.**

This invariant is the single most important requirement of this screen. Every design decision below is evaluated against it. Violations of this invariant leak hidden information and compromise game integrity.

### How Concealment Is Enforced

| Mechanism | Detail |
|-----------|--------|
| Visual parity | Active players and waiting players see the same background, particles, wave indicator, and ambient elements. The action UI overlays the waiting screen for active players only — but to an observer, both screens show activity. |
| Interaction parity | Waiting players have fidget interactions (embers, smoke, candle) that produce visible screen activity, haptic feedback, and sound. An observer sees both active and waiting players tapping and interacting with their phones. |
| Audio parity | Narrator cues play for ALL roles in the game setup (concealment principle from `narrator-cues.md`). Fidget sounds on waiting screens provide ambient cover for action confirmation sounds. |
| Timing parity | Wave transitions (T-08, 800ms) play for ALL players simultaneously, not just the active player. All players see the wave dot advance at the same time. |

**Minimum wave duration guarantee:** The server enforces a minimum wave duration of **8 seconds** regardless of how quickly actions are submitted (see `night-actions.md` Concealment Invariant). This guarantees that no wave is short enough to reveal how quickly its actors submitted.

---

## Layout

### Primary Layout

```
┌─────────────────────────────────────┐
│  [phase bg: AppColors.phaseNight]   │
│  [AppGlows.candle center]           │
│  [AppParticles.embers + fog + dust] │
│                                     │
│                                     │
│   "The fire crackles softly..."     │  <- Resting text
│                                     │     AppTextStyles.flavor
│     Sit by the fire and wait.       │     AppColors.parchmentMuted
│                                     │     Static. Same on every phone.
│                                     │
│  ┌─────────────────────────────┐    │
│  │  FIDGET ZONE                │    │  <- Touch-responsive area
│  │  (embers, smoke, candle)    │    │     Full width, ~200dp tall
│  │                             │    │     Overlaps candle glow
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  Wave ● ● ○ ○   Timer 0:07 │    │  <- Wave progress + timer
│  └─────────────────────────────┘    │     AppColors.surface
│                                     │     AppRadius.md (8dp)
└─────────────────────────────────────┘
```

---

## Preconditions

- Game is in night phase
- Player has completed role reveal (S05-REVEALED hold complete)
- Player is NOT the active player for the current wave, OR player has no night action at all
- Phase background is `AppColors.phaseNight`
- `AppGlows.candle` is active
- `AppParticles.embers`, `AppParticles.fog`, and `AppParticles.dust` are active
- `Ambience.night` is playing

---

## States

| State ID | Trigger | What the user sees | Audio/Haptic |
|----------|---------|-------------------|--------------|
| WAIT-IDLE | Player enters waiting (after role reveal or after their wave action completes) | Resting text. Fidget zone active. Wave dots showing progress. Particles and candle glow ambient. | `Ambience.night` continues. No haptic. |
| WAIT-FIDGET-EMBER | Player taps in fidget zone | 5-8 ember particles burst from tap point (F-01). Scatter upward, fade over 800ms. | `AppHaptics.fidgetResponse` (H-13), `SoundCues.fidgetEmber` (S-17, 50% volume) |
| WAIT-FIDGET-SMOKE | Player drags across fidget zone | Smoke trail follows finger (F-02). Persists 1200ms after lift. Max 3 concurrent trails. | `AppHaptics.fidgetResponse` (H-13, on drag start), `SoundCues.fidgetSmoke` (S-18, 50% volume on lift) |
| WAIT-FIDGET-CANDLE | Player taps and holds on candle glow area | `AppGlows.candle` radius expands 15%, opacity +0.04 while held. Settles back over 600ms on release (F-03). | `AppHaptics.fidgetResponse` (H-13, on hold start). No sound. |
| WAIT-WAVE-TRANSITION | Server advances to next wave | Wave dot fills (UI-23, 300ms). Next dot activates with pulse (UI-24). T-08 transition plays (800ms). | `AppHaptics.narratorBeat` (H-11) when narrator cue fires. Narrator audio. |
| WAIT-TO-ACTION | Player's wave is called and player has an action | Resting text fades out (300ms, `AppCurves.exit`). Action UI fades in (500ms, `AppCurves.enter`). Per T-08 timeline. | `AppHaptics.narratorBeat` (H-11), narrator audio |
| WAIT-ACTION-RETURN | Player completes their action, more waves remain | Action UI fades out. Waiting screen resumes with updated wave dots. | None |
| WAIT-NIGHT-END | All waves complete | NC-DAWN narrator cue. T-02 cinematic transition (2500ms) to discussion phase. | `AppHaptics.phaseShift` (H-06), `AppHaptics.narratorBeat` (H-11), narrator audio, `Ambience.night` fades out |
| WAIT-DISCONNECT | Player disconnects (self or other) | P-DISCONNECT overlay (T-09). Screen freezes. | `SoundCues.disconnect` (S-14), `AppHaptics.tapMedium` (H-02) |
| WAIT-HINT | First time on waiting screen | Hint H-09 appears: "Touch the screen to play with the fire." Dismisses on tap. | None |

---

## Transitions

| From State | Condition | To (screen/state) | Animation |
|------------|-----------|-------------------|-----------|
| S05-TRANSITION (night-actions.md) | Role reveal complete, player has no immediate action | WAIT-IDLE | UI-01 crossfade (400ms) |
| Any CAT*-CLOSE (night-actions.md) | Player's wave action complete, more waves remain | WAIT-ACTION-RETURN | T-08 wave transition (800ms) |
| WAIT-IDLE / WAIT-ACTION-RETURN | Player's wave is called and player has action | WAIT-TO-ACTION | T-08 wave transition (800ms) |
| WAIT-IDLE / WAIT-ACTION-RETURN | All waves complete | WAIT-NIGHT-END | T-02 cinematic (2500ms) |
| Any WAIT-* | Disconnect detected | WAIT-DISCONNECT | T-09 overlay (600ms) |

---

## Interactions

| Element | Event | Result | Haptic | Sound |
|---------|-------|--------|--------|-------|
| Fidget zone | Tap | Ember burst from tap point (F-01). 5-8 particles scatter upward. | `AppHaptics.fidgetResponse` (H-13) | `SoundCues.fidgetEmber` (S-17, 50% vol) |
| Fidget zone | Drag | Smoke trail follows finger path (F-02). Persists 1200ms after lift. | `AppHaptics.fidgetResponse` (H-13, drag start) | `SoundCues.fidgetSmoke` (S-18, 50% vol, on lift) |
| Candle glow area | Long press | Candle glow expands (F-03). Settles on release. | `AppHaptics.fidgetResponse` (H-13, hold start) | None |
| Hint H-09 | Tap | Dismiss hint permanently. | None | None |
| Wave dots | — | Not interactive. Informational only. | — | — |
| Timer | — | Not interactive. Informational only. | — | — |

**Failure paths:**

| Interaction | Failure | Result |
|-------------|---------|--------|
| Fidget tap | Too many concurrent particles | Oldest particles dropped if >60 total (per `AppParticles` budget in design-tokens.md). No visible error. |
| Fidget drag | Max 3 smoke trails | 4th drag has no visual trail. Haptic still fires. |

---

## Wave Progress Indicator

### Layout

```
┌─────────────────────────────────────┐
│  ● ● ○ ○           0:07            │
│  W1 W2 W3 W4       timer           │
└─────────────────────────────────────┘
```

| Element | Style |
|---------|-------|
| Container | `AppColors.surface`, `AppRadius.md` (8dp), `AppShadows.card`, horizontal layout |
| Padding | `AppSpacing.md` (12dp) internal |
| Dots (left side) | Inline row, `AppSpacing.sm` (8dp) gap between dots |
| Timer (right side) | `AppTextStyles.timerCompact`, right-aligned |

### Dot States

| State | Visual | Animation |
|-------|--------|-----------|
| Completed | Filled circle, 8dp, `AppColors.tallowGold` at full opacity | UI-23: fill from 0.2 to 1.0 opacity over 300ms on completion |
| Active | Filled circle, 8dp, `AppColors.tallowGold` | UI-24: scale pulse 1.0->1.2->1.0, 2000ms cycle, sinusoidal |
| Upcoming | Outlined circle, 8dp, `AppColors.outline` | Static |

### Dot Count

The number of dots equals the number of active waves in the current game. Skipped waves (role not in game) are not shown. Examples:

| Roles in Game | Waves Active | Dot Count |
|---------------|-------------|-----------|
| WW, Seer, Robber | W2 (WW), W3 (Seer, Robber) | 2 dots |
| Doppelganger, WW, Minion, Mason, Seer, Robber, TM, Drunk, Insomniac | All 4 waves | 4 dots |
| WW, Villager, Villager | W2 (WW) only | 1 dot |

**Important:** Wave dots represent wave groups (W1, W2, W3, W4), NOT individual role calls within a wave. A single Wave 3 dot covers the entire Seer->Robber->TM->Drunk sequence. This prevents dot count from leaking information about how many roles are performing actions in a wave.

### Timer

| Property | Value |
|----------|-------|
| Display | `AppTextStyles.timerCompact` (Space Grotesk, 24dp, bold) |
| Content | Total remaining time for the current wave. Counts down. |
| Color | Static `AppColors.parchment`. No color ramp during night (color ramp reserved for discussion/voting timers per design-tokens.md). |
| Visibility | Always visible during night. Same timer visible on both waiting and action screens (timing parity). |

---

## Fidget Interactions

All fidget interactions are defined in `sound-and-motion.md` (F-01, F-02, F-03). This section specifies the screen-level integration.

### Fidget Zone

| Property | Value |
|----------|-------|
| Area | Full screen width, approximately bottom 55% of screen (below resting text, overlapping candle glow area) |
| Hit testing | Fidget zone receives all touch events on the screen outside the wave indicator. |
| Layer order | Fidget particles render above phase background and grain, below resting text and wave indicator. |
| Concurrency | All three fidget types can be active simultaneously. |

### F-01: Poke Embers

Per `sound-and-motion.md` F-01:

| Property | Value |
|----------|-------|
| Gesture | Tap anywhere in fidget zone |
| Response | 5-8 ember particles burst from tap point |
| Particle color | `AppColors.tallowGold` at opacity 0.3-0.6 |
| Particle physics | Upward scatter with gravity curve, faster than ambient embers (40-60 dp/s initial velocity) |
| Fade | 800ms from burst to invisible |
| Sound | `SoundCues.fidgetEmber` (S-17) at 50% of sound effect volume |
| Haptic | `AppHaptics.fidgetResponse` (H-13) |

### F-02: Swirl Smoke

Per `sound-and-motion.md` F-02:

| Property | Value |
|----------|-------|
| Gesture | Drag across fidget zone |
| Response | Smoke trail follows finger path |
| Trail color | `AppColors.parchment` at opacity 0.04-0.08 |
| Trail width | 30-50dp |
| Persistence | 1200ms after finger lifts, then dissipates with diffusion |
| Max concurrent | 3 trails. 4th drag produces no trail (haptic still fires). |
| Sound | `SoundCues.fidgetSmoke` (S-18) at 50% volume, fires on finger lift |
| Haptic | `AppHaptics.fidgetResponse` (H-13), fires on drag start |

### F-03: Candle Flame

Per `sound-and-motion.md` F-03:

| Property | Value |
|----------|-------|
| Gesture | Tap and hold on the candle glow center area (approximately center 30% of screen where `AppGlows.candle` is visible) |
| Response | `AppGlows.candle` radius expands by 15%, opacity increases by 0.04 |
| Hold behavior | Effect persists while finger is held down |
| Release | Glow settles back to normal over 600ms, `AppCurves.standard` |
| Sound | None |
| Haptic | `AppHaptics.fidgetResponse` (H-13), fires on hold start only |

---

## Narrator Cues

Narrator cues during the night play for ALL players simultaneously (concealment principle). The waiting screen does not display narrator text — the audio plays over the waiting screen.

| Trigger | What Waiting Players Experience | Reference |
|---------|-------------------------------|-----------|
| Any wake cue (NC-W1-WAKE through NC-W4-DOPPEL-INS-WAKE) | Hear narrator audio. Feel `AppHaptics.narratorBeat` (H-11). Wave dot may advance. No other visual change. | `narrator-cues.md` |
| Any close cue (NC-W1-CLOSE through NC-W4-DOPPEL-INS-CLOSE) | Hear narrator audio. Feel H-11. No visual change. | `narrator-cues.md` |
| NC-DAWN | Hear "Everyone, wake up! Discuss." Night waiting screen transitions out via T-02 cinematic. | `narrator-cues.md`, T-02 in `sound-and-motion.md` |

**Active player returning to waiting:** When a player completes their night action and returns to the waiting screen, the transition is T-08 (800ms). This is the same T-08 that all other players experience for the wave transition — maintaining timing parity.

---

## Errors

| Error | In-World Headline | Clear Subtitle | Recovery |
|-------|-------------------|----------------|----------|
| Player disconnect (self) | "The spirits are restless..." | Connection lost. Reconnecting... | P-DISCONNECT overlay (T-09). Waiting state preserved. |
| Player disconnect (other) | "A villager has wandered into the fog..." | {name} disconnected. Game paused. | P-DISCONNECT overlay. Screen frozen. Timer paused. |

---

## Animation

All animations reference `sound-and-motion.md` by ID.

| Moment | Reference | Duration | Easing | What moves |
|--------|-----------|----------|--------|------------|
| Ember burst (F-01) | F-01 | 800ms | Physics-based (gravity curve) | 5-8 particles scatter from tap point, drift upward, fade to 0. |
| Smoke trail (F-02) | F-02 | 1200ms after release | Diffusion | Trail follows finger, persists, then dissipates. |
| Candle expand (F-03) | F-03 | Hold + 600ms settle | `AppCurves.standard` (settle) | `AppGlows.candle` radius +15%, opacity +0.04 while held, settles on release. |
| Wave dot fill | UI-23 | 300ms | `AppCurves.standard` | Dot opacity 0.2 -> 1.0 |
| Wave dot active pulse | UI-24 | 2000ms loop | Sinusoidal | Active dot scale 1.0 -> 1.2 -> 1.0 |
| Wave transition | T-08 | 800ms total | `AppCurves.exit` / `AppCurves.enter` | Resting text dims (300ms), dot update (300ms), resting text restores (500ms at 300ms offset) |

**Reduced motion:**

| Element | Alternative |
|---------|------------|
| Fidget embers (F-01) | 8-12 static ember dots at fixed positions, mid-opacity (0.25). No burst animation. Dots refresh on tap. |
| Fidget smoke (F-02) | Skip entirely — too subtle static. |
| Fidget candle (F-03) | Glow change is instant (no settle animation). |
| Wave dot pulse | Static filled dot, no pulse. |
| Wave transition | Instant swap. |

---

## Strings

| Key | Default Text | Notes |
|-----|-------------|-------|
| `waiting.rest_headline` | "The fire crackles softly..." | Resting flavor text |
| `waiting.rest_subtitle` | Sit by the fire and wait. | Resting clear text |
| `waiting.hint_fidget` | Touch the screen to play with the fire | Onboarding hint H-09 |
| `waiting.wave_label` | Wave {current} of {total} | Accessibility: wave progress |
| `waiting.timer_label` | {time} remaining | Accessibility: timer |

---

## Information Architecture

### What the Waiting Player Sees

| Information | Tier | Source | Display |
|-------------|------|--------|---------|
| Wave progress | 1 (Public) | Server broadcast | Dot indicator — same for all players |
| Wave timer | 1 (Public) | Server broadcast | Timer — same value for all players |
| Fidget interaction results | N/A (not game-relevant) | Client-side only | Particle effects — no server involvement |
| Own prior night results | 2 (Player-Scoped) | Cached client-side from earlier waves | NOT displayed on waiting screen. Available via tap-to-reveal in discussion/voting. |

### What the Waiting Player Does NOT See

| Hidden Information | Why |
|-------------------|-----|
| Which player is currently acting | Concealment invariant. No visual, timing, or audio difference reveals the active player. |
| What action the active player is performing | Concealment invariant. |
| When the active player submits their action | A wave advances when all expected actions are in or the timer expires, but never before the 8-second minimum (see `night-actions.md` wave timing floor). |
| How many actions are expected in the current wave | Wave dots represent wave groups, not individual roles. A 4-role Wave 3 has the same 1 dot as a 1-role Wave 2. |

### Concealment Verification Checklist

This checklist must pass for every change to this screen:

- [ ] A player performing a night action and a player waiting see the same wave indicator state.
- [ ] A player performing a night action and a player waiting hear the same narrator cues at the same time.
- [ ] A player performing a night action returns to the waiting screen via T-08, which is the same transition all players see for wave advancement.
- [ ] Fidget sounds play at comparable volume and frequency to night action confirmation sounds, providing ambient audio cover. An observer hearing a nearby phone cannot reliably determine whether a sound was a game action or a fidget interaction.
- [ ] The wave timer counts down at the same rate for all players.
- [ ] The wave dot count does not reveal the number of roles with actions in a wave.
- [ ] No loading state, error state, or empty state appears only for active or only for waiting players.

---

## Accessibility

### Screen Reader Support

| Element | Semantic Label | Notes |
|---------|---------------|-------|
| Waiting screen (container) | "Night phase. Waiting for your turn. Wave {current} of {total}." | Announced on entry and wave change (`liveRegion: assertive`). |
| Fidget zone | "Night waiting area. Tap to poke embers. Drag to swirl smoke. Press and hold the center to brighten the candle." | Accessible label on fidget zone. Actions produce haptic and audio feedback. |
| Wave dots | "Night wave {current} of {total} in progress." | Updated on wave change. |
| Timer | "{seconds} seconds remaining in this wave." | Announced at 50% (`polite`), 25% and 10% (`assertive`) thresholds. |

### Fidget Accessibility

Screen reader users cannot see visual fidget effects, but they can **tap the fidget zone** to trigger `AppHaptics.fidgetResponse` + `SoundCues.fidgetEmber`. The haptic/audio IS the fidget.

The concealment invariant for screen reader users is maintained through consistent haptic/audio presence — all phones produce occasional sounds and haptics regardless of night action status.

### Reduced Motion

All reduced motion alternatives are listed in the Animation section above. Key principle: fidget interactions still produce haptic feedback in reduced motion mode. The visual effect is simplified but the tactile response is unchanged.

### Color-Blind Safety

| Element | Color Signal | Redundant Signal |
|---------|-------------|-----------------|
| Wave dots (active) | `AppColors.tallowGold` | Scale pulse animation (UI-24) |
| Wave dots (completed) | `AppColors.tallowGold` filled | Filled vs outlined shape |

### General

| Requirement | Implementation |
|-------------|---------------|
| Dynamic text sizing | Resting text supports up to 200% text scale. Fidget zone shrinks proportionally. |
| Contrast | All text meets contrast requirements per design-tokens.md. |

---

## Open Questions

(none)
