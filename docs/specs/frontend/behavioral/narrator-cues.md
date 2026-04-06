# Narrator Cue Sheet

## Identity

| Field     | Value |
|-----------|-------|
| type      | narrator-cue |
| id        | NC |
| phase     | all |

This document is the complete narrator cue sheet for Midnight Village. Every moment where narrator audio plays is enumerated here with trigger conditions, semantic content, emotional beat, and cross-modal pairings. Screen specs reference cues by ID.

---

## Narrator System Architecture

### Persona Slot

The narrator is a **pluggable persona**. This cue sheet defines:
- **When** a cue fires (trigger + conditions)
- **What information** the cue conveys (semantic content)
- **What mood** the cue carries (emotional beat)
- **What the default text is** (the "gothic storyteller" baseline persona)

The actual voice, tone, and phrasing are a persona layer. Swapping personas (game host, character voices, etc.) changes how the text is delivered but never changes the semantic content or trigger conditions.

### Concealment Principle

**Narrator cues play for ALL roles selected in the game setup, regardless of whether a role card ended up with a player or in the center.** This prevents information leakage. If Werewolf is in the game, the Werewolf wake cue plays even if both Werewolf cards are in the center. Players cannot deduce center card identities from which narrator cues are heard.

The server controls what each player's UI shows. The narrator audio is a shared broadcast -- all players hear the same cues in the same order.

### Timing Model

| Context | Timing Rule |
|---------|-------------|
| Wake cue -> action window | Cue plays, then server opens the action timer for that role's wave |
| Action window -> close cue | Server fires close cue when all expected actions are submitted OR wave timer expires |
| Close cue -> next wake cue | T-08 wave transition (800ms) per `sound-and-motion.md` |
| Phase transition cues | Embedded in T-01 through T-07 timelines per `sound-and-motion.md` |

### Cue Delivery

| Property | Value |
|----------|-------|
| Audio format | Narrator persona audio (TTS or pre-recorded) via `SoundCues.narratorCue` (S-16) |
| Text display | `AppTextStyles.narrator` (Libre Baskerville italic, 22dp) centered on overlay during phase transitions; not displayed during night wave cues (audio only) |
| Haptic | `AppHaptics.narratorBeat` (H-11) fires at the START of every narrator cue without exception |
| Volume | 100% of master volume (top of mix hierarchy per `sound-and-motion.md`) |

---

## Preconditions

- Game has been created and roles have been selected and dealt
- Game state machine has advanced past lobby phase
- Audio system is initialized and narrator persona is loaded
- For night cues: night phase is active
- For post-night cues: respective phase is active

---

## States

All narrator cues organized by game phase and wave. Each cue is a state in the narrator system.

### Night Phase -- Game Start

| Cue ID | Condition | Trigger | Semantic Content | Emotional Beat |
|--------|-----------|---------|-----------------|----------------|
| NC-GAME-START | Always (game has started) | T-01 cinematic begins; fires at narrator overlay offset (800ms into T-01) | The night has begun. The village descends into darkness. Atmospheric scene-setting. | Mysterious, descending, threshold-crossing |

**Haptic:** H-11 (`AppHaptics.narratorBeat`)
**Sound:** S-16 (`SoundCues.narratorCue`) -- narrator voice
**Phase reference:** T-01 (Lobby -> Night) timeline, narrator overlay at offset 800ms. This is the text displayed on the cinematic overlay.

---

### Night Phase -- Opening

| Cue ID | Condition | Trigger | Semantic Content | Emotional Beat |
|--------|-----------|---------|-----------------|----------------|
| NC-OPEN | Always (game has started) | After NC-GAME-START completes; fires at ~1600ms into T-01 (after cinematic text fades) | All players must close their eyes / prepare for the night phase. Mechanical instruction. | Solemn, commanding, ritual |

**Haptic:** H-11 (`AppHaptics.narratorBeat`)
**Sound:** S-16 (`SoundCues.narratorCue`) -- narrator voice
**Phase reference:** T-01 (Lobby -> Night) timeline, after the cinematic narrator overlay

---

### Night Phase -- Wave 1: Doppelganger

**Condition for entire section:** Doppelganger role card is in the game setup.

| Cue ID | Condition | Trigger | Semantic Content | Emotional Beat |
|--------|-----------|---------|-----------------|----------------|
| NC-W1-WAKE | Doppelganger in game | Wave 1 begins | Doppelganger should wake, look at another player's card, become that role, and perform its action if immediate | Mysterious, conspiratorial -- the first secret of the night |
| NC-W1-CLOSE | Doppelganger in game | Doppelganger action submitted or wave timer expires | Doppelganger should close their eyes | Brief, transitional |
| NC-W1-MINION-SUB | Doppelganger in game AND Minion in game | Immediately after NC-W1-CLOSE | If Doppelganger is now a Minion, she should keep eyes open; otherwise close them. Werewolves should extend thumbs for identification. | Tense, secretive -- an extra layer of conspiracy |
| NC-W1-MINION-END | Doppelganger in game AND Minion in game | After Doppelganger-as-Minion identification window (~5s) | Werewolves should retract thumbs. Doppelganger should close eyes. | Settling, closing the sub-ritual |

**Doppelganger-as-Minion sub-cases:**

**Sub-case A -- Minion IS in the game setup:**
NC-W1-MINION-SUB and NC-W1-MINION-END both fire. The full Wave 1 cue sequence is:
```
NC-W1-WAKE -> [action window] -> NC-W1-CLOSE -> NC-W1-MINION-SUB -> [identification window] -> NC-W1-MINION-END
```
This sequence plays regardless of whether the Doppelganger actually copied Minion (concealment principle). The server shows the Werewolf-identification UI to the Doppelganger only if she copied Minion; otherwise she sees the standard waiting screen.

**Sub-case B -- Minion is NOT in the game setup:**
NC-W1-MINION-SUB and NC-W1-MINION-END are SKIPPED. The Wave 1 cue sequence is shorter:
```
NC-W1-WAKE -> [action window] -> NC-W1-CLOSE
```
The Minion variant cannot apply because the Minion card does not exist in this game. No concealment concern since Minion's absence is public information (role tokens are visible).

**Timing impact:** Sub-case A adds ~8-10 seconds to Wave 1 (identification window + two narrator cues). The night phase timer must account for this when Doppelganger and Minion are both in the game.

---

### Night Phase -- Wave 2: Werewolves

**Condition for entire section:** Werewolf role card is in the game setup.

| Cue ID | Condition | Trigger | Semantic Content | Emotional Beat |
|--------|-----------|---------|-----------------|----------------|
| NC-W2-WW-WAKE | Werewolf in game | Wave 2 begins | All Werewolves should wake and identify each other | Dark, predatory, pack recognition |
| NC-W2-WW-LONE | Werewolf in game | After NC-W2-WW-WAKE, concurrent with action window | If only one Werewolf is awake, they may peek at one center card | Isolated, cautious -- the lone hunter |
| NC-W2-WW-CLOSE | Werewolf in game | Werewolf identification/peek complete or wave timer expires | Werewolves should close their eyes | Brief, transitional |

**Doppelganger-as-Werewolf:** If Doppelganger copied Werewolf in Wave 1, the Doppelganger player opens their eyes during NC-W2-WW-WAKE alongside real Werewolves. No additional narrator cue is needed. The standard Werewolf wake cue covers this -- the server shows the Doppelganger player as a Werewolf in the identification UI.

**Lone Werewolf logic:** NC-W2-WW-LONE always plays when Werewolf is in the game (concealment). The server determines whether a player qualifies as lone Werewolf and shows the center-card peek UI only to that player.

---

### Night Phase -- Wave 2: Minion

**Condition for entire section:** Minion role card is in the game setup.

| Cue ID | Condition | Trigger | Semantic Content | Emotional Beat |
|--------|-----------|---------|-----------------|----------------|
| NC-W2-MIN-WAKE | Minion in game | After NC-W2-WW-CLOSE + T-08 transition | Minion should wake. Werewolves should extend thumbs for identification. This is one-way -- Werewolves do not learn who the Minion is. | Servile, watchful -- the secret agent reporting in |
| NC-W2-MIN-CLOSE | Minion in game | After Minion identification window or wave timer expires | Werewolves should retract thumbs. Minion should close eyes. | Brief, transitional |

**Doppelganger-as-Minion:** If Doppelganger copied Minion, she does NOT wake again during NC-W2-MIN-WAKE. She already received Werewolf identification during the Wave 1 special Minion variant (NC-W1-MINION-SUB). Only the real Minion player (if they exist -- i.e., a player was dealt the Minion card) wakes here.

---

### Night Phase -- Wave 2: Masons

**Condition for entire section:** Mason role cards are in the game setup.

| Cue ID | Condition | Trigger | Semantic Content | Emotional Beat |
|--------|-----------|---------|-----------------|----------------|
| NC-W2-MASON-WAKE | Mason in game | After NC-W2-MIN-CLOSE (or NC-W2-WW-CLOSE if Minion not in game) + T-08 transition | Masons should wake and identify each other | Warm, trusting -- a secret alliance revealed |
| NC-W2-MASON-CLOSE | Mason in game | After Mason identification or wave timer expires | Masons should close their eyes | Brief, transitional |

**Doppelganger-as-Mason:** If Doppelganger copied Mason in Wave 1, the Doppelganger player opens their eyes during NC-W2-MASON-WAKE alongside real Mason(s). No additional narrator cue needed. The server includes the Doppelganger in the Mason identification UI.

**Lone Mason:** If only one Mason is among players (the other is in the center), the waking Mason sees no one. If Doppelganger copied Mason, both the Doppelganger and the real Mason see each other. No narrator script variant is needed; the UI handles it.

---

### Night Phase -- Wave 3: Seer

**Condition for entire section:** Seer role card is in the game setup.

| Cue ID | Condition | Trigger | Semantic Content | Emotional Beat |
|--------|-----------|---------|-----------------|----------------|
| NC-W3-SEER-WAKE | Seer in game | Wave 3 begins | Seer should wake and choose: peek at one player's card or two center cards | Mystical, knowing -- the village oracle sees truth |
| NC-W3-SEER-CLOSE | Seer in game | Seer action submitted or wave timer expires | Seer should close their eyes | Brief, transitional |

**Action optionality:** Seer action is optional ("may"). Timer expiry without action is a valid skip.

**Doppelganger-as-Seer:** Doppelganger performed the Seer action during Wave 1 (no separate narrator cue). The real Seer acts independently here in Wave 3. Both see pre-swap state for their respective timing windows.

---

### Night Phase -- Wave 3: Robber

**Condition for entire section:** Robber role card is in the game setup.

| Cue ID | Condition | Trigger | Semantic Content | Emotional Beat |
|--------|-----------|---------|-----------------|----------------|
| NC-W3-ROB-WAKE | Robber in game | After NC-W3-SEER-CLOSE + T-08 transition | Robber should wake and may swap their card with another player's card, then view their new card | Sly, opportunistic -- the thief at work |
| NC-W3-ROB-CLOSE | Robber in game | Robber action submitted or wave timer expires | Robber should close their eyes | Brief, transitional |

**Action optionality:** Robber action is optional ("may"). Can choose not to swap.

**Doppelganger-as-Robber:** Performed Robber action during Wave 1. Real Robber acts here on post-Doppelganger state.

---

### Night Phase -- Wave 3: Troublemaker

**Condition for entire section:** Troublemaker role card is in the game setup.

| Cue ID | Condition | Trigger | Semantic Content | Emotional Beat |
|--------|-----------|---------|-----------------|----------------|
| NC-W3-TM-WAKE | Troublemaker in game | After NC-W3-ROB-CLOSE + T-08 transition | Troublemaker should wake and may swap two other players' cards | Mischievous, playful -- stirring the pot |
| NC-W3-TM-CLOSE | Troublemaker in game | Troublemaker action submitted or wave timer expires | Troublemaker should close their eyes | Brief, transitional |

**Action optionality:** Troublemaker action is optional ("may"). Can choose not to swap.

**Doppelganger-as-Troublemaker:** Performed Troublemaker action during Wave 1. Real Troublemaker acts here on post-Doppelganger state.

---

### Night Phase -- Wave 3: Drunk

**Condition for entire section:** Drunk role card is in the game setup.

| Cue ID | Condition | Trigger | Semantic Content | Emotional Beat |
|--------|-----------|---------|-----------------|----------------|
| NC-W3-DRUNK-WAKE | Drunk in game | After NC-W3-TM-CLOSE + T-08 transition | Drunk should wake and swap their card with a center card (does not view new card) | Bumbling, hapless -- fate takes the wheel |
| NC-W3-DRUNK-CLOSE | Drunk in game | Drunk action submitted or wave timer expires | Drunk should close their eyes | Brief, transitional |

**Action optionality:** Drunk action is MANDATORY. Timer expiry without action is a timeout, not a legitimate skip.

**Doppelganger-as-Drunk:** Performed Drunk action during Wave 1. Real Drunk acts here.

---

### Night Phase -- Wave 4: Insomniac

**Condition for entire section:** Insomniac role card is in the game setup.

| Cue ID | Condition | Trigger | Semantic Content | Emotional Beat |
|--------|-----------|---------|-----------------|----------------|
| NC-W4-INS-WAKE | Insomniac in game | Wave 4 begins | Insomniac should wake and look at their own card to see if it changed | Anxious, curious -- "am I still who I was?" |
| NC-W4-INS-CLOSE | Insomniac in game | Insomniac has viewed card or wave timer expires | Insomniac should close their eyes | Settling, resigned |

---

### Night Phase -- Wave 4: Doppelganger-as-Insomniac

**Condition for entire section:** Doppelganger role card is in the game setup AND Insomniac role card is in the game setup.

| Cue ID | Condition | Trigger | Semantic Content | Emotional Beat |
|--------|-----------|---------|-----------------|----------------|
| NC-W4-DOPPEL-INS-WAKE | Doppelganger AND Insomniac both in game | After NC-W4-INS-CLOSE + T-08 transition | If Doppelganger copied Insomniac, she should wake and look at her own card | Anxious, curious -- same as Insomniac but tinged with uncertainty ("did I even copy the right role?") |
| NC-W4-DOPPEL-INS-CLOSE | Doppelganger AND Insomniac both in game | Doppelganger has viewed card or wave timer expires | Doppelganger should close her eyes | Settling, the last secret of the night |

**Concealment:** This cue pair plays regardless of whether the Doppelganger actually copied Insomniac. The server shows the card-peek UI only if Doppelganger copied Insomniac; otherwise the Doppelganger sees the waiting screen. Other players hear the narrator cue either way.

**Timing:** This is always the LAST night cue pair before NC-DAWN (when both Doppelganger and Insomniac are in the game).

---

### Night Phase -- Closing / Dawn

| Cue ID | Condition | Trigger | Semantic Content | Emotional Beat |
|--------|-----------|---------|-----------------|----------------|
| NC-DAWN | Always (game is in night phase) | All night waves complete; fires at narrator overlay offset within T-02 (800ms into T-02) | All players should open their eyes. The night is over. Discussion begins. | Energizing, communal -- the darkness lifts, truth-seeking begins |

**Phase reference:** T-02 (Night -> Discussion) timeline, narrator overlay at offset 800ms. The semantic content of NC-DAWN includes both "everyone wake up" and "discuss" -- these are a single cue, not two separate cues.

---

### Discussion Phase

| Cue ID | Condition | Trigger | Semantic Content | Emotional Beat |
|--------|-----------|---------|-----------------|----------------|
| NC-DISC-WARN | Always (discussion phase active) | Discussion timer crosses the 25% remaining threshold | Time is running low for discussion | Urgent, pressing -- the clock tightens |

NC-DISC-WARN is **optional** for the narrator persona. Some personas may omit it (silent approach where the timer color ramp provides the urgency). The system fires the cue; the persona decides whether to vocalize.

**Note:** Discussion start is handled by NC-DAWN (combined "wake up and discuss" cue). There is no separate discussion-start narrator cue.

---

### Voting Phase

| Cue ID | Condition | Trigger | Semantic Content | Emotional Beat |
|--------|-----------|---------|-----------------|----------------|
| NC-VOTE-START | Always (voting phase begins) | T-03 transition, fires at narrator overlay offset (400ms into T-03) | Voting begins. All players must choose someone. | Grave, decisive -- the moment of judgment |

**Phase reference:** T-03 (Discussion -> Voting) timeline, narrator overlay at offset 400ms.

---

### Elimination Phase

| Cue ID | Condition | Trigger | Semantic Content | Emotional Beat |
|--------|-----------|---------|-----------------|----------------|
| NC-ELIM-DEATH | A player received >= 2 votes (highest) | M-04 sequence, fires at offset 1600ms | [Player name] has been eliminated. Their role is [Role]. | Dramatic, theatrical -- the campfire story climax |
| NC-ELIM-DEATH-TIE | Two or more players tied for most votes (>= 2 each) | M-04 sequence, fires for each eliminated player in sequence | Multiple players have been eliminated. [Name] was the [Role]. (Repeated per player.) | Dramatic, escalating with each reveal |
| NC-ELIM-HUNTER | Eliminated player holds Hunter card (original or via Doppelganger-as-Hunter) | After M-04 initial sequence, during Hunter chain pause (600ms after first elimination) | The Hunter takes a final shot. Dramatic lead-in to the chain kill. | Sudden, retaliatory -- a dying strike |
| NC-ELIM-HUNTER-TARGET | Hunter chain kill | After NC-ELIM-HUNTER, during second M-04 sequence at offset 1600ms | [Hunter's vote target name] is also eliminated. Their role is [Role]. | Dramatic, secondary blow -- the chain completes |
| NC-ELIM-ROLE | A player was eliminated (fires after each NC-ELIM-DEATH or NC-ELIM-DEATH-TIE) | Immediately after the name announcement for each eliminated player, at M-04 offset 1600ms | [Player name] was the [Role]. Reveals the eliminated player's actual role identity. | Revelatory, settling -- the truth behind the mask |
| NC-ELIM-NONE | No player received >= 2 votes | M-05 sequence, fires at offset 200ms | No one was eliminated. The village remains whole. | Solemn, cold, anticlimactic -- an eerie quiet |

**Hunter chain detail:** NC-ELIM-HUNTER fires ONLY if the eliminated player's current card (after all night swaps) is Hunter OR Doppelganger-who-copied-Hunter. The system checks `doppelganger_copied_role` on the Doppelganger card. NC-ELIM-HUNTER is the dramatic lead-in; NC-ELIM-HUNTER-TARGET announces the chain-killed player's name and role.

**Dynamic content:** NC-ELIM-DEATH, NC-ELIM-DEATH-TIE, NC-ELIM-HUNTER-TARGET, and NC-ELIM-ROLE contain player names and role names. The narrator persona system must support dynamic string interpolation.

---

### Results Phase

| Cue ID | Condition | Trigger | Semantic Content | Emotional Beat |
|--------|-----------|---------|-----------------|----------------|
| NC-RESULT-VILLAGE | Village team is in the winners list | M-06 sequence, fires at offset 0ms | The Village wins. The werewolf threat has been eliminated. | Triumphant, warm -- the good guys prevail |
| NC-RESULT-WEREWOLF | Werewolf team is in the winners list | M-06 sequence, fires at offset 0ms | The Werewolves win. The village has been deceived. | Dark, satisfied -- the predators survive |
| NC-RESULT-TANNER | Tanner (or Doppelganger-as-Tanner) is in the winners list | M-06 sequence, fires after team result (200ms delay) | The Tanner wins. They got exactly what they wanted. | Ironic, gleeful -- the ultimate bluff pays off |
| NC-RESULT-NOBODY | Winners list is empty | M-06 sequence, fires at offset 0ms | No one wins. The village falls to confusion. | Hollow, bleak -- everybody loses |

**Multiple winners:** Tanner win is independent and can co-occur with Village win. In that case, NC-RESULT-VILLAGE fires first, then NC-RESULT-TANNER after a 200ms pause. The narrator communicates both results.

**Dynamic content:** NC-RESULT cues use team names. No player names -- the detailed breakdown is in the results UI, not the narrator.

---

## Doppelganger Conditional Path Matrix

This table enumerates ALL 12 possible roles the Doppelganger can copy and the narrator cue implications of each path. Cross-referenced from `docs/specs/onuw/doppelganger.md`.

| # | Copied Role | Team Becomes | Follow-up Timing | Follow-up Action | Narrator Cue Impact | Additional Cues |
|---|-------------|-------------|------------------|------------------|--------------------|--------------------|
| 1 | Werewolf | Werewolf | Wave 2 | Opens eyes with Werewolves | Standard NC-W2-WW-WAKE covers it; Doppelganger is included in Werewolf identification UI | None |
| 2 | Minion | Werewolf | Wave 1 (special) | Sees Werewolf thumbs via NC-W1-MINION-SUB | NC-W1-MINION-SUB + NC-W1-MINION-END fire (if Minion in game). See sub-case detail below. | NC-W1-MINION-SUB, NC-W1-MINION-END |
| 3 | Mason | Village | Wave 2 | Opens eyes with Masons | Standard NC-W2-MASON-WAKE covers it; Doppelganger included in Mason identification UI | None |
| 4 | Seer | Village | Wave 1 (immediate) | Peek player or center cards | No extra narrator cue. Action happens silently in Wave 1 UI during Doppelganger's action window. | None |
| 5 | Robber | Village (varies) | Wave 1 (immediate) | Swap + peek new card | No extra narrator cue. Swap + peek happens silently in Wave 1 UI. | None |
| 6 | Troublemaker | Village | Wave 1 (immediate) | Swap two other players | No extra narrator cue. Swap happens silently in Wave 1 UI. | None |
| 7 | Drunk | Village (varies) | Wave 1 (immediate) | Swap with center (blind) | No extra narrator cue. Swap happens silently in Wave 1 UI. | None |
| 8 | Insomniac | Village | Wave 4 | Peek own card after all swaps | NC-W4-DOPPEL-INS-WAKE + NC-W4-DOPPEL-INS-CLOSE fire (if Insomniac in game) | NC-W4-DOPPEL-INS-WAKE, NC-W4-DOPPEL-INS-CLOSE |
| 9 | Villager | Village | None | None | No follow-up. Doppelganger closes eyes after initial peek. | None |
| 10 | Tanner | Independent | None | None | No follow-up. Doppelganger closes eyes after initial peek. | None |
| 11 | Hunter | Village | None | None | No follow-up. Hunter passive ability tracked via `doppelganger_copied_role` for elimination phase. | Possible NC-ELIM-HUNTER if Doppelganger-as-Hunter is eliminated |
| 12 | Doppelganger | Village | None | None | Impossible in base game (only one Doppelganger card). No recursive copy. Documented for completeness. | None |

### Key observations:

- **Paths 4-7** (Wave 3 immediate actions): Doppelganger acts silently during her Wave 1 action window. The narrator says the standard NC-W1-WAKE cue, which covers all immediate actions with "If your new role has a night action, do it now." No per-action narrator variant is needed.
- **Paths 1, 3** (Wave 2 participation): Doppelganger wakes with the copied role's group during their standard Wave 2 cue. No additional Doppelganger-specific cue.
- **Path 2** (Minion): The ONLY path that requires a dedicated Doppelganger narrator sub-script (NC-W1-MINION-SUB/END) during Wave 1.
- **Path 8** (Insomniac): The ONLY path that requires a dedicated Doppelganger narrator cue outside Wave 1 (NC-W4-DOPPEL-INS-WAKE/CLOSE in Wave 4).
- **Paths 9-12** (no-action roles): Doppelganger closes eyes immediately. No follow-up.

---

## Doppelganger-as-Minion: Detailed Sub-Cases

The most complex narrator cue conditional in the game. The Wave 1 Doppelganger script has two structurally different forms depending on whether Minion is in the game.

### Sub-Case A: Minion IS in the Game Setup

**When:** The host selected the Minion role card for this game (regardless of whether Minion ended up with a player or in the center).

**Wave 1 narrator cue sequence:**

| Step | Cue | Content | Server UI Action |
|------|-----|---------|-----------------|
| 1 | NC-W1-WAKE | Doppelganger wake + action instruction | Show Doppelganger player the peek-a-card UI |
| 2 | -- | [Action window: Doppelganger peeks and optionally performs follow-up] | Doppelganger selects target, server resolves copy + follow-up |
| 3 | NC-W1-CLOSE | Doppelganger close eyes | Dismiss action UI, show waiting screen |
| 4 | NC-W1-MINION-SUB | "If you are now a Minion, keep eyes open..." + Werewolves thumbs | IF Doppelganger copied Minion: show Werewolf identification UI. ELSE: keep waiting screen. |
| 5 | -- | [Identification window: ~5s for Doppelganger-as-Minion to observe] | Server holds for timer |
| 6 | NC-W1-MINION-END | Werewolves retract thumbs, Doppelganger close eyes | Dismiss identification UI |

**Total Wave 1 duration:** Action window (~10s) + 2 cues (~3s) + identification window (~5s) + 2 cues (~3s) = ~21s.

**Key point:** Steps 4-6 play regardless of what the Doppelganger actually copied (concealment principle). If the Doppelganger copied Seer, she still hears the Minion sub-script but her UI shows the waiting screen, not the Werewolf identification.

### Sub-Case B: Minion is NOT in the Game Setup

**When:** The host did not select the Minion role card for this game.

**Wave 1 narrator cue sequence:**

| Step | Cue | Content | Server UI Action |
|------|-----|---------|-----------------|
| 1 | NC-W1-WAKE | Doppelganger wake + action instruction | Show Doppelganger player the peek-a-card UI |
| 2 | -- | [Action window: Doppelganger peeks and optionally performs follow-up] | Doppelganger selects target, server resolves copy + follow-up |
| 3 | NC-W1-CLOSE | Doppelganger close eyes | Dismiss action UI, show waiting screen |

**Total Wave 1 duration:** Action window (~10s) + 2 cues (~3s) = ~13s.

**Key point:** No Minion sub-script. The Doppelganger cannot have copied Minion because the card does not exist. Minion's absence from the game is public information (role tokens are visible to all players), so omitting this section does not leak information.

### Sub-Case Comparison

| Aspect | Sub-Case A (Minion in game) | Sub-Case B (Minion not in game) |
|--------|----------------------------|-------------------------------|
| Wave 1 cues | NC-W1-WAKE, NC-W1-CLOSE, NC-W1-MINION-SUB, NC-W1-MINION-END | NC-W1-WAKE, NC-W1-CLOSE |
| Wave 1 duration | ~21s | ~13s |
| Wave 2 Minion call | NC-W2-MIN-WAKE, NC-W2-MIN-CLOSE (plays) | Does not play (Minion not in game) |
| Total night impact | +8s in Wave 1, +10s in Wave 2 = ~18s longer | Baseline |
| Concealment concern | Minion sub-script always plays in Wave 1 (conceals whether Doppelganger actually copied Minion) | No concealment needed (Minion card publicly absent) |

---

## Transitions

Narrator cue sequencing follows the game's state machine. The order within the night phase is strictly defined by the wake order.

### Night Phase Cue Sequence (Complete)

All cues listed in order. Skip any cue whose condition is not met. T-08 (800ms wave transition) plays between each wave group.

| Order | Cue ID | Wave | Condition |
|-------|--------|------|-----------|
| 0 | NC-GAME-START | -- | Always (T-01 cinematic overlay, 800ms into T-01) |
| 1 | NC-OPEN | -- | Always (after NC-GAME-START, ~1600ms into T-01) |
| 2 | NC-W1-WAKE | 1 | Doppelganger in game |
| 3 | NC-W1-CLOSE | 1 | Doppelganger in game |
| 4 | NC-W1-MINION-SUB | 1 | Doppelganger in game AND Minion in game |
| 5 | NC-W1-MINION-END | 1 | Doppelganger in game AND Minion in game |
| -- | T-08 | -- | Between Wave 1 and Wave 2 |
| 6 | NC-W2-WW-WAKE | 2 | Werewolf in game |
| 7 | NC-W2-WW-LONE | 2 | Werewolf in game (always plays for concealment) |
| 8 | NC-W2-WW-CLOSE | 2 | Werewolf in game |
| -- | T-08 | -- | Between Werewolf and Minion within Wave 2 |
| 9 | NC-W2-MIN-WAKE | 2 | Minion in game |
| 10 | NC-W2-MIN-CLOSE | 2 | Minion in game |
| -- | T-08 | -- | Between Minion and Mason within Wave 2 |
| 11 | NC-W2-MASON-WAKE | 2 | Mason in game |
| 12 | NC-W2-MASON-CLOSE | 2 | Mason in game |
| -- | T-08 | -- | Between Wave 2 and Wave 3 |
| 13 | NC-W3-SEER-WAKE | 3 | Seer in game |
| 14 | NC-W3-SEER-CLOSE | 3 | Seer in game |
| -- | T-08 | -- | Between Seer and Robber within Wave 3 |
| 15 | NC-W3-ROB-WAKE | 3 | Robber in game |
| 16 | NC-W3-ROB-CLOSE | 3 | Robber in game |
| -- | T-08 | -- | Between Robber and Troublemaker within Wave 3 |
| 17 | NC-W3-TM-WAKE | 3 | Troublemaker in game |
| 18 | NC-W3-TM-CLOSE | 3 | Troublemaker in game |
| -- | T-08 | -- | Between Troublemaker and Drunk within Wave 3 |
| 19 | NC-W3-DRUNK-WAKE | 3 | Drunk in game |
| 20 | NC-W3-DRUNK-CLOSE | 3 | Drunk in game |
| -- | T-08 | -- | Between Wave 3 and Wave 4 |
| 21 | NC-W4-INS-WAKE | 4 | Insomniac in game |
| 22 | NC-W4-INS-CLOSE | 4 | Insomniac in game |
| -- | T-08 | -- | Between Insomniac and Doppelganger-Insomniac within Wave 4 |
| 23 | NC-W4-DOPPEL-INS-WAKE | 4 | Doppelganger AND Insomniac both in game |
| 24 | NC-W4-DOPPEL-INS-CLOSE | 4 | Doppelganger AND Insomniac both in game |
| 26 | NC-DAWN | -- | Always |

### Post-Night Cue Sequence

| Order | Cue ID | Phase | Condition |
|-------|--------|-------|-----------|
| 27 | NC-DISC-WARN | Discussion | Always (optional vocalization by persona) |
| 28 | NC-VOTE-START | Voting | Always |
| 29 | NC-ELIM-DEATH / NC-ELIM-DEATH-TIE / NC-ELIM-NONE | Elimination | Depends on vote outcome |
| 29a | NC-ELIM-ROLE | Elimination | Fires after each NC-ELIM-DEATH (role identity spoken) |
| 30 | NC-ELIM-HUNTER | Elimination | Hunter card holder was eliminated |
| 30a | NC-ELIM-HUNTER-TARGET | Elimination | Chain-killed player announced (after NC-ELIM-HUNTER) |
| 31 | NC-RESULT-VILLAGE / NC-RESULT-WEREWOLF / NC-RESULT-NOBODY | Results | Depends on win condition evaluation |
| 32 | NC-RESULT-TANNER | Results | Tanner (or Doppelganger-as-Tanner) died |

---

## Night Phase Duration Estimation

The total night phase duration depends on which roles are in the game. This table helps the server calculate expected night duration for timer management and player communication.

| Roles in Game | Waves Active | Estimated Night Duration |
|---------------|-------------|------------------------|
| Minimum (3-player, no Doppelganger, no Minion) | Partial Wave 2, partial Wave 3 | ~30-45s |
| Typical 5-player (WW, Seer, Robber, TM, Villager) | Wave 2 (WW), Wave 3 (Seer, Robber, TM) | ~50-70s |
| Full 12-role setup (all roles, Doppelganger + Minion) | All 4 waves, Minion sub-case A | ~120-150s |

Per-role time contribution:
- Each role with an action: ~10s (action window) + ~3s (wake + close cues) = ~13s
- Doppelganger with Minion sub-case: +8s over base Doppelganger
- T-08 transitions: 800ms each, ~8-12 transitions in a full game = ~8s total
- NC-OPEN + NC-DAWN: ~3s each = ~6s

---

## Strings

All narrator cue text strings. These are the default "gothic storyteller" persona text. Alternative personas replace these strings while preserving the semantic content.

### Night Phase Strings

| Cue ID | Default Text | Notes |
|--------|-------------|-------|
| NC-GAME-START | "Night falls on the village..." | Atmospheric scene-setter. Displayed as cinematic overlay text during T-01. Fires before NC-OPEN. |
| NC-OPEN | "Everyone, close your eyes." | Short, commanding, ritual. Mechanical instruction after the atmospheric opener. |
| NC-W1-WAKE | "Doppelganger, wake up and look at another player's card. You are now that role. If your new role has a night action, do it now." | Longest single cue. Must be clear on the multi-step instruction. |
| NC-W1-CLOSE | "Doppelganger, close your eyes." | Brief. |
| NC-W1-MINION-SUB | "If you are now a Minion, keep your eyes open. Otherwise, close them. Werewolves, stick out your thumb so the Doppelganger-Minion can see who you are." | Complex conditional phrasing. Persona must preserve the if/otherwise structure. |
| NC-W1-MINION-END | "Werewolves, put your thumbs away. Doppelganger, close your eyes." | Two instructions in sequence. |
| NC-W2-WW-WAKE | "Werewolves, wake up and look for other Werewolves." | Short, predatory. |
| NC-W2-WW-LONE | "If there is only one Werewolf, you may look at one center card." | Conditional offer. Always played for concealment. |
| NC-W2-WW-CLOSE | "Werewolves, close your eyes." | Brief. |
| NC-W2-MIN-WAKE | "Minion, wake up. Werewolves, stick out your thumb so the Minion can see who you are." | Two instructions. Establishes the one-way information flow. |
| NC-W2-MIN-CLOSE | "Werewolves, put your thumbs away. Minion, close your eyes." | Two instructions in sequence. |
| NC-W2-MASON-WAKE | "Masons, wake up and look for other Masons." | Short, warm. |
| NC-W2-MASON-CLOSE | "Masons, close your eyes." | Brief. |
| NC-W3-SEER-WAKE | "Seer, wake up. You may look at another player's card or two of the center cards." | Choice-presenting. Must clearly convey the two options. |
| NC-W3-SEER-CLOSE | "Seer, close your eyes." | Brief. |
| NC-W3-ROB-WAKE | "Robber, wake up. You may exchange your card with another player's card, and then view your new card." | Action sequence instruction. |
| NC-W3-ROB-CLOSE | "Robber, close your eyes." | Brief. |
| NC-W3-TM-WAKE | "Troublemaker, wake up. You may exchange cards between two other players." | Short action instruction. |
| NC-W3-TM-CLOSE | "Troublemaker, close your eyes." | Brief. |
| NC-W3-DRUNK-WAKE | "Drunk, wake up and exchange your card with a card from the center." | Imperative (mandatory action). No "may." |
| NC-W3-DRUNK-CLOSE | "Drunk, close your eyes." | Brief. |
| NC-W4-INS-WAKE | "Insomniac, wake up and look at your card." | Short. Self-targeting peek. |
| NC-W4-INS-CLOSE | "Insomniac, close your eyes." | Brief. |
| NC-W4-DOPPEL-INS-WAKE | "Doppelganger, if you viewed the Insomniac card, wake up and look at your card." | Conditional instruction. Plays for concealment regardless of what Doppelganger copied. |
| NC-W4-DOPPEL-INS-CLOSE | "Doppelganger, close your eyes." | Brief. Last night cue before dawn. |
| NC-DAWN | "Everyone, wake up! Discuss." | Energizing. Marks the transition from secrecy to social energy. Combined wake-up and discussion-start. |

### Post-Night Strings

| Cue ID | Default Text | Notes |
|--------|-------------|-------|
| NC-DISC-WARN | "Time is running out..." | Optional vocalization. Persona may choose to remain silent and let timer color ramp speak. |
| NC-VOTE-START | "Time to vote." | Short, grave. The weight of the moment. |
| NC-ELIM-DEATH | "{name} has been eliminated." | Dynamic: player name interpolated. |
| NC-ELIM-DEATH-TIE | "{name} has been eliminated." | Same template, repeated per eliminated player in tie. |
| NC-ELIM-ROLE | "{name} was the {role}." | Fires immediately after NC-ELIM-DEATH for each eliminated player. Dynamic: player name + role name. |
| NC-ELIM-HUNTER | "The Hunter takes aim..." | Precedes the Hunter chain-kill reveal. Dramatic pause follows. |
| NC-ELIM-HUNTER-TARGET | "{name} has also been eliminated. {name} was the {role}." | The Hunter's chain-kill victim. Dynamic. |
| NC-ELIM-NONE | "No one was eliminated." | Solemn, anticlimactic. |
| NC-RESULT-VILLAGE | "The Village wins!" | Warm, triumphant. |
| NC-RESULT-WEREWOLF | "The Werewolves win!" | Dark, satisfied. |
| NC-RESULT-TANNER | "The Tanner wins!" | Ironic, gleeful. Fires after team result if Tanner also won. |
| NC-RESULT-NOBODY | "No one wins." | Hollow, bleak. |

### String Interpolation Variables

| Variable | Source | Example |
|----------|--------|---------|
| `{name}` | Player display name from server game state | "Alice" |
| `{role}` | Role name from server role definitions | "Werewolf", "Doppelganger" |
| `{team}` | Team name from server team definitions | "Village", "Werewolf" |

---

## Open Questions

(none)
