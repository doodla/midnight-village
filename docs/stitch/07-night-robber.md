# Night Action — Robber

**Stitch ID:** `2efa48a94d4449d69a96567f9298d55a`
**Phase:** Night (Wave 3)
**Action type:** `swap_with_player`

## Prompt

```
Night action screen for the Robber role in "Midnight Village" werewolf game. The Robber picks one player to swap cards with. Mobile, very dark theme (#0D0B0F background).

Top: Role indicator "ROBBER" with a mask icon in gold, circular timer showing "9s".

Instruction text: "Choose a player to rob. You'll swap cards and see your new role." in warm off-white body text.

Player grid: 5 player tiles in a 2-column grid plus one centered at bottom. Each tile is a dark card (#1A1714) with a circular avatar (initials in a colored circle) and the player name below. Names: Alice, Bob, Carol, Dave, Eve. "Bob" is selected with a glowing gold border.

Below the grid: A subtle note "(Optional — skip if you don't want to swap)" in small muted text.

Bottom: Large "Swap with Bob" button in blood-ember red, full width. Enabled since a target is selected.

Feel: Tense and sneaky. The Robber is about to steal someone's identity.
```

## Data & Interactions

- **Submit:** `{action_type: "swap_with_player", targets: {player_id: X}}`
- **Optional:** Can skip
- **Result:** Reveals the new role (the card you took from the target)
