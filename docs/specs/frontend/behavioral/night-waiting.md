# Night Waiting

## Identity

| Field     | Value |
|-----------|-------|
| type      | screen |
| id        | S09 |
| phase     | night |
| route     | /game/:gameId |

This spec defines the night waiting engagement layer — the screen every player sees when they are not actively performing a night action. Its primary purpose is **concealment**: ensuring that an outside observer cannot determine which player is currently acting by looking at phone screens.

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
| Content parity | The waiting screen has rotating content (trivia, lore) that changes at intervals, giving the screen the appearance of dynamic activity even without player interaction. |

**Minimum wave duration guarantee:** The server enforces a minimum wave duration of **8 seconds** regardless of how quickly actions are submitted (see `night-actions.md` Concealment Invariant). This guarantees that waiting content has at least 8 seconds per wave to resolve, ensuring at least one complete content cycle (5 seconds) per wave with margin.

---

## Layout

### Primary Layout

```
┌─────────────────────────────────────┐
│  [phase bg: AppColors.phaseNight]   │
│  [AppGlows.candle center]           │
│  [AppParticles.embers + fog + dust] │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  CONTENT AREA               │    │
│  │                             │    │
│  │  [Trivia / Lore / Quiz]    │    │  <- Rotating content
│  │                             │    │     AppColors.surface
│  │                             │    │     AppRadius.lg (12dp)
│  │                             │    │     AppShadows.card
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  FIDGET ZONE                │    │  <- Touch-responsive area
│  │  (embers, smoke, candle)    │    │     Full width, ~200dp tall
│  │                             │    │     Overlaps candle glow
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  Wave ● ● ○ ○   Timer 0:42 │    │  <- Wave progress + timer
│  └─────────────────────────────┘    │     AppColors.surface
│                                     │     AppRadius.md (8dp)
└─────────────────────────────────────┘
```

### Content Card Variants

**Trivia / Medieval Fact:**

```
┌─────────────────────────────────────┐
│                                     │
│  "Did you know?"                    │  <- AppTextStyles.label
│                                     │     AppColors.parchmentMuted
│  Medieval villages elected a        │
│  "reeve" to manage communal         │  <- AppTextStyles.body
│  land and settle disputes.          │     AppColors.parchment
│                                     │
└─────────────────────────────────────┘
```

**Live Quiz:**

```
┌─────────────────────────────────────┐
│                                     │
│  "Village Trivia"                   │  <- AppTextStyles.heading3
│                                     │
│  Which role sees other players      │  <- AppTextStyles.body
│  of the same role at night?         │
│                                     │
│  ┌───────────────────────────┐      │
│  │  A) Seer                  │      │  <- Answer option
│  └───────────────────────────┘      │     AppColors.surfaceInset
│  ┌───────────────────────────┐      │     AppRadius.md (8dp)
│  │  B) Mason                 │      │     AppSpacing.sm (8dp) gap
│  └───────────────────────────┘      │
│  ┌───────────────────────────┐      │
│  │  C) Robber                │      │
│  └───────────────────────────┘      │
│  ┌───────────────────────────┐      │
│  │  D) Drunk                 │      │
│  └───────────────────────────┘      │
│                                     │
└─────────────────────────────────────┘
```

**Quiz — Answer Revealed:**

```
┌─────────────────────────────────────┐
│                                     │
│  "Village Trivia"                   │
│                                     │
│  Which role sees other players      │
│  of the same role at night?         │
│                                     │
│  ┌───────────────────────────┐      │
│  │  A) Seer                  │      │  <- Unselected, dimmed
│  └───────────────────────────┘      │
│  ┌───────────────────────────┐      │
│  │  B) Mason              ✓ │      │  <- Correct: AppColors.moonlitSage
│  └───────────────────────────┘      │     border + checkmark
│  ┌───────────────────────────┐      │
│  │  C) Robber                │      │
│  └───────────────────────────┘      │
│  ┌───────────────────────────┐      │
│  │  D) Drunk              ✗ │      │  <- Player chose wrong:
│  └───────────────────────────┘      │     AppColors.bloodEmber border
│                                     │
│  "Masons see each other!"           │  <- AppTextStyles.flavorSmall
│                                     │     AppColors.parchmentMuted
└─────────────────────────────────────┘
```

**Tablet:** Content card width capped at `AppDimensions.maxContentWidth` (480dp), centered. Fidget zone extends full screen width. Additional breathing room (`AppSpacing.xxxl`, 40dp) above content card.

**Landscape:** Content card shifts to left half. Fidget zone fills right half. Wave indicator spans full width at bottom.

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
| WAIT-IDLE | Player enters waiting (after role reveal or after their wave action completes) | Content card showing trivia/lore. Fidget zone active. Wave dots showing progress. Particles and candle glow ambient. | `Ambience.night` continues. No haptic. |
| WAIT-CONTENT-ROTATE | Content rotation timer fires (5s) | Current content card crossfades (UI-01, 400ms) to next content item. | None |
| WAIT-QUIZ-ACTIVE | Quiz content loads | Quiz question with 4 answer options displayed. Options are tappable. | None |
| WAIT-QUIZ-ANSWERED | Player taps an answer | Selected answer highlighted. Correct answer revealed with `AppColors.moonlitSage` border. Wrong answer (if selected) marked with `AppColors.bloodEmber` border. Explanation text appears. | `AppHaptics.tapLight` (H-01) |
| WAIT-QUIZ-TIMEOUT | Quiz auto-rotates before player answers | Quiz replaced by next content item (crossfade, UI-01, 400ms). No penalty. | None |
| WAIT-FIDGET-EMBER | Player taps in fidget zone | 5-8 ember particles burst from tap point (F-01). Scatter upward, fade over 800ms. | `AppHaptics.fidgetResponse` (H-13), `SoundCues.fidgetEmber` (S-17, 50% volume) |
| WAIT-FIDGET-SMOKE | Player drags across fidget zone | Smoke trail follows finger (F-02). Persists 1200ms after lift. Max 3 concurrent trails. | `AppHaptics.fidgetResponse` (H-13, on drag start), `SoundCues.fidgetSmoke` (S-18, 50% volume on lift) |
| WAIT-FIDGET-CANDLE | Player taps and holds on candle glow area | `AppGlows.candle` radius expands 15%, opacity +0.04 while held. Settles back over 600ms on release (F-03). | `AppHaptics.fidgetResponse` (H-13, on hold start). No sound. |
| WAIT-WAVE-TRANSITION | Server advances to next wave | Wave dot fills (UI-23, 300ms). Next dot activates with pulse (UI-24). Content crossfade to new wave context. T-08 transition plays (800ms). | `AppHaptics.narratorBeat` (H-11) when narrator cue fires. Narrator audio. |
| WAIT-TO-ACTION | Player's wave is called and player has an action | Waiting content fades out (300ms, `AppCurves.exit`). Action UI fades in (500ms, `AppCurves.enter`). Per T-08 timeline. | `AppHaptics.narratorBeat` (H-11), narrator audio |
| WAIT-ACTION-RETURN | Player completes their action, more waves remain | Action UI fades out. Waiting screen resumes with updated wave dots. Content picks up where it left off. | None |
| WAIT-NIGHT-END | All waves complete | NC-DAWN narrator cue. T-02 cinematic transition (2500ms) to discussion phase. | `AppHaptics.phaseShift` (H-06), `AppHaptics.narratorBeat` (H-11), narrator audio, `Ambience.night` fades out |
| WAIT-DISCONNECT | Player disconnects (self or other) | P-DISCONNECT overlay (T-09). All content freezes. | `SoundCues.disconnect` (S-14), `AppHaptics.tapMedium` (H-02) |
| WAIT-LOADING | Content data not yet loaded from server | Shimmer placeholder in content card area (UI-12). Fidget zone still active. Wave dots still visible. | None |
| WAIT-EMPTY | Server has no content to serve (edge case) | Empty state: "The fire crackles softly..." / "Sit by the fire and wait." + candle icon (P-EMPTY pattern). Fidget zone still active. | None |
| WAIT-HINT | First time on waiting screen | Hint H-09 appears: "Touch the screen to play with the fire." Dismisses on tap. | None |

---

## Transitions

| From State | Condition | To (screen/state) | Animation |
|------------|-----------|-------------------|-----------|
| S05-TRANSITION (night-actions.md) | Role reveal complete, player has no immediate action | WAIT-IDLE | UI-01 crossfade (400ms) |
| Any CAT*-CLOSE (night-actions.md) | Player's wave action complete, more waves remain | WAIT-ACTION-RETURN | T-08 wave transition (800ms) |
| WAIT-IDLE / WAIT-ACTION-RETURN | Player's wave is called and player has action | WAIT-TO-ACTION | T-08 wave transition (800ms) |
| WAIT-IDLE / WAIT-ACTION-RETURN | All waves complete | WAIT-NIGHT-END | T-02 cinematic (2500ms) |
| WAIT-CONTENT-ROTATE | 5s content timer | WAIT-IDLE (with new content) | UI-01 crossfade (400ms) |
| WAIT-QUIZ-ANSWERED | 5s after answer reveal | WAIT-CONTENT-ROTATE | UI-01 crossfade to next content |
| Any WAIT-* | Disconnect detected | WAIT-DISCONNECT | T-09 overlay (600ms) |

---

## Interactions

| Element | Event | Result | Haptic | Sound |
|---------|-------|--------|--------|-------|
| Fidget zone | Tap | Ember burst from tap point (F-01). 5-8 particles scatter upward. | `AppHaptics.fidgetResponse` (H-13) | `SoundCues.fidgetEmber` (S-17, 50% vol) |
| Fidget zone | Drag | Smoke trail follows finger path (F-02). Persists 1200ms after lift. | `AppHaptics.fidgetResponse` (H-13, drag start) | `SoundCues.fidgetSmoke` (S-18, 50% vol, on lift) |
| Candle glow area | Long press | Candle glow expands (F-03). Settles on release. | `AppHaptics.fidgetResponse` (H-13, hold start) | None |
| Quiz answer option | Tap | Option selected. Correct answer highlighted green (`AppColors.moonlitSage` 1dp border). Wrong selection highlighted red (`AppColors.bloodEmber` 1dp border). Explanation appears. Unselected wrong answers dim to `AppOpacity.disabled` (0.38). | `AppHaptics.tapLight` (H-01) | None |
| Content card | Swipe left/right | Manually advance to next/previous content item. Resets 5s rotation timer. | None | None |
| Hint H-09 | Tap | Dismiss hint permanently. | None | None |
| Wave dots | — | Not interactive. Informational only. | — | — |
| Timer | — | Not interactive. Informational only. | — | — |

**Failure paths:**

| Interaction | Failure | Result |
|-------------|---------|--------|
| Fidget tap | Too many concurrent particles | Oldest particles dropped if >60 total (per `AppParticles` budget in design-tokens.md). No visible error. |
| Fidget drag | Max 3 smoke trails | 4th drag has no visual trail. Haptic still fires. |
| Quiz answer | Server doesn't validate answer | Quiz answers are validated client-side (decorative, not game-relevant). No server round-trip needed. |
| Content rotation | No new content from server | Repeat previous content pool in shuffled order. Show `WAIT-EMPTY` only if pool is completely empty. |

---

## Content System

### Content Resolution Constraint

**All waiting content MUST resolve within 5 seconds.** This ensures every player sees at least one complete content cycle per wave, given the 8-second minimum wave duration floor (see `night-actions.md` Concealment Invariant).

| Content Type | Resolution Requirement |
|-------------|----------------------|
| Trivia / facts / lore | Content cards rotate every 5 seconds maximum. |
| Quiz questions | 5-second answer window. Auto-rotates if unanswered. |
| Mini-games (future) | Must have a natural completion or checkpoint within 5 seconds. |
| Fidget interactions | Resolve immediately (no change needed). |

### Content Types

| Type | Source | Rotation | Interactive | Concealment Impact |
|------|--------|----------|-------------|-------------------|
| Medieval fact | Server-provided library | 5s auto-rotate | Read only | Low — passive reading |
| Lore snippet | Server-provided library | 5s auto-rotate | Read only | Low — passive reading |
| Village rumor | Server-generated, contextual | 5s auto-rotate | Read only | Medium — contextual flavor |
| Live quiz | Server-provided question bank | 5s per question | Tap to answer | High — active engagement |
| Mini-game | Future extension slot | Session-based | Full interaction | High — active engagement |

### Content Delivery Model

| Property | Value |
|----------|-------|
| Source | Server pushes content pool at game start. Client rotates locally. |
| Pool size | Minimum 48 items per game (enough for ~4 minutes of night at 5s rotation). |
| Composition | 60% facts/lore, 30% quiz, 10% rumors. Server determines mix. |
| Deduplication | Client tracks shown items. No repeat within the same night phase. After pool exhaustion, reshuffle. |
| Fallback | If server fails to deliver content pool, client uses a hardcoded fallback set of 10 medieval facts. |
| Future: AI-generated | Server can generate contextual content via AI (lore that references roles in play, village rumors about player names). This is a progressive enhancement, not a v1 requirement. |

### Content Card Visual Treatment

| Property | Value |
|----------|-------|
| Background | `AppColors.surface` |
| Border | 1dp `AppColors.outline` |
| Corner radius | `AppRadius.lg` (12dp) |
| Shadow | `AppShadows.card` |
| Padding | `AppSpacing.base` (16dp) |
| Category label | `AppTextStyles.label`, `AppColors.parchmentMuted` — "Did you know?", "Village Trivia", "Village Rumor" |
| Content text | `AppTextStyles.body`, `AppColors.parchment` |
| Flavor text | `AppTextStyles.flavorSmall`, `AppColors.parchmentMuted` — explanations, context |

### Quiz Mechanics

| Property | Value |
|----------|-------|
| Question format | Multiple choice, 4 options |
| Answer validation | Client-side only. Not game-relevant. No score tracked. |
| Correct answer highlight | `AppColors.moonlitSage` 1dp border on correct option. Checkmark icon. |
| Wrong answer highlight | `AppColors.bloodEmber` 1dp border on player's wrong selection. X icon. Correct answer also highlighted green. |
| Unselected options | Dim to `AppOpacity.disabled` (0.38) after answer reveal. |
| Explanation | Brief text below options in `AppTextStyles.flavorSmall`. Appears with `AppDurations.fast` (200ms) fade-in. |
| Auto-advance | 5s after answer reveal, auto-rotate to next content. |
| Timeout | If player doesn't answer within 5s, auto-rotate. No penalty. |
| Content | ONUW game knowledge (roles, mechanics), medieval history, logic puzzles. NOT related to the current game state (no leaking hidden info). |

### Shared Content System

The content system (trivia, quiz, lore, mini-games) is a **shared component** used in multiple contexts:

| Context | Content Pool | Rotation Interval | Duration Window | Notes |
|---------|-------------|-------------------|-----------------|-------|
| Night waiting | Standard pool (facts, lore, quiz) | 5s per item | 8s minimum wave duration | Primary use. All content must resolve within 5 seconds. |
| Host disconnect | Extended pool (longer quizzes, multiplayer mini-games) | 10-15s per item | Up to 5 minutes | Longer-form content suitable for extended waiting. Multiplayer rounds encouraged. |
| Discussion (no-action roles) | Standard pool (facts, lore) | 5s per item | Discussion timer duration | Read-only content cards for Villager, Hunter, Tanner. No quiz interaction during discussion. |

**Shared constraints (all contexts):**
- Content must not reveal game state or hidden information
- Content must feel native to the Firelit Gothic aesthetic
- Content source: server-provided pool, client-side rotation
- Fallback: hardcoded set of 10 medieval facts if server pool unavailable

**Mini-game slot (future extension):**

| Property | Value |
|----------|-------|
| Purpose | Reserved for multiplayer mini-games, particularly in the host-disconnect context where players have up to 5 minutes |
| V1 behavior | Quiz-only. No multiplayer mini-games. Slot is reserved but not rendered. |
| Design constraints | Must not require server round-trips for game logic (latency budget). Must be completable in segments (interruptible when host reconnects — current round finishes, then stops). Must not reveal player identity or night action status. Must work at any player count. |
| Integration point | Content type `mini-game` in the content delivery model. Client renders a dedicated mini-game widget when this type is received. |

---

## Wave Progress Indicator

### Layout

```
┌─────────────────────────────────────┐
│  ● ● ○ ○           0:42            │
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
| Area | Full screen width, approximately bottom 55% of screen (below content card, overlapping candle glow area) |
| Hit testing | Fidget zone receives all touch events not consumed by content card interactions (quiz answers, content swipe). |
| Layer order | Fidget particles render above phase background and grain, below content card and wave indicator. |
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

Narrator cues during the night play for ALL players simultaneously (concealment principle). The waiting screen does not display narrator text — the audio plays over the waiting screen while the content continues to display.

| Trigger | What Waiting Players Experience | Reference |
|---------|-------------------------------|-----------|
| Any wake cue (NC-W1-WAKE through NC-W4-DOPPEL-INS-WAKE) | Hear narrator audio. Feel `AppHaptics.narratorBeat` (H-11). Wave dot may advance. No visual change to waiting content. | `narrator-cues.md` |
| Any close cue (NC-W1-CLOSE through NC-W4-DOPPEL-INS-CLOSE) | Hear narrator audio. Feel H-11. No visual change. | `narrator-cues.md` |
| NC-DAWN | Hear "Everyone, wake up! Discuss." Night waiting screen transitions out via T-02 cinematic. | `narrator-cues.md`, T-02 in `sound-and-motion.md` |

**Active player returning to waiting:** When a player completes their night action and returns to the waiting screen, the transition is T-08 (800ms). This is the same T-08 that all other players experience for the wave transition — maintaining timing parity.

---

## Errors

| Error | In-World Headline | Clear Subtitle | Recovery |
|-------|-------------------|----------------|----------|
| Content pool empty | "The fire crackles softly..." | Sit by the fire and wait. | P-EMPTY pattern. Fidget zone still active. Client requests content refresh from server. |
| Content load failure | (no error shown) | (silent fallback) | Client uses hardcoded fallback set of 10 medieval facts. No user-facing error. |
| Player disconnect (self) | "The spirits are restless..." | Connection lost. Reconnecting... | P-DISCONNECT overlay (T-09). Waiting state preserved. |
| Player disconnect (other) | "A villager has wandered into the fog..." | {name} disconnected. Game paused. | P-DISCONNECT overlay. All content frozen. Timer paused. |
| Quiz answer after rotation | (no error) | (silently ignored) | If quiz auto-rotates before tap registers, tap is ignored. No ghost interaction. |

---

## Animation

All animations reference `sound-and-motion.md` by ID.

| Moment | Reference | Duration | Easing | What moves |
|--------|-----------|----------|--------|------------|
| Content card crossfade | UI-01 | 400ms | `AppCurves.standard` | Old content fades out, new content fades in. Simultaneous cross-dissolve within the card. |
| Quiz answer highlight | — | 200ms | `AppCurves.standard` | Correct: border color transitions to `AppColors.moonlitSage`. Wrong: border to `AppColors.bloodEmber`. Unselected: opacity to 0.38. |
| Quiz explanation appear | — | 200ms | `AppCurves.enter` | Explanation text fades in below options. |
| Ember burst (F-01) | F-01 | 800ms | Physics-based (gravity curve) | 5-8 particles scatter from tap point, drift upward, fade to 0. |
| Smoke trail (F-02) | F-02 | 1200ms after release | Diffusion | Trail follows finger, persists, then dissipates. |
| Candle expand (F-03) | F-03 | Hold + 600ms settle | `AppCurves.standard` (settle) | `AppGlows.candle` radius +15%, opacity +0.04 while held, settles on release. |
| Wave dot fill | UI-23 | 300ms | `AppCurves.standard` | Dot opacity 0.2 -> 1.0 |
| Wave dot active pulse | UI-24 | 2000ms loop | Sinusoidal | Active dot scale 1.0 -> 1.2 -> 1.0 |
| Wave transition | T-08 | 800ms total | `AppCurves.exit` / `AppCurves.enter` | Current content out (300ms), dot update (300ms), new content in (500ms at 300ms offset) |
| Content swipe | — | 300ms | `AppCurves.standard` | Card content slides horizontally in swipe direction. New content slides in from opposite side. |

**Reduced motion:**

| Element | Alternative |
|---------|------------|
| Content crossfade | Instant swap (no crossfade) |
| Fidget embers (F-01) | 8-12 static ember dots at fixed positions, mid-opacity (0.25). No burst animation. Dots refresh on tap. |
| Fidget smoke (F-02) | Skip entirely — too subtle static. |
| Fidget candle (F-03) | Glow change is instant (no settle animation). |
| Wave dot pulse | Static filled dot, no pulse. |
| Wave transition | Instant swap. |

---

## Strings

| Key | Default Text | Notes |
|-----|-------------|-------|
| `waiting.fact_label` | Did you know? | Category label for medieval facts |
| `waiting.lore_label` | Village Lore | Category label for lore snippets |
| `waiting.rumor_label` | Village Rumor | Category label for contextual rumors |
| `waiting.quiz_label` | Village Trivia | Category label for quiz questions |
| `waiting.quiz_correct` | Correct! | Shown when player selects right answer |
| `waiting.quiz_wrong` | Not quite. | Shown when player selects wrong answer |
| `waiting.empty_headline` | "The fire crackles softly..." | Empty state flavor text |
| `waiting.empty_subtitle` | Sit by the fire and wait. | Empty state clear text |
| `waiting.hint_fidget` | Touch the screen to play with the fire | Onboarding hint H-09 |
| `waiting.wave_label` | Wave {current} of {total} | Accessibility: wave progress |
| `waiting.timer_label` | {time} remaining | Accessibility: timer |
| `waiting.content_swipe_hint` | Swipe for more | Shown briefly on first content card (then hidden) |

---

## Information Architecture

### What the Waiting Player Sees

| Information | Tier | Source | Display |
|-------------|------|--------|---------|
| Wave progress | 1 (Public) | Server broadcast | Dot indicator — same for all players |
| Wave timer | 1 (Public) | Server broadcast | Timer — same value for all players |
| Trivia / lore / quiz content | N/A (not game-relevant) | Server content pool | Content card — NOT derived from game state |
| Fidget interaction results | N/A (not game-relevant) | Client-side only | Particle effects — no server involvement |
| Own prior night results | 2 (Player-Scoped) | Cached client-side from earlier waves | NOT displayed on waiting screen. Available via tap-to-reveal in discussion/voting. |

### What the Waiting Player Does NOT See

| Hidden Information | Why |
|-------------------|-----|
| Which player is currently acting | Concealment invariant. No visual, timing, or audio difference reveals the active player. |
| What action the active player is performing | Concealment invariant. |
| When the active player submits their action | Wave advancement occurs only at timer expiry or when all expected actions are submitted, subject to the 8-second minimum wave duration floor. Early submission does not trigger early transition. |
| How many actions are expected in the current wave | Wave dots represent wave groups, not individual roles. A 4-role Wave 3 has the same 1 dot as a 1-role Wave 2. |
| Content served to other players | Content rotation is client-local. Each player may see different trivia. |

### Concealment Verification Checklist

This checklist must pass for every change to this screen:

- [ ] A player performing a night action and a player waiting see the same wave indicator state.
- [ ] A player performing a night action and a player waiting hear the same narrator cues at the same time.
- [ ] A player performing a night action returns to the waiting screen via T-08, which is the same transition all players see for wave advancement.
- [ ] Fidget sounds play at comparable volume and frequency to night action confirmation sounds, providing ambient audio cover. An observer hearing a nearby phone cannot reliably determine whether a sound was a game action or a fidget interaction.
- [ ] The content card rotates on a fixed timer, not triggered by game events.
- [ ] The wave timer counts down at the same rate for all players.
- [ ] The wave dot count does not reveal the number of roles with actions in a wave.
- [ ] No loading state, error state, or empty state appears only for active or only for waiting players.

---

## Accessibility

### Screen Reader Support

| Element | Semantic Label | Notes |
|---------|---------------|-------|
| Waiting screen (container) | "Night phase. Waiting for your turn. Wave {current} of {total}." | Announced on entry and wave change (`liveRegion: assertive`). |
| Content card (fact/lore) | "Did you know? {fact text}" | Announced on rotation (`liveRegion: polite`). 5s interval. |
| Content card (quiz) | "Village Trivia. {question text}. Options: A, {option}. B, {option}. C, {option}. D, {option}." | Full question and options read. |
| Quiz answer option | "{option text}. Double tap to select." | Standard button semantics. |
| Quiz result (correct) | "Correct! {explanation}" | `liveRegion: assertive`. |
| Quiz result (wrong) | "Not quite. The answer is {correct}. {explanation}" | `liveRegion: assertive`. |
| Fidget zone | "Night waiting area. Tap to poke embers. Drag to swirl smoke. Press and hold the center to brighten the candle." | Accessible label on fidget zone. Actions produce haptic and audio feedback. |
| Wave dots | "Night wave {current} of {total} in progress." | Updated on wave change. |
| Timer | "{seconds} seconds remaining in this wave." | Announced at 50% (`polite`), 25% and 10% (`assertive`) thresholds. |

### Fidget Accessibility

Screen reader users cannot see visual fidget effects, but they can:
1. **Tap the fidget zone** to trigger `AppHaptics.fidgetResponse` + `SoundCues.fidgetEmber`. The haptic/audio IS the fidget.
2. **Receive trivia/lore** announced via `liveRegion: polite` every 5s — primary passive engagement.
3. **Answer quiz questions** with full screen reader support (question read, options navigable, result announced).

The concealment invariant for screen reader users is maintained through consistent haptic/audio presence — all phones produce occasional sounds and haptics regardless of night action status.

### Reduced Motion

All reduced motion alternatives are listed in the Animation section above. Key principle: fidget interactions still produce haptic feedback in reduced motion mode. The visual effect is simplified but the tactile response is unchanged.

### Color-Blind Safety

| Element | Color Signal | Redundant Signal |
|---------|-------------|-----------------|
| Quiz correct answer | `AppColors.moonlitSage` border | Checkmark icon (✓) |
| Quiz wrong answer | `AppColors.bloodEmber` border | X icon (✗) |
| Wave dots (active) | `AppColors.tallowGold` | Scale pulse animation (UI-24) |
| Wave dots (completed) | `AppColors.tallowGold` filled | Filled vs outlined shape |

### General

| Requirement | Implementation |
|-------------|---------------|
| Touch target (quiz options) | Each option meets `AppDimensions.touchTargetMin` (48dp). Options are full-width cards with `AppSpacing.sm` (8dp) internal padding + `AppSpacing.sm` (8dp) gap. |
| Dynamic text sizing | Content text and quiz questions support up to 200% text scale. Card expands vertically. Fidget zone shrinks proportionally. |
| Contrast | All text meets contrast requirements per design-tokens.md. Content text: `AppColors.parchment` on `AppColors.surface` (10.8:1). Labels: `AppColors.parchmentMuted` on `AppColors.surface` (4.2:1, large text only). |

---

## Open Questions

(none)
