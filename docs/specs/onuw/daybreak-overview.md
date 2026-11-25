# One Night Ultimate Werewolf: Daybreak — Expansion Overview

Daybreak is the first expansion for ONUW.
It adds 11 new roles, the Artifact token system, Shield tokens, and a fourth center card mechanic.
All Daybreak roles can be freely mixed with base game roles.

**Not in v1 scope.** This document is for future planning.

## What's New

### 11 New Roles

| Role | Team | Wave | Action | Key Mechanic |
|------|------|------|--------|--------------|
| Sentinel | Village | 0 (before Doppelganger) | Place shield token | Blocks all card interaction on target |
| Alpha Wolf | Werewolf | 2-B (after Werewolves) | Swap Center Werewolf card with player | Converts a player to Werewolf |
| Mystic Wolf | Werewolf | 2-C (after Werewolves) | Peek one player's card | Werewolf with Seer-like intel |
| Dream Wolf | Werewolf | None (no wake) | Thumb-up during Werewolf phase | Werewolf who doesn't wake |
| Apprentice Seer | Village | 5-B | Peek one center card | Weaker Seer variant |
| Paranormal Investigator | Village* | 5-C | Peek up to 2 players (stops on WW/Tanner) | Can convert to enemy team |
| Witch | Village* | 6-B | Peek center card, must swap it with a player | Forced swap if she peeks |
| Village Idiot | Village | 7-B | Rotate all player cards left or right | Mass card shuffle |
| Revealer | Village | 10 | Flip one player's card face-up | Creates public information |
| Curator | Village | 11 (last) | Place random Artifact token on a player | Role/ability override |
| Bodyguard | Village | None (no wake) | Protects one player from elimination | Vote-phase passive |

*P.I. can become Werewolf or Tanner mid-night. Witch's team changes if she swaps her own card.

### New Mechanics

1. **Shield Token (Sentinel)** — A physical token placed on a card.
   The shielded card cannot be viewed, moved, or receive an Artifact.
   Blocks even the Drunk's mandatory swap if placed on the Drunk's card.

2. **Artifact Tokens (Curator)** — 6 face-down tokens, one placed randomly on a player. The recipient secretly views it after the night. Artifacts can override role and team:

   | Artifact | Effect |
   |----------|--------|
   | Claw of the Werewolf | You are now a Werewolf |
   | Brand of the Villager | You are now a Villager (no abilities) |
   | Cudgel of the Tanner | You are now a Tanner |
   | Void of Nothingness | No effect |
   | Mask of Muting | Cannot speak (hand signals only) |
   | Shroud of Shame | Must face away from players (can speak, cannot look) |

   Artifacts that change role also remove passive abilities (Hunter's kill-on-death, Tanner's win condition).

3. **Center Werewolf Card (Alpha Wolf)** — When Alpha Wolf is in play, a fourth center-area card is added
   (a Werewolf card placed perpendicular to the 3 center cards).
   All roles that interact with center cards can also interact with this card.

4. **Face-Up Cards (Revealer)** — A face-up card is public information during discussion. If Revealer flips a Werewolf or Tanner, it must be flipped back down.

## Combined Wake Order (Base + Daybreak)

```
#0:    Sentinel
#1:    Doppelganger
#2:    Werewolves (+ Dream Wolf thumb-up)
  #2-B:  Alpha Wolf
  #2-C:  Mystic Wolf
#3:    Minion (+ Dream Wolf thumb-up)
#4:    Masons
#5:    Seer
  #5-B:  Apprentice Seer
  #5-C:  Paranormal Investigator
#6:    Robber
  #6-B:  Witch
#7:    Troublemaker
  #7-B:  Village Idiot
#8:    Drunk
#9:    Insomniac
  #9a:   Doppelganger-Insomniac
#10:   Revealer
  #10a:  Doppelganger-Revealer
#11:   Curator
  #11a:  Doppelganger-Curator

No-wake: Villager, Tanner, Hunter, Bodyguard, Dream Wolf
```

## Implementation Considerations

### New State Requirements

| Mechanic | State Needed |
|----------|-------------|
| Shield token | `shielded_player_id: Optional[int]` on game state |
| Artifact tokens | `artifact: Optional[ArtifactType]` per player |
| Center Werewolf card | Variable center card count (3 or 4) |
| Face-up cards | `face_up: bool` per player card |
| P.I. team conversion | Mutable `effective_role` during night phase |

### New Action Types

| Action | Role | Notes |
|--------|------|-------|
| `place_shield` | Sentinel | Target: any player except self |
| `place_artifact` | Curator | Target: any player; artifact randomly selected |
| `flip_card` | Revealer | Target: any player; conditional flip-back |
| `rotate_all` | Village Idiot | Direction: left or right |
| `peek_and_must_swap` | Witch | Peek center, then mandatory swap to any player |
| `forced_swap_center_werewolf` | Alpha Wolf | Must swap center WW card with non-WW player |
| `conditional_peek` | P.I. | Peek up to 2 players; stops on WW/Tanner |

### Phased Implementation Recommendation

**Phase 1 (extends existing patterns):** Alpha Wolf, Mystic Wolf, Dream Wolf, Apprentice Seer — these need only variants of existing peek/see_team actions plus the fourth center card.

**Phase 2 (new interaction mechanics):** P.I., Witch, Village Idiot, Revealer, Bodyguard — these introduce team conversion, forced swaps, mass rotation, face-up state, and vote-phase protection.

**Phase 3 (token infrastructure):** Sentinel + Curator — these require the shield token and artifact token systems, which interact with nearly every other role's action validation.

See [daybreak-roles.md](daybreak-roles.md) for detailed per-role specifications.
