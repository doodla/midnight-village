# One Night Ultimate Werewolf — Voting and Resolution Specification

## Discussion Phase

### Rules

- All players open their eyes and discuss
- **Timer:** Configurable duration (recommended 5–10 minutes)
- Players may say anything — truth or lies
- Players may **never** show their card to anyone
- Players may **never** look at any card after the night phase ends
- No restrictions on who can speak or when

### Key Principle

After the night phase, a player's role is the card **currently in front of them**, which may differ from their original card. Players should try to determine what team they are currently on, not what team they started on.

## Voting Phase

### Mechanics

1. When the discussion timer expires, voting begins immediately
2. On a count of three, every player simultaneously points at one other player
3. Votes are cast at the same instant — no player sees another's vote before committing

### Voting Rules

| Rule | Detail |
|------|--------|
| Must vote | Every player must vote — no abstaining |
| No self-votes | Players cannot vote for themselves |
| Simultaneous | All votes are revealed at the same instant |
| Final | Votes cannot be changed after the count |

### Digital Implementation

In the app, voting works differently from the physical game:

1. Each player submits their vote through the app during the voting timer
2. Votes are hidden from all players until all votes are in (or the timer expires)
3. If a player does not submit a vote before the timer expires, their vote is **skipped** (they effectively abstain — their vote is not counted)
4. Once all votes are collected (or the timer expires), all votes are revealed simultaneously to all players

## Resolution Phase

Resolution happens in a strict order:

### Step 1: Tally Votes

Count how many votes each player received.

### Step 2: Determine Deaths from Voting

| Scenario | Result |
|----------|--------|
| One player has the most votes (≥ 2) | That player dies |
| Multiple players tied for most votes (each ≥ 2) | **All** tied players die |
| No player has more than 1 vote | **No one dies** |
| One player has exactly 1 vote (and it's the highest) | **No one dies** (minimum 2 required) |

**The minimum vote threshold is 2.** A player must receive at least 2 votes to be eliminated.

### Step 3: Apply Hunter

If a player holding the **Hunter card** (at end of night, after all swaps) is among the dead:
- The player that the Hunter **voted for** is also eliminated
- This happens regardless of how many votes the Hunter's target received
- The Hunter's target could even have 0 votes — they still die

**Important:** The Hunter ability belongs to the **card position**, not the original player. If the Hunter card was swapped to a different player during the night, the new holder of the Hunter card has the ability.

### Step 4: Evaluate Win Conditions

Win conditions are evaluated against the **final** set of dead players (after Hunter chain) and the **final** role assignments (after all night swaps).

## Win Conditions

### Team Definitions at End of Game

A player's team is determined by the card **currently in front of them** after all night swaps:

| Card | Team |
|------|------|
| Werewolf | Werewolf |
| Minion | Werewolf |
| Doppelganger (copied Werewolf) | Werewolf |
| Doppelganger (copied Minion) | Werewolf |
| Seer, Robber, Troublemaker, Drunk, Insomniac, Mason, Hunter, Villager | Village |
| Doppelganger (copied any village role) | Village |
| Tanner | Independent |
| Doppelganger (copied Tanner) | Independent |

### Win Condition Evaluation

Win conditions are **not mutually exclusive** — multiple teams can win in the same game.

#### Scenario A: At Least One Werewolf Is Among Players

| Condition | Winners |
|-----------|---------|
| At least one Werewolf player dies, Tanner does not die | Village wins |
| At least one Werewolf player dies, Tanner also dies | Village wins AND Tanner wins |
| No Werewolf player dies, Tanner does not die | Werewolf team wins |
| No Werewolf player dies, Tanner dies | **Tanner wins ONLY** — Werewolf team does NOT win (Tanner death blocks Werewolf win) |

**Critical rule from official rulebook:** "If the Tanner dies and no Werewolves die, the Werewolves do **not** win." The Tanner dying is a special override that blocks the Werewolf team's win condition.

#### Scenario B: No Werewolves Among Players (All Werewolf Cards in Center)

| Condition | Winners |
|-----------|---------|
| No one dies | Village wins |
| Someone dies (non-Minion, non-Tanner) | Village loses (someone died). See Minion special rules below. |
| Only the Minion dies | No team wins (Village fails no-death condition; Minion fails someone-else-dies condition) |
| Tanner dies | Tanner wins; Village loses (someone died). If only the Tanner dies, the Minion does **not** win (see Minion special rules) |

#### Scenario C: No Werewolf Cards in Game at All

If the host selected no Werewolf role cards for the game:
| Condition | Winners |
|-----------|---------|
| No one dies | Village wins |
| Someone dies | Village loses |

### Minion Special Rules

The Minion has unique win conditions:

| Situation | Minion Wins? |
|-----------|-------------|
| Werewolves among players, no Werewolf dies | Yes (wins with Werewolf team) |
| Werewolves among players, a Werewolf dies | No (loses with Werewolf team) |
| Minion dies but no Werewolf dies | Yes (Werewolf team still wins) |
| No Werewolves among players, a non-Minion/non-Doppelganger-as-Minion, non-Tanner player dies | Yes |
| No Werewolves among players, only the Tanner dies | No (**decided 18 Nov 2026:** the Tanner wins alone; a Tanner death blocks the Werewolf team, and the Minion wins or loses with that team) |
| No Werewolves among players, only Minion dies | No |
| No Werewolves among players, no one dies | No (Village wins) |

### Hunter Special Interactions

| Scenario | Result |
|----------|--------|
| Hunter dies, voted for a Werewolf | Werewolf also dies → Village wins |
| Hunter dies, voted for a Villager | Villager also dies → check other win conditions |
| Hunter dies, voted for Tanner | Tanner also dies → Tanner wins |
| Hunter dies in a tie | Hunter ability still triggers |
| Hunter's target was already dying (in same tie) | No additional effect (already dead) |
| Player who now holds Hunter card (after swap) dies | That player's vote target dies (not the original Hunter's target) |

### Tanner Special Interactions

| Scenario | Tanner Wins? | Village Wins? | Werewolf Wins? |
|----------|-------------|---------------|----------------|
| Only Tanner dies, Werewolves exist | Yes | No | **No** (Tanner death blocks WW win) |
| Tanner + Werewolf both die (tie) | Yes | Yes | No |
| Tanner dies, no WW in play | Yes | No (someone died) | — |
| Tanner not eliminated | No | (check other conditions) | (check other conditions) |
| Doppelganger-as-Tanner dies | Yes (Doppel wins as Tanner) | (check other conditions) | (check other conditions) |

## Win Condition Evaluation Algorithm

```
function evaluate_winners(dead_players, final_roles, doppelganger_copied_role):
    winners = []

    # Determine effective roles (resolve Doppelganger)
    # Any player holding the "Doppelganger" card (whether the original Doppelganger
    # or someone who received it via Troublemaker swap) has the copied role as their
    # effective role. The copied role is a property of the CARD, not the player.
    # For passive abilities (Hunter chain, Tanner win), use doppelganger_copied_role.
    effective_roles = copy(final_roles)
    for player_id, role in effective_roles:
        if role == "Doppelganger":
            effective_roles[player_id] = doppelganger_copied_role  # single value, card property

    # Identify teams
    werewolf_players = [p for p in players if effective_roles[p] in ("Werewolf")]
    tanner_players = [p for p in players if effective_roles[p] == "Tanner"]
    minion_players = [p for p in players if effective_roles[p] == "Minion"]

    # Check Tanner win (independent — evaluated first)
    for tanner in tanner_players:
        if tanner in dead_players:
            winners.append("Tanner")

    # Check Village vs Werewolf
    tanner_died = "Tanner" in winners
    if len(werewolf_players) > 0:
        # Werewolves exist among players
        if any(w in dead_players for w in werewolf_players):
            winners.append("Village")
        elif not tanner_died:
            # Werewolf team wins ONLY if no Werewolf died AND Tanner did not die
            # Official rule: "If the Tanner dies and no Werewolves die, the Werewolves do not win"
            winners.append("Werewolf")
    else:
        # No Werewolves among players (all in center or not in game)
        if len(dead_players) == 0:
            winners.append("Village")
        elif len(minion_players) > 0:
            # Minion special case: Minion wins if a non-Minion player dies
            non_minion_dead = [p for p in dead_players if p not in minion_players]
            if len(non_minion_dead) > 0:
                winners.append("Werewolf")  # Minion wins with Werewolf team
            # If only Minion died, no team wins cleanly
        else:
            # No Werewolves, no Minion, someone died — village loses, no team wins
            # (Werewolf win requires "at least one player is a Werewolf")
            pass  # winners stays empty — nobody wins

    return winners
```

**Notes:**
- The Minion is on the Werewolf team. The Minion wins when "Werewolf" is in the winners list.
- Special case: if no Werewolves are among players and only the Minion dies, the Minion does **not** win.
- Hunter chain kills do **not** recurse. If the Hunter kills a Doppelganger-as-Hunter, that second "Hunter" does not trigger a further chain.

## Complete Resolution Example

### Setup
- 5 players: Alice, Bob, Carol, Dave, Eve
- Roles dealt: Alice=Werewolf, Bob=Seer, Carol=Robber, Dave=Villager, Eve=Hunter
- Center: [Werewolf, Minion, Tanner]

### Night
1. Bob (Seer) peeks Alice → sees Werewolf
2. Carol (Robber) swaps with Alice → Carol=Werewolf, Alice=Robber
3. Eve (Hunter) does not wake

### Final Roles
Alice=Robber, Bob=Seer, Carol=Werewolf, Dave=Villager, Eve=Hunter

### Discussion
Bob claims Seer, says "Alice is the Werewolf." Carol stays quiet. Alice says "I was robbed, I'm now... something." Carol claims Villager.

### Voting
Alice→Carol, Bob→Alice, Carol→Bob, Dave→Alice, Eve→Alice

### Resolution
1. **Tally:** Alice=3, Bob=1, Carol=1
2. **Deaths:** Alice dies (3 votes, ≥ 2)
3. **Hunter:** Alice holds Robber, not Hunter. No chain.
4. **Reveal:** Alice's card is Robber. Alice is on Village team.
5. **Win check:** Werewolf players = [Carol]. Carol is alive. No Werewolf died. → **Werewolf team wins.**

The village was misled by stale information — Bob saw Alice as Werewolf, but Carol robbed Alice before Bob's information could be used.

## Edge Cases Summary

| Edge Case | Resolution |
|-----------|------------|
| All votes tied (everyone gets 1 vote) | No one dies |
| 3-way tie at 2+ votes each | All three die |
| Hunter dies in a tie | Hunter kills their vote target too (no recursive chain — if target is also a Hunter-type, it does NOT trigger again) |
| Hunter's vote target already dying in same tie | No additional effect |
| No Werewolves in game, no one dies | Village wins |
| No Werewolves in game, non-Minion dies, Minion present | Minion (Werewolf team) wins |
| No Werewolves in game, someone dies, no Minion | No team wins (village loses, no WW team to win) |
| No Werewolves in game, only Minion dies | No team wins |
| Tanner dies with a Werewolf | Both Tanner and Village win |
| Tanner dies alone, Werewolves survive | **Tanner wins only** — Werewolf team does NOT win |
| Player disconnects before voting | Vote skipped (not counted) |
| Doppelganger-as-Hunter dies | Doppelganger's vote target also dies |
| Doppelganger-as-Tanner dies | Doppelganger wins as Tanner |
| Robber stole Werewolf card | Robber is now Werewolf; original holder is Robber |
| Drunk swapped with Werewolf from center | Drunk is now Werewolf (doesn't know it) |
