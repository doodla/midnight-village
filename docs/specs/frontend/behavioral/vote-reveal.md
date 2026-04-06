# Vote Reveal & Elimination

## Identity

| Field     | Value |
|-----------|-------|
| type      | screen |
| id        | S13, S14 |
| phase     | voting (reveal), results (elimination) |
| route     | /game/:gameId |

This spec covers the Vote Reveal screen (S13) and the Elimination screen (S14). Together they form the theatrical climax of the game — the payoff for all the tension built during discussion and voting. The choreography must be precise: tension builds through the tally, peaks at the verdict, and resolves through elimination or silence.

---

## Layout

### S13: Vote Tally Build

```
┌─────────────────────────────────────┐
│  [phase bg: AppColors.phaseVoting]  │
│  [AppParticles.embers + dust + fog] │
│                                     │
│  ┌─────────────────────────────┐    │
│  │                             │    │
│  │  [AVA] Alice    ████░░  3  │    │  <- Horizontal bar chart
│  │  [AVA] Bob      ██░░░░  2  │    │     Each row: avatar (32dp)
│  │  [AVA] Carol    █░░░░░  1  │    │     + name + bar + count
│  │  [AVA] Dave     ░░░░░░  0  │    │
│  │  [AVA] Eve      ░░░░░░  0  │    │     Bars grow progressively
│  │                             │    │     per M-03 choreography
│  └─────────────────────────────┘    │
│                                     │
└─────────────────────────────────────┘
```

**12-player variant:**

```
┌─────────────────────────────────────┐
│  [phase bg + particles]             │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  [AVA] Alice    ████░  4   │    │  <- Scrollable if >8 rows
│  │  [AVA] Bob      ███░░  3   │    │     Rows sorted by final
│  │  [AVA] Carol    ██░░░  2   │    │     vote count (descending)
│  │  [AVA] Dave     ██░░░  2   │    │     after tally complete
│  │  [AVA] Eve      █░░░░  1   │    │
│  │  [AVA] Frank    ░░░░░  0   │    │     During build: rows in
│  │  [AVA] Grace    ░░░░░  0   │    │     server-shuffled order
│  │  [AVA] Henry    ░░░░░  0   │    │
│  │  [AVA] Iris     ░░░░░  0   │    │
│  │  [AVA] Jack     ░░░░░  0   │    │
│  │  [AVA] Kate     ░░░░░  0   │    │
│  │                             │    │
│  └─────────────────────────────┘    │
│                                     │
└─────────────────────────────────────┘
```

**Bar chart visual treatment:**

| Element | Style |
|---------|-------|
| Container | `AppColors.surface`, `AppRadius.lg` (12dp), `AppShadows.card`, `AppSpacing.base` (16dp) padding |
| Row height | 48dp (matches `AppDimensions.touchTargetMin`) |
| Row gap | `AppSpacing.sm` (8dp) |
| Avatar | `AppDimensions.avatarSm` (32dp) |
| Name | `AppTextStyles.body`, `AppColors.parchment` |
| Bar background | `AppColors.surfaceInset`, `AppRadius.sm` (4dp), full available width |
| Bar fill | `AppColors.tallowGold`, `AppRadius.sm` (4dp), width proportional to vote count |
| Vote count | `AppTextStyles.labelLarge` (Space Grotesk), `AppColors.parchment`, right-aligned |
| Highest-voted bar (after tally) | Bar fill pulses `AppColors.tallowGold` (per T-05 timeline) |
| Tied bars | All tied bars pulse simultaneously |

**Voter indicators:** Small voter avatars (`AppDimensions.avatarSm`, 32dp) appear at the end of each vote bar segment as votes are added during the tally build (M-03).

| Player Count | Voter Indicators | Rationale |
|-------------|-----------------|-----------|
| 3-10 players | Shown — small avatar at each vote segment | Enough space; adds drama seeing WHO voted for whom |
| 11+ players | Hidden — dots only | Too many avatars at small size; voter identity available in results table |

**Tablet:** Container centered at `AppDimensions.maxContentWidth` (480dp). Rows have more breathing room (`AppSpacing.md`, 12dp gap).

**Landscape:** Bar chart extends full width minus screen padding. Rows are wider, bars more readable.

---

### S14: Elimination Announcement

```
┌─────────────────────────────────────┐
│  [phase bg: AppColors.phaseVoting]  │
│  [AppGlows.bloodVignette]           │
│  [particles dimmed]                 │
│                                     │
│                                     │
│                                     │
│           ALICE                     │  <- AppTextStyles.displayXl
│                                     │     (40dp, Epilogue bold)
│                                     │     AppColors.parchment
│                                     │     Scale 0.8→1.0 + fade in
│                                     │
│         ┌───────────┐               │
│         │  ROLE     │               │  <- Inline card flip (M-02)
│         │  REVEAL   │               │     120dp × 160dp
│         │  [icon]   │               │     Team accent border
│         │  Werewolf │               │
│         └───────────┘               │
│                                     │
│                                     │
└─────────────────────────────────────┘
```

### S14: No Elimination Variant

```
┌─────────────────────────────────────┐
│  [phase bg: AppColors.phaseVoting]  │
│  [AppGlows.noDeathWash]             │
│                                     │
│                                     │
│                                     │
│                                     │
│      No one was eliminated.         │  <- AppTextStyles.display
│                                     │     AppColors.noDeathBlue
│                                     │     Fade in, centered
│                                     │
│                                     │
│                                     │
│                                     │
└─────────────────────────────────────┘
```

### S14: Hunter Chain Variant

```
┌─────────────────────────────────────┐
│  [After first elimination...]       │
│                                     │
│      "The Hunter takes aim..."      │  <- AppTextStyles.narrator
│                                     │     Libre Baskerville italic
│                                     │     400ms display
│                                     │
│  [600ms pause]                      │
│                                     │
│  [Second elimination sequence       │
│   plays with same layout as         │
│   standard elimination above]       │
│                                     │
└─────────────────────────────────────┘
```

---

## Preconditions

### S13: Vote Reveal

- All votes submitted OR voting timer expired
- T-04 (Voting -> Vote Reveal) transition has completed
- Vote data received from server (all vote targets)

### S14: Elimination

- Vote tally build (M-03) has completed
- T-05 (Vote Reveal -> Elimination) transition has completed
- Server has computed elimination outcome (who dies, Hunter chain, win conditions)

---

## States

### S13: Vote Reveal States

| State ID | Trigger | What the user sees | Audio/Haptic |
|----------|---------|-------------------|--------------|
| TALLY-LOCK | T-04 begins (0ms) | Vote selections lock. Selection indicators pulse once (scale 1.0->1.1->1.0, `AppCurves.bounce`). No more interaction. | `AppHaptics.tapMedium` (H-02), `SoundCues.votesLocked` (S-06) |
| TALLY-RECONFIG | T-04 (300ms) | Voting grid reconfigures into bar chart layout. Player cards shrink and reposition into tally rows. Timer fades out. | None |
| TALLY-FRAME | T-04 (900ms) | Empty bar chart frame fades in. All bars at zero width. Player names and avatars visible. | None |
| TALLY-BUILD | T-04 complete (1200ms), M-03 begins | Votes appear progressively over 6000ms (`AppDurations.voteBuild`). Each vote extends a bar. Per-vote haptic and sound. | Per-vote: `AppHaptics.tallyTick` (H-10), `SoundCues.tallyTick` (S-07) |
| TALLY-VOTE-N | Each vote in sequence | Target player's bar extends by one unit (300ms, `AppCurves.bounce`). Vote count increments. Optional voter indicator appears at bar end. | `AppHaptics.tallyTick` (H-10), `SoundCues.tallyTick` (S-07) |
| TALLY-FINAL-VOTE | Last vote (400ms extra delay before it) | Bar extends with `AppCurves.dramatic` instead of `AppCurves.bounce`. Haptic escalates to `AppHaptics.tapMedium` (H-02). | `AppHaptics.tapMedium` (H-02), `SoundCues.tallyTick` (S-07) |
| TALLY-TIE-PULSE | Two or more players tied for highest (≥2 each) after last vote | All tied bars pulse `AppColors.tallowGold` simultaneously (2 pulses, 400ms cycle). | None |
| TALLY-COMPLETE | All votes displayed | Tally holds for ~1000ms. T-05 transition begins. | None |

**Vote ordering logic:**
- Votes appear in random server-shuffled order (not grouped by target)
- The vote that pushes a player to "most votes" is always last or second-to-last (server orders this for maximum drama)
- Per-vote delay = `AppDurations.voteBuild` / (N + 2), where N = total votes. The +2 adds breathing room.

### S14: Elimination States

| State ID | Trigger | What the user sees | Audio/Haptic |
|----------|---------|-------------------|--------------|
| ELIM-VERDICT | T-05 begins (0ms) | Highest-voted bar highlighted. Non-eliminated bars dim to 40% opacity. Dramatic pause. | `SoundCues.verdictDrum` (S-08) |
| ELIM-TALLY-EXIT | T-05 (1000ms) | Tally UI fades/scales down (opacity 1->0, scale 1.0->0.95, 500ms, `AppCurves.exit`). | None |
| ELIM-ANNOUNCE | T-05 complete (1500ms), M-04 begins | `AppGlows.bloodVignette` fades in (600ms). Eliminated player's name appears large (scale 0.8->1.0, fade in, `AppCurves.dramatic`). | `SoundCues.eliminationReveal` (S-09), `AppHaptics.elimination` (H-12) |
| ELIM-HOLD | M-04 (600ms) | Name holds on screen. 400ms dramatic pause. | None |
| ELIM-ROLE | M-04 (1000ms) | Role card fades in below name. Inline card flip (M-02 variant). Team accent border. | `SoundCues.cardPeek` (S-05) |
| ELIM-NARRATOR | M-04 (1600ms) | Narrator cue fires: NC-ELIM-DEATH ("{name} has been eliminated.") then NC-ELIM-ROLE ("{name} was the {role}."). | `AppHaptics.narratorBeat` (H-11), narrator audio |
| ELIM-HUNTER-PAUSE | If eliminated player holds Hunter card | 600ms pause after initial elimination. | None |
| ELIM-HUNTER-TEXT | After hunter pause | "The Hunter takes aim..." text in `AppTextStyles.narrator`, centered, 400ms display. NC-ELIM-HUNTER narrator cue fires. | `AppHaptics.narratorBeat` (H-11), narrator audio |
| ELIM-HUNTER-TARGET | After hunter text | Second elimination sequence: name + role card for Hunter's vote target. Same M-04 structure (2000ms). | Same as ELIM-ANNOUNCE through ELIM-NARRATOR |
| ELIM-NONE-ANNOUNCE | No player received ≥2 votes, M-05 begins | `AppGlows.noDeathWash` fades in (600ms, `AppCurves.standard`). "No one was eliminated." text in `AppTextStyles.display`, `AppColors.noDeathBlue`, opacity 0->1. NC-ELIM-NONE fires. | `SoundCues.noElimination` (S-10), `AppHaptics.tapMedium` (H-02) |
| ELIM-NONE-HOLD | M-05 (1200ms) | Text holds. 600ms pause. | None |
| ELIM-TIE | Multiple players tied at ≥2 votes | Sequential elimination: each player's elimination plays M-04 with 400ms gap between. Names revealed in vote-count order (highest first; if truly tied, alphabetical). | Per-player: full M-04 audio/haptic |
| ELIM-COMPLETE | All elimination(s) done | T-06 transition begins (Elimination -> Results, 1500ms). | Per T-06 timeline |
| ELIM-DISCONNECT | Disconnect during reveal | P-DISCONNECT overlay (T-09). Sequence pauses. Resumes on reconnect from the current beat. | `SoundCues.disconnect` (S-14), `AppHaptics.tapMedium` (H-02) |

---

## Transitions

| From State | Condition | To (screen/state) | Animation |
|------------|-----------|-------------------|-----------|
| Voting (any VOTE-*) | All votes in or timer expires | TALLY-LOCK | T-04 (1200ms). Votes lock. Grid reconfigures to tally. |
| TALLY-COMPLETE | Tally build done | ELIM-VERDICT | T-05 (1500ms). Highest bar highlighted. Tally exits. |
| ELIM-COMPLETE (elimination) | Elimination sequence done | Results (S15) | T-06 (1500ms). Blood vignette fades out. Results UI fades in. |
| ELIM-COMPLETE (no elimination) | No-death sequence done | Results (S15) | T-06 (1500ms). No-death wash fades out. Results UI fades in. |
| ELIM-ANNOUNCE | Eliminated player holds Hunter card | ELIM-HUNTER-PAUSE | 600ms pause, then Hunter chain sequence |
| ELIM-TIE (per player) | Tie elimination, more tied players remain | Next ELIM-ANNOUNCE | 400ms gap, then next player's elimination |

---

## Interactions

Both S13 and S14 are **non-interactive**. These are choreographed sequences that play to completion. Players watch — they do not tap, select, or dismiss.

| Element | Event | Result | Haptic | Sound |
|---------|-------|--------|--------|-------|
| Entire screen (S13) | Any tap | Ignored. Tally build cannot be skipped or accelerated. | None | None |
| Entire screen (S14) | Any tap | Ignored. Elimination sequence cannot be skipped. | None | None |
| Tally bars | — | Not interactive. Display only. | — | — |
| Elimination name/card | — | Not interactive. Display only. | — | — |

**No interactions by design.** Per `sound-and-motion.md` usage rules: "DO NOT interrupt a theatrical moment sequence (M-01 through M-06) with user input. These play to completion."

**Exception:** P-DISCONNECT overlay can appear during these sequences if a player disconnects. The overlay pauses the sequence.

---

## Narrator Cues

| Trigger | Cue ID | Semantic Content | Screen Context | Haptic |
|---------|--------|-----------------|----------------|--------|
| M-04 (1600ms) — player eliminated | NC-ELIM-DEATH | "{name} has been eliminated." | After name display + role card reveal | `AppHaptics.narratorBeat` (H-11) |
| Immediately after NC-ELIM-DEATH | NC-ELIM-ROLE | "{name} was the {role}." | Role identity spoken | `AppHaptics.narratorBeat` (H-11) |
| Multiple players tied | NC-ELIM-DEATH-TIE | "{name} has been eliminated." (per player) | Fires for each eliminated player in tie sequence | H-11 per player |
| Hunter chain | NC-ELIM-HUNTER | "The Hunter takes aim..." | After initial elimination, before chain target | H-11 |
| Hunter chain target | NC-ELIM-HUNTER-TARGET | "{name} has also been eliminated. {name} was the {role}." | Second elimination | H-11 |
| No player ≥2 votes | NC-ELIM-NONE | "No one was eliminated." | During M-05 sequence | H-11 |

**Dynamic content:** NC-ELIM-DEATH, NC-ELIM-ROLE, NC-ELIM-HUNTER-TARGET contain player names and role names. The narrator persona system must support string interpolation.

---

## Errors

| Error | In-World Headline | Clear Subtitle | Recovery |
|-------|-------------------|----------------|----------|
| Vote data load failure | "The darkness deepens..." | Failed to load vote results. Retrying... | Auto-retry. Tally build waits for data. If 3 failures, show overlay error. |
| Elimination data missing | "Something stirs in the darkness..." | Failed to determine elimination. Retrying... | Auto-retry. Sequence pauses. Server re-sends on reconnect. |
| Player disconnect during tally | "A villager has wandered into the fog..." | {name} disconnected. Game paused. | P-DISCONNECT overlay. Tally pauses at current vote. Resumes on reconnect. |
| Player disconnect during elimination | "A villager has wandered into the fog..." | {name} disconnected. Game paused. | P-DISCONNECT overlay. Sequence pauses at current beat. Resumes on reconnect. |
| Audio playback failure | (no visible error) | (silent fallback) | If narrator audio fails, sequence continues visually. Text on screen carries the information. |

---

## Animation

All animations reference `sound-and-motion.md` by ID.

### T-04: Voting -> Vote Reveal

| Moment | Offset (ms) | Duration (ms) | Layer | Action | Easing |
|--------|-------------|---------------|-------|--------|--------|
| Vote lock pulse | 0 | 300 | Voting UI | Selection indicators pulse scale 1.0->1.1->1.0 | `AppCurves.bounce` |
| Grid reconfig | 300 | 400 | Voting grid | Cards shrink/reposition into bar chart rows | `AppCurves.dramatic` |
| Timer fade | 300 | 400 | Timer | Fades out | `AppCurves.exit` |
| Dramatic pause | 700 | 200 | — | Silence before tally | — |
| Bar chart frame | 900 | 300 | Tally UI | Empty bar chart fades in | `AppCurves.enter` |

### M-03: Vote Tally Build (6000ms total)

| Moment | Duration | Layer | Action | Easing |
|--------|----------|-------|--------|--------|
| Per-vote bar extend | 300ms | Vote bar | Target bar grows by one vote unit | `AppCurves.bounce` (normal), `AppCurves.dramatic` (final vote) |
| Per-vote count update | 200ms | Vote count | Number increments | `AppCurves.standard` |
| Per-vote voter indicator | 200ms | Voter dot/avatar | Appears at bar end | `AppCurves.enter` |
| Final vote extra delay | 400ms | — | Pause before last vote | — |
| Tie pulse | 2 × 400ms | Tied bars | `AppColors.tallowGold` pulse | Sinusoidal |

**Reduced motion (M-03):** All bars fill simultaneously over 1000ms. No stagger, no per-vote animation. Vote counts display final values instantly.

### T-05: Vote Reveal -> Elimination (1500ms)

| Moment | Offset (ms) | Duration (ms) | Layer | Action | Easing |
|--------|-------------|---------------|-------|--------|--------|
| Non-eliminated dim | 0 | 400 | Tally bars | Bars dim to 40% opacity | `AppCurves.standard` |
| Highest bar pulse | 0 | 400 | Winning bar | Pulses `AppColors.tallowGold` | `AppCurves.dramatic` |
| Dramatic hold | 400 | 600 | — | Silence | — |
| Tally exit | 1000 | 500 | Tally UI | Fade/scale out: opacity 1->0, scale 1.0->0.95 | `AppCurves.exit` |

**Reduced motion (T-05):** Highest bar highlighted instantly for 1000ms. Tally fades out over 300ms.

### M-04: Elimination Announcement (2000ms per player)

| Moment | Offset (ms) | Duration (ms) | Layer | Action | Easing |
|--------|-------------|---------------|-------|--------|--------|
| Blood vignette in | 0 | 600 | Glow | `AppGlows.bloodVignette` fades in | `AppCurves.dramatic` |
| Name appear | 0 | 600 | Player name | `AppTextStyles.displayXl`, scale 0.8->1.0, opacity 0->1 | `AppCurves.dramatic` |
| Name hold | 600 | 400 | — | Hold beat | — |
| Role card reveal | 1000 | 600 | Role card | Inline card flip (M-02 variant), team accent border | `AppCurves.dramatic` |
| Narrator cue | 1600 | — | Narrator | NC-ELIM-DEATH + NC-ELIM-ROLE fire | — |

**Hunter chain (after initial M-04):**

| Moment | Offset (ms) | Duration (ms) | Layer | Action |
|--------|-------------|---------------|-------|--------|
| Pause | 0 | 600 | — | Dramatic silence |
| Hunter text | 600 | 400 | Narrator overlay | "The Hunter takes aim..." in `AppTextStyles.narrator` |
| Hunter cue | 600 | — | Narrator | NC-ELIM-HUNTER fires |
| Chain elimination | 1000 | 2000 | Full M-04 | Second player: name + role, same structure |

**Total Hunter chain: ~5000ms** (2000ms initial + 1000ms pause/text + 2000ms chain target).

**Tie elimination:** Each player's M-04 plays sequentially with 400ms gap. Order: highest vote count first; if truly tied, alphabetical.

**Reduced motion (M-04):** Name and role appear statically (no scale animation). Blood vignette appears at full opacity instantly. Total: 1200ms.

### M-05: No Elimination (1800ms)

| Moment | Offset (ms) | Duration (ms) | Layer | Action | Easing |
|--------|-------------|---------------|-------|--------|--------|
| No-death wash | 0 | 600 | Glow | `AppGlows.noDeathWash` fades in | `AppCurves.standard` |
| Text appear | 200 | 400 | Display text | "No one was eliminated." in `AppTextStyles.display`, `AppColors.noDeathBlue`, opacity 0->1 | `AppCurves.enter` |
| Narrator cue | 200 | — | Narrator | NC-ELIM-NONE fires | — |
| Hold | 1200 | 600 | — | Pause | — |

**Reduced motion (M-05):** Text appears instantly with wash at full opacity. Total: 1200ms.

### T-06: Elimination -> Results (1500ms)

| Moment | Offset (ms) | Duration (ms) | Layer | Action | Easing |
|--------|-------------|---------------|-------|--------|--------|
| Elimination UI out | 0 | 600 | Elimination UI | Fade out opacity 1->0 | `AppCurves.exit` |
| Glow out | 0 | 600 | Glow | `AppGlows.bloodVignette` or `AppGlows.noDeathWash` fades out | `AppCurves.exit` |
| Ambience crossfade | 0 | 1500 | Ambient | Previous ambience -> `Ambience.results` | Linear |
| Background crossfade | 600 | 600 | Background | -> `AppColors.phaseResults` | `AppCurves.standard` |
| Results UI in | 900 | 600 | Results UI | M-06 (Win/Loss) fades/scales in | `AppCurves.enter` |

---

## Strings

| Key | Default Text | Notes |
|-----|-------------|-------|
| `reveal.votes_locked` | Votes locked | Brief flash at lock moment |
| `reveal.tally_count` | {count} | Vote count per player in bar chart |
| `elimination.name` | {player} | Large name display |
| `elimination.role` | {role} | Role name on revealed card |
| `elimination.narrator_death` | {name} has been eliminated. | Narrator cue text |
| `elimination.narrator_role` | {name} was the {role}. | Narrator cue text |
| `elimination.narrator_hunter` | The Hunter takes aim... | Hunter chain preamble |
| `elimination.narrator_hunter_target` | {name} has also been eliminated. {name} was the {role}. | Hunter chain victim |
| `elimination.no_one` | No one was eliminated. | No-death variant text |
| `elimination.narrator_no_one` | No one was eliminated. | Narrator cue text |
| `elimination.tie_prefix` | Multiple players were eliminated. | Optional prefix for tie narration |

---

## Information Architecture

### What Is Revealed and When

| Moment | Information Tier Change | What Becomes Public |
|--------|------------------------|-------------------|
| T-04 (vote lock) | Vote targets move from Tier 3 -> Tier 1 (via progressive reveal) | Who each player voted for |
| M-03 (tally build) | Progressive Tier 1 disclosure | Vote counts per player, one vote at a time |
| M-04 (elimination) | Eliminated player's role moves from Tier 3 -> Tier 1 | Eliminated player's current role card |
| M-04 (Hunter chain) | Chain target's role moves from Tier 3 -> Tier 1 | Chain target's current role card |
| M-05 (no elimination) | No new info | "No one was eliminated" (Tier 1 fact) |

### What Remains Hidden

| Information | Status | Notes |
|-------------|--------|-------|
| Non-eliminated players' roles | Tier 3 (server-only) | NOT revealed during elimination. Revealed in results table (S15). |
| Night action log | Tier 3 (server-only) | NOT revealed until full autopsy in results. |
| Doppelganger's copied role | Tier 3 (server-only) | NOT revealed until results table. Exception: if Doppelganger is eliminated, their effective role is shown (resolved from `doppelganger_copied_role`). |

### Doppelganger Elimination Display

When a player holding the Doppelganger card is eliminated, the role card revealed shows the **effective role** (the copied role), not "Doppelganger." This is because the Doppelganger card IS the copied role for all game resolution purposes.

| Scenario | Card Shown | Team Accent |
|----------|-----------|-------------|
| Doppelganger copied Werewolf, eliminated | Werewolf | `AppColors.teamWerewolf` |
| Doppelganger copied Tanner, eliminated | Tanner | `AppColors.teamIndependent` |
| Doppelganger copied Seer, eliminated | Seer | `AppColors.teamVillage` |
| Doppelganger card was never peeked (started in center, Drunk took it) | Doppelganger (no copied role) | `AppColors.teamVillage` (default) |

---

## Accessibility

### S13: Vote Tally

| Requirement | Implementation |
|-------------|---------------|
| Screen reader: tally start | `Semantics(liveRegion: assertive, label: "Vote results are being revealed.")` at M-03 start. |
| Screen reader: per-vote | Each vote announced: "[Voter] voted for [Target]. [Target] now has [count] votes." `liveRegion: polite`. |
| Screen reader: final vote | Announced with emphasis: "Final vote: [Voter] voted for [Target]. [Target] has [count] votes — the most." `liveRegion: assertive`. |
| Screen reader: tie | "Tie! [Player A] and [Player B] each have [count] votes." `liveRegion: assertive`. |
| Screen reader: tally complete | "All votes counted. [Player] received the most votes with [count]." or "All votes counted. No player received 2 or more votes." `liveRegion: assertive`. |
| Reduced motion | All bars fill simultaneously (no stagger). Counts display final values. |

### S14: Elimination

| Requirement | Implementation |
|-------------|---------------|
| Screen reader: elimination | `Semantics(liveRegion: assertive, label: "[Player name] has been eliminated. They were the [Role name].")`. Announced after name + role card are both displayed. |
| Screen reader: Hunter chain | "The Hunter takes aim. [Target name] has also been eliminated. They were the [Role name]." `liveRegion: assertive`. |
| Screen reader: no elimination | "No one was eliminated." `liveRegion: assertive`. |
| Screen reader: tie elimination | Each elimination announced sequentially with the same pattern. |
| Reduced motion | No scale animations. Name and role appear statically. Blood vignette at full opacity instantly. |
| Color-blind: elimination | Blood vignette is atmospheric (red-tinted screen edge). The elimination information is conveyed by text (name + role), not color. |
| Color-blind: no elimination | `AppColors.noDeathBlue` text paired with explicit text "No one was eliminated." Color reinforces mood but text carries meaning. |
| Color-blind: role card | Team accent border paired with team name text label on the revealed card (same treatment as role reveal S05). |

### General

| Requirement | Implementation |
|-------------|---------------|
| Non-interactive screen | Screen reader announces: "Vote reveal in progress. Please wait." No focusable interactive elements during M-03/M-04/M-05. |
| Focus management | After elimination sequence completes and T-06 transitions to results, focus moves to the results headline. |
| Dynamic text | Player names may be long. Names truncate with ellipsis on the bar chart rows (max width: 40% of row). Full name shown in elimination announcement (no truncation — `AppTextStyles.displayXl` wraps if needed). |

---

## Rule Verification

| Claim | Source | Verbatim Citation |
|-------|--------|-------------------|
| Minimum 2 votes to die | `docs/specs/onuw/voting-and-resolution.md`, Step 2 | "The player(s) with the most votes die, provided they received at least 2 votes." / "The minimum vote threshold is 2." |
| No player >1 vote = no one dies | `docs/specs/onuw/voting-and-resolution.md`, Step 2 | "If no player has more than 1 vote, no one dies." |
| 1 vote highest but <2 = no one dies | `docs/specs/onuw/voting-and-resolution.md`, Step 2 | "If one player has exactly 1 vote (and it's the highest), no one dies (minimum 2 required)." |
| Tied players all die | `docs/specs/onuw/voting-and-resolution.md`, Step 2 | "If there is a tie for the most votes (and the tied count is ≥ 2), all tied players die." |
| Hunter chain: vote target also dies | `docs/specs/onuw/voting-and-resolution.md`, Step 3 | "If the Hunter dies, the player the Hunter voted for also dies (regardless of how many votes that target received)." |
| Hunter ability follows the card | `docs/specs/onuw/voting-and-resolution.md`, Step 3 | "The Hunter ability belongs to the card position, not the original player. If the Hunter card was swapped to a different player during the night, the new holder of the Hunter card has the ability." |
| Hunter chain does not recurse | `docs/specs/onuw/voting-and-resolution.md`, Notes | "Hunter chain kills do not recurse. If the Hunter kills a Doppelganger-as-Hunter, that second 'Hunter' does not trigger a further chain." |
| Doppelganger-as-Hunter has passive | `docs/specs/onuw/doppelganger.md`, Copies Hunter | "if the Doppelganger-as-Hunter is eliminated, the player the Doppelganger voted for is also eliminated (Hunter's passive ability)." |
| Doppelganger-as-Hunter: server checks copied role | `docs/specs/onuw/doppelganger.md`, Copies Hunter | "The Hunter ability is tracked by the copied role for the Doppelganger, not by the physical card. Since the Doppelganger's physical card says 'Doppelganger,' the server must check doppelganger_copied_role." |
| Tanner death blocks Werewolf win | `docs/specs/onuw/voting-and-resolution.md`, Scenario A | "If the Tanner dies and no Werewolves die, the Werewolves do not win." |
| Tanner + Werewolf both die = both win | `docs/specs/onuw/voting-and-resolution.md`, Scenario A | "At least one Werewolf player dies, Tanner also dies: Village wins AND Tanner wins." |
| Doppelganger-as-Tanner dies = Tanner wins | `docs/specs/onuw/doppelganger.md`, Copies Tanner | "Doppelganger-as-Tanner wins only if the Doppelganger is eliminated." |
| No WW among players + no one dies = Village wins | `docs/specs/onuw/voting-and-resolution.md`, Scenario B | "No one dies: Village wins." |
| Votes simultaneous, no peek before commit | `docs/specs/onuw/voting-and-resolution.md`, Voting Rules | "All votes are revealed at the same instant." |
| Vote timeout = skip (not counted) | `docs/specs/onuw/voting-and-resolution.md`, Digital Implementation | "If a player does not submit a vote before the timer expires, their vote is skipped (they effectively abstain — their vote is not counted)." |

---

## Open Questions

(none)
