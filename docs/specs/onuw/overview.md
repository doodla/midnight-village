# One Night Ultimate Werewolf — Game Overview

## What Is ONUW?

One Night Ultimate Werewolf (ONUW) is a social deduction game for 3–10 players.
Each player receives a secret role card, then a single night phase occurs where some roles perform actions (peeking at cards, swapping cards).
Afterward, players discuss and vote to eliminate one player.
The game lasts about 10 minutes.

**Publisher:** Bezier Games
**Designer:** Ted Alspach

## Components

- **Role cards** — one per player, plus 3 extras placed face-down in the center of the table
- **Role tokens** — placed face-up in the center so all players know which roles are in the game (public information)

## Setup

1. **Select roles.** The host chooses which roles to include. The total number of role cards must equal **player count + 3** (the 3 extras go to the center).
2. **Shuffle and deal.** Shuffle all selected role cards face-down. Deal one to each player. Place the remaining 3 face-down in the center.
3. **Place role tokens.** Place one token for each role in the game face-up in the center. All players can see which roles are potentially in play.
4. **Players peek.** Each player secretly looks at their own card, memorizes it, then places it face-down in front of them, within reach of other players (this enables night swaps).

### Recommended First-Game Setups

| Players | Roles |
|---------|-------|
| 3 | 2 Werewolves, Seer, Robber, Troublemaker, Villager |
| 4 | Add 1 Villager |
| 5 | Add 2 Villagers |
| 5+ | Introduce Drunk, Insomniac, Minion, Tanner, Hunter, Mason, Doppelganger as desired |

## Game Flow

```
SETUP → NIGHT → DISCUSSION → VOTING → RESOLUTION
```

### Phase 1: Night

All players close their eyes. Roles are called one at a time in a fixed order.
When a role is called, that player opens their eyes, performs their action (peek, swap, etc.), then closes their eyes.
Roles not in the game are skipped.

**Duration:** ~10 seconds per role. Total night is typically 1–2 minutes.

See [night-phase.md](night-phase.md) for the complete night phase specification.

### Phase 2: Discussion

All players open their eyes. A timer starts (configurable; typically 5–10 minutes).

**Rules during discussion:**
- Players may say anything — truth or lies
- Players may **never** show their card to anyone
- Players may **never** look at any card (their own or others')
- Players should try to determine what team they are currently on (their role may have changed during the night due to swaps)

**Key insight:** Your role at discussion time is whatever card is currently in front of you, which may differ from the card you originally looked at.

### Phase 3: Voting

When the discussion timer expires, all players vote simultaneously.

**Voting rules:**
- On a count of three, every player points at one other player
- Votes are simultaneous — no player sees others' votes before committing
- Players **cannot** abstain — everyone must vote
- Players **cannot** vote for themselves

### Phase 4: Resolution

1. **Count votes.** Tally how many votes each player received.
2. **Determine deaths.**
   - The player(s) with the **most votes** die, provided they received **at least 2 votes**.
   - If **no player** has more than 1 vote, **no one dies**.
   - If there is a **tie** for the most votes (and the tied count is ≥ 2), **all tied players die**.
3. **Apply Hunter.** If the Hunter dies, the player the Hunter voted for **also dies** (regardless of vote count).
4. **Reveal roles.** Dead players flip their cards face-up. (Optionally, all players reveal.)
5. **Determine winners.** See [voting-and-resolution.md](voting-and-resolution.md) for complete win conditions.

## Teams

| Team | Goal |
|------|------|
| **Village** | Eliminate at least one Werewolf |
| **Werewolf** | Survive — no Werewolf gets eliminated |
| **Independent (Tanner)** | Get yourself eliminated |

A player's team is determined by the card **currently in front of them** at the end of the night, not the card they started with.
If the Robber steals a Werewolf card, the Robber is now on the Werewolf team.

## V1 Role Set (12 Roles)

| Role | Team | Night Action | Count |
|------|------|-------------|-------|
| Werewolf | Werewolf | See other Werewolves (lone wolf: peek 1 center) | 2 |
| Minion | Werewolf | See all Werewolves (one-way) | 1 |
| Villager | Village | None | 3 |
| Seer | Village | Peek 1 player card OR 2 center cards | 1 |
| Robber | Village | Swap own card with another player's, view new card | 1 |
| Troublemaker | Village | Swap two other players' cards (blind) | 1 |
| Drunk | Village | Swap own card with 1 center card (blind) | 1 |
| Insomniac | Village | View own card after all swaps | 1 |
| Mason | Village | See other Masons | 2 |
| Hunter | Village | None (passive: kills vote target if Hunter dies) | 1 |
| Tanner | Independent | None (wins if eliminated) | 1 |
| Doppelganger | Village* | Copy another player's role and act as that role | 1 |

*Doppelganger's team changes to match the copied role's team.

**Total cards available:** 16 (select player_count + 3 for each game)

## Information Architecture

### Public Information (known to all)
- Which roles are in the game (role tokens)
- Number of players
- Number of center cards (always 3)
- Phase transitions and timers
- Vote results (after simultaneous reveal)
- Dead players' revealed cards

### Private Information (known only to the server)
- All card assignments (original and current)
- Center card identities
- Night action log (who did what)
- Each player's current role

### Player-Scoped Information (known to individual players)
- Their original role card (from setup peek)
- Results of their night action (what they saw/learned)
- Their vote choice

**Critical constraint for digital implementation:** The server must never leak private information through API responses, WebSocket events, error messages, or
timing side-channels. Each player's view must be scoped to only what that player legitimately knows.

## Setup Validation Constraints

The following rules must be enforced server-side during game setup (lobby → game start):

| Constraint | Rule |
|------------|------|
| Player count | 3–10 players |
| Card count | player_count + 3 |
| Masons | Must be used in pairs — cannot include just 1 Mason card |
| Role uniqueness | Most roles have max 1 card; Werewolf has max 2, Villager has max 3, Mason has exactly 0 or 2 |
| Minimum roles | At least player_count + 3 total cards must be selected |

For expansion-specific setup constraints (Alpha Wolf's +4 card count, Center Werewolf card requirement), see [daybreak-overview.md](daybreak-overview.md).
