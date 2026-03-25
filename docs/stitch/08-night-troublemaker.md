# Night Action — Troublemaker

**Stitch ID:** `05c311ebe75741a78400de15d4df6554`
**Phase:** Night (Wave 3)
**Action type:** `swap_others`

## Prompt

```
Night action screen for the Troublemaker role in "Midnight Village" werewolf game. The Troublemaker picks TWO other players to swap their cards (blind swap). Mobile, very dark theme (#0D0B0F).

Top: Role indicator "TROUBLEMAKER" with a swap-arrows icon in gold, circular timer showing "8s".

Instruction text: "Choose two players to swap their cards. You won't see what they have." in warm off-white.

Player grid: 5 player tiles (2-column grid). Each is a dark card with avatar and name. "Alice" and "Dave" are both selected — Alice has a "1" badge on her tile, Dave has a "2" badge, both with glowing gold borders. Unselected players (Bob, Carol, Eve) are dimmed slightly.

Below grid: Small muted text "(Optional — skip if you don't want to swap)"

Bottom: Large "Swap Alice and Dave" button in blood-ember red, full width. Shows the two names to confirm.

Feel: Mischievous, chaotic. Creating confusion in the dark.
```

## Data & Interactions

- **Submit:** `{action_type: "swap_others", targets: {player_ids: [X, Y]}}`
- **Must select exactly 2 distinct players** (neither can be self)
- **Optional:** Can skip
- **Result:** No result shown (blind swap — Troublemaker doesn't see what they swapped)
