# Results Screen

**Stitch ID:** `ce4acd57bb0f485aa093dd14fb92544e` (Werewolf wins), `63216f7570b14d50a77f57e8bdb7b7ae` (Village wins)
**Phase:** Results
**Route:** `/game/:gameId/results`

## Prompt

```
Game results screen for "Midnight Village" werewolf game. The big reveal — all hidden information disclosed. Mobile, dark theme with dramatic flair.

Background: Dark (#0F0D0B) with a subtle warm glow.

Top section - Winner announcement: "WEREWOLVES WIN!" in large bold uppercase, colored blood-ember red (#C94038). Below it: "No Werewolf was eliminated." in smaller warm off-white. Below that: Your personal outcome "YOU LOSE" in a red badge/chip, or "YOU WIN" in a green badge.

Divider line.

Middle section - Player Roles table: A scrollable list of all 5 players, each in a card row:
- Alice: "Robber → Werewolf" (original role arrow final role, showing the swap changed her team). Red "LOSE" badge. Skull icon (eliminated). "Voted for: Carol"
- Bob: "Seer" (no change). Gold "WIN" badge. "Voted for: Alice"
- Carol: "Werewolf → Robber" (was swapped by Robber). Red team indicator. "WIN" badge. "Voted for: Bob"
- Dave: "Villager" (no change). Gold "WIN" badge. "Voted for: Alice"
- Eve: "Hunter" (no change). Gold "WIN" badge. "Voted for: Alice"

Below players: "Center Cards: Werewolf, Minion, Tanner" in muted text.

Collapsible section: "What happened at night?" with expand arrow. Shows night action log entries chronologically.

Bottom sticky bar: Two buttons — "Play Again" large filled button in tallow gold (#C8A24D), and "Leave" small outlined button.

The results screen is where the story of the game comes together. Every swap, every lie, every lucky guess is revealed.
```

## Data

- **Source:** `GET /api/onuw/games/<id>/results/`
- **Fields:** winning_teams, reason, eliminated_players, players (original_role, final_role, outcome, vote_target_id), center_cards, night_actions_log
- **Progressive disclosure:** Winner → role table → night log (expandable)
- **Night log formatting:** Client-side text generation from structured action data
- **Actions:** "Play Again" → return to lobby, "Leave" → home screen

## Win Condition Display

| Scenario | Color | Text |
|----------|-------|------|
| Village wins | Tallow Gold | "VILLAGE WINS!" |
| Werewolves win | Bloodmoon Red | "WEREWOLVES WIN!" |
| Tanner wins | Grave Dust | "TANNER WINS!" |
| Multiple winners | Show both in sequence |
| No one wins | Muted grey | "NOBODY WINS" |
