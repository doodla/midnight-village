# Sound & Motion -- Firelit Gothic

## Identity

| Field   | Value |
|---------|-------|
| type    | creative-direction |
| domain  | motion, sound, haptic |

This document is the **single source of truth** for all animation choreography, haptic feedback, sound cues, and ambient soundscapes in Midnight Village. Every phase transition, theatrical moment, and interaction feedback is defined here with exact timing, easing, and cross-modal pairings.

All motion token values (durations, easing curves) and visual effect tokens (glows, particles) are defined in `design-tokens.md`. This document references those tokens by name and builds choreography sequences from them.

---

## Vocabulary

### Phase Transition Choreography

Every game-flow transition is defined here. No other document may define phase transition timing. Screen specs reference these by ID.

---

#### T-01: Lobby -> Night -- "Game Start"

| Property | Value |
|----------|-------|
| Total duration | 2500ms (`AppDurations.cinematic`) |
| Trigger | Host presses "Start Game", server confirms game creation |
| Narrator text | "Night falls on the village..." |
| Haptic | `AppHaptics.phaseShift` at offset 0ms |
| Sound | `SoundCues.gameStart` at offset 0ms, `Ambience.night` fade-in begins at 800ms |

**Timeline:**

| Offset (ms) | Duration (ms) | Layer | Action | Easing |
|-------------|---------------|-------|--------|--------|
| 0 | 500 | Lobby UI | Fade out opacity 1.0 -> 0.0, scale 1.0 -> 0.97 | `AppCurves.exit` |
| 0 | 800 | Background | Crossfade `AppColors.phaseLobby` -> black via scrim overlay at `AppOpacity.scrim` | `AppCurves.standard` |
| 0 | -- | Particles | `AppParticles.dust` fade out over 400ms | `AppCurves.exit` |
| 800 | 600 | Narrator overlay | `AppTextStyles.narrator` text fades in centered on screen, opacity 0.0 -> 1.0 | `AppCurves.enter` |
| 800 | -- | Ambient | `Ambience.night` begins fade-in from 0% to 100% volume over 1200ms | linear |
| 800 | -- | Particles | `AppParticles.embers` + `AppParticles.fog` begin spawning at 0 opacity, ramping to normal over 800ms | linear |
| 1800 | 400 | Narrator overlay | Text fades out opacity 1.0 -> 0.0 | `AppCurves.exit` |
| 1800 | 700 | Background | Scrim fades to `AppColors.phaseNight` | `AppCurves.standard` |
| 1800 | -- | Glow | `AppGlows.candle` fades in opacity 0.0 -> target over 700ms | `AppCurves.standard` |
| 2200 | 300 | Night UI | Role reveal card entry begins (see M-01) | `AppCurves.enter` |

**Reduced motion:** Instant cut to `AppColors.phaseNight` background. Narrator text appears statically for 1500ms, then disappears. Night UI appears immediately after. Total time: 1800ms.

---

#### T-02: Night -> Discussion -- "Dawn"

| Property | Value |
|----------|-------|
| Total duration | 2500ms (`AppDurations.cinematic`) |
| Trigger | All night waves complete, server sends discussion phase start |
| Narrator text | "Everyone, wake up. Discuss." |
| Haptic | `AppHaptics.phaseShift` at offset 0ms |
| Sound | `SoundCues.phaseTransition` at offset 0ms, `Ambience.night` fades out, `Ambience.discussion` fades in |

**Timeline:**

| Offset (ms) | Duration (ms) | Layer | Action | Easing |
|-------------|---------------|-------|--------|--------|
| 0 | 500 | Night UI | Fade out opacity 1.0 -> 0.0 | `AppCurves.exit` |
| 0 | 500 | Particles | `AppParticles.embers` + `AppParticles.fog` fade out | `AppCurves.exit` |
| 0 | 800 | Background | Crossfade `AppColors.phaseNight` -> scrim black | `AppCurves.standard` |
| 0 | -- | Ambient | `Ambience.night` fades out over 800ms | linear |
| 0 | -- | Glow | `AppGlows.candle` fades out over 500ms | `AppCurves.exit` |
| 800 | 600 | Narrator overlay | "Everyone, wake up. Discuss." fades in | `AppCurves.enter` |
| 800 | -- | Ambient | `Ambience.discussion` begins fade-in over 1000ms | linear |
| 1800 | 400 | Narrator overlay | Text fades out | `AppCurves.exit` |
| 1800 | 700 | Background | Scrim fades to `AppColors.phaseDiscussion` | `AppCurves.standard` |
| 1800 | -- | Particles | `AppParticles.embers` + `AppParticles.dust` begin spawning, ramp to normal over 700ms | linear |
| 2200 | 300 | Discussion UI | Timer and discussion layout fade in | `AppCurves.enter` |

**Reduced motion:** Instant cut. Narrator text static for 1500ms. Discussion UI appears after. Total: 1800ms.

---

#### T-03: Discussion -> Voting -- "Time to Vote"

| Property | Value |
|----------|-------|
| Total duration | 2000ms |
| Trigger | Discussion timer expires or host ends discussion early |
| Narrator text | "Time to vote." |
| Haptic | `AppHaptics.phaseShift` at offset 0ms |
| Sound | `SoundCues.votingStart` at offset 0ms, `Ambience.discussion` crossfades to `Ambience.voting` |

**Timeline:**

| Offset (ms) | Duration (ms) | Layer | Action | Easing |
|-------------|---------------|-------|--------|--------|
| 0 | 400 | Discussion UI | Timer and content fade out | `AppCurves.exit` |
| 0 | -- | Ambient | `Ambience.discussion` begins crossfade to `Ambience.voting` over 1500ms | linear |
| 400 | 600 | Narrator overlay | "Time to vote." fades in | `AppCurves.enter` |
| 400 | 600 | Background | Crossfade `AppColors.phaseDiscussion` -> `AppColors.phaseVoting` | `AppCurves.standard` |
| 400 | -- | Particles | `AppParticles.fog` begins spawning if not already active | linear |
| 1200 | 400 | Narrator overlay | Text fades out | `AppCurves.exit` |
| 1400 | 600 | Voting UI | Player grid and timer fade in, stagger 50ms per player card | `AppCurves.enter` |

**Reduced motion:** Instant cut. Narrator text static for 1000ms. Voting UI appears after. Total: 1200ms.

---

#### T-04: Voting -> Vote Reveal -- "Votes Are In"

| Property | Value |
|----------|-------|
| Total duration | 1200ms (then M-03 Vote Tally Build begins) |
| Trigger | All votes submitted or voting timer expires |
| Narrator text | none |
| Haptic | `AppHaptics.tapMedium` at offset 0ms |
| Sound | `SoundCues.votesLocked` at offset 0ms |

**Timeline:**

| Offset (ms) | Duration (ms) | Layer | Action | Easing |
|-------------|---------------|-------|--------|--------|
| 0 | 300 | Voting UI | Vote selections lock -- no more interaction. Selection indicators pulse once (scale 1.0 -> 1.1 -> 1.0) | `AppCurves.bounce` |
| 300 | 400 | Voting grid | Grid reconfigures to tally layout: player cards shrink and reposition into result bar chart slots | `AppCurves.dramatic` |
| 300 | 400 | Timer | Timer fades out | `AppCurves.exit` |
| 700 | -- | -- | Pause beat (dramatic silence before tally) | -- |
| 900 | 300 | Vote tally UI | Empty bar chart frame fades in | `AppCurves.enter` |

M-03 (Vote Tally Build) begins immediately after at offset 1200ms.

**Reduced motion:** Instant transition to tally layout. 400ms pause, then tally appears. Total: 600ms.

---

#### T-05: Vote Reveal -> Elimination -- "The Verdict"

| Property | Value |
|----------|-------|
| Total duration | 1500ms (then M-04 or M-05 begins) |
| Trigger | Vote tally build complete (M-03 finished) |
| Narrator text | none (narrator fires in M-04/M-05) |
| Haptic | none (haptic fires in M-04/M-05) |
| Sound | `SoundCues.verdictDrum` at offset 0ms -- low tension swell |

**Timeline:**

| Offset (ms) | Duration (ms) | Layer | Action | Easing |
|-------------|---------------|-------|--------|--------|
| 0 | 400 | Vote tally | Non-eliminated players' bars dim to 40% opacity | `AppCurves.standard` |
| 0 | 400 | Vote tally | Highest-voted player bar pulses gold (`AppColors.tallowGold`) | `AppCurves.dramatic` |
| 400 | -- | -- | Hold beat -- 600ms dramatic pause | -- |
| 1000 | 500 | Vote tally | Tally UI fades/scales down: opacity 1.0 -> 0.0, scale 1.0 -> 0.95 | `AppCurves.exit` |

M-04 (Elimination) or M-05 (No Elimination) begins at offset 1500ms depending on whether anyone died.

**Reduced motion:** Highest-voted bar highlighted instantly for 1000ms. Tally fades out over 300ms. Total: 1300ms.

---

#### T-06: Elimination -> Results -- "The Aftermath"

| Property | Value |
|----------|-------|
| Total duration | 1500ms |
| Trigger | Elimination announcement moment complete (M-04 or M-05 finished) |
| Narrator text | none |
| Haptic | none |
| Sound | `Ambience.results` begins fade-in at offset 0ms over 1500ms |

**Timeline:**

| Offset (ms) | Duration (ms) | Layer | Action | Easing |
|-------------|---------------|-------|--------|--------|
| 0 | 600 | Elimination UI | Fade out opacity 1.0 -> 0.0 | `AppCurves.exit` |
| 0 | 600 | Glow | `AppGlows.bloodVignette` or `AppGlows.noDeathWash` fades out | `AppCurves.exit` |
| 0 | -- | Ambient | Previous ambience crossfades to `Ambience.results` over 1500ms | linear |
| 600 | 600 | Background | Crossfade to `AppColors.phaseResults` | `AppCurves.standard` |
| 900 | 600 | Results UI | Team headline (M-06) fades/scales in | `AppCurves.enter` |

M-06 (Win/Loss Announcement) begins at offset 900ms.

**Reduced motion:** Instant cut to results background. Results UI appears after 400ms. Total: 600ms.

---

#### T-07: Results -> Lobby -- "Play Again"

| Property | Value |
|----------|-------|
| Total duration | 1000ms |
| Trigger | Host or player taps "Play Again" |
| Narrator text | none |
| Haptic | `AppHaptics.tapLight` at offset 0ms |
| Sound | `SoundCues.playAgain` at offset 0ms, `Ambience.results` crossfades to `Ambience.lobby` |

**Timeline:**

| Offset (ms) | Duration (ms) | Layer | Action | Easing |
|-------------|---------------|-------|--------|--------|
| 0 | 400 | Results UI | Fade out opacity 1.0 -> 0.0, scale 1.0 -> 0.98 | `AppCurves.exit` |
| 0 | -- | Ambient | `Ambience.results` crossfades to `Ambience.lobby` over 800ms | linear |
| 0 | -- | Particles | Current particles fade out over 400ms | `AppCurves.exit` |
| 400 | 600 | Background | Crossfade to `AppColors.phaseLobby` | `AppCurves.standard` |
| 400 | -- | Particles | `AppParticles.dust` begins spawning | linear |
| 600 | 400 | Lobby UI | Player list and lobby controls fade in | `AppCurves.enter` |

**Reduced motion:** Instant cut. Total: 300ms crossfade.

---

#### T-08: Night Wave-to-Wave Transition

| Property | Value |
|----------|-------|
| Total duration | 800ms |
| Trigger | Current wave actions complete, server advances to next wave |
| Narrator text | Per-wave narrator call (see `narrator-cues.md`) |
| Haptic | `AppHaptics.narratorBeat` when narrator cue fires |
| Sound | Per-wave narrator audio cue |

**Timeline:**

| Offset (ms) | Duration (ms) | Layer | Action | Easing |
|-------------|---------------|-------|--------|--------|
| 0 | 300 | Night action UI / waiting UI | Current content fades out | `AppCurves.exit` |
| 0 | 300 | Wave indicator | Previous wave dot fills, next wave dot highlights with `AppColors.tallowGold` pulse | `AppCurves.standard` |
| 300 | -- | Narrator | Wave narrator cue fires (sound + haptic) | -- |
| 300 | 500 | Night action UI / waiting UI | New wave content fades in (action prompt for active player, or updated waiting screen) | `AppCurves.enter` |

**Reduced motion:** Instant swap. Wave indicator updates without animation. Total: 100ms.

---

#### T-09: Disconnect Overlay

| Property | Value |
|----------|-------|
| Total duration | 600ms in, holds until resolved, 600ms out |
| Trigger | Server detects player disconnect |
| Narrator text | none |
| Haptic | `AppHaptics.tapMedium` on appearance |
| Sound | `SoundCues.disconnect` at offset 0ms |

**Timeline (in):**

| Offset (ms) | Duration (ms) | Layer | Action | Easing |
|-------------|---------------|-------|--------|--------|
| 0 | 400 | Scrim | Full-screen scrim fades in at `AppOpacity.scrim` | `AppCurves.standard` |
| 0 | 400 | Game UI | All interactive elements become non-interactive (disabled state) | -- |
| 200 | 400 | Overlay card | Disconnect message card slides up from bottom, opacity 0 -> 1 | `AppCurves.enter` |
| 200 | -- | Ambient | Current ambience volume ducks to 30% over 400ms | linear |

**Timeline (out -- on reconnect):**

| Offset (ms) | Duration (ms) | Layer | Action | Easing |
|-------------|---------------|-------|--------|--------|
| 0 | -- | Sound | `SoundCues.reconnect` plays | -- |
| 0 | -- | Haptic | `AppHaptics.confirmationPulse` | -- |
| 0 | 400 | Overlay card | "They have returned!" text swap, then card slides down | `AppCurves.exit` |
| 200 | 400 | Scrim | Fades out | `AppCurves.standard` |
| 200 | -- | Ambient | Volume restores to 100% over 400ms | linear |
| 400 | -- | Game UI | Re-enable interactivity, resume timers | -- |

**Reduced motion:** Overlay appears/disappears instantly with no slide. Scrim crossfades over 200ms.

---

### Theatrical Moment Sequences

Choreographed multi-beat moments that are the emotional peaks of the game. Each is a self-contained sequence with synchronized visual, haptic, and sound elements.

---

#### M-01: Role Reveal -- "The Envelope Moment"

The signature hero moment. A sealed card arrives face-down. The player taps to break the seal and discover their role. Personal, tactile, secretive.

| Property | Value |
|----------|-------|
| Total duration | 400ms entry + player-initiated flip (600ms) + 400ms settle = ~1400ms |
| Trigger | Night phase begins after T-01 game start cinematic |
| Context | Each player sees this on their own device, independently |

**Phase 1: Card Entry (automatic, no player action needed)**

| Offset (ms) | Duration (ms) | Layer | Action | Easing |
|-------------|---------------|-------|--------|--------|
| 0 | 400 | Card | Card slides in from bottom of screen: translateY(+200dp) -> 0, opacity 0.0 -> 1.0, scale 0.85 -> 1.0 | `AppCurves.enter` |
| 0 | 400 | Card shadow | `AppShadows.overlay` fades in | `AppCurves.enter` |
| 200 | 300 | Prompt | "Tap to reveal your role" text fades in below card, `AppTextStyles.body`, `AppColors.parchmentMuted` | `AppCurves.enter` |

Card displays face-down: `AppColors.surface` with decorative card back pattern, `AppRadius.xxl` (24dp), centered on screen. Card aspect ratio: 3:4 portrait (240dp x 320dp on phone, scales proportionally).

**Phase 2: Card Flip (player taps card)**

| Offset (ms) | Duration (ms) | Layer | Action | Easing |
|-------------|---------------|-------|--------|--------|
| 0 | -- | Haptic | `AppHaptics.dramaticReveal` fires | -- |
| 0 | -- | Sound | `SoundCues.waxSealBreak` plays | -- |
| 0 | 200 | Prompt | "Tap to reveal" fades out | `AppCurves.exit` |
| 0 | 300 | Card | 3D Y-axis rotation 0deg -> 90deg (card turns edge-on) | `AppCurves.dramatic` (first half) |
| 150 | 150 | Glow | `AppGlows.vision` begins intensifying: opacity 0.12 -> 0.20 | `AppCurves.standard` |
| 300 | -- | Card content | At 90deg (edge-on, invisible): swap card back for card front (role art, name, team, description) | instant |
| 300 | 300 | Card | 3D Y-axis rotation 90deg -> 0deg (card face revealed) | `AppCurves.dramatic` (second half) |
| 300 | 300 | Card border | Border color transitions to team accent color (`AppColors.teamVillage` / `teamWerewolf` / `teamIndependent`) | `AppCurves.standard` |

Total flip: 600ms (`AppDurations.theatrical`).

**Phase 3: Settle (automatic after flip)**

| Offset (ms) | Duration (ms) | Layer | Action | Easing |
|-------------|---------------|-------|--------|--------|
| 0 | 400 | Team glow | Team glow (`AppGlows.teamVillage` / `teamWerewolf` / `teamIndependent`) fades in around card | `AppCurves.standard` |
| 0 | 300 | Glow | `AppGlows.vision` settles back: opacity 0.20 -> 0.12 | `AppCurves.standard` |
| 200 | 200 | Role info | Role name and team badge fade in below the card art | `AppCurves.enter` |

**Card front layout (top to bottom):**
- Role illustration (hero art, fills upper 60% of card)
- Role name in `AppTextStyles.heading1`
- Team badge: team color background pill with team name in `AppTextStyles.label`
- Brief role description in `AppTextStyles.bodySmall`

**Reduced motion:** Card appears face-down instantly (no slide). On tap, card cross-fades front/back over 300ms (no 3D rotation). Team glow appears instantly.

---

#### M-02: Night Action Card Peek

When a player views another player's card or a center card during the night (Seer, Robber, Werewolf lone peek, Doppelganger initial peek). Uses the same visual language as Role Reveal but at smaller scale and without the entry animation.

| Property | Value |
|----------|-------|
| Total duration | 600ms flip + 400ms hold |
| Trigger | Player selects a target and server returns peek result |
| Context | Night action result reveal |

**Timeline:**

| Offset (ms) | Duration (ms) | Layer | Action | Easing |
|-------------|---------------|-------|--------|--------|
| 0 | -- | Haptic | `AppHaptics.tapMedium` | -- |
| 0 | -- | Sound | `SoundCues.cardPeek` plays | -- |
| 0 | 300 | Target card | Card in grid/slot flips: 3D Y-axis 0deg -> 90deg | `AppCurves.dramatic` |
| 0 | 300 | Glow | `AppGlows.vision` appears on peeked card | `AppCurves.standard` |
| 300 | -- | Card content | Swap face-down for face-up (showing peeked role) | instant |
| 300 | 300 | Target card | 3D Y-axis 90deg -> 0deg | `AppCurves.dramatic` |
| 600 | -- | -- | Card holds face-up until player dismisses or wave ends | -- |

Card peek display: smaller than role reveal card. Shows role icon + role name + team accent border. Uses same `AppRadius.xxl` but at 120dp x 160dp scale.

**For Robber:** After peek, card slides from target position to player's position (300ms, `AppCurves.dramatic`) to visually represent the swap.

**For center card peeks (Seer option B, Werewolf lone):** Cards flip in their center card slots. If two center cards are peeked (Seer), they flip simultaneously.

**Reduced motion:** Instant crossfade reveal (200ms). No 3D rotation.

---

#### M-03: Vote Tally Build

The controlled progressive reveal of voting results. Builds tension through paced visual accumulation.

| Property | Value |
|----------|-------|
| Total duration | 6000ms (`AppDurations.voteBuild`) |
| Trigger | T-04 transition complete, tally UI visible |
| Context | Vote reveal phase |

**Layout:** Horizontal bar chart. Each player has a row: avatar (small, 32dp) + name on left, vote bar extending right. Bars start at zero width.

**Sequence logic:**
- Total votes = N (one per player who submitted)
- Per-vote delay = `AppDurations.voteBuild` / (N + 2). The +2 adds breathing room for the opening pause and final emphasis.
- Votes appear in random server-shuffled order (not grouped by target)
- The vote that pushes a player to "most votes" is always last or second-to-last (server orders this for maximum drama)

**Per-vote beat:**

| Offset (ms) | Duration (ms) | Layer | Action | Easing |
|-------------|---------------|-------|--------|--------|
| 0 | -- | Haptic | `AppHaptics.tallyTick` | -- |
| 0 | -- | Sound | `SoundCues.tallyTick` | -- |
| 0 | 300 | Vote bar | Target player's bar extends by one vote unit, width grows | `AppCurves.bounce` |
| 0 | 200 | Vote count | Number next to bar increments | `AppCurves.standard` |
| 0 | 200 | Voter indicator | Small voter avatar appears at the end of the bar (optional, can be dots instead) | `AppCurves.enter` |

**Final vote emphasis:** The last vote (which often decides the outcome) gets a 400ms delay before it, and the bar extension uses `AppCurves.dramatic` instead of `AppCurves.bounce`. Haptic is `AppHaptics.tapMedium` instead of `tapLight`.

**Tie handling:** If two or more players are tied for highest at the end, all tied bars pulse `AppColors.tallowGold` simultaneously (2 pulses, 400ms cycle).

**Reduced motion:** All bars fill simultaneously over 1000ms. No stagger, no per-vote animation. Vote counts display final values.

---

#### M-04: Elimination Announcement -- "The Death"

Fun but fast. Dramatic without killing momentum.

| Property | Value |
|----------|-------|
| Total duration | 2000ms per eliminated player |
| Trigger | T-05 transition complete |
| Narrator text | "[Player name] has been eliminated." |
| Context | A player received the most votes (>= 2 threshold) |

**Timeline:**

| Offset (ms) | Duration (ms) | Layer | Action | Easing |
|-------------|---------------|-------|--------|--------|
| 0 | -- | Sound | `SoundCues.eliminationReveal` plays | -- |
| 0 | -- | Haptic | `AppHaptics.elimination` fires | -- |
| 0 | 600 | Glow | `AppGlows.bloodVignette` fades in across full screen | `AppCurves.dramatic` |
| 0 | 600 | Player name | Eliminated player's name appears in `AppTextStyles.displayXl`, scale 0.8 -> 1.0, opacity 0 -> 1 | `AppCurves.dramatic` |
| 600 | -- | -- | Hold beat -- 400ms | -- |
| 1000 | 600 | Role card | Small role card fades in below name showing eliminated player's actual role (card flip, same as M-02 but inline) | `AppCurves.dramatic` |
| 1000 | -- | Sound | `SoundCues.cardPeek` plays for role reveal | -- |
| 1600 | -- | Narrator | Narrator cue fires: "[Name] was the [Role]." | -- |

**Hunter chain variant:** If the eliminated player holds the Hunter card:
- After the initial 2000ms, a 600ms pause
- Then: "The Hunter takes aim..." narrator text (400ms)
- Second elimination sequence plays for the Hunter's vote target (same M-04 structure, another 2000ms)
- Total for Hunter chain: ~5000ms

**Tie elimination (multiple players die):** Each player's elimination plays sequentially with a 400ms gap between them. Names are revealed in vote-count order (highest first; if truly tied, alphabetical).

**Reduced motion:** Name and role appear statically. Blood vignette appears at full opacity instantly. No scale animations. Total: 1200ms.

---

#### M-05: No Elimination -- "Silence"

When no player receives >= 2 votes.

| Property | Value |
|----------|-------|
| Total duration | 1800ms |
| Trigger | T-05 transition complete, no player meets death threshold |
| Narrator text | "No one was eliminated." |

**Timeline:**

| Offset (ms) | Duration (ms) | Layer | Action | Easing |
|-------------|---------------|-------|--------|--------|
| 0 | 600 | Glow | `AppGlows.noDeathWash` fades in | `AppCurves.standard` |
| 0 | -- | Sound | `SoundCues.noElimination` plays -- solemn, not triumphant | -- |
| 0 | -- | Haptic | `AppHaptics.tapMedium` | -- |
| 200 | 400 | Text | "No one was eliminated." appears in `AppTextStyles.display`, `AppColors.noDeathBlue`, opacity 0 -> 1 | `AppCurves.enter` |
| 200 | -- | Narrator | Narrator cue fires | -- |
| 1200 | -- | -- | Hold beat -- 600ms | -- |

**Reduced motion:** Text appears instantly with `AppGlows.noDeathWash` at full opacity. Total: 1200ms.

---

#### M-06: Win/Loss Announcement

Team result headline followed by personal outcome. Both matter equally per vision brief.

| Property | Value |
|----------|-------|
| Total duration | 2000ms |
| Trigger | T-06 transition begins (Results phase entry) |
| Narrator text | "[Team] wins!" |

**Timeline:**

| Offset (ms) | Duration (ms) | Layer | Action | Easing |
|-------------|---------------|-------|--------|--------|
| 0 | -- | Sound | `SoundCues.winFanfare` (if player won) or `SoundCues.lossSomber` (if player lost) | -- |
| 0 | -- | Haptic | `AppHaptics.winCelebration` (if won) or `AppHaptics.lossCommiserate` (if lost) | -- |
| 0 | 600 | Team headline | "[TEAM] WINS!" in `AppTextStyles.displayXl`, team accent color, scale 0.7 -> 1.0, opacity 0 -> 1 | `AppCurves.bounce` |
| 0 | 600 | Background accent | Subtle team color wash behind headline (team color at 6% opacity, full-screen) | `AppCurves.standard` |
| 600 | -- | -- | Hold beat -- 400ms | -- |
| 1000 | 400 | Personal outcome | "You Win." / "You Lose." in `AppTextStyles.heading1`, `AppColors.parchment`, opacity 0 -> 1, centered below headline | `AppCurves.enter` |
| 1400 | 600 | Results table | Player result summary begins fading in below (progressive disclosure) | `AppCurves.enter` |

**Multiple winners (Tanner + Village both win):** Headline shows both ("VILLAGE WINS! TANNER WINS!") or splits into two lines. Personal outcome reflects the player's own team result.

**No team wins:** Headline reads "NO ONE WINS" in `AppColors.parchmentMuted`. No fanfare sound; play `SoundCues.lossSomber`.

**Reduced motion:** Headline and personal outcome appear simultaneously with no scale animation. Crossfade over 300ms.

---

#### M-07: Team Change — "You Crossed Over"

When a player's team changes during a night action (specifically: Doppelganger follow-up reveals a card from a different team). A brief atmospheric shift that signals the identity change.

| Property | Value |
|----------|-------|
| Total duration | 1800ms |
| Trigger | Server returns a night action result that changes the player's team |
| Context | Doppelganger-as-Robber steals a Werewolf card; any future role that causes mid-action team change |

**Timeline:**

| Offset (ms) | Duration (ms) | Layer | Action | Easing |
|-------------|---------------|-------|--------|--------|
| 0 | -- | Haptic | `AppHaptics.dramaticReveal` (H-07) fires | -- |
| 0 | 600 | Glow | `AppGlows.candle` tint shifts from `AppColors.tallowGold` to new team color (e.g., `AppColors.teamWerewolf`) | `AppCurves.dramatic` |
| 0 | 600 | Glow | New team glow (e.g., `AppGlows.teamWerewolf`) pulses once across full screen: opacity 0 → 0.15 → 0 | `AppCurves.dramatic` |
| 0 | 400 | Info strip | Role info strip border color transitions to new team accent | `AppCurves.standard` |
| 200 | 400 | Text | "You are now on the {team} team" appears in team accent color, `AppTextStyles.heading3`, opacity 0 → 1 | `AppCurves.enter` |
| 1000 | 800 | Glow | `AppGlows.candle` tint returns to `AppColors.tallowGold` | `AppCurves.standard` |
| 1000 | 400 | Text | Team text fades out, opacity 1 → 0 | `AppCurves.exit` |
| 1200 | 600 | Info strip | Border remains at new team color (permanent for rest of night) | -- |

**Reduced motion:** No glow shift. Team text appears statically for 1500ms. Info strip border changes instantly. Total: 1500ms.

---

### Standard UI Motion

Everyday transitions that are not phase-level cinematic moments. These maintain the quality bar without competing with theatrical beats.

| ID | Element | Trigger | Property | From | To | Duration | Easing | Notes |
|----|---------|---------|----------|------|-----|----------|--------|-------|
| UI-01 | Screen sub-state | Content changes within a phase | opacity, position | current | next | `AppDurations.crossfade` (400ms) | `AppCurves.standard` | E.g., night waiting -> night action within same phase |
| UI-02 | Button press | Pointer down | color | normal | pressed (darken 15%) | `AppDurations.micro` (100ms) | `AppCurves.standard` | Per `AppColors.statePressed` |
| UI-03 | Button release | Pointer up | color | pressed | normal | `AppDurations.fast` (200ms) | `AppCurves.standard` | |
| UI-04 | Selection glow appear | Element selected | boxShadow | none | `AppGlows.selection` | `AppDurations.fast` (200ms) | `AppCurves.standard` | Per design tokens |
| UI-05 | Selection glow remove | Element deselected | boxShadow | `AppGlows.selection` | none | `AppDurations.fast` (200ms) | `AppCurves.standard` | |
| UI-06 | Tooltip appear | Long-press or hover | opacity, translateY | 0, +4dp | 1, 0 | `AppDurations.fast` (200ms) | `AppCurves.enter` | Uses `AppColors.surfaceElevated` + `AppShadows.elevated` |
| UI-07 | Tooltip dismiss | Tap elsewhere | opacity | 1 | 0 | `AppDurations.micro` (100ms) | `AppCurves.exit` | |
| UI-08 | Bottom sheet appear | Sheet triggered | translateY | +100% | 0 | `AppDurations.standard` (300ms) | `AppCurves.enter` | With scrim backdrop at `AppOpacity.scrim` |
| UI-09 | Bottom sheet dismiss | Swipe down or tap scrim | translateY | 0 | +100% | `AppDurations.standard` (300ms) | `AppCurves.exit` | |
| UI-10 | Modal overlay appear | Modal triggered | opacity, scale | 0, 0.95 | 1, 1.0 | `AppDurations.standard` (300ms) | `AppCurves.enter` | Scrim at `AppOpacity.scrim` |
| UI-11 | Modal overlay dismiss | Close action | opacity, scale | 1, 1.0 | 0, 0.95 | `AppDurations.fast` (200ms) | `AppCurves.exit` | |
| UI-12 | Loading shimmer | Content loading | opacity | 0.05 | 0.15 | 1500ms (loop) | `AppCurves.standard` | Atmospheric shimmer on `AppColors.surface` placeholders |
| UI-13 | Player card appear (stagger) | Grid populates | opacity, translateY | 0, +8dp | 1, 0 | `AppDurations.standard` (300ms) | `AppCurves.enter` | 50ms stagger delay between cards |
| UI-14 | Ready state toggle | Player taps ready/unready | scale | 1.0 -> 1.08 -> 1.0 | -- | `AppDurations.fast` (200ms) | `AppCurves.bounce` | Subtle pop on state change |
| UI-15 | Error toast appear | Error condition | translateY, opacity | -100%, 0 | 0, 1 | `AppDurations.standard` (300ms) | `AppCurves.enter` | Slides down from top. Auto-dismiss after 4000ms. |
| UI-16 | Error toast dismiss | Timeout or swipe | translateY, opacity | 0, 1 | -100%, 0 | `AppDurations.fast` (200ms) | `AppCurves.exit` | |
| UI-17 | CTA glow pulse | Primary CTA visible | boxShadow opacity | 0.15 | 0.25 | 3000ms (loop) | sinusoidal | Per `AppGlows.cta` definition in design tokens |
| UI-18 | Timer color shift | Timer threshold crossed | color | previous ramp color | next ramp color | `AppDurations.crossfade` (400ms) | `AppCurves.standard` | Per timer color ramp in design tokens |
| UI-19 | Timer pulse (urgent) | Timer below 25% | opacity | 0.8 | 1.0 | 2000ms (loop) | sinusoidal | `AppColors.timerUrgent` |
| UI-20 | Timer pulse (critical) | Timer below 10% | opacity | 0.7 | 1.0 | 800ms (loop) | sinusoidal | `AppColors.timerCritical` |
| UI-21 | Tap-to-reveal overlay | Player taps to show hidden info | opacity | 0.0 | 1.0 | `AppDurations.fast` (200ms) | `AppCurves.enter` | Role reminder, vote selection |
| UI-22 | Tap-to-reveal hide | Player taps again or timeout (3s) | opacity | 1.0 | 0.0 | `AppDurations.fast` (200ms) | `AppCurves.exit` | Auto-hides after 3000ms |
| UI-23 | Wave dot fill | Night wave completes | fill opacity | 0.2 | 1.0 | `AppDurations.standard` (300ms) | `AppCurves.standard` | Dot color: `AppColors.tallowGold` |
| UI-24 | Wave dot active pulse | Current wave active | scale | 1.0 -> 1.2 -> 1.0 | -- | 2000ms (loop) | sinusoidal | Active wave dot gently pulses |
| UI-25 | Vote counter increment | New vote submitted | scale | 1.0 -> 1.15 -> 1.0 | -- | `AppDurations.fast` (200ms) | `AppCurves.bounce` | "4/6 have chosen" counter |
| UI-26 | Voting pressure: background darken | Timer approaches end | background opacity | 0.0 | 0.08 | over final 30% of timer | linear | Subtle darkening overlay |
| UI-27 | Voting pressure: particle intensify | Timer approaches end | particle count, speed | normal | 1.5x count, 1.3x speed | over final 30% of timer | linear | Embers and fog increase subtly |

---

### Haptic Pattern Vocabulary

Every haptic feedback pattern in the game. All patterns use Flutter's `HapticFeedback` API or custom sequences built from it.

| ID | Name | Dart Reference | Pattern | Intensity | Usage |
|----|------|---------------|---------|-----------|-------|
| H-01 | Tap Light | `AppHaptics.tapLight` | `HapticFeedback.lightImpact()` | Light | Button press, minor UI interaction, tooltip |
| H-02 | Tap Medium | `AppHaptics.tapMedium` | `HapticFeedback.mediumImpact()` | Medium | Important action confirmation, card peek start, phase shift accent |
| H-03 | Tap Heavy | `AppHaptics.tapHeavy` | `HapticFeedback.heavyImpact()` | Heavy | Elimination reveal impact |
| H-04 | Selection Click | `AppHaptics.selectionClick` | `HapticFeedback.selectionClick()` | Ultra-light | Vote target selection/change, toggle switch, list selection |
| H-05 | Confirmation Pulse | `AppHaptics.confirmationPulse` | `[medium, 80ms pause, light]` | Medium-Light | Vote lock-in (timer expires with selection), action submission confirmed by server, reconnect |
| H-06 | Phase Shift | `AppHaptics.phaseShift` | `[medium, 120ms pause, light]` | Medium-Light | Every phase transition (T-01 through T-07). Signals game state advancement. |
| H-07 | Dramatic Reveal | `AppHaptics.dramaticReveal` | `[light, 100ms, light, 100ms, medium]` | Ascending crescendo | Role reveal card flip (M-01), elimination role reveal |
| H-08 | Win Celebration | `AppHaptics.winCelebration` | `[light, 60ms, light, 60ms, light, 60ms, heavy]` | Rapid crescendo | Win announcement (M-06). Three quick taps building to one strong tap. |
| H-09 | Loss Commiserate | `AppHaptics.lossCommiserate` | `[medium, 200ms, light]` | Diminishing | Loss announcement (M-06). One medium thud settling into a soft tap. |
| H-10 | Tally Tick | `AppHaptics.tallyTick` | `HapticFeedback.lightImpact()` | Light | Each vote increment during tally build (M-03) |
| H-11 | Narrator Beat | `AppHaptics.narratorBeat` | `HapticFeedback.mediumImpact()` | Medium | Narrator cue playback (accompanies audio). One definitive pulse. |
| H-12 | Elimination | `AppHaptics.elimination` | `[heavy, 150ms, medium]` | Heavy-Medium | Elimination announcement impact (M-04). A strong beat followed by a settling tap. |
| H-13 | Fidget Response | `AppHaptics.fidgetResponse` | `HapticFeedback.lightImpact()` | Light | Night waiting fidget interactions (ember poke, smoke swirl, flame play) |

**Custom sequence notation:** `[type, delay_ms, type, delay_ms, type]` -- each type is `light`, `medium`, or `heavy`. Delays are pauses between impacts.

**Implementation:** Wrap sequences in a `Future`-based chain:
```
haptic(light) -> await Future.delayed(100ms) -> haptic(light) -> await Future.delayed(100ms) -> haptic(medium)
```

---

### Sound Cue Vocabulary

All discrete sound effects (non-ambient). Sound cues are tied to moments and actions, never to specific roles. The narrator persona system (pluggable voice/tone) is separate; these are UI/game sounds.

| ID | Name | Dart Reference | Trigger | Character Description | Duration Range | Constraints |
|----|------|---------------|---------|----------------------|---------------|-------------|
| S-01 | Game Start | `SoundCues.gameStart` | T-01 begins | Low resonant chime, like a distant church bell or gong. Warm, ominous, inviting. Sets the tone. | 1500-2500ms | Plays once. Tail can overlap with narrator. |
| S-02 | Phase Transition | `SoundCues.phaseTransition` | T-02, T-03 begin | Soft atmospheric whoosh, like wind shifting. Brief, not dramatic. | 600-1000ms | Distinct from game start. Lower energy. |
| S-03 | Voting Start | `SoundCues.votingStart` | T-03 begins | Subtle tension note, single low string pluck or muted bell. Signals gravity without alarm. | 400-800ms | Should feel "quiet intensity" not "warning". |
| S-04 | Wax Seal Break | `SoundCues.waxSealBreak` | M-01 card flip tap | Crisp tactile snap -- a wax seal cracking, parchment tearing. Physical, satisfying. | 200-400ms | The hero sound. Must feel premium and tactile. |
| S-05 | Card Peek | `SoundCues.cardPeek` | M-02 card peek reveal | Softer version of wax seal -- paper slide or light parchment rustle. | 150-300ms | Quieter than S-04. Used frequently during night. |
| S-06 | Votes Locked | `SoundCues.votesLocked` | T-04 begins | Low thud or stamp -- like a gavel or seal pressed into wax. Finality. | 300-500ms | Signals "no more changes". Definitive. |
| S-07 | Tally Tick | `SoundCues.tallyTick` | Each vote in M-03 | Light wooden tick, like a bead on an abacus or a pebble in a bowl. | 50-150ms | Must work at rapid succession (300-700ms apart). No tail overlap. |
| S-08 | Verdict Drum | `SoundCues.verdictDrum` | T-05 begins | Low rolling drum or tension swell. Builds anticipation for who dies. | 1000-1500ms | Fades into silence before elimination reveal. |
| S-09 | Elimination Reveal | `SoundCues.eliminationReveal` | M-04 begins | Sharp dramatic sting -- a sudden chord, not horror but theatrical. Think campfire story climax. | 400-800ms | Pairs with `AppGlows.bloodVignette`. Must feel fun, not grim. |
| S-10 | No Elimination | `SoundCues.noElimination` | M-05 begins | Hollow wind, a moment of emptiness. Solemn but brief. | 800-1200ms | Cold and still, matching `AppGlows.noDeathWash`. Not sad, just... quiet. |
| S-11 | Win Fanfare | `SoundCues.winFanfare` | M-06 (player won) | Warm triumphant chord -- tavern celebration energy, not orchestral. Brief and bright. | 800-1200ms | Must feel earned but not overblown. |
| S-12 | Loss Somber | `SoundCues.lossSomber` | M-06 (player lost) | Muted low chord, settling downward. Not crushing, just a gentle "oh well." | 800-1200ms | Players should still feel good about playing. Not punitive. |
| S-13 | Play Again | `SoundCues.playAgain` | T-07 begins | Quick warm chime -- reshuffle energy, "let's go again." | 300-500ms | Upbeat and quick. New round energy. |
| S-14 | Disconnect | `SoundCues.disconnect` | T-09 overlay appears | Low hollow tone, like a candle guttering. Something is missing. | 400-600ms | Not alarming. Atmospheric concern. |
| S-15 | Reconnect | `SoundCues.reconnect` | T-09 overlay dismisses | Warm return tone -- flame re-igniting. Relief. | 300-500ms | Pairs with `AppHaptics.confirmationPulse`. |
| S-16 | Narrator Cue | `SoundCues.narratorCue` | Any narrator text appears | Not a UI sound -- this is the narrator voice audio itself. Placeholder for the pluggable persona audio system. | varies | Duration determined by narrator persona TTS/pre-recorded length. |
| S-17 | Fidget Ember | `SoundCues.fidgetEmber` | Player pokes ember in night waiting | Tiny ember crackle, like a fireplace pop. Satisfying. | 100-200ms | Very quiet (50% volume). Should not distract other players. |
| S-18 | Fidget Smoke | `SoundCues.fidgetSmoke` | Player swirls smoke in night waiting | Soft wispy exhale. | 200-400ms | Very quiet (50% volume). Ambient, not assertive. |
| S-19 | Timer Warning | `SoundCues.timerWarning` | Timer crosses 10% remaining | Single muted tick or subtle bell. Alert without alarm. | 100-200ms | Plays once at threshold. Not repeated. |

---

### Ambient Soundscape Vocabulary

Continuous background audio per game phase. Ambient soundscapes crossfade during phase transitions (see T-XX timelines for crossfade durations). All ambience plays at 40% master volume to stay beneath UI sounds and narrator.

| ID | Phase | Dart Reference | Layers | Character | Loop Duration | Constraints |
|----|-------|---------------|--------|-----------|---------------|-------------|
| A-01 | Lobby | `Ambience.lobby` | Tavern murmur (distant voices), crackling fireplace, occasional glass clink, wooden creaks | Warm, social, anticipatory. The sound of friends gathering at a tavern. Convivial, not busy. | 60-90s seamless loop | Volume peaks at 40%. Murmur should be indistinct (no recognizable words). |
| A-02 | Night | `Ambience.night` | Crickets, distant owl call (sparse), wind through leaves, faint wolf howl (very distant, max 1 per loop) | Mysterious, still, expectant. A village at midnight. Quiet enough to hear your own thoughts. | 90-120s seamless loop | Quietest ambience (30% relative to lobby). Wolf howl must be so distant it could be imagined. |
| A-03 | Discussion | `Ambience.discussion` | Dawn chorus (sparse birds), light wind, very subtle tension drone (low frequency, barely audible) | Stirring, transitional. Night is over, something is about to happen. Slightly unsettled. | 60-90s seamless loop | Tension drone at max 10% of total ambience volume. Birds should be sparse, not a chorus. |
| A-04 | Voting | `Ambience.voting` | Near-silence with subtle low-frequency hum, occasional distant heartbeat-like pulse (1 every 8-12s), wind dying down | Tense, hushed. The room holds its breath. Pressure without panic. | 60-90s seamless loop | Minimal layers. The near-silence IS the design choice. Heartbeat pulse is felt more than heard. |
| A-05 | Results | `Ambience.results` | Warm settling tone (sustained low pad), distant fire crackle, faint return of tavern warmth | Reflective, resolving. The story is told, the dust settles. Warm return after tension. | 60-90s seamless loop | Gradually warmer over loop duration. Should feel like returning to safety. |

**Crossfade behavior:** All phase ambience crossfades are linear (not eased). The outgoing track fades to 0% while the incoming track fades to target volume. Crossfade duration is specified in each phase transition (T-XX) timeline. Typical: 800-1500ms.

**Reduced motion / quiet mode:** All ambience can be disabled independently from sound effects via a user setting. When disabled, no ambient audio plays. Sound cues and narrator still function.

---

### Fidget Interaction Motion

Night waiting ambient fidget elements that give all players something to do with their phone (concealing who has an active night action). These are fun, low-stakes, and purely atmospheric.

| ID | Interaction | Gesture | Visual Response | Duration | Sound | Haptic | Constraints |
|----|------------|---------|----------------|----------|-------|--------|-------------|
| F-01 | Poke Embers | Tap on screen | 5-8 ember particles burst from tap point, scatter upward with gravity curve, fade over 800ms | 800ms | `SoundCues.fidgetEmber` | `AppHaptics.fidgetResponse` | Ember color: `AppColors.tallowGold` at opacity 0.3-0.6. Particles use same physics as `AppParticles.embers` but faster initial velocity (40-60 dp/s). |
| F-02 | Swirl Smoke | Drag across screen | Smoke trail follows finger path, persists 1200ms after finger lifts, dissipates with diffusion | 1200ms after release | `SoundCues.fidgetSmoke` (on finger lift) | `AppHaptics.fidgetResponse` (on drag start) | Smoke color: `AppColors.parchment` at opacity 0.04-0.08. Trail width: 30-50dp. Max 3 concurrent trails. |
| F-03 | Candle Flame | Tap and hold on candle glow area | `AppGlows.candle` reacts: radius expands by 15%, opacity increases by 0.04 while held. On release, settles back over 600ms. | Hold duration + 600ms settle | none | `AppHaptics.fidgetResponse` (on hold start) | Only works if `AppGlows.candle` is visible (night phase). Settle easing: `AppCurves.standard`. |

---

## Usage Rules

### Motion

- DO: Use `AppDurations.standard` (300ms) as the fallback for any transition not explicitly listed in this document.
- DO: Use `AppCurves.dramatic` for all theatrical moments (anything in the "Theatrical Moment Sequences" section) and phase transitions.
- DO: Play phase transitions to completion before accepting user input on the new phase. Transitions are non-interruptible.
- DO: Provide reduced-motion alternatives for every animation. Reduced motion should use instant cuts or simple crossfades, never eliminate information.
- DO: Stagger element entry when multiple items appear simultaneously (50ms per item, per UI-13).
- DO NOT: Use `AppDurations.theatrical` (600ms) or `AppDurations.cinematic` (2500ms) for standard UI transitions. They are reserved for the moments defined in this document.
- DO NOT: Chain more than 2 sequential animations on a single element outside of theatrical moment sequences.
- DO NOT: Interrupt a theatrical moment sequence (M-01 through M-07) with user input. These play to completion.
- DO NOT: Animate elements that are off-screen or obscured.
- DO NOT: Add easing to particle system motion. Particles use linear or physics-based movement only.

### Haptics

- DO: Fire haptics at the START of the associated action, not at completion.
- DO: Use `AppHaptics.selectionClick` (H-04) for any reversible selection change (voting, night action targeting).
- DO: Use `AppHaptics.phaseShift` (H-06) for every phase transition without exception.
- DO: Use `AppHaptics.narratorBeat` (H-11) every time a narrator audio cue plays.
- DO NOT: Fire haptics more frequently than every 80ms. If two haptic events would overlap, drop the lower-priority one.
- DO NOT: Use `AppHaptics.tapHeavy` (H-03) for anything other than `AppHaptics.elimination` sub-pattern. Heavy impact is reserved for elimination.
- DO NOT: Fire haptics on passive state changes (timer color ramp, particle system, ambient glow changes). Haptics are for player actions and game events.
- DO NOT: Create custom haptic patterns outside this vocabulary. All haptic feedback in the app must use one of H-01 through H-13.

### Sound

- DO: Normalize all audio assets to -16 LUFS. Playback volume controls the mix hierarchy: Narrator (100%) > Sound Cues (70%) > Ambient (40% default). Fidget sounds at 50% of Sound Cue volume. These percentages are the single source of truth for relative loudness.
- DO: Crossfade ambient tracks during phase transitions (never hard-cut).
- DO: Allow sound cues to overlap with ambient (they sit on separate audio channels).
- DO: Provide independent volume controls for: Narrator, Sound Effects, Ambient (three sliders, future settings screen).
- DO NOT: Play role-specific sound effects. Sounds are tied to actions (peek, swap, reveal) and moments (phase transitions, elimination), never to which role the player has.
- DO NOT: Play the same sound cue more than once within 200ms. Debounce concurrent triggers.
- DO NOT: Allow ambient loops to have audible seams. All ambient tracks must be seamless loops.
- DO NOT: Play sound cues during reduced-motion mode unless the user has explicitly kept sound enabled. Respect system silent mode.

---

## Pairing Rules

### Haptic-Sound Pairings

Every haptic event has a corresponding sound event. They fire simultaneously (offset 0ms between them). Neither should fire without the other except when sound is muted.

| Haptic | Paired Sound | Context |
|--------|-------------|---------|
| `AppHaptics.tapLight` (H-01) | no sound | Button feedback is haptic-only to avoid audio clutter |
| `AppHaptics.tapMedium` (H-02) | varies by context | Paired with contextual sound (card peek, votes locked, etc.) |
| `AppHaptics.selectionClick` (H-04) | no sound | Selection changes are haptic-only (frequent, would be noisy) |
| `AppHaptics.confirmationPulse` (H-05) | `SoundCues.reconnect` (in reconnect context) | Only has paired sound in reconnect; otherwise haptic-only |
| `AppHaptics.phaseShift` (H-06) | `SoundCues.phaseTransition` or context-specific (game start, voting start) | Phase shift always has a sound, but the specific sound varies by transition |
| `AppHaptics.dramaticReveal` (H-07) | `SoundCues.waxSealBreak` (role reveal) or `SoundCues.cardPeek` (night peek) | The reveal haptic always pairs with a reveal sound |
| `AppHaptics.winCelebration` (H-08) | `SoundCues.winFanfare` | Always together |
| `AppHaptics.lossCommiserate` (H-09) | `SoundCues.lossSomber` | Always together |
| `AppHaptics.tallyTick` (H-10) | `SoundCues.tallyTick` | Always together, one pair per vote |
| `AppHaptics.narratorBeat` (H-11) | `SoundCues.narratorCue` | Always together -- narrator audio IS the paired sound |
| `AppHaptics.elimination` (H-12) | `SoundCues.eliminationReveal` | Always together |
| `AppHaptics.fidgetResponse` (H-13) | `SoundCues.fidgetEmber` or `SoundCues.fidgetSmoke` | Paired with fidget-specific sound |

### Glow-Motion Pairings

Atmospheric glows and their associated motion contexts. When a glow is active, certain motion behaviors are expected.

| Glow | Required Motion Context | Notes |
|------|------------------------|-------|
| `AppGlows.candle` | `AppParticles.embers` must be active | Candle glow without embers feels dead. Always pair on night screens. |
| `AppGlows.vision` | Card flip or card peek animation must be in progress or just completed | Vision glow only appears during reveal moments, never standalone. |
| `AppGlows.bloodVignette` | M-04 elimination sequence must be active | Blood vignette is exclusively an elimination effect. |
| `AppGlows.noDeathWash` | M-05 no-elimination sequence must be active | Mutually exclusive with `AppGlows.bloodVignette`. |
| `AppGlows.selection` | Selected element must have UI-04 glow appear animation applied | Selection glow uses the `AppDurations.fast` (200ms) appear animation, not instant. |
| Team glow pulse (M-07) | CAT5-TEAM-CHANGE must be active | Only fires during Doppelganger team-change moment. Team glow is a one-shot pulse, not persistent. |

### Phase-Ambience Pairings

Each phase has exactly one ambient soundscape. No phase uses silence; no phase uses another phase's ambience.

| Phase | Ambience | Particles Active |
|-------|----------|-----------------|
| Lobby | `Ambience.lobby` | `AppParticles.dust` only |
| Night | `Ambience.night` | `AppParticles.embers` + `AppParticles.dust` + `AppParticles.fog` |
| Discussion | `Ambience.discussion` | `AppParticles.embers` + `AppParticles.dust` |
| Voting | `Ambience.voting` | `AppParticles.embers` + `AppParticles.dust` + `AppParticles.fog` |
| Results | `Ambience.results` | `AppParticles.dust` only |

---

## Examples

### Dart: Haptic Sequence Execution

```dart
abstract final class AppHaptics {
  /// H-01: Light tap for button press
  static Future<void> tapLight() async {
    await HapticFeedback.lightImpact();
  }

  /// H-07: Dramatic reveal — ascending crescendo
  /// Pattern: [light, 100ms, light, 100ms, medium]
  static Future<void> dramaticReveal() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.mediumImpact();
  }

  /// H-08: Win celebration — rapid crescendo
  /// Pattern: [light, 60ms, light, 60ms, light, 60ms, heavy]
  static Future<void> winCelebration() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 60));
    await HapticFeedback.heavyImpact();
  }

  /// H-12: Elimination — heavy impact settling to medium
  /// Pattern: [heavy, 150ms, medium]
  static Future<void> elimination() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    await HapticFeedback.mediumImpact();
  }
}
```

### Dart: Phase Transition Orchestrator (Conceptual)

```dart
Future<void> executeTransition(PhaseTransition transition) async {
  // Fire haptic and sound simultaneously at offset 0
  AppHaptics.phaseShift();
  _audioEngine.play(transition.soundCue);

  // Fade out current phase UI
  await _currentPhaseController.fadeOut(
    duration: AppDurations.theatrical,
    curve: AppCurves.exit,
  );

  // Crossfade background
  _backgroundController.crossfadeTo(
    transition.targetPhaseBackground,
    duration: const Duration(milliseconds: 800),
    curve: AppCurves.standard,
  );

  // Crossfade ambient audio
  _audioEngine.crossfadeAmbience(
    to: transition.targetAmbience,
    duration: const Duration(milliseconds: 1200),
  );

  // Show narrator overlay if present
  if (transition.narratorText != null) {
    await Future.delayed(const Duration(milliseconds: 800));
    await _narratorOverlay.show(
      text: transition.narratorText!,
      style: AppTextStyles.narrator,
      duration: const Duration(milliseconds: 600),
      curve: AppCurves.enter,
    );
    AppHaptics.narratorBeat();
    _audioEngine.play(SoundCues.narratorCue);
    await Future.delayed(const Duration(milliseconds: 1000));
    await _narratorOverlay.hide(
      duration: const Duration(milliseconds: 400),
      curve: AppCurves.exit,
    );
  }

  // Update particles
  _particleEngine.transitionTo(transition.targetParticles);

  // Fade in new phase UI
  await _nextPhaseController.fadeIn(
    duration: AppDurations.standard,
    curve: AppCurves.enter,
  );
}
```

### Dart: Role Reveal Card Flip

```dart
Future<void> flipRoleCard() async {
  // Fire haptic and sound at flip start
  AppHaptics.dramaticReveal();
  _audioEngine.play(SoundCues.waxSealBreak);

  // Intensify vision glow
  _visionGlow.animateTo(
    opacity: 0.20,
    duration: const Duration(milliseconds: 300),
    curve: AppCurves.standard,
  );

  // First half: rotate to edge-on (0 -> 90 degrees)
  await _cardRotation.animateTo(
    pi / 2, // 90 degrees
    duration: const Duration(milliseconds: 300),
    curve: AppCurves.dramatic,
  );

  // Swap content at edge-on position
  setState(() => _showFront = true);

  // Second half: rotate to face-up (90 -> 0 degrees)
  await _cardRotation.animateTo(
    0,
    duration: const Duration(milliseconds: 300),
    curve: AppCurves.dramatic,
  );

  // Apply team glow
  _teamGlow.animateTo(
    opacity: teamGlowOpacity,
    duration: AppDurations.crossfade,
    curve: AppCurves.standard,
  );

  // Settle vision glow back
  _visionGlow.animateTo(
    opacity: 0.12,
    duration: const Duration(milliseconds: 300),
    curve: AppCurves.standard,
  );
}
```

### Dart: Vote Tally Build Sequence

```dart
Future<void> buildVoteTally(List<Vote> votes) async {
  final perVoteDelay = AppDurations.voteBuild ~/ (votes.length + 2);

  // Opening pause
  await Future.delayed(Duration(milliseconds: perVoteDelay));

  for (var i = 0; i < votes.length; i++) {
    final isLast = i == votes.length - 1;

    // Extra pause before final vote
    if (isLast) {
      await Future.delayed(const Duration(milliseconds: 400));
    }

    // Fire haptic + sound
    AppHaptics.tallyTick();
    _audioEngine.play(SoundCues.tallyTick);

    // Animate bar extension
    _bars[votes[i].targetId]!.extend(
      byVotes: 1,
      duration: const Duration(milliseconds: 300),
      curve: isLast ? AppCurves.dramatic : AppCurves.bounce,
    );

    if (!isLast) {
      await Future.delayed(Duration(milliseconds: perVoteDelay));
    }
  }
}
```

---

## Open Questions

(none)
