# One Night Ultimate Werewolf — Recommended Role Setups

Curated role combinations by player count, sourced from the official Bezier Games rulebook, their blog, and community consensus.

## Base Game Only

### 3 Players (6 cards)

| Setup | Roles |
|-------|-------|
| Starter | Werewolf, Werewolf, Seer, Robber, Troublemaker, Villager |

The minimum viable game. Robber prevents trivial Werewolf wins by creating uncertainty about who is actually the Werewolf.

### 4 Players (7 cards)

| Setup | Roles |
|-------|-------|
| Starter | Werewolf, Werewolf, Seer, Robber, Troublemaker, Villager, Villager |

Add one Villager. Same dynamics as 3-player with slightly more deduction.

### 5 Players (8 cards)

| Setup | Roles |
|-------|-------|
| Starter | Werewolf, Werewolf, Seer, Robber, Troublemaker, Villager, Villager, Villager |
| Intermediate | Werewolf, Werewolf, Seer, Robber, Troublemaker, Drunk, Insomniac, Villager |
| Advanced | Werewolf, Werewolf, Minion, Seer, Robber, Troublemaker, Tanner, Villager |

### 6 Players (9 cards)

| Setup | Roles |
|-------|-------|
| Classic | Werewolf, Werewolf, Minion, Seer, Robber, Troublemaker, Villager, Villager, Villager |
| Chaotic | Werewolf, Werewolf, Seer, Robber, Troublemaker, Drunk, Insomniac, Tanner, Villager |
| Full info | Werewolf, Werewolf, Seer, Robber, Troublemaker, Mason, Mason, Insomniac, Villager |

### 7–8 Players (10–11 cards)

| Setup | Roles |
|-------|-------|
| Standard | Werewolf, Werewolf, Minion, Seer, Robber, Troublemaker, Mason, Mason, Drunk, Insomniac, [Villager(s)] |
| With Tanner | Werewolf, Werewolf, Minion, Tanner, Seer, Robber, Troublemaker, Mason, Mason, Insomniac, [Villager(s)] |

Masons are recommended at 8+ players to give the village a reliable anchor.

### 9–10 Players (12–13 cards)

| Setup | Roles |
|-------|-------|
| All-in | Werewolf, Werewolf, Minion, Tanner, Hunter, Seer, Robber, Troublemaker, Mason, Mason, Drunk, Insomniac, [Villager(s)] |
| With Doppelganger | Doppelganger, Werewolf, Werewolf, Minion, Seer, Robber, Troublemaker, Mason, Mason, Drunk, Insomniac, Tanner, [Villager(s)] |

## Base + Daybreak

### 5 Players (8 cards)

| Setup | Roles |
|-------|-------|
| Werewolf power | Sentinel, Werewolf, Alpha Wolf, Mystic Wolf, Apprentice Seer, P.I., Witch, Troublemaker |
| Classic + Daybreak | Werewolf, Werewolf, Seer, Robber, Troublemaker, Apprentice Seer, Witch, Revealer |

### 10 Players (13 cards)

| Setup | Roles |
|-------|-------|
| Official scenario | Werewolf, Mystic Wolf, Mason, Mason, Seer, P.I., Robber, Witch, Troublemaker, Revealer, Curator, Hunter, Tanner |
| Balanced advanced | Werewolf, Alpha Wolf, Minion, Seer, Apprentice Seer, Robber, Witch, Troublemaker, Village Idiot, Insomniac, Mason, Mason, Tanner |

## Automatic Decks (the deck chips)

A lobby whose settings say `deck: "auto"` (with `deck_chip` set to `simple`, `classic` or
`chaos`; `simple` if absent) has no card list of its own. At the deal the server builds
the deck for the number of players then at the table, from this table, under the lobby
lock, so a player who joined or left since the host chose the chip changes nothing the
host has to fix. Every row is a legal deck of exactly players + 3 cards. The table lives
in code in one place (`backend/apps/onuw/engine/decks.py`, `DECK_TABLE`) and a test
compares it with the rows below, so the two cannot drift apart.

`Role ×n` is `n` cards of that role.

| Players | Simple | Classic | Chaos |
|---------|--------|---------|-------|
| 3 | Werewolf ×2, Seer, Robber, Troublemaker, Villager | Werewolf ×2, Seer, Robber, Troublemaker, Villager | Werewolf ×2, Seer, Robber, Troublemaker, Drunk |
| 4 | Werewolf ×2, Seer, Robber, Troublemaker, Villager ×2 | Werewolf ×2, Seer, Robber, Troublemaker, Villager ×2 | Werewolf ×2, Seer, Robber, Troublemaker, Drunk, Tanner |
| 5 | Werewolf ×2, Seer, Robber, Troublemaker, Villager ×3 | Werewolf ×2, Seer, Robber, Troublemaker, Drunk, Insomniac, Villager | Werewolf ×2, Minion, Seer, Robber, Troublemaker, Tanner, Villager |
| 6 | Werewolf ×2, Seer, Robber, Troublemaker, Insomniac, Villager ×3 | Werewolf ×2, Minion, Seer, Robber, Troublemaker, Villager ×3 | Werewolf ×2, Seer, Robber, Troublemaker, Drunk, Insomniac, Tanner, Villager |
| 7 | Werewolf ×2, Seer, Robber, Troublemaker, Drunk, Insomniac, Villager ×3 | Werewolf ×2, Minion, Seer, Robber, Troublemaker, Mason ×2, Drunk, Insomniac | Werewolf ×2, Minion, Tanner, Seer, Robber, Troublemaker, Mason ×2, Insomniac |
| 8 | Werewolf ×2, Seer, Robber, Troublemaker, Drunk, Insomniac, Villager ×3, Hunter | Werewolf ×2, Minion, Seer, Robber, Troublemaker, Mason ×2, Drunk, Insomniac, Villager | Werewolf ×2, Minion, Tanner, Seer, Robber, Troublemaker, Mason ×2, Insomniac, Villager |
| 9 | Werewolf ×2, Seer, Robber, Troublemaker, Drunk, Insomniac, Mason ×2, Villager ×3 | Werewolf ×2, Minion, Tanner, Hunter, Seer, Robber, Troublemaker, Mason ×2, Drunk, Insomniac | Doppelganger, Werewolf ×2, Minion, Seer, Robber, Troublemaker, Mason ×2, Drunk, Insomniac, Tanner |
| 10 | Werewolf ×2, Seer, Robber, Troublemaker, Drunk, Insomniac, Mason ×2, Villager ×3, Hunter | Werewolf ×2, Minion, Tanner, Hunter, Seer, Robber, Troublemaker, Mason ×2, Drunk, Insomniac, Villager | Doppelganger, Werewolf ×2, Minion, Seer, Robber, Troublemaker, Mason ×2, Drunk, Insomniac, Tanner, Villager |

- **Simple** is the gentlest deck for the table size: no Minion, Tanner or Doppelganger.
  It cannot also avoid Masons at 9 and 10 players: without Minion, Masons, Tanner and the
  Doppelganger the largest legal deck holds 11 cards (2 Werewolves, Seer, Robber,
  Troublemaker, Drunk, Insomniac, Hunter and 3 Villagers), which seats 8 players. The
  Mason pair is the gentlest addition (it is advised from 8 players).
- **Classic** and **Chaos** are the recommended setups above (Classic at 3 and 4 players
  is Simple).
- Choosing a chip sets `deck: "auto"`; editing a card makes the deck custom (`deck:
  "custom"` with the `roles` the host chose) and the server then uses those cards as
  before.

## Balance Principles

### General Guidelines

1. **Always include at least one information role** for the village (Seer, Robber, Troublemaker, or Apprentice Seer)
2. **Insomniac is powerful at all player counts** — she knows her final role, hard-countering swaps
3. **Masons are recommended for 8+ players** to give the village a reliable information anchor
4. **Tanner adds unpredictability** — best introduced after players know the base game
5. **Doppelganger adds complexity** — recommended for experienced groups only
6. **The Minion changes the game significantly** — without Minion, Werewolves must self-coordinate; with Minion, there's a dedicated village misdirector

### Role Category Balance

A good setup should include roles from multiple categories:

| Category | Examples | Purpose |
|----------|----------|---------|
| Information (active) | Seer, Robber, Apprentice Seer | Gather facts during night |
| Information (passive) | Insomniac, Mason | Know facts about self/partner |
| Disruption | Troublemaker, Drunk, Village Idiot | Create uncertainty via swaps |
| Deception | Werewolf, Minion, Tanner | Lie and mislead |
| Verification | Insomniac, Revealer | Confirm or deny claims |
| Deterrent | Hunter, Bodyguard | Affect voting calculus |

### Anti-Patterns

| Pattern | Problem |
|---------|---------|
| No information roles | Village has nothing to discuss; pure guessing |
| All information, no disruption | Too easy for village; Werewolves always lose |
| Too many Villagers | Boring for many players; no night engagement |
| Doppelganger with beginners | Confusion; slows down the game |
| Hunter + Tanner + Bodyguard | Vote-phase mechanics stack; resolution becomes confusing |
