# Asset Inventory

## Identity

| Field   | Value |
|---------|-------|
| type    | assets |
| domain  | art, sound, motion |

This document is the complete manifest of every asset required for the Midnight Village frontend. Each entry defines what must be produced, in what format, at what dimensions, and the art direction constraints that govern it.

All visual constraints reference `design-tokens.md` for values and `art-direction.md` for style rules. Sound and motion assets reference `sound-and-motion.md` for behavioral specifications.

---

## Role Card Illustrations

12 unique character portraits. These are the hero art assets of the game — the centerpiece of the role reveal moment.

**Shared constraints (all 12):**

| Property | Value |
|----------|-------|
| Format | PNG with transparency |
| Source resolution | 780 × 1040px (3:4 aspect ratio per `art-direction.md`) |
| Export variants | 1x (260 × 347), 2x (520 × 693), 3x (780 × 1040) |
| Style | Digital painting, warm candlelight, visible brush texture (see `art-direction.md` Style Direction) |
| Lighting | Single warm source from below-left |
| Composition | Chest-up portrait, centered, facing viewer or 3/4 turn |
| Background | Dark atmospheric fade to transparent. No scene or location. |
| Post-processing | Color grade to team palette, add 2% grain overlay, verify warmth |

| Asset ID | Role | Team Color Token | Character Summary | Distinguishing Elements |
|----------|------|-----------------|-------------------|------------------------|
| `role-art-werewolf` | Werewolf | `AppColors.teamWerewolf` | Human with predatory undertone, sharp features, amber-red eyes | Faint claw marks on collar, wolf shadow behind, unnatural eye-catch |
| `role-art-minion` | Minion | `AppColors.teamWerewolf` | Servile, hooded, slightly unsettling | One gleaming eye visible, wringing hands, deep hood shadow |
| `role-art-villager` | Villager | `AppColors.teamVillage` | Honest farmer or tradesperson, watchful | Simple clothing, work-worn hands, direct gaze, nearby candle |
| `role-art-seer` | Seer | `AppColors.teamVillage` | Wise elder or mystic, otherworldly calm | Crystal ball or scrying mirror, ornate robes, third eye in shadow |
| `role-art-robber` | Robber | `AppColors.teamVillage` | Roguish, charming, quick | Mask on forehead/neck, stolen goods bag, mischievous half-smile |
| `role-art-troublemaker` | Troublemaker | `AppColors.teamVillage` | Chaotic, amused, wild-haired trickster | Playing cards or dice, mismatched clothing, spark of mischief |
| `role-art-drunk` | Drunk | `AppColors.teamVillage` | Bleary, confused, good-natured | Tankard or bottle, unfocused gaze, ruddy cheeks, crooked hat |
| `role-art-insomniac` | Insomniac | `AppColors.teamVillage` | Alert, anxious, wide-eyed | Dark circles, bright eyes, low-burning candle, nightclothes |
| `role-art-mason` | Mason | `AppColors.teamVillage` | Stoic builder or craftsperson, trustworthy | Mason's tools (square, compass), apron, calloused hands |
| `role-art-hunter` | Hunter | `AppColors.teamVillage` | Grim, determined, armed | Crossbow, weathered face, scars, eyes tracking off-frame |
| `role-art-tanner` | Tanner | `AppColors.teamIndependent` | Desperate, feverish, pitiful | Stained leather apron, chemical-burned hands, wild eyes |
| `role-art-doppelganger` | Doppelganger | `AppColors.teamVillage` | Uncanny, shifting, identity unclear | Face in shadow or reflection, blurred features, mirror shard |

---

## Card Back Assets

Assets for the face-down state of role cards. The "sealed envelope" before the reveal.

| Asset ID | Name | Format | Dimensions | Description | Constraints |
|----------|------|--------|------------|-------------|-------------|
| `card-back-pattern` | Quatrefoil Pattern | SVG | Tileable, 48 × 48dp unit cell | Interlocking quatrefoil geometric in diagonal grid | 0.5dp stroke in `AppColors.outline` at 40% opacity. 24dp center-to-center spacing. 6dp lobe radius. 45-degree rotation. See `art-direction.md` Card Back Pattern. |
| `card-back-seal` | Village Wax Seal | PNG | 128 × 128px (displays at 64dp) | Circular wax seal with wolf head silhouette | `AppColors.tallowGold` at 60% opacity. Irregular wax-drip edge. 2dp inset shadow. Wolf head uses sigil symbol #9. |
| `card-back-trefoil` | Corner Trefoil | SVG | 8 × 8dp | Small gothic trefoil for card back frame corners | `AppColors.outlineSubtle`. Placed at each corner of the inner decorative frame. |

---

## Sigil Icons

20 vector icons for the player avatar system. Each must be legible at 16dp and clear at 32dp.

**Shared constraints (all 20):**

| Property | Value |
|----------|-------|
| Format | SVG (source), exported as Flutter `CustomPainter` or icon font |
| Design | Single-weight line art, outline only, no fills |
| Complexity | Max 20 anchor points per symbol |
| Corner style | Slightly rounded, warm (no sharp geometric precision) |
| Stroke width | Defined per avatar size: 1.5dp (32dp avatar), 2dp (48dp), 2.5dp (64dp) |
| Color | Applied at render time from sigil color palette (10 colors in `art-direction.md`) |
| Optical sizing | Each icon optically centered within a square bounding box, not mathematically centered |

| Asset ID | Index | Symbol | Key Visual Elements |
|----------|-------|--------|-------------------|
| `sigil-crescent-moon` | 0 | Crescent Moon | Waning crescent, horns right, single curved stroke |
| `sigil-raven` | 1 | Raven | Profile perched bird, folded wings, visible beak |
| `sigil-dagger` | 2 | Dagger | Straight blade, crossguard, pommel detail |
| `sigil-chalice` | 3 | Chalice | Stemmed goblet, wide rim, narrow base |
| `sigil-skeleton-key` | 4 | Skeleton Key | Ornate circular bow, long shaft, simple bit |
| `sigil-watching-eye` | 5 | Watching Eye | Almond eye shape, iris circle, stylized lash lines |
| `sigil-candle-flame` | 6 | Candle Flame | Teardrop flame atop narrow candle taper |
| `sigil-shield` | 7 | Shield | Heater shield shape, no internal emblem |
| `sigil-crown` | 8 | Crown | Three-pointed crown, band across bottom |
| `sigil-wolf-head` | 9 | Wolf Head | Profile canine, pointed ear, closed mouth |
| `sigil-skull` | 10 | Skull | Front view, round cranium, jaw, two eye sockets |
| `sigil-rose` | 11 | Rose | Open bloom with visible petals, one leaf on stem |
| `sigil-serpent` | 12 | Serpent | Coiled S-curve body, raised head, forked tongue |
| `sigil-pentacle-star` | 13 | Pentacle Star | Five-pointed star, single continuous stroke |
| `sigil-grimoire` | 14 | Grimoire | Closed book outline, clasp on right edge |
| `sigil-bell` | 15 | Bell | Traditional bell silhouette, visible clapper |
| `sigil-quill` | 16 | Quill | Feather quill at ~30-degree angle, barb detail |
| `sigil-compass-rose` | 17 | Compass Rose | Four-pointed directional star, north emphasized |
| `sigil-hourglass` | 18 | Hourglass | Two triangles meeting at pinch point, sand lines |
| `sigil-lantern` | 19 | Lantern | Hanging lantern, glass pane divisions, handle ring |

---

## Role Icons

12 small symbolic icons for inline role identification. These are NOT cropped card portraits — they are simple, purpose-designed symbolic icons (e.g., a moon for Werewolf, an eye for Seer, crossed swords for Hunter). A separate asset set from the full role card illustrations, used as small inline indicators.

**Shared constraints (all 12):**

| Property | Value |
|----------|-------|
| Format | SVG (vector, scales to any dp) |
| Sizes used | 16dp (game history), 24dp (role selection, night info strip, results table) |
| Color | Monochrome `AppColors.parchment`, with team accent color applied via tint at render time |
| Style | Simple line art, consistent stroke weight, readable at 16dp |
| Complexity | Must be legible as silhouettes |
| Production | Designed (not generated) |

| Asset ID | Role | Symbol | Key Visual Elements |
|----------|------|--------|-------------------|
| `role-icon-werewolf` | Werewolf | Crescent Moon | Waning moon with sharp edges, predatory |
| `role-icon-minion` | Minion | Hooded Figure | Simple hood silhouette, single eye dot |
| `role-icon-villager` | Villager | Torch | Upright torch with flame tip |
| `role-icon-seer` | Seer | Eye | Open eye with pupil, mystical |
| `role-icon-robber` | Robber | Mask | Simple domino mask shape |
| `role-icon-troublemaker` | Troublemaker | Crossed Arrows | Two arrows crossing in an X |
| `role-icon-drunk` | Drunk | Tankard | Simple mug/tankard silhouette |
| `role-icon-insomniac` | Insomniac | Open Eye (Tired) | Wide eye with lines beneath (bags) |
| `role-icon-mason` | Mason | Square & Compass | Overlapping mason's tools |
| `role-icon-hunter` | Hunter | Crossed Swords | Two blades crossing |
| `role-icon-tanner` | Tanner | Hide | Animal hide silhouette |
| `role-icon-doppelganger` | Doppelganger | Mirror | Hand mirror outline, crack line |

### Elimination Method Icons

3 small icons for the results table elimination badges. These indicate HOW a player was eliminated.

**Shared constraints:**

| Property | Value |
|----------|-------|
| Format | SVG |
| Sizes used | 16dp (results table badge) |
| Color | Monochrome `AppColors.parchmentMuted`, with contextual tint at render time |
| Style | Simple line art, consistent with sigil icon style |

| Asset ID | Method | Symbol | Key Visual Elements |
|----------|--------|--------|-------------------|
| `elim-icon-voted` | Voted out | Crossed swords | Two short blades crossing in an X |
| `elim-icon-tied` | Tied vote | Balanced scales | Simple balance scale, level |
| `elim-icon-hunter` | Hunter chain | Crossbow bolt | Single bolt/arrow, angled downward |

---

## Background Illustrations

Atmospheric silhouette illustrations for phase backgrounds. Quiet mood-setters, never focal points.

**Shared constraints (all backgrounds):**

| Property | Value |
|----------|-------|
| Format | SVG (source) |
| Style | Silhouette / outline art only. No filled areas or detail. |
| Color | Monochrome. Phase background hex lightened by 8-12%. |
| Complexity | 3-5 major shapes. |
| Anchor | Bottom-anchored, bleeding off bottom and sides. |
| Opacity | Rendered at per-phase opacity (8-12%, see table below). |
| Blend mode | Screen or Normal at low opacity. |
| Layer position | Above phase background fill, below noise grain, below all content. |
| Width | Cover max viewport width (at least 480dp). No tiling. |

| Asset ID | Phase | Opacity | Content | Mood |
|----------|-------|---------|---------|------|
| `bg-welcome-village` | Welcome / Auth | 12% | Misty village silhouette: clustered buildings, church steeple, bare trees, faint moon above | Approaching the village at night. Mystery. Invitation. |
| `bg-lobby-tavern` | Lobby | 10% | Tavern interior suggestion: timber beam outlines, hanging lantern shapes, fireplace glow arc | Inside the tavern. Warm, social, anticipation. |
| `bg-discussion-square` | Discussion | 8% | Village square: cobblestone pattern suggestion, well outline, distant building rooflines | Dawn stirring. The village wakes for debate. |
| `bg-results-graveyard` | Results | 8% | Graveyard elements: iron fence segments, 2-3 headstone shapes, bare tree silhouette | Resolution. Aftermath. Reveal of truth. |

Night and Voting phases have no background illustration — they rely on particle effects and glows for atmosphere (see `design-tokens.md` Particle Effect Tokens and `art-direction.md` Particle Effects).

---

## Textures

| Asset ID | Name | Format | Dimensions | Description | Usage | Constraints |
|----------|------|--------|------------|-------------|-------|-------------|
| `texture-noise-grain` | Film Grain | PNG | 512 × 512px, tileable | Perlin noise / film grain pattern | Overlaid on all screens at `AppOpacity.grain` (3%) in Overlay blend mode | Must tile seamlessly. Static (not animated). 2x resolution for retina. See `design-tokens.md` Decorative Effects. |
| `texture-particle-ember` | Ember Sprite | PNG | 16 × 16px | Soft-edged circle/oval, warm golden, pre-colored | Source sprite for `AppParticles.embers` system | Gaussian-blurred edge. `AppColors.tallowGold` base. Opacity controlled by particle system. |
| `texture-particle-dust` | Dust Mote Sprite | PNG | 8 × 8px | Tiny soft circle, near-white | Source sprite for `AppParticles.dust` system | Gaussian blur. `AppColors.parchment` base. Very small. |
| `texture-particle-fog` | Fog Wisp Sprite | PNG | 256 × 128px | Large soft blob, irregular edges, cloud-like | Source sprite for `AppParticles.fog` system | Heavy Gaussian blur (20dp radius). `AppColors.parchment` base. Organic shape. |

---

## UI Illustrations

Small-scale illustrations for specific UI moments. Not hero art — functional atmosphere.

| Asset ID | Name | Format | Dimensions | Description | Usage | Constraints |
|----------|------|--------|------------|-------------|-------|-------------|
| `ui-empty-lobby` | Empty Lobby | SVG | 120 × 120dp | Lonely tavern table with single candle, empty chairs suggested | Lobby screen when only the host is present | Monochrome, `AppColors.parchmentMuted`. Warm, inviting. |
| `ui-error-fog` | Error Fog | SVG | 80 × 80dp | Swirling fog with lost-looking lantern | Error states ("The spirits are restless...") | Monochrome, `AppColors.parchmentMuted`. Atmospheric. |
| `ui-disconnect-fog` | Wandered Into Fog | SVG | 80 × 80dp | Figure disappearing into fog, hand reaching back | Disconnection notification | Monochrome, `AppColors.parchmentMuted`. |
| `ui-loading-candle` | Flickering Candle | SVG + animation | 48 × 64dp | Single candle with animated flame | Loading / connecting state | `AppColors.tallowGold` flame. Simple 3-frame flicker loop. 600ms cycle. |
| `ui-no-elimination` | Tombstone Untouched | SVG | 100 × 100dp | Clean, undisturbed gravestone with small flowers | "No one dies" elimination variant | Monochrome, `AppColors.noDeathBlue`. Peaceful, untouched. |
| `ui-win-village` | Village Dawn | SVG | 160 × 80dp | Village skyline with rising sun rays | Village team wins result header | `AppColors.tallowGold` rays, monochrome village. Celebratory. |
| `ui-win-werewolf` | Wolf Moon | SVG | 160 × 80dp | Full moon with wolf silhouette howling | Werewolf team wins result header | `AppColors.bloodmoonRed` moon glow, monochrome wolf. Ominous triumph. |
| `ui-win-tanner` | Broken Chains | SVG | 160 × 80dp | Broken shackles/chains, freed | Tanner wins result header | `AppColors.graveDust` monochrome. Relief, not celebration. |
| `ui-candle-countdown` | Countdown Candle | SVG + animation | 48 × 160dp | Tall taper candle that visually burns down. Flame at tip with ember particles. Wax melts proportionally to remaining time. | Host-disconnect 5-minute countdown | `AppColors.tallowGold` flame. Candle body in `AppColors.parchmentMuted`. Flame flicker: 3-frame loop, 600ms cycle (same as `ui-loading-candle`). Wax level is a linear interpolation from full to empty over the countdown duration. |

---

## Sound Assets

Sound behavioral specs are defined in `sound-and-motion.md`. This section inventories the audio files required.

### Narrator Audio Slots

Each slot is a semantic audio cue point. The actual voice/recording varies by narrator persona (pluggable system). All slots must have at least one default recording.

| Asset ID | Cue Point | Semantic Content | Duration Target | Emotional Beat |
|----------|-----------|-----------------|----------------|---------------|
| `narrator-game-start` | Game start transition | "Night falls on the village..." | 2–3s | Mysterious, descending |
| `narrator-wave-werewolf` | Werewolf wake | "Werewolves, open your eyes..." | 2–3s | Dark, commanding |
| `narrator-wave-minion` | Minion wake | "Minion, open your eyes..." | 2–3s | Conspiratorial, low |
| `narrator-wave-mason` | Mason wake | "Masons, open your eyes..." | 2–3s | Steady, trustworthy |
| `narrator-wave-seer` | Seer wake | "Seer, open your eyes..." | 2–3s | Mystical, wise |
| `narrator-wave-robber` | Robber wake | "Robber, open your eyes..." | 2–3s | Sly, quick |
| `narrator-wave-troublemaker` | Troublemaker wake | "Troublemaker, open your eyes..." | 2–3s | Mischievous, playful |
| `narrator-wave-drunk` | Drunk wake | "Drunk, open your eyes..." | 2–3s | Warm, slightly amused |
| `narrator-wave-insomniac` | Insomniac wake | "Insomniac, open your eyes..." | 2–3s | Alert, whispering |
| `narrator-wave-doppelganger` | Doppelganger wake | "Doppelganger, open your eyes..." | 2–3s | Eerie, shifting |
| `narrator-wave-close` | Wave close (generic) | "Close your eyes..." | 1–2s | Calming, final |
| `narrator-discussion-start` | Discussion begins | "Everyone, open your eyes. Discuss." | 2–3s | Urgent, bright |
| `narrator-voting-start` | Voting begins | "Time to vote." | 1–2s | Solemn, weighted |
| `narrator-elimination` | Elimination reveal | "The village has spoken." | 1–2s | Grave, theatrical |
| `narrator-no-elimination` | No elimination | "No one dies tonight." | 1–2s | Hollow, cold |
| `narrator-village-wins` | Village wins | "The village is safe." | 2–3s | Triumphant, warm |
| `narrator-werewolf-wins` | Werewolf wins | "The werewolves survive." | 2–3s | Ominous, satisfied |
| `narrator-tanner-wins` | Tanner wins | "The tanner escapes." | 2–3s | Bittersweet, relieved |
| `narrator-nobody-wins` | No team wins (NC-RESULT-NOBODY) | "No one wins." | 1–2s | Hollow, bleak |
| `narrator-w1-minion-sub` | Doppelganger-Minion sub-script (NC-W1-MINION-SUB) | "If you are now a Minion, keep your eyes open. Werewolves, stick out your thumb." | 3–4s | Tense, secretive |
| `narrator-w1-minion-end` | Doppelganger-Minion end (NC-W1-MINION-END) | "Werewolves, put your thumbs away. Doppelganger, close your eyes." | 2–3s | Settling, closing |
| `narrator-ww-lone` | Lone Werewolf option (NC-W2-WW-LONE) | "If there is only one Werewolf, you may look at one center card." | 2–3s | Isolated, cautious |
| `narrator-doppel-insomniac` | Doppelganger-as-Insomniac wake (NC-W4-DOPPEL-INS-WAKE) | "Doppelganger, if you viewed the Insomniac card, wake up and look at your card." | 3–4s | Anxious, curious |
| `narrator-hunter-chain` | Hunter chain lead-in (NC-ELIM-HUNTER) | "The Hunter takes aim..." | 1–2s | Sudden, retaliatory |
| `narrator-disc-warn` | Discussion time warning (NC-DISC-WARN) | "Time is running out..." | 1–2s | Urgent, pressing |

**Format requirements:**

| Property | Value |
|----------|-------|
| Format | OGG Vorbis (primary), MP3 (fallback) |
| Sample rate | 44.1 kHz |
| Bit depth | 16-bit |
| Channels | Mono |
| Loudness | Normalized to -16 LUFS (playback volume controlled by mixer — see `sound-and-motion.md`) |
| Silence | Max 100ms silence at start/end |
| Naming | `narrator/{persona}/{cue-id}.ogg` — e.g., `narrator/default/game-start.ogg` |

### Ambient Atmosphere

Looping background soundscapes, one per phase.

| Asset ID | Phase | Description | Duration | Emotional Character |
|----------|-------|-------------|----------|-------------------|
| `ambient-lobby` | Lobby | Tavern murmur: distant conversation, fire crackle, occasional glass clink | 60s loop | Warm, social, inviting |
| `ambient-night` | Night | Night crickets, distant owl, gentle wind, deep quiet | 60s loop | Mysterious, still, vast |
| `ambient-discussion` | Discussion | Morning village: birdsong beginning, wind, distant activity | 60s loop | Stirring, alert, building |
| `ambient-voting` | Voting | Tense silence: low rumble, heartbeat suggestion, breath | 30s loop | Tight, pressured, anticipation |
| `ambient-results` | Results | Settling dust: wind dying down, embers popping, silence settling | 30s loop | Resolution, exhale, aftermath |

**Format requirements:**

| Property | Value |
|----------|-------|
| Format | OGG Vorbis (primary), MP3 (fallback) |
| Sample rate | 44.1 kHz |
| Channels | Stereo |
| Loudness | Normalized to -16 LUFS (playback volume controlled by mixer — see `sound-and-motion.md`) |
| Loop point | Seamless loop — no audible join. Crossfade window: 2s. |
| Naming | `ambient/{phase-id}.ogg` |

### UI Sound Effects

Short sound cues paired with interactions and game beats.

| Asset ID | Trigger | Description | Duration | Haptic Pairing |
|----------|---------|-------------|----------|---------------|
| `sfx-button-tap` | Any button press | Soft wooden tap, warm | <100ms | Light tap |
| `sfx-card-flip` | Role card flip reveal | Wax seal breaking + paper unfold | 300–400ms | Medium tap |
| `sfx-card-deal` | Card arriving face-down | Soft card-on-table slide | 200ms | Light tap |
| `sfx-selection-change` | Vote target change, action target change | Subtle click, like a wooden token placed | <100ms | Light tap |
| `sfx-vote-lock` | Voting phase ends (all votes finalized) | Gavel-like thud, authoritative | 200ms | Confirmation pulse |
| `sfx-vote-count-tick` | Each vote appearing in tally | Quick tick, clock-like | <50ms | None |
| `sfx-elimination-reveal` | Eliminated player name appears | Heavy door closing, reverberant thud | 400ms | Gentle thud |
| `sfx-phase-transition` | Phase overlay begins | Low tonal drone, descending | 1–2s (under narrator) | None |
| `sfx-player-join` | Player joins lobby | Tavern door opening, brief warmth rush | 300ms | None |
| `sfx-player-ready` | Player toggles ready | Wooden click, satisfying | <100ms | Light tap |
| `sfx-timer-warning` | Timer enters 25% threshold | Single low bell toll | 500ms | None |
| `sfx-timer-critical` | Timer enters 10% threshold | Faster bell toll, higher pitch | 300ms | Light tap |
| `sfx-win-celebration` | Win announcement (your team) | Brief warm chime sequence, ascending | 800ms | Celebration pattern |
| `sfx-loss-commiseration` | Loss announcement (your team) | Low descending tone, muted | 600ms | Commiseration pattern |
| `sfx-disconnect` | Player disconnection detected | Wind gust, hollow | 400ms | None |
| `sfx-reconnect` | Player reconnection | Door opening again, brief warmth | 300ms | Light tap |

**Format requirements:**

| Property | Value |
|----------|-------|
| Format | OGG Vorbis (primary), MP3 (fallback) |
| Sample rate | 44.1 kHz |
| Bit depth | 16-bit |
| Channels | Mono |
| Loudness | Normalized to -16 LUFS (playback volume controlled by mixer — see `sound-and-motion.md`) |
| Naming | `sfx/{asset-id}.ogg` |

---

## Animation Assets

Animations are code-driven (Flutter Animations/Rive), not pre-rendered video. This section defines the sequences that need choreography implementation.

| Asset ID | Name | Type | Duration | Description | Token References |
|----------|------|------|----------|-------------|-----------------|
| `anim-card-flip` | Role Card Flip | Code (Flutter) | 600ms (`AppDurations.theatrical`) | 3D Y-axis rotation from face-down to face-up. Midpoint: card edge-on. Second half reveals face with team glow. | `AppCurves.dramatic`, `AppGlows.teamVillage`/`teamWerewolf`/`teamIndependent` |
| `anim-card-deal` | Card Deal | Code (Flutter) | 400ms | Card slides in from bottom, slight scale-up (0.9 -> 1.0), settles with subtle bounce. | `AppCurves.enter`, `AppShadows.card` |
| `anim-phase-transition` | Phase Transition Overlay | Code (Flutter) | 2500ms (`AppDurations.cinematic`) | Full-screen overlay fades in (500ms), narrator text fades in (400ms), holds (1200ms), all fades out (400ms). Background crossfades underneath. | `AppOpacity.scrim`, `AppTextStyles.narrator` |
| `anim-vote-tally` | Vote Tally Build | Code (Flutter) | 6000ms (`AppDurations.voteBuild`) | Bar chart fills progressively. Each vote appears with a tick sound. Most-voted player highlighted with emphasis last. | `AppColors.tallowGold` (bar fill), `sfx-vote-count-tick` |
| `anim-elimination-reveal` | Elimination Announcement | Code (Flutter) | 1200ms | Player name scales up from 0.8 to 1.0 (400ms), holds (400ms), role fades in below (400ms). Blood vignette fades in simultaneously. | `AppGlows.bloodVignette`, `AppTextStyles.displayXl`, `sfx-elimination-reveal` |
| `anim-timer-pulse` | Timer Pulse | Code (Flutter) | Variable (see timer ramp) | Opacity oscillation on timer text. 2s cycle at urgent, 0.8s cycle at critical. | `AppColors.timerUrgent`, `AppColors.timerCritical` |
| `anim-selection-glow` | Selection Glow In/Out | Code (Flutter) | 200ms (`AppDurations.fast`) | Glow ring fades in around selected element, fades out on deselect. | `AppGlows.selection`, `AppCurves.standard` |
| `anim-pressure-dim` | Voting Pressure | Code (Flutter) | Continuous | Phase background gradually darkens by 10% as voting timer approaches 0. Particle intensity increases. | `AppColors.phaseVoting`, `AppParticles.embers` |
| `anim-win-pop` | Win Announcement Pop | Code (Flutter) | 400ms | Headline text scales from 0.0 to 1.05 (300ms, `AppCurves.bounce`), then settles to 1.0 (100ms). | `AppTextStyles.displayXl`, `AppCurves.bounce` |
| `anim-loading-candle` | Loading Candle Flicker | Code (SVG + Flutter) | 600ms loop | 3-frame candle flame animation: normal, stretch-left, stretch-right. Subtle. | `AppColors.tallowGold`, `ui-loading-candle` |

---

## Asset Directory Structure

```
assets/
├── images/
│   ├── roles/
│   │   ├── werewolf.png          (+ 2x/, 3x/ variants)
│   │   ├── minion.png
│   │   ├── villager.png
│   │   ├── seer.png
│   │   ├── robber.png
│   │   ├── troublemaker.png
│   │   ├── drunk.png
│   │   ├── insomniac.png
│   │   ├── mason.png
│   │   ├── hunter.png
│   │   ├── tanner.png
│   │   └── doppelganger.png
│   ├── card/
│   │   ├── card-back-pattern.svg
│   │   ├── card-back-seal.png     (+ 2x/, 3x/)
│   │   └── card-back-trefoil.svg
│   ├── sigils/
│   │   ├── crescent-moon.svg
│   │   ├── raven.svg
│   │   ├── dagger.svg
│   │   ├── chalice.svg
│   │   ├── skeleton-key.svg
│   │   ├── watching-eye.svg
│   │   ├── candle-flame.svg
│   │   ├── shield.svg
│   │   ├── crown.svg
│   │   ├── wolf-head.svg
│   │   ├── skull.svg
│   │   ├── rose.svg
│   │   ├── serpent.svg
│   │   ├── pentacle-star.svg
│   │   ├── grimoire.svg
│   │   ├── bell.svg
│   │   ├── quill.svg
│   │   ├── compass-rose.svg
│   │   ├── hourglass.svg
│   │   └── lantern.svg
│   ├── role-icons/
│   │   ├── werewolf.svg
│   │   ├── minion.svg
│   │   ├── villager.svg
│   │   ├── seer.svg
│   │   ├── robber.svg
│   │   ├── troublemaker.svg
│   │   ├── drunk.svg
│   │   ├── insomniac.svg
│   │   ├── mason.svg
│   │   ├── hunter.svg
│   │   ├── tanner.svg
│   │   └── doppelganger.svg
│   ├── backgrounds/
│   │   ├── welcome-village.svg
│   │   ├── lobby-tavern.svg
│   │   ├── discussion-square.svg
│   │   └── results-graveyard.svg
│   ├── ui/
│   │   ├── empty-lobby.svg
│   │   ├── error-fog.svg
│   │   ├── disconnect-fog.svg
│   │   ├── loading-candle.svg
│   │   ├── no-elimination.svg
│   │   ├── win-village.svg
│   │   ├── win-werewolf.svg
│   │   └── win-tanner.svg
│   └── textures/
│       ├── noise-grain.png
│       ├── particle-ember.png
│       ├── particle-dust.png
│       └── particle-fog.png
├── audio/
│   ├── narrator/
│   │   └── default/
│   │       ├── game-start.ogg
│   │       ├── wave-werewolf.ogg
│   │       ├── wave-minion.ogg
│   │       ├── wave-mason.ogg
│   │       ├── wave-seer.ogg
│   │       ├── wave-robber.ogg
│   │       ├── wave-troublemaker.ogg
│   │       ├── wave-drunk.ogg
│   │       ├── wave-insomniac.ogg
│   │       ├── wave-doppelganger.ogg
│   │       ├── wave-close.ogg
│   │       ├── w1-minion-sub.ogg
│   │       ├── w1-minion-end.ogg
│   │       ├── ww-lone.ogg
│   │       ├── doppel-insomniac.ogg
│   │       ├── discussion-start.ogg
│   │       ├── disc-warn.ogg
│   │       ├── voting-start.ogg
│   │       ├── elimination.ogg
│   │       ├── hunter-chain.ogg
│   │       ├── no-elimination.ogg
│   │       ├── village-wins.ogg
│   │       ├── werewolf-wins.ogg
│   │       ├── tanner-wins.ogg
│   │       └── nobody-wins.ogg
│   ├── ambient/
│   │   ├── lobby.ogg
│   │   ├── night.ogg
│   │   ├── discussion.ogg
│   │   ├── voting.ogg
│   │   └── results.ogg
│   └── sfx/
│       ├── button-tap.ogg
│       ├── card-flip.ogg
│       ├── card-deal.ogg
│       ├── selection-change.ogg
│       ├── vote-lock.ogg
│       ├── vote-count-tick.ogg
│       ├── elimination-reveal.ogg
│       ├── phase-transition.ogg
│       ├── player-join.ogg
│       ├── player-ready.ogg
│       ├── timer-warning.ogg
│       ├── timer-critical.ogg
│       ├── win-celebration.ogg
│       ├── loss-commiseration.ogg
│       ├── disconnect.ogg
│       └── reconnect.ogg
└── fonts/
    ├── Epilogue/
    ├── DMSans/
    ├── SpaceGrotesk/
    └── LibreBaskerville/
```

---

## Asset Summary

| Category | Count | Format | Production Method |
|----------|-------|--------|-------------------|
| Role card illustrations | 12 | PNG (3 densities) | AI generation (Imagen) + manual post-processing |
| Card back assets | 3 | SVG + PNG | Manual design / procedural |
| Sigil icons | 20 | SVG | Manual vector design |
| Role icons | 12 | SVG | Manual vector design |
| Background illustrations | 4 | SVG | Manual vector design |
| Textures | 4 | PNG | Procedural generation |
| UI illustrations | 8 | SVG (+ 1 animated) | Manual vector design |
| Narrator audio slots | 25 | OGG + MP3 | Voice recording per persona |
| Ambient soundscapes | 5 | OGG + MP3 | Sound design / composition |
| UI sound effects | 16 | OGG + MP3 | Sound design / foley |
| Animation sequences | 10 | Code (Flutter) | Implementation |
| Font families | 4 | TTF/OTF (Google Fonts) | Google Fonts package |
| **Total unique assets** | **123** | | |

---

## Usage Rules

- DO: Generate all 12 role illustrations in a single batch to maintain style consistency. If one must be regenerated, compare against the full set.
- DO: Export raster assets at 1x, 2x, and 3x densities using Flutter's asset resolution system.
- DO: Normalize all audio files to -16 LUFS. Relative volume is controlled by playback mixer percentages defined in `sound-and-motion.md` (Narrator 100%, SFX 80%, Ambient 40%).
- DO: Test sigil legibility at the smallest avatar size (32dp) on a physical device before approving.
- DO: Organize narrator audio by persona folder to support the pluggable persona system.
- DO NOT: Ship role art without post-processing color grading to match team palettes. Raw AI output drifts.
- DO NOT: Use lossy compression on sigil SVGs. They must remain crisp at all sizes.
- DO NOT: Create ambient loops shorter than 30 seconds — short loops become noticeable.
- DO NOT: Mix stereo and mono formats within a category. Narrator and SFX are mono; ambient is stereo.
- DO NOT: Bundle unused narrator persona recordings in the production build. Personas load on demand.

## Pairing Rules

- Each role card illustration pairs with its team color border, team glow, and the `card-back-*` assets (same card surface, different face).
- `texture-noise-grain` is applied to every screen — it pairs with every phase background.
- Particle textures (`texture-particle-*`) pair with their corresponding `AppParticles.*` system parameters from `design-tokens.md`.
- Every `narrator-*` audio slot pairs with a `sfx-phase-transition` sound underneath (phase transitions) or fires standalone (wave calls).
- Every SFX asset with a haptic pairing column must fire its haptic simultaneously — sound and haptic are designed together, not independently.

## Examples

### Flutter: Loading a Role Card Image

```dart
Image.asset(
  'assets/images/roles/werewolf.png',
  width: 300, // AppDimensions display max width
  height: 400, // 3:4 aspect ratio
  fit: BoxFit.contain,
)
```

### Flutter: Registering Asset Variants

```yaml
# pubspec.yaml
flutter:
  assets:
    - assets/images/roles/
    - assets/images/roles/2x/
    - assets/images/roles/3x/
    - assets/images/sigils/
    - assets/images/role-icons/
    - assets/images/backgrounds/
    - assets/images/card/
    - assets/images/ui/
    - assets/images/textures/
    - assets/audio/narrator/default/
    - assets/audio/ambient/
    - assets/audio/sfx/
```

### Audio: Loudness Hierarchy

```
All files normalized to -16 LUFS. Mixer controls relative volume:

Narrator (100%)  ████████████████████
SFX      ( 80%)  ████████████████
Ambient  ( 40%)  ████████
```

Narrator is the reference level. SFX sit below for clarity. Ambient sits well below for constant background presence without fatigue. All volume relationships are controlled by the mixer, not file loudness.

---

## Open Questions

(none)
