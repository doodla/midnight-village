# Role Selection (Host Only)

**Stitch ID:** `4dfd4d3bfa7f4bb49ef9286dc409cb79`
**Phase:** Lobby (host only)
**Route:** `/lobby/:code/roles` or modal sheet

## Prompt

```
Role selection screen for "Midnight Village" werewolf game. Host is picking which roles to include. Mobile, dark atmospheric theme.

Top app bar: Close/X button on left, "Game Setup" title center, right side shows "8/8 cards" in green text (valid count).

Scrollable list of role cards grouped by team with section headers:

Section "WEREWOLF TEAM" with red (#C94038) accent bar:
- Werewolf card: red team circle icon, name "Werewolf", subtitle "Knows other werewolves", trailing count stepper showing [- 2 +]
- Minion card: same red style, "Minion", "Knows werewolves, they don't know you", count [- 1 +]

Section "VILLAGE TEAM" with gold (#C8A24D) accent bar:
- Seer: "Peeks at one player or two center cards" [- 1 +]
- Robber: "Swaps card with another player" [- 1 +]
- Troublemaker: "Swaps two other players' cards" [- 1 +]
- Villager: "No night action" [- 0 +]
- Drunk, Insomniac, Mason, Hunter all at 0

Section "INDEPENDENT" with grey (#8B7D6B) accent bar:
- Tanner: "Wins if eliminated" [- 0 +]

Bottom sticky button: "Save Setup" filled button, full width.

Each role card is a list tile with the team-colored circle, name, one-line description, and +/- stepper buttons. Tactile, physical card feel.
```

## Data & Validation

- **Required cards:** `player_count + 3`
- **Constraints:**
  - Mason count must be 0 or 2 (stepper jumps 0→2→0)
  - Werewolf: 0-2, Villager: 0-3, all others: 0-1
  - Player count: 3-10
- **Validation runs on every count change** — errors shown inline
- **Presets available** filtered by player count (from recommended-setups.md)
