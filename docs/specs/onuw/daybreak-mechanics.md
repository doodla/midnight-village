# One Night Ultimate Werewolf: Daybreak — New Mechanics

**Not in v1 scope.** Detailed specification of mechanics introduced in Daybreak that do not exist in the base game.

## 1. Shield Token System

### Overview

The Sentinel (Wave 0) places a single shield token on one player's card. The shielded card is immune to all interaction for the rest of the night.

### What the Shield Blocks

| Action | Blocked? | Notes |
|--------|----------|-------|
| Seer peek | Yes | Cannot view shielded card |
| Robber swap | Yes | Cannot swap with shielded card |
| Troublemaker swap | Yes | Cannot include shielded card in swap |
| Drunk swap (own card shielded) | Yes | Drunk cannot act if their own card is shielded |
| Alpha Wolf swap | Yes | Cannot target shielded card |
| Mystic Wolf peek | Yes | Cannot view shielded card |
| Witch swap | Yes | Cannot swap center card with shielded card |
| Village Idiot rotation | Yes | Shielded card excluded from rotation |
| Insomniac self-peek | **Yes** | Shield blocks all viewing; Drunk precedent confirms mandatory actions are also blocked |
| Curator artifact placement | Yes | Cannot place artifact on shielded card |
| Revealer flip | Yes | Cannot flip shielded card |
| Doppelganger initial peek | Yes | Cannot view shielded card |

### Implementation Notes

- Up to **two** shields can exist per game (Sentinel + Doppelganger-as-Sentinel each place one — the Daybreak box includes 2 physical shield tokens)
- Sentinel's shield is placed in Wave 0 (before Doppelganger). Doppelganger-as-Sentinel places a second shield immediately during Wave 1.
- All action validators must check shield status before executing
- State: `shielded_player_ids: set[int]` on game state (not a single Optional — can be 0, 1, or 2 shields)

## 2. Artifact Token System

### Overview

The Curator (Wave 11, last) places a randomly-selected face-down Artifact token on a player's card. After the night phase, the recipient secretly views it.

### Artifact Tokens

| Artifact | Type | Effect |
|----------|------|--------|
| Claw of the Werewolf | Role change | Player is now a Werewolf |
| Brand of the Villager | Role change | Player is now a Villager (no abilities) |
| Cudgel of the Tanner | Role change | Player is now a Tanner (only wins if eliminated) |
| Void of Nothingness | No effect | Trap — player doesn't know it's void until they look |
| Mask of Muting | Behavioral | Cannot speak during discussion (hand signals only) |
| Shroud of Shame | Behavioral | Must face away from other players; can speak, cannot look |

### Role-Changing Artifact Rules

When a player receives a role-changing artifact:
- Their **team** changes to match the new role
- Their **passive abilities** are removed (Hunter's kill-on-death, Tanner's win condition, etc.)
- Their **night action** has already occurred — the artifact doesn't retroactively undo it
- Their **information** from the night still exists — a Seer who receives Brand of the Villager still knows what they saw

### Artifact Setup

- Select which artifacts to include (can use a subset)
- Shuffle selected artifacts face-down
- Curator draws one at random during the night
- Remaining artifacts are not used

### Implementation Notes

- State: `artifact: Optional[ArtifactType]` per player
- Artifact resolution happens after night phase, before discussion
- Requires a new private event: "view your artifact" pushed to one player
- Win condition evaluation must check artifact overrides after role card evaluation

## 3. Center Werewolf Card (Fourth Center Position)

### Overview

When Alpha Wolf is in the game, one additional Werewolf card is placed perpendicular to the standard 3 center cards. This creates a fourth center-area position.

### Rules

- The Center Werewolf card **can** be interacted with by any role that targets center cards:
  - Seer peeking 2 center cards — can choose the Center Werewolf card as one of the two
  - Drunk swapping with center — can swap with the Center Werewolf card
  - Witch swapping center with player — can use the Center Werewolf card
  - Apprentice Seer peeking one center card — can view the Center Werewolf card
- Alpha Wolf **must** swap the Center Werewolf card with a non-Werewolf player's card
- After the swap, the Center Werewolf card position holds whatever card was formerly in front of the targeted player

### Setup Constraint

- Alpha Wolf requires at least one other Werewolf-type card (regular Werewolf, Mystic Wolf, or Dream Wolf) to serve as the Center Werewolf card
- Total card count is **player_count + 4** when Alpha Wolf is in play (not +3)

### Implementation Notes

- Center cards array must be variable length: 3 (base) or 4 (Alpha Wolf in game)
- The fourth position should be clearly marked as "Center Werewolf" for the Alpha Wolf's action
- All center-card-targeting logic must iterate over the actual center array length, not assume 3
- Setup validation must enforce the extra Werewolf card requirement

## 4. Face-Up Cards (Revealer Mechanic)

### Overview

The Revealer can flip one player's card face-up during the night. A face-up card is public information during discussion.

### Rules

- If the flipped card is Werewolf or Tanner → must flip back face-down
- If the flipped card is any other role → stays face-up
- Only one flip attempt per Revealer
- Doppelganger-as-Revealer gets their own flip (could result in 2 face-up cards)

### Discussion Phase Impact

- All players can see the face-up card(s) during discussion
- The face-up player's role is confirmed — eliminates uncertainty about that player
- This dramatically changes discussion dynamics (one less unknown)

### Face-Up + Other Mechanics

- **Village Idiot rotation:** Face-up status is a property of the **card**, not the seat. When Village Idiot rotates cards, face-up cards move with the card and remain face-up in their new position. Shielded face-up cards do not move (excluded from rotation).
- **Robber/Troublemaker swaps:** Face-up status logically follows the card during any swap (the physical card moves, and its orientation goes with it). This is not explicitly confirmed in the rulebook for these specific roles but is the consistent physical interpretation.
- **Artifact placement:** An artifact can be placed on a face-up card — the artifact token is still secret (face-down on the card).

### Implementation Notes

- State: `face_up: bool` per player card (follows the card during swaps/rotation)
- The game state broadcast to all players must include face-up card identities
- Face-up cards are revealed at the start of discussion, not during night

## 5. Combined Wake Order Logic

### Doppelganger with Daybreak Roles

When Doppelganger copies a Daybreak role, the timing follows the same principle as base game:
- **Immediate action roles** (Sentinel, Alpha Wolf, Mystic Wolf, Apprentice Seer, P.I., Witch, Village Idiot): Doppelganger performs the action immediately in Wave 1
- **Wave 2 participation roles** (Dream Wolf): Doppelganger participates in Wave 2
- **Late-night roles** (Revealer, Curator): Doppelganger wakes immediately **after** the real role finishes, at positions #10a and #11a respectively — NOT in Wave 1. This follows the same pattern as Doppelganger-as-Insomniac.
- **No-action roles** (Bodyguard): No follow-up

### Wave Groupings for Implementation

| Wave | Roles | State Changes? |
|------|-------|----------------|
| 0 | Sentinel | Token placement only |
| 1 | Doppelganger + immediate follow-ups | Depends on copied role |
| 2 | Werewolves, Dream Wolf (thumb), Alpha Wolf, Mystic Wolf | Alpha Wolf: forced swap |
| 3 | Minion, Dream Wolf (thumb) | Information only |
| 4 | Masons | Information only |
| 5 | Seer, Apprentice Seer, P.I. | P.I. may convert (state change) |
| 6 | Robber, Witch | Card swaps |
| 7 | Troublemaker, Village Idiot | Card swaps/rotation |
| 8 | Drunk | Card swap with center |
| 9 | Insomniac, Doppelganger-Insomniac | Information only |
| 10 | Revealer, Doppelganger-Revealer | Card flip |
| 11 | Curator, Doppelganger-Curator | Token placement |

### Key Definitions

**"Werewolf" card for game purposes** includes: regular Werewolf, Alpha Wolf, Mystic Wolf, and Dream Wolf. This definition applies to:
- P.I. conversion (stops and converts on any Werewolf-type card)
- Revealer flip-back (must flip back any Werewolf-type card)
- Alpha Wolf target exclusion (cannot swap with another Werewolf-type player)

### Expanded Action Validation

With Daybreak, action validation becomes more complex:
- Every peek/swap action must check the shield
- Center card actions must handle variable center count
- P.I. peek has conditional stopping logic (Minion does NOT trigger conversion despite being on Werewolf team)
- Witch peek triggers mandatory swap — server should verify at least one non-shielded swap target exists before allowing the peek (Witch's peek is optional, so she can avoid the trap)
- Village Idiot rotation must skip shielded cards; face-up state travels with rotated cards
- Curator cannot target shielded or already-artifacted cards
- Artifacts that change role remove ALL special powers (including Bodyguard's vote-phase protection, Hunter's kill-on-death, Tanner's win condition)

**Shield impossibility note:** With at most 2 shield tokens (Sentinel + Doppelganger-as-Sentinel), it is physically impossible to shield all non-Werewolf players in any standard game (3+ players). The "all valid targets shielded" scenario for Alpha Wolf and Witch is a theoretical impossibility, but should still be handled gracefully (skip action) as a defensive implementation measure.
