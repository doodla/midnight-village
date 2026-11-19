# One Night Ultimate Werewolf — Doppelganger Specification

The Doppelganger is the most complex role in ONUW. This document specifies every interaction the Doppelganger can have with every other role.

## Core Mechanic

1. The Doppelganger wakes **first** (Wave 1), before all other roles
2. She looks at one other player's card
3. She **becomes** that role — taking on its team, win conditions, and night action
4. If the copied role has a night action, she performs it (timing depends on the copied role)
5. Her physical card stays as "Doppelganger" in front of her — the copy is tracked by the server

## Doppelganger Interaction Matrix

### Copies Werewolf

| Property | Detail |
|----------|--------|
| Team becomes | Werewolf |
| Follow-up wave | Wave 2 |
| Follow-up action | Wakes with Werewolves, sees all other Werewolf players |

**Detailed behavior:**
- In Wave 1: Doppelganger peeks a player's card, sees "Werewolf"
- Doppelganger closes eyes
- In Wave 2 (Werewolf call): Doppelganger opens eyes along with real Werewolves
- All Werewolves see each other (including Doppelganger-as-Werewolf)
- If Doppelganger is the only "Werewolf" awake (the real Werewolf card she peeked at is in the slot of the player she copied, but that player is ALSO a Werewolf — they both wake): standard multi-Werewolf behavior
- **Lone Werewolf interaction:** If Doppelganger copies Werewolf and no other Werewolves wake (both real Werewolf cards are in the center), the Doppelganger is the lone Werewolf and **may** peek one center card

**Win condition:** Doppelganger wins with Werewolf team. If the Doppelganger-as-Werewolf is eliminated, Village wins.

---

### Copies Minion

| Property | Detail |
|----------|--------|
| Team becomes | Werewolf |
| Follow-up wave | Wave 1 (special script at end of Doppelganger phase) |
| Follow-up action | Sees all Werewolf players via thumb-up |

**Detailed behavior:**
- In Wave 1: Doppelganger peeks a player's card, sees "Minion"
- Special narrator script: "If you are now a Minion, keep your eyes open. Otherwise, close them."
- Werewolves extend thumbs (eyes closed)
- Doppelganger-as-Minion sees which players are Werewolves
- "Werewolves, put your thumbs away. Doppelganger, close your eyes."
- When the real Minion wakes in Wave 2, the real Minion also sees Werewolf thumbs

**Werewolves do NOT know** that there are now two Minion-like roles in play.

**Win condition:** Same as Minion. Doppelganger-as-Minion wins with Werewolf team. If no Werewolves are among players, Doppelganger-as-Minion wins if a non-Minion/non-Doppelganger player dies.

---

### Copies Mason

| Property | Detail |
|----------|--------|
| Team becomes | Village |
| Follow-up wave | Wave 2 |
| Follow-up action | Wakes with Masons, sees other Mason players |

**Detailed behavior:**
- In Wave 1: Doppelganger peeks a player's card, sees "Mason"
- Doppelganger closes eyes
- In Wave 2 (Mason call): Doppelganger opens eyes with real Mason(s)
- Doppelganger and real Mason(s) see each other

**Edge cases:**
- If Doppelganger copies the one Mason that's among players and the other Mason is in the center: Doppelganger and real Mason see each other (2 Masons present)
- If both real Masons are among players: all three (Doppelganger + 2 Masons) see each other
- If both real Mason cards are in the center: impossible — Doppelganger can only copy a player's card, not a center card

**Win condition:** Village team.

---

### Copies Seer

| Property | Detail |
|----------|--------|
| Team becomes | Village |
| Follow-up wave | Immediately in Wave 1 (before any other role wakes) |
| Follow-up action | Peek one player's card OR two center cards |

**Detailed behavior:**
- In Wave 1: Doppelganger peeks a player's card, sees "Seer"
- **Immediately** (still in the Doppelganger phase), the Doppelganger performs the Seer action:
  - Option A: Look at one other player's card
  - Option B: Look at two center cards
- Doppelganger closes eyes
- The real Seer later wakes in Wave 3 and performs their own Seer action independently

**Critical timing:** The Doppelganger-as-Seer acts in Wave 1, seeing the **original** card state (before any Wave 2 or Wave 3 actions). The real Seer acts at the start of Wave 3, also seeing the pre-swap state (but after any Doppelganger Wave 1 actions — which for Seer don't change state anyway).

**Win condition:** Village team.

---

### Copies Robber

| Property | Detail |
|----------|--------|
| Team becomes | Village (changes to match stolen card's team) |
| Follow-up wave | Immediately in Wave 1 |
| Follow-up action | Swap own card with another player's, view new card |

**Detailed behavior:**
- In Wave 1: Doppelganger peeks a player's card, sees "Robber"
- **Immediately**, the Doppelganger performs the Robber action:
  - Selects one other player
  - Swaps her Doppelganger card with that player's card
  - Views her new card (the one she took)
- Doppelganger closes eyes
- The real Robber later wakes in Wave 3 and performs their own Robber action

**Critical timing:** The Doppelganger-as-Robber swaps in Wave 1, before any other role acts. This means:
- The player she robbed now has the "Doppelganger" card
- She now has whatever card that player had
- When the real Robber acts in Wave 3, they see the post-Doppelganger state

**Team change:** If the Doppelganger-as-Robber steals a Werewolf card, she is now on the Werewolf team.

**Win condition:** Matches her new card's team.

---

### Copies Troublemaker

| Property | Detail |
|----------|--------|
| Team becomes | Village |
| Follow-up wave | Immediately in Wave 1 |
| Follow-up action | Swap two other players' cards (blind) |

**Detailed behavior:**
- In Wave 1: Doppelganger peeks a player's card, sees "Troublemaker"
- **Immediately**, the Doppelganger performs the Troublemaker action:
  - Selects two other players
  - Swaps their cards without looking
- Doppelganger closes eyes
- The real Troublemaker later wakes in Wave 3 and performs their own action

**Critical timing:** The swap happens in Wave 1, before any other role acts. The real Troublemaker in Wave 3 operates on the post-Doppelganger state.

**Win condition:** Village team (Doppelganger's own card is not affected by the swap she performs).

---

### Copies Drunk

| Property | Detail |
|----------|--------|
| Team becomes | Village (changes to match center card's team) |
| Follow-up wave | Immediately in Wave 1 |
| Follow-up action | Swap own card with a center card (blind) |

**Detailed behavior:**
- In Wave 1: Doppelganger peeks a player's card, sees "Drunk"
- **Immediately**, the Doppelganger performs the Drunk action:
  - Selects one center card
  - Swaps her Doppelganger card with that center card
  - Does **not** view her new card
- Doppelganger closes eyes
- If she does not make this choice before window 1 ends (or her phone is gone past the grace period), the server swaps her with a seeded random center card, as for the real Drunk
- The real Drunk later wakes in Wave 3 and performs their own Drunk action

**Critical timing:** The Doppelganger-as-Drunk swaps in Wave 1. Her Doppelganger card goes to the center. She now holds a center card but doesn't know what it is. The real Drunk in Wave 3 swaps with a (potentially different) center card.

**Win condition:** Matches whatever center card she received (unknown to her).

---

### Copies Insomniac

| Property | Detail |
|----------|--------|
| Team becomes | Village |
| Follow-up wave | Wave 4 (after real Insomniac) |
| Follow-up action | Peek own card |

**Detailed behavior:**
- In Wave 1: Doppelganger peeks a player's card, sees "Insomniac"
- Doppelganger closes eyes (no immediate action)
- Waves 2 and 3 proceed normally (other roles may swap the Doppelganger's card)
- In Wave 4: Real Insomniac wakes and peeks own card
- Then: "Doppelganger, if you viewed the Insomniac card, wake up and look at your card."
- Doppelganger-as-Insomniac peeks her own card to see if it changed

**Critical value:** If the Robber or Troublemaker swapped the Doppelganger's card during Wave 3, the Doppelganger-as-Insomniac will discover her new role in Wave 4. This is the only way the Doppelganger can learn she was swapped.

**Win condition:** Village team (unless her card was swapped to a Werewolf card, in which case she's on the Werewolf team — but the Insomniac peek tells her this).

---

### Copies Villager

| Property | Detail |
|----------|--------|
| Team becomes | Village |
| Follow-up wave | None |
| Follow-up action | None |

**Detailed behavior:**
- In Wave 1: Doppelganger peeks a player's card, sees "Villager"
- Doppelganger closes eyes. No further action during the night.

**Win condition:** Village team.

---

### Copies Tanner

| Property | Detail |
|----------|--------|
| Team becomes | Independent |
| Follow-up wave | None |
| Follow-up action | None |

**Detailed behavior:**
- In Wave 1: Doppelganger peeks a player's card, sees "Tanner"
- Doppelganger closes eyes. No further action during the night.

**Win condition:** Doppelganger-as-Tanner wins **only** if the Doppelganger is eliminated. This is independent of other team wins.

---

### Copies Hunter

| Property | Detail |
|----------|--------|
| Team becomes | Village |
| Follow-up wave | None |
| Follow-up action | None |

**Detailed behavior:**
- In Wave 1: Doppelganger peeks a player's card, sees "Hunter"
- Doppelganger closes eyes. No further action during the night.

**Win condition:** Village team. Additionally, if the Doppelganger-as-Hunter is eliminated, the player the Doppelganger voted for is also eliminated (Hunter's passive ability).

**Important:** The Hunter ability is tracked by the **copied role** for the Doppelganger, not by the physical card. Since the Doppelganger's physical card says "Doppelganger," the server must check `doppelganger_copied_role` to determine if the Doppelganger has the Hunter ability.

---

### Copies Doppelganger

This scenario cannot occur in the base game (there is only one Doppelganger card). If it were to occur in a future expansion:

| Property | Detail |
|----------|--------|
| Team becomes | Village |
| Follow-up wave | None |
| Follow-up action | None |

The Doppelganger would see "Doppelganger" and do nothing further. No recursive copying.

---

## Doppelganger Swap Interactions

## Team Resolution Rule

**A player's team is always determined by the physical card currently in front of them at the end of the night.** This applies to the Doppelganger the same as any other player.

The Doppelganger card is special: it **becomes** the copied role for all game resolution purposes. Any player holding the Doppelganger card at the end of the night has the team and role of whatever the Doppelganger originally copied. The physical card still says "Doppelganger," but the server resolves it to the copied role for:
- **Team determination** — the card's team matches the copied role's team
- **Passive abilities** (Hunter's chain-kill, Tanner's win condition) — tracked via `doppelganger_copied_role` metadata on the card
- **Win condition evaluation** — the algorithm resolves "Doppelganger" → copied role for any holder

**Exception:** If the Doppelganger card was never used to peek (e.g., it started in the center and was taken by the Drunk), the card has no copied role and defaults to Village team.

### Doppelganger Is Robbed

If the Robber targets the Doppelganger during Wave 3:
- The Robber takes the "Doppelganger" card and sees "Doppelganger" (the printed card face)
- The Doppelganger now has the "Robber" card in front of her
- The Doppelganger's team for win conditions is **Village** (Robber card = Village team)
- The Robber's team for win conditions **matches whatever the Doppelganger copied** (the Doppelganger card carries the copied role). If the Doppelganger copied Werewolf, the Robber is now on the Werewolf team.
- The `doppelganger_copied_role` is a property of the **card**, not the player — it follows the card to whoever holds it

### Doppelganger Is Troublemaker'd

If the Troublemaker swaps the Doppelganger with another player:
- The Doppelganger's physical card ("Doppelganger") moves to the other player's position
- The other player's card moves to the Doppelganger's position
- The Doppelganger's **team for win conditions** is determined by whichever card is now in front of her (not the copied role)
- The other player's **team for win conditions** is determined by the Doppelganger card they now hold — which means the **copied role's team** (e.g., if the Doppelganger copied Werewolf, the other player is now on the Werewolf team)
- The **copied role information** (night actions, passive abilities) is a property of the Doppelganger card — it follows the card, not the original Doppelganger player

### Doppelganger-as-Robber Steals, Then Gets Robbed

1. Wave 1: Doppelganger copies Robber, steals Alice's Werewolf card → Doppelganger now has Werewolf card, Alice has Doppelganger card (which carries copied role = Robber)
2. Wave 3: Real Robber steals from Doppelganger → Robber gets Werewolf card, Doppelganger gets Robber card
3. Final: Doppelganger holds Robber card → Village team. Robber holds Werewolf card → Werewolf team. Alice holds Doppelganger card (copied Robber) → Village team.

## Summary Table

| Copied Role | Team | Follow-up Timing | Follow-up Action | Gains Information? |
|-------------|------|-------------------|------------------|--------------------|
| Werewolf | Werewolf | Wave 2 | See teammates | Yes |
| Minion | Werewolf | Wave 1 (special) | See Werewolves | Yes |
| Mason | Village | Wave 2 | See Masons | Yes |
| Seer | Village | Wave 1 (immediate) | Peek player/center | Yes |
| Robber | Village→varies | Wave 1 (immediate) | Swap + peek | Yes |
| Troublemaker | Village | Wave 1 (immediate) | Swap two others | No |
| Drunk | Village→varies | Wave 1 (immediate) | Swap with center | No |
| Insomniac | Village | Wave 4 | Peek own card | Yes |
| Villager | Village | None | — | No (beyond initial peek) |
| Tanner | Independent | None | — | No (beyond initial peek) |
| Hunter | Village | None | — | No (beyond initial peek) |
| Doppelganger | Village | None | — | No (beyond initial peek) |
