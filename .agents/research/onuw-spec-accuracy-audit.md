---
id: research-onuw-spec-accuracy-audit
title: ONUW Spec Accuracy Audit — Base Game and Daybreak
domain: [game-rules, specs]
status: concluded
created: 2026-04-03
updated: 2026-04-03
agent: claude-code
builds-on: []
tags: [onuw, accuracy, rules-verification, doppelganger]
---

## Summary

Comprehensive accuracy audit of all 11 spec files in `docs/specs/onuw/`. Found **1 critical error** (Doppelganger card team resolution when swapped), **1 significant inconsistency** (Team Resolution Rule section contradicts the win condition algorithm), and **1 ambiguous but defensible position** (Doppelganger follow-up optionality). All other major claims — wake order, win conditions, Hunter chain, Minion edge cases, Bodyguard mechanics, Daybreak timing — verified as accurate.

## Findings

### CRITICAL: Doppelganger Card Team When Swapped

**Files:** `doppelganger.md` lines 269-276, 279-285

The spec claims that when the Robber takes the Doppelganger's card, the Robber is on the **Village team** ("Doppelganger card = Village team, base team"). This is wrong. Per official rules confirmed by multiple authoritative sources:

> "If a player receives the Doppelganger card during the night, she is the role the Doppelganger originally viewed."

The Doppelganger card **becomes** the copied role for all game resolution purposes, including team determination. A Robber who takes a Doppelganger-that-copied-Werewolf is on the **Werewolf team**, not Village.

**Internal contradiction:** The win condition algorithm at `voting-and-resolution.md` lines 166-173 **correctly** resolves the Doppelganger card to the copied role. The algorithm and the Doppelganger interaction examples directly contradict each other. The algorithm is right; the examples are wrong.

**Affected sections:**
- `doppelganger.md` "Doppelganger Is Robbed" — line 275 says Village, should say "matches whatever the Doppelganger copied"
- `doppelganger.md` "Team Resolution Rule" — lines 263-267 say copied role "only matters for night actions and passive abilities." It also matters for team.
- `doppelganger.md` "Doppelganger Is Troublemaker'd" — lines 279-285 correctly describe the Doppelganger player's new team but omit that the other player (who now holds the Doppelganger card) has the copied role's team

**Edge case:** If the Doppelganger card was never used to peek (e.g., it started in the center and was taken by the Drunk), then the Doppelganger card reverts to Village. This is the only case where the "base team" applies.

**Sources:** UltraBoardGames (official rules transcription), onenightultimate.com (official strategy site), One Night Fandom Wiki — all consistent, no dissenting sources found.

### SIGNIFICANT: Team Resolution Rule Section Misleading

**File:** `doppelganger.md` lines 263-267

The section states: "A player's team is always determined by the physical card currently in front of them at the end of the night." This sentence is correct. But it then says: "The copied role only matters for: Night actions [...] Passive abilities [...]"

This omits the most important thing the copied role determines: **team**. The Doppelganger card's team IS the copied role's team (unless the card was never peeked). The section should state that the copied role determines team, night actions, AND passive abilities for anyone holding the Doppelganger card.

### AMBIGUOUS: Doppelganger Follow-Up Optionality

**File:** `night-phase.md` line 212-213

The spec classifies "Doppelganger follow-up" as **Mandatory** citing "Do it now (imperative)."

**Evidence for mandatory (spec's position):**
- Base game narrator script: "do it now" — no "may"
- Rules prose: "she does that action right now" — indicative, not permissive
- Community consensus: all secondary sources describe it as mandatory

**Evidence for inheriting optionality:**
- Daybreak expansion rulebook explicitly uses "may" for Doppelganger-as-Apprentice Seer, mirroring the copied role's optionality
- "The action of her new role" arguably includes the optionality rules

**Assessment:** The spec's "mandatory" position is the dominant community interpretation and matches the literal base game text. The Daybreak evidence introduces genuine ambiguity. No designer ruling was found. The spec should note this is a contested interpretation, but the current position is defensible.

### VERIFIED CORRECT

| Claim | File | Status |
|-------|------|--------|
| Wake order (12 steps, 4 waves) | night-phase.md | Correct |
| Seer: peek 1 player OR 2 center | roles.md | Correct |
| Robber: optional swap + view new card | roles.md | Correct |
| Troublemaker: optional blind swap of two others | roles.md | Correct |
| Drunk: mandatory blind swap with center | roles.md, night-phase.md | Correct |
| Lone Werewolf: optional center peek | roles.md | Correct |
| Minion: one-way info (sees WW, WW don't see Minion) | roles.md | Correct |
| Masons: must come in pairs | roles.md, overview.md | Correct |
| Hunter: passive kill-on-death, follows the card | roles.md | Correct |
| Tanner: independent win if eliminated | roles.md | Correct |
| Tanner death blocks Werewolf win | voting-and-resolution.md | Correct |
| Min 2 votes to die | voting-and-resolution.md | Correct |
| Tied players all die | voting-and-resolution.md | Correct |
| Hunter chain does NOT recurse | voting-and-resolution.md | Correct — universal consensus, no dissent found |
| No WW among players + no one dies = Village wins | voting-and-resolution.md | Correct |
| No WW among players + only Minion dies = no team wins | voting-and-resolution.md | Correct — dominant reading of rulebook text |
| Doppelganger copies in Wave 1 | night-phase.md, doppelganger.md | Correct |
| Doppelganger Wave 3 copies act immediately in Wave 1 | night-phase.md | Correct |
| Doppelganger-as-Insomniac wakes in Wave 4 after real Insomniac | night-phase.md | Correct |
| Player count 3-10, cards = player_count + 3 | overview.md | Correct |
| Win condition algorithm (excluding Doppelganger swap bug) | voting-and-resolution.md | Correct |
| Bodyguard vote = protection (same gesture) | daybreak-roles.md | Correct |
| Doppelganger-as-Revealer wakes after real Revealer, not Wave 1 | daybreak-mechanics.md | Correct |
| Shield blocks all interaction including mandatory Drunk swap | daybreak-mechanics.md | Correct |
| Alpha Wolf: +4 cards, forced swap of center WW card | daybreak-overview.md, daybreak-roles.md | Correct |

### MINOR: Base Game Overview References Expansion Content

**File:** `overview.md` lines 139-140

The setup validation table mentions Alpha Wolf (+4 cards) and requires "Werewolf, Mystic Wolf, or Dream Wolf" — all Daybreak roles. While technically correct for the platform, this mixes base and expansion scopes. The base game overview should focus on base game constraints, with expansion constraints in the Daybreak specs.

### MINOR: Doppelganger-as-Robber Sees New Card Wording

**File:** `doppelganger.md` line 115

The spec says the Doppelganger-as-Robber "Views her new card (the one she took)." This is correct — but worth clarifying that what the Robber action shows is the card she now holds after the swap. The Doppelganger-as-Robber does NOT see the Robber card itself (she already knows she copied Robber from her Wave 1 peek). She sees the card she stole from the target player.

## Conclusion

The specs are accurate on the vast majority of rules claims. The critical fix needed is the Doppelganger card team resolution — the "Village base team" claim in `doppelganger.md` is provably wrong and contradicts the spec's own win condition algorithm. This should be fixed to state that the Doppelganger card carries the copied role's team to any holder.

**Priority fixes:**
1. Fix `doppelganger.md` "Doppelganger Is Robbed" section — Robber's team matches copied role, not Village
2. Fix `doppelganger.md` "Team Resolution Rule" — copied role determines team, not just night actions/passives
3. Fix `doppelganger.md` "Doppelganger Is Troublemaker'd" — add note about other player's team
4. Optionally: add a note to `night-phase.md` that Doppelganger follow-up optionality is contested
5. Optionally: move Alpha Wolf setup validation from `overview.md` to Daybreak specs
