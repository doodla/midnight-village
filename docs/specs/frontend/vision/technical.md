# Midnight Village — Technical Vision Brief

The technical half of the frontend vision brief: how the system should work, what constraints it must satisfy, and what the implementation must achieve. This is the document an engineering agent reads for aesthetic tokens, animation specs, sound architecture, platform requirements, accessibility, and spec templates.

> **See also:** [product.md](product.md) — the product half covering emotional north star, quality bar, personas, screen direction, scope, and process.

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
