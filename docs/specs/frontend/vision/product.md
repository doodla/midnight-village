# Midnight Village — Product Vision Brief

The product half of the frontend vision brief: what the experience should be, why, and for whom. This is the "soul" document — the emotional north star, quality bar, personas, screen direction, scope decisions, and production process.

> **See also:** [technical.md](technical.md) — the technical half covering aesthetic tokens, animation, sound, platform, accessibility, and spec templates.

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
- Content layer: medieval facts, rotating lore snippets, village rumors.
- Interactive layer: ambient fidget elements (poke embers, swirl smoke, play with a candle flame). Fun and benign.
- Live quiz: low-stakes trivia that everyone participates in simultaneously. No pressure.
- Multiplayer mini-games: a future extension point. Spec the slot.
- Server-driven content (trivia/facts served from backend, AI-generated library later).
- Wave progress indicator (dot system showing which wave is active).
- Feel: campfire stories while waiting for your turn. Cozy, engaging, concealing.

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
- **Night waiting engagement layer:** Medieval trivia, live quiz, ambient fidget interactions.
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
