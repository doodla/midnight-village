# One Night Ultimate Werewolf: Daybreak — Role Specifications

**Not in v1 scope.** Detailed specifications for all 11 Daybreak roles, for future implementation planning.

---

## Sentinel

| Property | Value |
|----------|-------|
| Team | Village |
| Wave | 0 (first to wake — before Doppelganger) |
| Action type | `place_shield` |
| Card count | 1 |

**Night action:** May place a shield token on any other player's card (not their own).

**Shield effect:** The shielded card may not be:
- Viewed by any role (Seer, Robber peek, Mystic Wolf, etc.)
- Moved by any role (Robber swap, Troublemaker swap, Drunk swap, Alpha Wolf swap)
- Given an Artifact token by the Curator

**Critical rule:** Even the Drunk's **mandatory** swap is blocked if the Drunk's own card is shielded. The Drunk simply cannot act.

**Doppelganger interaction:** If Doppelganger copies Sentinel, she immediately places a second shield token on any player's card (not her own card).
The Daybreak box includes 2 physical shield tokens, so up to 2 shields can be active simultaneously.

---

## Alpha Wolf

| Property | Value |
|----------|-------|
| Team | Werewolf |
| Wave | 2 (wakes with Werewolves), then 2-B (acts alone) |
| Action type | `forced_swap_center_werewolf` |
| Card count | 1 |

**Setup requirement:** When Alpha Wolf is in the game, place one additional Werewolf-type card (regular Werewolf, Mystic Wolf, or Dream Wolf) perpendicular to
the 3 center cards. This "Center Werewolf card" is a fourth center-area position.
This means:
- At least one other Werewolf-type card must be included in the role selection
- Total card count is **player_count + 4** (not +3) when Alpha Wolf is in play
- The Center Werewolf card is separate from the 3 standard center cards

**Night action (two parts):**
1. Wakes with all Werewolves in Wave 2 — sees other Werewolves
2. After Werewolves close eyes, Alpha Wolf wakes alone and **must** swap the Center Werewolf card with any non-Werewolf player's card (without viewing either)

**Effect:** The targeted player unknowingly becomes a Werewolf. Their original card goes to the Center Werewolf position.

**Special rules:**
- Cannot swap with their own card or another known Werewolf's card
- The Center Werewolf card can be interacted with by any role that targets center cards (Seer peeking 2 center cards, Drunk swapping, etc.)
- The swap is **mandatory** — Alpha Wolf must choose a target

**Doppelganger interaction:** Doppelganger-as-Alpha Wolf immediately performs the Center Werewolf swap during Wave 1.
She then wakes with the main Werewolf group in Wave 2 (the standard Werewolf call).
She does **not** wake during the Alpha Wolf's solo sub-wave (2-B).

---

## Mystic Wolf

| Property | Value |
|----------|-------|
| Team | Werewolf |
| Wave | 2 (wakes with Werewolves), then 2-C (acts alone) |
| Action type | `peek_player` |
| Card count | 1 |

**Night action (two parts):**
1. Wakes with all Werewolves in Wave 2 — sees other Werewolves
2. After Werewolves close eyes, Mystic Wolf wakes alone and **may** look at one other player's card

**Strategic value:** Gives the Werewolf team Seer-like information. The Mystic Wolf knows a player's role, which helps Werewolves coordinate lies during discussion.

**Doppelganger interaction:** Doppelganger-as-Mystic Wolf immediately peeks one player's card during Wave 1.
She then wakes with the main Werewolf group in Wave 2.
She does **not** wake during the Mystic Wolf's solo sub-wave (2-C).

---

## Dream Wolf

| Property | Value |
|----------|-------|
| Team | Werewolf |
| Wave | None (never opens eyes) |
| Action type | `none` (passive thumb-up) |
| Card count | 1 |

**Night mechanic:** Does **not** wake with Werewolves. Instead:
- When Werewolves are called: Dream Wolf sticks out thumb (eyes closed). Other Werewolves see the thumb and know the Dream Wolf's identity.
- When Minion is called: Dream Wolf also sticks out thumb.

**Narrator script change:** "Werewolves, except for the Dream Wolf, wake up and look for other Werewolves. Dream Wolf, stick out your thumb."

**Special rules:**
- The Dream Wolf knows they are on the Werewolf team but does **not** see who the other Werewolves are
- Other Werewolves know who the Dream Wolf is (they see the thumb)
- The Minion sees the Dream Wolf's thumb along with other Werewolf thumbs

**Doppelganger interaction:** Doppelganger-as-Dream Wolf sticks out her thumb when Werewolves are called.
Does not open eyes. She does **not** learn the identities of other Werewolves — she only knows she is on the Werewolf team (from her Wave 1 peek).

---

## Apprentice Seer

| Property | Value |
|----------|-------|
| Team | Village |
| Wave | 5-B (after Seer) |
| Action type | `peek_center` (one card only) |
| Card count | 1 |

**Night action:** May look at **one** center card.

**Distinction from Seer:** The Seer can peek one player OR two center cards. The Apprentice Seer can only peek one center card — weaker but still useful.

**Doppelganger interaction:** Doppelganger-as-Apprentice Seer immediately peeks one center card during Wave 1. Does not wake at position 5-B.

---

## Paranormal Investigator (P.I.)

| Property | Value |
|----------|-------|
| Team | Village (can convert to Werewolf or Tanner) |
| Wave | 5-C (after Apprentice Seer) |
| Action type | `conditional_peek` |
| Card count | 1 |

**Night action:** May look at up to two other players' cards, one at a time:
1. Peek first player's card
2. If it's a **Werewolf** → P.I. becomes a Werewolf (joins Werewolf team), must stop
3. If it's a **Tanner** → P.I. becomes a Tanner (only wins if eliminated), must stop
4. If it's anything else → may choose to peek a second player (same stop rules apply)
5. If second card is also not Werewolf/Tanner → done, stays on Village team

**Critical edge cases:**
- If P.I. peeks a **Doppelganger** who copied a Werewolf, the P.I. sees "Doppelganger" (the physical card) and does **not** convert. The P.I. does not know what the Doppelganger saw.
- If P.I. peeks the **Minion**, the P.I. does **not** convert — even though the Minion is on the Werewolf team. Only the physical "Werewolf" and "Tanner" cards trigger conversion.
- The P.I. conversion check is against the **card name**, not the team. Alpha Wolf, Mystic Wolf, and Dream Wolf cards **do** trigger conversion (they are Werewolf-type cards).

**Doppelganger interaction:** Doppelganger-as-P.I.
immediately performs the peek-and-convert action during Wave 1.
If the Doppelganger-as-P.I. peeks a Werewolf card, she **becomes a Werewolf** (joins the Werewolf team for win conditions).
If she peeks a Tanner, she becomes a Tanner.

---

## Witch

| Property | Value |
|----------|-------|
| Team | Village (changes if she swaps her own card) |
| Wave | 6-B (after Robber) |
| Action type | `peek_and_must_swap` |
| Card count | 1 |

**Night action (conditional mandatory):**
1. May look at one center card
2. If she looks: she **must** swap that center card with any player's card (including her own), without viewing the player's card
3. If she doesn't look: nothing happens

**Team change:** If the Witch swaps her own card with a center card, her team changes to whatever center card she received (she doesn't know what it is).

**Distinction from Drunk:** The Drunk must always swap and never peeks. The Witch's peek is optional, but if she peeks, the swap is mandatory.

**Doppelganger interaction:** Doppelganger-as-Witch immediately performs the peek-and-swap during Wave 1.

---

## Village Idiot

| Property | Value |
|----------|-------|
| Team | Village |
| Wave | 7-B (after Troublemaker) |
| Action type | `rotate_all` |
| Card count | 1 |

**Night action:** May move all players' cards (except their own) one position to the **left** or one position to the **right**.
The direction is their choice. The rotation is all-or-nothing — they cannot move a subset.

**Excluded from rotation:**
- Village Idiot's own card
- Shielded cards (Sentinel's token)
- Center cards

**Effect:** Every non-excluded player now holds the card that was in front of the player to their left (or right). This is a mass swap.

**Doppelganger interaction:** Doppelganger-as-Village Idiot immediately rotates all cards during Wave 1.

---

## Revealer

| Property | Value |
|----------|-------|
| Team | Village |
| Wave | 10 |
| Action type | `flip_card` |
| Card count | 1 |

**Night action:** May flip one other player's card face-up.
- If the revealed card is a **Werewolf** or **Tanner** → must flip it back face-down
- If the revealed card is anything else (including Doppelganger, P.I.) → leave it face-up

**Face-up effect:** A face-up card is **public information** during the discussion phase. All players can see that player's role.

**Special rules:**
- Gets only one flip attempt, even if the card must be flipped back
- Cannot flip their own card

**Doppelganger interaction:** Doppelganger-as-Revealer wakes immediately after the real Revealer goes to sleep and may flip one face-down player card.
The same flip-back rules apply: if the flipped card is a Werewolf or Tanner, it must be flipped back face-down.
This means up to 2 cards can be face-up during discussion (one from each Revealer).

---

## Curator

| Property | Value |
|----------|-------|
| Team | Village |
| Wave | 11 (last waking role) |
| Action type | `place_artifact` |
| Card count | 1 |

**Night action:** May place one randomly-selected face-down Artifact token on any player's card (including their own).

**Cannot place on:**
- A shielded card (Sentinel's token)
- A card that already has an Artifact token

**Artifact resolution:** After the night phase ends (but before discussion), the player with the Artifact secretly views it. They may not show it but may say anything about it.

**Artifact effects:**
- Role-changing artifacts (Claw/Brand/Cudgel) override the player's role and team
- Role-changing artifacts also remove passive abilities (Hunter's kill, Tanner's win condition)
- Mask of Muting and Shroud of Shame are behavioral restrictions, not role changes
- Void of Nothingness does nothing (but the player doesn't know which artifact they received until they look)

**Doppelganger interaction:** Doppelganger-as-Curator wakes immediately after the real Curator goes to sleep and may place an Artifact.

---

## Bodyguard

| Property | Value |
|----------|-------|
| Team | Village |
| Wave | None (no night action) |
| Action type | `none` (vote-phase passive) |
| Card count | 1 |

**Vote-phase mechanic:** During voting, the Bodyguard points at (votes for) a player.
That player **cannot be eliminated**, regardless of vote count.
If the protected player would have died, the player with the next-highest vote count (minimum 2 votes) is eliminated instead.

**Special rules:**
- The Bodyguard's protection is applied during vote resolution, after tallying
- The Bodyguard can protect themselves
- If no one else has ≥2 votes after the protected player is excluded, no one dies
- The Bodyguard's "vote" for a player serves as both their vote AND their protection target (same gesture)

**Note:** This role has no night action. The protection mechanic lives entirely in the voting resolution phase, requiring a hook in the elimination resolver that the base game does not have.
