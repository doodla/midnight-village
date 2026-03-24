# One Night Ultimate Werewolf — Role Specifications

## Role Reference

Each role definition includes: team, night wake wave, action type, what the player sees/does, and special rules.

---

## Werewolf Team

### Werewolf

| Property | Value |
|----------|-------|
| Team | Werewolf |
| Wave | 2 |
| Action type | `see_team` |
| Card count | 2 |

**Night action:** All Werewolves open their eyes simultaneously and see each other.

**Lone Werewolf rule:** If only one Werewolf is among the players (the other Werewolf card(s) are in the center), the lone Werewolf **may** look at one center card. This is optional — they can choose not to peek.

**What the player sees:**
- Multiple Werewolves: the identity of all other Werewolf players
- Lone Werewolf: an empty list of teammates, plus optionally the role of one center card

**Special rules:**
- A player who currently holds a Werewolf card at the end of the night is on the Werewolf team, even if they started as something else (e.g., they were robbed by the Robber)
- Werewolf cards in the center do **not** count as "Werewolves in play" for win conditions — only player-held Werewolf cards matter
- Masons use the same wave but Werewolves and Masons do **not** see each other

**Strategy:** Werewolves must lie during discussion. They know each other's identities, giving them a coordination advantage. A common strategy is for one Werewolf to claim a village role while the other stays quiet.

---

### Minion

| Property | Value |
|----------|-------|
| Team | Werewolf |
| Wave | 2 |
| Action type | `see_team` |
| Card count | 1 |

**Night action:** The Minion opens their eyes. Werewolves (with eyes closed) put their thumbs up. The Minion sees which players are Werewolves. This is **one-directional** — Werewolves do **not** know who the Minion is.

**What the player sees:**
- A list of all Werewolf player identities
- If no Werewolves are among players (all in center): an empty list

**Special rules:**
- The Minion wins with the Werewolf team
- If the Minion is eliminated but no Werewolf is eliminated, the Werewolf team (including the dead Minion) **still wins**
- If there are **no Werewolves among players** (all Werewolf cards in center): the Minion wins if at least one non-Minion player is eliminated. The Minion loses if no one is eliminated or if only the Minion is eliminated.
- If the Minion's card is swapped during the night, the player who now holds the Minion card did NOT see the Werewolves — the information is tied to the player who woke up, not the card

**Strategy:** The Minion knows the Werewolves but they don't know the Minion. The Minion should protect Werewolves by deflecting suspicion, making false claims, or even deliberately acting suspicious to draw votes away from the real Werewolves.

---

## Village Team

### Villager

| Property | Value |
|----------|-------|
| Team | Village |
| Wave | None |
| Action type | `none` |
| Card count | 3 |

**Night action:** None. The Villager never wakes during the night.

**What the player sees:** Nothing — no night information.

**Special rules:**
- Pure discussion role with no mechanical advantage
- Multiple Villagers can be in the same game

**Strategy:** Villagers have no information but also have a "clean" claim — they can truthfully say they are a Villager and saw nothing. Listen for inconsistencies in other players' claims.

---

### Seer

| Property | Value |
|----------|-------|
| Team | Village |
| Wave | 3 |
| Action type | `peek_player` OR `peek_center` |
| Card count | 1 |

**Night action:** The Seer chooses **one** of two options:
- **Option A:** Look at one other player's card
- **Option B:** Look at two center cards

The Seer does **not** move any cards — peek only.

**What the player sees:**
- Option A: the current role of one chosen player
- Option B: the current roles of two chosen center cards

**Special rules:**
- The Seer's action is **optional** — they may choose not to peek (timer expires with no action = skip)
- The Seer acts at the **start** of Wave 3, before Robber, Troublemaker, and Drunk. This means the Seer sees the pre-swap state (before any Wave 3 swaps)
- The Seer cannot peek their own card
- Peeking center cards reveals what is NOT in play (or what might be swapped in later by the Drunk)

**Strategy:** The Seer is the strongest information role for the village. Peeking a player gives certainty about one person; peeking center cards reveals which roles are not in play. Claiming Seer is standard but risky — Werewolves will try to discredit the Seer or counter-claim Seer.

---

### Robber

| Property | Value |
|----------|-------|
| Team | Village (changes to match stolen card's team) |
| Wave | 3 |
| Action type | `swap_with_player` |
| Card count | 1 |

**Night action:** The Robber selects one other player. The Robber **swaps** their own card with that player's card, then **views** their new card (the one they just took). The targeted player does not know they were robbed.

**What the player sees:**
- The role of the card they just took (their new role)

**Special rules:**
- The Robber's action is **optional** — they may choose not to swap (timer expires with no action = skip)
- After swapping, the Robber's team changes to match their new card. If they rob a Werewolf, they are now on the Werewolf team
- The Robber does **not** perform the night action of their new role
- The robbed player now holds the Robber card but doesn't know it
- The Robber acts **after** the Seer but **before** the Troublemaker in canonical Wave 3 order

**Strategy:** The Robber has strong self-knowledge — they know their current role. If they robbed a Werewolf, they must decide whether to reveal this (helping the village find the player who now holds the Werewolf card, but making themselves a Werewolf in the process).

---

### Troublemaker

| Property | Value |
|----------|-------|
| Team | Village |
| Wave | 3 |
| Action type | `swap_others` |
| Card count | 1 |

**Night action:** The Troublemaker selects two **other** players (not themselves). The Troublemaker swaps those two players' cards with each other. The Troublemaker does **not** look at either card.

**What the player sees:** Nothing — the swap is blind.

**Special rules:**
- The Troublemaker's action is **optional** — they may choose not to swap
- The Troublemaker cannot target themselves
- If they do swap, they must target exactly two distinct other players
- Acts on the state **after** Seer and Robber have resolved (canonical Wave 3 ordering)
- The Troublemaker themselves remain on the Village team (their own card is unaffected)
- Neither swapped player knows their card changed

**Strategy:** The Troublemaker creates chaos. Revealing who they swapped during discussion helps the village deduce current roles, but Werewolves may also false-claim Troublemaker. If the Troublemaker swapped a known Werewolf with a Villager, the former Werewolf is now safe and the former Villager is the new target.

---

### Drunk

| Property | Value |
|----------|-------|
| Team | Village (changes to match center card's team) |
| Wave | 3 |
| Action type | `swap_with_center` |
| Card count | 1 |

**Night action:** The Drunk selects one center card. The Drunk's card is swapped with that center card. The Drunk does **not** view their new card.

**What the player sees:** Nothing — the swap is blind. The Drunk has no idea what role they now hold.

**Special rules:**
- The Drunk's action is **mandatory** — they must swap with a center card
- The Drunk acts **last** in Wave 3 (after Seer, Robber, and Troublemaker)
- The Drunk's original card goes to the center
- The Drunk's new role (from the center) determines their team at end of game, but they don't know what it is
- The Insomniac (if also the Drunk after a swap) can discover their new role in Wave 4

**Strategy:** The Drunk can truthfully say "I was the Drunk, I swapped with a center card, I don't know what I am now." This is a strong honest claim. The Drunk relies on other players' information to figure out their own identity.

---

### Insomniac

| Property | Value |
|----------|-------|
| Team | Village |
| Wave | 4 |
| Action type | `peek_player` (targets self) |
| Card count | 1 |

**Night action:** The Insomniac opens their eyes and looks at their own card to see if it changed during the night.

**What the player sees:**
- Their **current** role card (which may differ from the Insomniac card they started with, if Robber or Troublemaker moved their card)

**Special rules:**
- Acts in Wave 4, **after** all Wave 3 swaps have resolved
- Only useful when Robber and/or Troublemaker are in the game (otherwise the Insomniac always sees "Insomniac" and gains trivial information)
- Cannot peek at other players — only their own card

**Strategy:** The Insomniac has strong self-verifying information. If they still see "Insomniac," they were not swapped. If they see a different role (e.g., Werewolf), they know they were targeted by the Robber or Troublemaker and must decide whether to reveal this.

---

### Mason

| Property | Value |
|----------|-------|
| Team | Village |
| Wave | 2 |
| Action type | `see_team` |
| Card count | 2 |

**Night action:** Both Masons open their eyes simultaneously and see each other.

**What the player sees:**
- Two Masons: each sees the other Mason's identity
- Lone Mason (the other Mason card is in the center): sees no one — knows the other Mason is in the center

**Special rules:**
- Masons **always** come in pairs in the card set — you cannot use just one Mason card
- If a Mason's card is swapped during Wave 3, they are no longer a Mason at the end of the game (but they still have the information from Wave 2)
- Masons and Werewolves are in the same wave but do **not** see each other — they wake in separate calls

**Strategy:** Masons have a confirmed mutual alibi, which is extremely powerful for the village. Two Masons who trust each other immediately narrow the suspect pool. However, they should be cautious about revealing too quickly — a Werewolf may claim to be "the other Mason."

---

### Hunter

| Property | Value |
|----------|-------|
| Team | Village |
| Wave | None |
| Action type | `none` (passive ability) |
| Card count | 1 |

**Night action:** None. The Hunter never wakes during the night.

**What the player sees:** Nothing — no night information.

**Special rules:**
- **Passive ability:** If the Hunter is eliminated (dies from voting), the player the Hunter **voted for** is also eliminated, regardless of how many votes that target received
- The Hunter's kill is applied during resolution, after vote tallying
- The Hunter's vote target is the player they pointed at during voting (not a separate choice)
- This ability belongs to the **card**, not the player. If the Hunter card was swapped to a different player, that player (not the original Hunter) has the ability
- If the Hunter dies in a tie, the ability still triggers

**Strategy:** The Hunter provides a deterrent — voting for the Hunter is risky because they'll take someone with them. A smart Hunter who suspects a Werewolf should vote for that Werewolf, ensuring the Werewolf dies even if the village accidentally eliminates the Hunter.

---

## Independent

### Tanner

| Property | Value |
|----------|-------|
| Team | Independent |
| Wave | None |
| Action type | `none` |
| Card count | 1 |

**Night action:** None. The Tanner never wakes during the night.

**What the player sees:** Nothing — no night information.

**Special rules:**
- The Tanner wins **only** if they are eliminated
- The Tanner's win is evaluated **independently** — Tanner can win alongside the Village team (if both Tanner and a Werewolf die). However, Tanner dying **does** block the Werewolf team from winning (see voting-and-resolution.md)
- If the Tanner is eliminated AND a Werewolf is also eliminated (e.g., in a tie): Tanner wins AND Village wins. Werewolves lose.
- If the Tanner is eliminated AND no Werewolves are eliminated: Tanner wins only. Village loses. Werewolves do **not** win (official rule: "If the Tanner dies and no Werewolves die, the Werewolves do not win").
- If no Werewolves are in play (all in center) and the Tanner is eliminated: Tanner wins, Village loses (village needed no one to die to win)
- The Tanner is on the **Independent** team (labeled `NEUTRAL` in the codebase) — not on the Village or Werewolf team for win conditions

**Strategy:** The Tanner wants to be voted out. This means acting suspicious, contradicting themselves, or making themselves look like a Werewolf — but not so obviously that players suspect a Tanner play. It's a delicate balance.

---

## Complex

### Doppelganger

| Property | Value |
|----------|-------|
| Team | Village (changes to match copied role's team) |
| Wave | 1 |
| Action type | Varies (depends on copied role) |
| Card count | 1 |

**Night action:** The Doppelganger opens their eyes first (before all other roles) and looks at one other player's card. The Doppelganger **becomes** that role — adopting its team, win conditions, and (if applicable) night action.

The Doppelganger's physical card stays as "Doppelganger" in front of them. The copy is mechanical — tracked by the server, not by card movement.

**See [doppelganger.md](doppelganger.md) for the complete Doppelganger interaction matrix.**

**What the player sees:**
- The role of one chosen player's card
- Then the results of whatever follow-up action the copied role grants

**Special rules:**
- Always acts first (Wave 1)
- Team changes immediately upon copying
- For wave-3 copied roles (Seer, Robber, Troublemaker, Drunk): the Doppelganger performs the action **immediately** during the Doppelganger phase, before any other role wakes
- For wave-2 copied roles (Werewolf, Mason, Minion): the Doppelganger wakes again during that wave to participate
- For wave-4 copied role (Insomniac): the Doppelganger wakes after the real Insomniac
- For roles with no night action (Villager, Tanner, Hunter): no follow-up
- Win conditions match the copied role entirely

**Strategy:** The Doppelganger is the most complex role. They have full information about one player's role plus whatever their copied action reveals. Their challenge is communicating what they know during discussion without revealing information that helps the Werewolves.
