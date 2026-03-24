# One Night Ultimate Werewolf — Night Phase Specification

## Overview

The night phase runs once per game, immediately after setup. Roles are called in a fixed order. Each role performs their action individually while all other players keep their eyes closed. The night takes approximately 1–2 minutes.

**Key rule:** The night is **strictly sequential**. Each role fully completes their action before the next role is called. There is no simultaneous execution within the night phase.

## Wake Order

Only roles that are actually in the game are called. If a role is not in play, it is skipped entirely.

| Step | Role | Wave | Action Category |
|------|------|------|-----------------|
| 1 | Doppelganger | 1 | Copy + conditional follow-up |
| 2 | Werewolves | 2 | Information (see teammates) |
| 3 | Minion | 2 | Information (see Werewolves, one-way) |
| 4 | Masons | 2 | Information (see teammates) |
| 5 | Seer | 3 | Information (peek) |
| 6 | Robber | 3 | State change (swap self with player) |
| 7 | Troublemaker | 3 | State change (swap two others) |
| 8 | Drunk | 3 | State change (swap self with center) |
| 9 | Insomniac | 4 | Information (peek own card) |
| 10 | Doppelganger-as-Insomniac | 4 | Information (peek own card) |

### Roles That Never Wake

These roles have no night action and are never called during the night:
- Villager
- Tanner
- Hunter

## Wave System

The wake order is grouped into 4 logical waves:

### Wave 1 — Doppelganger

The Doppelganger acts first, before any other role. She peeks at one other player's card and becomes that role.

**If the copied role has an immediate action (Seer, Robber, Troublemaker, Drunk):** The Doppelganger performs that action **immediately** during the Doppelganger phase, still in Wave 1. This happens before any other role wakes.

**If the copied role acts in Wave 2 (Werewolf, Mason, Minion):** The Doppelganger closes her eyes and wakes again when that role is called in Wave 2.

**If the copied role is Insomniac:** The Doppelganger wakes after the real Insomniac in Wave 4.

**If the copied role has no action (Villager, Tanner, Hunter):** No follow-up. Doppelganger closes eyes.

### Wave 2 — Information Gathering (No State Changes)

Werewolves, Minion, and Masons wake in this wave. **No cards are moved or swapped.** Players only gain information about who shares their team. Since no state changes occur, the ordering within Wave 2 is mechanically irrelevant — the narrator calls them in the order shown for thematic consistency only.

- **Werewolves** see each other (lone Werewolf may peek one center card)
- **Minion** sees all Werewolves (Werewolves don't see Minion)
- **Masons** see each other

If the Doppelganger copied a Wave 2 role, she participates in the relevant call:
- Doppelganger-as-Werewolf wakes with Werewolves, is visible to other Werewolves
- Doppelganger-as-Minion wakes during Minion phase, sees Werewolf thumbs
- Doppelganger-as-Mason wakes with Masons, is visible to the other Mason

### Wave 3 — State-Changing Actions (Strict Sequential Order)

This is the critical wave. Actions here **modify game state** (swap cards). The order within Wave 3 is **strict and canonical**:

```
Seer → Robber → Troublemaker → Drunk
```

Each role acts on the **current state** after all preceding roles in this wave have resolved. This means:

1. **Seer** peeks at the pre-swap state (sees cards before any Wave 3 swaps)
2. **Robber** swaps on the post-Seer state (Seer didn't change anything, so same state)
3. **Troublemaker** swaps on the post-Robber state (sees the result of Robber's swap)
4. **Drunk** swaps on the post-Troublemaker state (sees the result of all prior swaps)

**Doppelganger and Wave 3 roles:** Per official rules, when the Doppelganger copies a Wave 3 role (Seer, Robber, Troublemaker, Drunk), she performs that action **immediately during Wave 1** (the Doppelganger phase), before any other role wakes. The real role holder then acts normally in Wave 3. This means:

- Doppelganger-as-Seer peeks in Wave 1 (sees original state, before any swaps)
- Doppelganger-as-Robber swaps in Wave 1 (real Robber in Wave 3 sees post-Doppelganger state)
- Doppelganger-as-Troublemaker swaps in Wave 1
- Doppelganger-as-Drunk swaps with center in Wave 1

The canonical Wave 3 order for real role holders remains: `Seer → Robber → Troublemaker → Drunk`.

> **Implementation note:** The current codebase defers Doppelganger Wave 3 follow-ups to Wave 3 (placing them before the real role holder via sort key). This is a known deviation from official rules. The behavioral difference matters for Doppelganger-as-Seer specifically: in the current code she sees post-Wave-2 state, while officially she should see original state. This should be corrected.

### Wave 4 — Final Checks

The Insomniac (and Doppelganger-as-Insomniac) peek at their own card to see if it was swapped during Wave 3.

- **Insomniac** wakes first, peeks own card
- **Doppelganger-as-Insomniac** wakes second, peeks own card

## Narrator Script

The following is the complete narrator script. Only include lines for roles in the current game.

### Opening
> "Everyone, close your eyes."

### Doppelganger (Wave 1)
> "Doppelganger, wake up and look at another player's card. You are now that role. If your new role has a night action, do it now."

*Doppelganger opens eyes, peeks one player's card. If copied role has an immediate action (Seer/Robber/Troublemaker/Drunk), performs it now.*

> "Doppelganger, close your eyes."

**Special Minion variant** (only if Minion is in the game):
> "If you are now a Minion, keep your eyes open. Otherwise, close them. Werewolves, stick out your thumb so the Doppelganger-Minion can see who you are."

*If Doppelganger copied Minion, she keeps eyes open and sees Werewolf thumbs.*

> "Werewolves, put your thumbs away. Doppelganger, close your eyes."

### Werewolves (Wave 2)
> "Werewolves, wake up and look for other Werewolves."

*All Werewolves (including Doppelganger-as-Werewolf) open eyes and see each other.*

**Lone Werewolf variant:**
> "If there is only one Werewolf, you may look at one center card."

*Lone Werewolf may peek one center card (optional).*

> "Werewolves, close your eyes."

### Minion (Wave 2)
> "Minion, wake up. Werewolves, stick out your thumb so the Minion can see who you are."

*Minion opens eyes. Werewolves (eyes closed) extend thumbs. Minion sees Werewolf identities.*

> "Werewolves, put your thumbs away. Minion, close your eyes."

### Masons (Wave 2)
> "Masons, wake up and look for other Masons."

*Both Masons (including Doppelganger-as-Mason) open eyes and see each other. Lone Mason sees no one and deduces the other Mason is in the center.*

> "Masons, close your eyes."

### Seer (Wave 3)
> "Seer, wake up. You may look at another player's card or two of the center cards."

*Seer chooses: peek one player's card OR peek two center cards.*

> "Seer, close your eyes."

### Robber (Wave 3)
> "Robber, wake up. You may exchange your card with another player's card, and then view your new card."

*Robber may swap their card with another player's card, then views the taken card. May choose not to swap.*

> "Robber, close your eyes."

### Troublemaker (Wave 3)
> "Troublemaker, wake up. You may exchange cards between two other players."

*Troublemaker may swap two other players' cards without looking. May choose not to swap.*

> "Troublemaker, close your eyes."

### Drunk (Wave 3)
> "Drunk, wake up and exchange your card with a card from the center."

*Drunk must swap their card with one center card. Does not view new card.*

> "Drunk, close your eyes."

### Insomniac (Wave 4)
> "Insomniac, wake up and look at your card."

*Insomniac views own card to see if it changed.*

> "Insomniac, close your eyes."

### Doppelganger-as-Insomniac (Wave 4)
> "Doppelganger, if you viewed the Insomniac card, wake up and look at your card."

*Doppelganger-as-Insomniac views own card to see if it changed.*

> "Doppelganger, close your eyes."

### Closing
> "Everyone, wake up!"

## Action Types

| Action Type | Description | Roles |
|-------------|-------------|-------|
| `see_team` | See other players with the same role/team | Werewolf, Minion, Mason |
| `peek_player` | View one other player's current card | Seer (option A) |
| `peek_center` | View one or two center cards | Seer (option B), Werewolf (lone) |
| `swap_with_player` | Exchange own card with another player's, view new card | Robber |
| `swap_others` | Exchange two other players' cards (blind) | Troublemaker |
| `swap_with_center` | Exchange own card with a center card (blind) | Drunk |
| `peek_player` (self-target) | View own current card | Insomniac |
| `none` | No action | Villager, Tanner, Hunter |

## Action Optionality

The official rulebook uses specific language to indicate whether each role's action is optional or mandatory:

| Role | Optional? | Rulebook Language | Notes |
|------|-----------|-------------------|-------|
| Seer | **Optional** | "You **may** look at..." | Can choose not to peek |
| Robber | **Optional** | "You **may** exchange..." | Can choose not to swap |
| Troublemaker | **Optional** | "You **may** exchange..." | Can choose not to swap |
| Drunk | **Mandatory** | "Exchange your card..." (no "may") | Must swap with center |
| Werewolf (lone) | **Optional** | "You **may** view one center card" | Can decline center peek |
| Doppelganger initial peek | **Mandatory** | "Wake up and look at..." | Must look at a card |
| Doppelganger follow-up | **Mandatory** | "Do it now" (imperative) | Must perform copied action |

In the digital implementation, optional actions can be submitted as a "skip" (or allowed to time out). Mandatory actions should be enforced — the client must submit a valid action before the timer expires. If a mandatory action times out, it is still skipped (graceful degradation) but this is a timeout, not a legitimate choice.

## Timer Model (Digital Implementation)

In the physical game, the narrator counts to approximately 10 after each role call. In the digital app:

- Each wave has a configurable timer (default: ~7–10 seconds per role)
- Players without actions during a wave see a "waiting" screen
- If a player does not submit an action before the timer expires, their action is **skipped** (logged as `"skip"`, no state change)
- The server progresses to the next wave automatically when the timer expires or all expected actions are received
- The Doppelganger may need extra time since they must peek first and then potentially perform a follow-up action

## State Mutation Rules

1. **Wave 1 and Wave 2 do not mutate card positions** (except Doppelganger copying a Wave 3 role, which does mutate)
2. **Wave 3 mutations are sequential** — each action sees the result of all prior actions
3. **Wave 4 does not mutate card positions** — peek only
4. **All mutations are logged** — every action (including skips) is recorded for audit/replay
5. **State is immutable** — each action produces a new state object; the previous state is preserved

## Interaction Examples

### Example 1: Robber then Troublemaker

Initial state: Alice=Werewolf, Bob=Robber, Carol=Villager

1. Bob (Robber) swaps with Alice: Bob→Werewolf, Alice→Robber
2. Carol (Troublemaker) swaps Alice and Bob: Alice→Werewolf, Bob→Robber

Final: Alice=Werewolf, Bob=Robber, Carol=Villager. The Troublemaker "undid" the Robber's swap.

### Example 2: Robber then Troublemaker (different targets)

Initial state: Alice=Werewolf, Bob=Robber, Carol=Villager, Dave=Seer

1. Bob (Robber) swaps with Alice: Bob→Werewolf, Alice→Robber
2. Carol (Troublemaker) swaps Alice and Dave: Alice→Seer, Dave→Robber

Final: Alice=Seer, Bob=Werewolf, Carol=Villager, Dave=Robber.

### Example 3: Seer sees pre-swap state

Initial state: Alice=Werewolf, Bob=Seer, Carol=Robber

1. Bob (Seer) peeks at Alice: sees Werewolf
2. Carol (Robber) swaps with Alice: Carol→Werewolf, Alice→Robber

Bob's information ("Alice is Werewolf") is now **stale** — Alice is actually Robber now. Bob doesn't know about the swap.

### Example 4: Drunk into Werewolf

Initial state: Alice=Drunk, Center=[Werewolf, Villager, Seer]

1. Alice (Drunk) swaps with center card 0: Alice→Werewolf, Center=[Drunk, Villager, Seer]

Alice doesn't know she's now a Werewolf. She's on the Werewolf team but thinks she's probably something benign from the center.
