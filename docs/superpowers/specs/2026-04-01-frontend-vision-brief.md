# Midnight Village -- Frontend Vision Brief

This document captures the product owner's complete vision for the Midnight Village frontend experience. It serves as the authoritative design brief for all downstream agent teams: design, gap analysis, platform, and planning.

---

## 1. What This Is

A multiplayer social deduction game platform. Players -- typically in the same physical room -- use their phones for secret role actions and voting. The first game is One Night Ultimate Werewolf (ONUW), but the platform is designed to be extensible to other social deduction games (Mafia, custom variants) and to allow freely adding new roles, themes, and rule variations to ONUW itself.

ONUW is the starting template, not the ceiling.

---

## 2. Emotional North Star

**Social warmth with fun drama.**

This is friends at a tavern having a great time, not a horror game or a competitive esport. The gothic theming (Firelit Gothic) serves the *fun* -- it creates atmosphere and theatrical moments, but never at the expense of warmth or accessibility. Think of it as a campfire story: spooky enough to be exciting, cozy enough that everyone's laughing.

The emotional arc across a full game:

```
Lobby (warmth, anticipation)
  -> Role Reveal (delight, secrecy)
    -> Night Actions (mystery, mischief)
      -> Discussion (social energy, suspicion)
        -> Voting (tension, commitment)
          -> Vote Reveal (dramatic build)
            -> Elimination (theatrical beat)
              -> Results (satisfaction, storytelling)
                -> Debrief (laughter, "play again")
```

Every design decision should be tested against: *does this make the experience warmer and more fun, or just more complex?*

---

## 3. Quality Bar

Two reference points define the standard:

**Premium software craft (Linear, Arc Browser, Apple Health):**
- Buttery smooth transitions
- Considered spacing and visual hierarchy
- Micro-interactions that reward attention
- Nothing jank, nothing cheap
- Dark mode done right

**Strong art direction (Cult of the Lamb, Hades):**
- Every element reinforces the Firelit Gothic theme
- Consistent visual language across all screens
- Personality over minimalism
- Hand-crafted feel, not template-driven

The intersection: an app that feels *expensive* and *authored*. Not a generic dark-mode app with a gothic skin -- a product where the theme is inseparable from the experience.

---

## 4. Aesthetic: Firelit Gothic

"Warm darkness, not cold tech dark mode. Candlelit tavern at midnight. The UI feels like an artifact from the village itself, not a Silicon Valley app."

### Core Palette

| Name | Hex | Usage |
|------|-----|-------|
| Blood Ember | `#B8432F` | Primary CTA, danger, werewolf accent |
| Tallow Gold | `#C8A24D` | Selection, highlights, village team |
| Moonlit Sage | `#5B8A72` | Safe/positive accents (sparingly) |
| Deep Void | `#0D0B0F` | Night phase background |
| Surface | `#1A1714` | Cards, elevated surfaces |
| Parchment | `#E8DFD3` | Primary text (warm off-white) |
| Parchment Muted | `#9C9084` | Secondary/caption text |
| Outline | `#3D362C` | Borders, dividers |
| Bloodmoon Red | `#C94038` | Werewolf team |
| Grave Dust | `#8B7D6B` | Tanner/independent team |
| No Death Blue | `#6B7B8B` | "No one dies" -- the only cold color |

### Typography

| Role | Font | Character |
|------|------|-----------|
| Headlines | Epilogue | Serif-gothic gravitas |
| Body | DM Sans | Readability |
| Labels/Timers | Space Grotesk | Game UI precision |
| Atmospheric text | Libre Baskerville italic | Flavor, warmth |

### Decorative Effects

- **Candle glow:** Radial gradient from center (transparent -> void) on night screens
- **Blood vignette:** Red-tinted edge vignette for elimination
- **Vision glow:** Golden radial for seer/reveal moments
- **Noise grain:** Subtle texture overlay at 3% opacity across backgrounds
- **Particle systems:** Floating embers, dust motes in candlelight, subtle fog -- screens should feel alive with constant low-key ambient motion

### Phase Backgrounds

Each game phase has a distinct background tone, all warm-dark:

| Phase | Hex | Mood |
|-------|-----|------|
| Lobby | `#1A1410` | Warm interior |
| Night | `#0D0B0F` | Deepest void |
| Discussion | `#151210` | Dawn approaching |
| Voting | `#12100E` | Warm tension |
| Results | `#0F0D0B` | Settling into reveal |

### Color Mode

Dark mode is the default and the primary experience. A high-contrast light mode should be specified for accessibility but deferred for implementation.

---

## 5. Animation & Motion

### Philosophy

**Theatrical for big moments, tasteful everywhere else.**

The game has natural dramatic beats. Animations should amplify these beats, not compete with them. Between the peaks, motion should be smooth, considered, and never gratuitous.

### Big Moments (theatrical)

These deserve choreographed animation sequences with sound and haptic cues:

- **Role reveal:** The "envelope moment" -- card arrives face-down, player taps to flip with a 3D Y-axis rotation (~600ms), haptic tap, wax-seal-breaking sound cue. Personal and tactile.
- **Phase transitions:** Cinematic cuts -- full-screen overlays with narrator text ("Night falls on the village..."), background darkening, 2-3 second atmospheric transition before the new phase appears.
- **Game start:** Brief cinematic between lobby and role reveal. "Night falls on the village..." with background shift and narrator cue.
- **Vote reveal:** Controlled 5-7 second tally build. Votes appear progressively in a bar chart, fast enough to maintain energy, slow enough to feel the tension.
- **Elimination announcement:** Fun but fast. Not drawn out. The reveal of who was eliminated and their role should be dramatic but keep the game's momentum. Explore: reaction moments, "grave" animation, brief spotlight on the eliminated player.
- **Win/loss announcement:** Team result headline with personal outcome clearly shown. Balanced presentation -- both matter.

### Everywhere Else (tasteful)

- Smooth crossfades between sub-states within a phase (400ms)
- Subtle scale/opacity transitions on interactive elements
- Particle systems running continuously (embers, dust, fog)
- Loading states that feel atmospheric, not sterile

### Haptics

Subtle confirmation taps, not heavy rumble. Haptics fire on:
- Button presses (light tap)
- Card flips (medium tap)
- Vote lock-in (confirmation pulse)
- Elimination reveal (gentle thud)
- Win/loss (celebration or commiseration pattern)

Different patterns for different actions, but all restrained.

---

## 6. Sound & Narrator

### Narrator System

The narrator is a **pluggable persona slot**. The spec defines:
- **Cue points:** Every moment where audio should play
- **Semantic content:** What information the narrator must convey at each cue
- **Emotional beat:** The mood of the moment (mysterious, urgent, solemn, playful)

The actual voice, tone, and phrasing are a persona layer. The system should support swapping personas (gothic storyteller, game host, character voices like Rick Sanchez or Darth Vader) without changing the cue sheet.

### Narrator Cue Sheet (to be fully enumerated in the screen specs)

Key cue points include:
- Game start ("Night falls on the village...")
- Each wave's wake call ("Werewolves, open your eyes...")
- Wave completion transitions
- Discussion start ("Everyone, open your eyes. Discuss.")
- Voting start ("Time to vote.")
- Elimination announcement
- Winner announcement

### Sound Design

- **Ambient atmosphere:** Background soundscape per phase (night crickets, tavern murmur, tense silence)
- **No role-specific sound effects.** Sound cues are tied to *actions* and *moments*, not to which role you are
- **X-channel audio concept (future):** During discussion, if players are in the same room, explore playing different audio to different phones to create an immersive shared soundscape

### Haptic-Sound Pairing

Every narrator cue and major interaction beat pairs a sound cue with a haptic pattern. These are designed together, not independently.

---

## 7. Personas & User Journeys

### Two Primary Personas

**Host:**
- Creates the lobby, configures roles, starts the game
- First-class experience: distinctly designed control surfaces, contextual host controls, clear "you run this" energy
- Host controls are themed and integrated, not bolted-on admin UI
- Controls appear contextually (only when relevant, not cluttering non-host screens)

**Player:**
- Everyone who isn't the host
- Whether new or veteran is a *state* (first-time-use), not a separate persona
- Experience differs by role: a Seer has a complex night, a Villager has none
- Contextual first-time hints handle onboarding ("tap a player to peek at their card") -- these disappear after first use
- No tutorial game, no heavy onboarding

### Role Complexity Variance

The UI must gracefully handle that different roles have wildly different night experiences:
- **No action roles** (Villager, Hunter): need engaging waiting experience
- **Simple action roles** (Robber, Drunk): one selection
- **Choice roles** (Seer): choose between action types, then select targets
- **Multi-step roles** (Doppelganger): peek, then follow-up action
- **Auto-resolve roles** (Insomniac, Masons, Werewolves): information display, no interaction

The night action UI framework must be flexible enough to handle all of these through composition, not per-role screen design.

---

## 8. Screen-by-Screen Design Direction

### Pre-Game

**Welcome/Auth:**
- First screen. Creates atmosphere and excitement.
- Misty village illustration, title treatment, name input, "Enter the Village" CTA.
- Most players spend <10 seconds here. Large touch targets.
- Feel: approaching a candlelit tavern door at midnight.

**Home (Create/Join):**
- Greeting with player name, Create Game / Join Game cards.
- Show online player count somewhere (how many people are in the village).
- Hero lobby code input for joining (not a share sheet).
- Feel: the tavern interior, choosing your table.

### Lobby

**Lobby Waiting Room:**
- **Gathering at the tavern.** Warm, social, anticipation building.
- Players see each other arrive. Sense of group forming.
- Hero lobby code display: big, bold, letter-spaced, tap-to-copy.
- Player list with ready states, host badge.
- Host: role configuration, start game button.
- Host UX is first-class, contextual, themed.
- Feel: friends settling in around a table, candles lit.

**Role Selection (Host):**
- Role picker with count steppers.
- Validation banners for invalid configurations.
- Must support adding new/custom roles in the future (extensible list, not hardcoded grid).

### Night Phase

**Game Start Transition:**
- 2-3 second cinematic: "Night falls on the village..." with background darkening and narrator cue.
- Bridges the warm lobby into the mysterious night.

**Role Reveal:**
- The "envelope moment." Card arrives face-down. Player taps to flip.
- 3D card flip animation with haptic and sound.
- Shows: role icon, role name, team, description.
- Team-colored accent (gold for village, red for werewolf, grey for independent).
- Custom illustrated role art via Imagen (not Material Icons).
- Feel: opening a sealed letter in candlelight. Secretive, personal, exciting.

**Night Actions:**
- Flexible action framework that handles all role types through composition.
- Night action prompt: role info strip at top, action area in center, timer at bottom.
- Player selection: adaptive grid that works for 3-20+ players (Mafia support).
- Center card selection: face-down card slots with selection glow.
- Action results: card flip reveal (consistent visual language with role reveal).
- Feel: performing a secret ritual. Quiet, deliberate.

**Night Waiting (Critical Design Space):**
- **Everyone must have their phone out and be visibly interacting.**
- This is the primary information-leakage prevention mechanism. If only the active player is tapping, their identity is exposed.
- Interactive layer: ambient fidget elements (poke embers, swirl smoke, play with a candle flame). Fun and benign.
- Wave progress indicator (dot system showing which wave is active).
- Feel: sitting by the fire while waiting for your turn. Cozy, concealing.

### Discussion Phase

**Discussion View:**
- Primary content: big countdown timer + ambient atmosphere.
- The phone sets the mood while players talk face-to-face.
- Role reminder card: hidden by default, tap to reveal (light in-person guardrail).
- Roles in play: collapsible list for reference.
- Host: "End Discussion Early" button (contextual, themed).
- Timer color ramp: gold -> amber -> red pulse -> fast red pulse.
- X-channel audio concept: explore playing ambient soundscape that shifts as discussion progresses.
- Feel: the phone is a mood lamp and cheat sheet, not the center of attention.

### Voting Phase

**Voting:**
- Player grid for target selection.
- **Fluid selection** -- tap a player to select them as your vote target. Tap another player to change your mind. No "confirm and lock" step. Your current selection is your vote when the phase ends.
- **Blind voting** -- you see who has made a selection (checkmark) but not who they selected. Selections are mutable until the phase ends.
- **Pressure indicators** -- as the timer counts down, subtle environmental shifts: screen gets slightly darker, timer pulse quickens, particle effects intensify. Tension you feel, not information you read.
- Tap-to-reveal for your own current selection (in-person guardrail).
- Vote counter: "4/6 have chosen."
- Host can end voting early, which finalizes all current selections.
- Feel: the room goes quiet. Everyone is deciding. You can still change your mind.

**Vote Reveal:**
- Controlled 5-7 second tally build.
- Votes appear in a bar chart that fills progressively.
- Most-voted player highlighted last (or simultaneously with emphasis).
- Not dragged out, but enough time to feel the tension build.
- Feel: reading a verdict.

**Elimination Announcement:**
- Fun but fast. Don't kill momentum.
- Eliminated player's name displayed large, role revealed below.
- Blood vignette background effect.
- Explore: brief spotlight, "grave" animation, reaction moment.
- "No one dies" variant: cold blue tone, solemn but not sad.
- Hunter chain: second elimination after a brief pause.
- Feel: a theatrical beat, then move on.

### Results Phase

**Results (Layered Reveal):**
1. **Headline:** Team result + personal outcome. "VILLAGE WINS! -- You Win." Balanced presentation.
2. **Player table:** Everyone's original role -> final role, vote targets, outcomes. Progressive disclosure -- starts collapsed, players drill in.
3. **Full autopsy:** Complete night log. Every swap, every peek, chronological. Available on demand.
4. **Post-game debrief:** Linger and discuss, or hit "Play Again" for quick rematch.
- Play Again keeps the same group in the lobby with new role configuration.
- Feel: the campfire storytelling after the game. "I KNEW you were the werewolf!"

---

## 9. Player Avatars & Identity

### Profile

Name only. No profile screen. The welcome screen is the profile.

### Avatar System: Sigils

Players get a randomly assigned gothic sigil/symbol (moon, raven, dagger, chalice, etc.) paired with a deterministic color based on their name hash. This gives instant visual identity without requiring any setup.

### Optional Photo Upload

Players can optionally upload a photo. The system uses AI (Imagen) to enhance/stylize it to match the Firelit Gothic aesthetic -- turning a selfie into a gothic portrait. This is an upgrade path, not a requirement.

### Avatar Sizing

- Small (32dp): lists, compact displays
- Medium (48dp): grids, player cards
- Large (64dp): featured moments, results

### Role Card Art

Custom illustrated art for every role, generated via Imagen. Art direction constraints must be defined in the spec:
- Style: consistent across all roles (same artist feel)
- Color treatment: team-colored accents
- Dimensions: portrait orientation, specific aspect ratio
- Background: transparent or dark, compositable onto card surfaces

This is hero-quality art. The role reveal card is a signature moment.

---

## 10. Error Handling & Edge Cases

### Error Style: Fully In-World

All error states stay in the gothic theme. The pattern is:

**Thematic headline + clear subtitle.**

Examples:
- "The spirits are restless..." / *Connection lost. Reconnecting...*
- "A villager has wandered into the fog..." / *[Name] disconnected*
- "The tavern door is barred..." / *No lobby with that code*
- "The village is full..." / *This lobby has reached capacity*

Error containers use themed styling (gothic card, atmospheric background) but the subtitle is always unambiguous about what happened.

### Disconnect Handling

**Dramatic and game-pausing.**

When a player disconnects mid-game:
1. All players see an in-world notification: "A villager has wandered into the fog..."
2. Gameplay pauses. No one can take actions until the player reconnects or is dropped.
3. On reconnection: "They have returned!" with state catch-up.
4. The spec must also cover connectivity maintenance -- how the app keeps connections alive, detects drops early, and minimizes pause frequency.

### Reconnection

Graceful state recovery. The reconnected player catches up to the current game state seamlessly. A brief "Welcome back" moment, then they're in sync.

---

## 10b. Interaction Model: Fluid Until Finalized

### Core Principle

**Nothing is permanent until the host or the timer says so.**

Actions (votes, selections, choices) are *fluid* -- players can change their mind freely until the phase ends. The phase ending (by timer expiry or host advancing) is the locking mechanism, not a "confirm" button.

This applies across the game:
- **Voting:** You can change your vote target as many times as you want before the voting phase ends. No "vote locked in" state. Your current selection is your vote when the clock runs out.
- **Night actions:** Where applicable, players can adjust their selection until the wave timer expires or the host advances.
- **Lobby ready state:** Ready/unready toggles freely.

This eliminates "confirm and lock" patterns. The UI shows your *current selection* and makes it easy to change. Other players may see that you've *made a selection* (checkmark) but the selection itself remains private and mutable.

### Host Phase Control

The host has the power to advance any timed phase early:
- **Discussion:** "End discussion and start voting" (already in the spec)
- **Voting:** "End voting now" -- finalizes all current selections
- **Night waves:** Advance to next wave when all actions are in
- **Results/Debrief:** "Play again" or "End game"

These controls are contextual (appear only when relevant), themed (not admin-panel style), and first-class (not hidden behind menus).

### Dev/Iteration Friendly

The codebase and component architecture should be easy to modify and extend:
- Components designed for composition, not inheritance
- Data-driven rendering (role definitions, action types, phase configurations come from the server)
- Clear separation between game logic (server) and presentation (client)
- New roles, phases, or game variants should not require structural UI changes

---

## 10c. Developer Testing Harness

### Problem

Testing a multiplayer social deduction game requires seeing the experience from multiple players' perspectives simultaneously. Running 3+ Chrome instances is painful and slow. The harness should make it trivial to test any screen, any role, any state from a single window.

### Requirements

**Role/Player Switcher:**
- A dev-only overlay or drawer that lets you switch which player you're impersonating in real time.
- Dropdown of all players in the current game, with their role shown.
- Switching instantly re-renders the screen from that player's perspective (their role, their night action, their vote state).
- Works across all game phases.

**State Injection:**
- Jump to any game phase directly (skip the flow -- go straight to voting, or to the Seer's night action).
- Set arbitrary game state: who has what role, what actions have been taken, what votes are cast.
- Trigger specific scenarios: tie votes, Hunter chain, Doppelganger multi-step, lone werewolf, no elimination.

**Screen Gallery:**
- A catalog view showing all screens in all states, browsable without playing through a game.
- Useful for visual QA: see every component variant, every error state, every phase.

**Narrator/Audio Preview:**
- Trigger any narrator cue manually to test audio timing and haptic pairing.

**Scope:** Dev/debug only. Never ships to production. Can be a separate route (`/dev/harness`) or a debug drawer toggled by a dev flag.

---

## 11. Platform & Extensibility

### Device Support

- **Primary:** Mobile phones (360-430dp width). Portrait + landscape.
- **Secondary:** Tablets. Adaptive layouts that use extra space (larger cards, more breathing room, same content).
- **Tertiary:** Web/desktop. Mobile-first, web-aware. Note where web would differ (hover states, wider layouts, keyboard shortcuts) but don't design a separate desktop experience.

### Responsive Strategy

Phone-first spec with tablet adaptation notes per screen. Not pixel-precise breakpoints across all sizes -- principle-based adaptation:
- Max content width on large screens
- Breathing room scales up
- Grid columns can increase on tablets
- Touch targets maintain minimum size

### Player Count Scaling

The UI must handle **3-20+ players** gracefully. This is critical for future Mafia support.
- Player grids need to scale beyond 2 columns
- Vote reveals and result tables need to handle large player counts

### Game Extensibility

- The design system must not be ONUW-specific. Components should work with any role set.
- Role cards, night actions, team colors -- all driven by data, not hardcoded.
- Theme/variation support: the system should accommodate reskins (different color palettes, different aesthetic themes) without structural changes.

### Content Extensibility

- Narrator persona system is pluggable.
- Role definitions, wave configurations, and action types come from the backend.

---

## 12. Accessibility

**Spec fully, defer implementation.**

The spec should document what full accessibility looks like:
- Screen reader support with semantic labels
- Color-blind safe design (don't rely solely on color for team/state distinction)
- Reduced motion mode (respect system preference, provide static alternatives to particle effects and animated transitions)
- Dynamic text sizing support
- Sufficient contrast ratios across all surfaces
- Touch target minimums (48dp)

These requirements should be called out per screen/component, even if v1 implementation defers some of them.

---

## 13. Features Explicitly Out of Scope

These were discussed and intentionally excluded:

- **Settings screen:** Not in v1. Handle later.
- **Social features / friend system:** None. The game is the social experience. Players are in the same room or on a call.
- **Bottom navigation bar:** The game is a linear phase flow driven by a state machine. Persistent nav tabs contradict this UX.
- **Chat / messaging:** Players talk in person or via external tools (Zoom).
- **In-app voice chat:** Players use external tools.
- **Tutorial game:** Contextual hints handle onboarding.
- **Match replays:** The results autopsy covers this. No video-style replay.

---

## 14. Features Explicitly In Scope

- **Online player count:** Show how many people are currently in the village (global count on home screen).
- **Simple game history:** A recent games list (date, role, win/loss). Not detailed, just a glance.
- **Play again flow:** One-tap rematch keeping the same group.
- **Post-game debrief:** Linger on results, explore the night log, then play again.
- **Contextual onboarding hints:** First-time tooltips on key interactions, disappear after use.
- **Tap-to-reveal guardrails:** Sensitive info (role, night results) hidden by default during in-person play.
- **Night waiting fidgets:** Ambient fidget interactions (embers, smoke, candle).
- **Narrator cue system:** Pluggable persona with defined cue points.
- **Custom role art:** Generated via Imagen with defined art direction constraints.
- **Haptic feedback system:** Subtle confirmation patterns tied to game beats.
- **Particle/ambient motion system:** Floating embers, dust, fog across all screens.

---

## 15. Deliverable Categories

Specs produced from this brief fall into three living categories and one disposable category. The living categories are the source of truth -- if the app doesn't match them, it's a bug. The disposable category is fuel for getting to code; once the code exists, it speaks for itself.

### Living: Behavioral Spec

Answers: **"What happens when...?"**

- **Screen specs:** Every screen, every state, every interaction, every transition. What the user sees, taps, hears, and feels at each moment.
- **User journey maps:** Host journey and player journey through a complete game, including edge cases (disconnect, reconnect, late join, first-time use).
- **Narrator cue sheet:** Every audio cue point, what information it conveys, the emotional beat, the paired haptic pattern.
- **Animation choreography:** Every theatrical moment (role reveal, vote tally, elimination) with timing, sequencing, and easing. Every tasteful transition with duration and style.
- **Error states:** Every error scenario, the in-world message, the clear subtitle, the recovery path.
- **Interaction model:** Fluid-until-finalized behavior, host phase controls, tap-to-reveal guardrails.

If a screen doesn't behave as this spec describes, that's a bug to fix in the code, not a reason to update the spec.

### Living: Technical Requirements

Answers: **"How must it work?"**

- **Platform capabilities:** Implementation-ready specs for shared systems -- narrator cue framework, haptic engine, animation system, particle system, asset pipeline, dev harness, connectivity/pause system. Includes interfaces, data types, contracts, and data flow.
- **Accessibility requirements:** Screen reader support, color-blind safety, reduced motion, dynamic text, contrast ratios, touch targets. Per-screen callouts.
- **Responsive rules:** Phone-first layouts with tablet adaptation notes. Player count scaling (3-20+). Portrait + landscape. Max content widths, grid scaling principles.
- **Extensibility contracts:** How new roles, game types, narrator personas, and themes plug in without structural changes. Data-driven rendering requirements.
- **Dev harness spec:** Role switcher, state injection, screen gallery, narrator preview.

If the system doesn't satisfy these requirements, that's a bug.

### Living: Creative Direction

Answers: **"What should it look/sound/feel like?"**

- **Art direction:** Role card illustration constraints (style, dimensions, color treatment, consistency rules). Sigil design language. Particle effect descriptions. Background illustration guidelines.
- **Design tokens:** The Firelit Gothic palette, typography, spacing, radius, shadow/glow definitions. The authoritative visual language.
- **Sound design direction:** Ambient soundscape character per phase. Narrator persona slot definition. Haptic pattern vocabulary.
- **Emotional guidelines:** The "social warmth with fun drama" north star. Per-phase mood targets. Quality bar references (Linear + Cult of the Lamb).

This is the art bible. Every new asset, every new screen, every new role must be consistent with this direction. If a generated role card doesn't feel like it belongs, the creative direction tells you why.

### Disposable: Planning Artifacts

Useful for getting to code, then the code is the source of truth:

- Component inventories and file structures
- Gap analysis (current code vs spec)
- Implementation order and dependency maps
- Stitch mock prompts (the mocks themselves are reference, but the prompts are disposable)
- Task breakdowns and work packages

These are not maintained after implementation. The code replaces them.

---

## 16. Process & Review

### Production Pipeline

```
Vision Brief (this doc)
  -> Agent team produces detailed specs (behavioral, technical, creative)
     -> Self-validated by agent team
     -> Product owner reads and approves final organized specs
  -> Agent team produces Stitch mocks from approved specs
     -> Product owner approves mocks
  -> Engineering agents implement in vertical slices, bottom-up
     -> First slice: Role Reveal (lobby -> cinematic -> card flip)
     -> Code becomes source of truth for implementation details
     -> Specs remain source of truth for behavior, requirements, and creative direction
```

### Review Cadence

- **Specs:** Product owner reviews final organized output, not intermediate work. Agent teams self-validate internally.
- **Mocks:** Product owner approves visual mocks before engineering begins.
- **Implementation:** Quality assurance is engineered (automated tests + review agents), not manual. Product owner's time is expensive.
- **Spec updates:** If the compiler or runtime reveals that a spec is wrong, update the spec. The behavioral/technical/creative specs are living documents -- they evolve, but they always represent the intended truth.

### Vertical Slice Strategy

Build bottom-up in vertical slices to get something tangible fast. Each slice delivers a working, polished flow end-to-end:

1. **Role Reveal:** Lobby -> cinematic transition -> envelope card flip. The hero moment. If this feels right, the quality bar is established.
2. Subsequent slices TBD based on learnings from slice 1.

### File Organization

Mix of per-screen, per-concern, and per-phase files -- whatever fits the content. All organized under a maintained index so everything is findable. Consistency within each section; no single rigid structure imposed across all content.

### Done Criteria

A spec is done when an implementation agent can build the described behavior without asking clarifying questions. A screen is done when it matches the behavioral spec, satisfies the technical requirements, and is consistent with the creative direction.

---

## 17. Spec Templates

All spec documents use one of two templates. The template determines the document's structure. Sections marked REQUIRED must be populated; optional sections are included when relevant to the doc type.

### Template A: Behavioral Object

For anything with states, transitions, and interactions: screen specs, user journeys, narrator cue sheets, cross-cutting behavioral patterns.

```markdown
# [Name]

## Identity
<!-- REQUIRED. Machine-parseable header. -->
| Field     | Value                              |
|-----------|------------------------------------|
| type      | screen | journey | narrator-cue | pattern |
| id        | S05, J-host, NC-wave-start, etc.   |
| phase     | lobby | night | discussion | voting | results | all |
| route     | /game/:gameId (if applicable)      |

## Layout
<!-- REQUIRED for screens. ASCII wireframe showing structure. -->
<!-- Label every region. Note tablet/landscape adaptations. -->
┌─────────────────────────────┐
│  [appbar region]            │
│─────────────────────────────│
│  [content region]           │
│  [interactive region]       │
│  [footer region]            │
└─────────────────────────────┘

Tablet: [adaptation notes]
Landscape: [adaptation notes]

## Preconditions
<!-- REQUIRED. What must be true for this object to be active. -->
<!-- State machine entry conditions. No prose -- list conditions. -->
- condition 1
- condition 2

## States
<!-- REQUIRED. Exhaustive. Every visible state including loading, -->
<!-- empty, error. No state is too minor to list. -->
| State ID | Trigger | What the user sees | Audio/Haptic |
|----------|---------|-------------------|--------------|

## Transitions
<!-- REQUIRED. Where does each exit state go? -->
| From State | Condition | To (screen/state) | Animation |
|------------|-----------|-------------------|-----------|

## Interactions
<!-- REQUIRED for screens. Every interactive element. -->
<!-- Explicit success path AND failure path per interaction. -->
| Element | Event | Result | Haptic | Sound |
|---------|-------|--------|--------|-------|

## Narrator Cues
<!-- REQUIRED if audio fires on this screen. -->
<!-- Separate: trigger (when), content (what info), beat (mood). -->
| Trigger | Semantic Content | Emotional Beat | Haptic Pairing |
|---------|-----------------|----------------|----------------|

## Errors
<!-- REQUIRED. Every error scenario. -->
| Error | In-World Headline | Clear Subtitle | Recovery |
|-------|-------------------|----------------|----------|

## Animation
<!-- REQUIRED for screens. Exact values, never "smooth" or "nice." -->
| Moment | Duration | Easing | What moves |
|--------|----------|--------|------------|

## Strings
<!-- All user-facing text on this screen. Enables i18n. -->
| Key | Default Text | Notes |
|-----|-------------|-------|

## Information Architecture
<!-- REQUIRED for screens. What the player sees vs doesn't see. -->
<!-- Host vs player differences. Hidden info guardrails. -->

## Accessibility
<!-- REQUIRED. Spec now, implement later. -->
<!-- Screen reader labels, contrast notes, reduced-motion fallback. -->

## Open Questions
<!-- Anything the team debated but didn't fully resolve. -->
<!-- Must be empty for the spec to be considered "done." -->
```

#### Section inclusion by doc type

| Section | Screen | Journey | Narrator Cue | Pattern |
|---------|--------|---------|-------------|---------|
| Identity | YES | YES | YES | YES |
| Layout | YES | no | no | optional |
| Preconditions | YES | YES | YES | YES |
| States | YES | YES (phases as states) | YES (cues as states) | YES |
| Transitions | YES | YES | YES | optional |
| Interactions | YES | no | no | YES |
| Narrator Cues | if audio | no | IS the doc | optional |
| Errors | YES | YES | no | YES |
| Animation | YES | optional | no | optional |
| Strings | YES | no | YES (cue text) | optional |
| Info Architecture | YES | YES | no | optional |
| Accessibility | YES | optional | no | optional |
| Open Questions | YES | YES | YES | YES |

### Template B: Reference Inventory

For anything that defines a vocabulary others reference: design tokens, creative direction, asset inventories.

```markdown
# [Token Set / Asset Type / Creative Domain]

## Identity
<!-- REQUIRED. -->
| Field   | Value                                  |
|---------|----------------------------------------|
| type    | tokens | assets | creative-direction   |
| domain  | color | typography | sound | motion | art |

## Vocabulary
<!-- REQUIRED. The authoritative table. This IS the document. -->
<!-- Every item: name, value/description, usage, constraints. -->
| Name | Value | Usage | Constraints |
|------|-------|-------|-------------|

## Usage Rules
<!-- REQUIRED. When to use and when NOT to. Binary, no judgment. -->
- DO: [specific instruction]
- DO NOT: [specific instruction]

## Pairing Rules
<!-- How elements relate to each other. -->
- [element A] always pairs with [element B] when [condition]

## Examples
<!-- Concrete, copy-pasteable. Dart code, exact measurements. -->

## Open Questions
<!-- Must be empty for "done." -->
```

### Template Rules (apply to both)

1. **No "use your judgment"** -- specify the judgment
2. **No "smooth" or "nice"** -- use exact values (300ms, easeInOut)
3. **Tables over prose** for all enumerable things. Prose only for rules requiring reasoning.
4. **Token references, not raw values** -- `AppColors.tallowGold`, not `#C8A24D`
5. **Every state listed** -- including loading, empty, error, disabled, reconnecting
6. **ASCII wireframe per screen** -- showing layout, hierarchy, regions
7. **Explicit success AND failure paths** for every interaction
8. **Open Questions must be empty** for a spec to be considered done -- resolve or escalate
