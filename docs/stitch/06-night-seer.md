# Night Action — Seer

**Stitch ID:** `3cc5d237e52c48b8b0350baee041771a`
**Phase:** Night (Wave 3)
**Action types:** `peek_player` OR `peek_center`

## Prompt

```
Night action screen for the Seer role in "Midnight Village" werewolf game. The Seer must choose to peek at one player's card OR two center cards. Mobile, very dark theme.

Background: Deep void black (#0D0B0F).

Top section: Small role indicator showing "SEER" with an eye icon in gold, and a circular timer ring showing "8s" depleting.

Middle: A choice prompt. Text "Choose your action:" in warm off-white.

Two option cards side by side:
- Left card: "Peek Player" — icon of a person with an eye. "Look at one player's card." Tappable, with a gold border when selected.
- Right card: "Peek Center" — icon of three cards face-down. "Look at two center cards." Tappable.

Below (shown when "Peek Player" is selected): A grid of player name cards (5 players). Each is a dark surface tile showing an avatar circle and name. Names: Alice, Bob, Carol, Dave, Eve. The player "Carol" is selected with a glowing gold (#C8A24D) border.

Bottom: A large "Confirm" button in blood-ember red, full width. Only enabled when a target is selected.

Feel: focused, secretive, time-pressured. The dark background isolates the choices.
```

## Data & Interactions

- **Action prompt from server:** `action_types: ["peek_player", "peek_center"]`, `valid_targets: {player_ids: [...], center_indices: [0,1,2]}`
- **Peek Player:** Select 1 player → submit `{action_type: "peek_player", targets: {player_id: X}}`
- **Peek Center:** Select 2 center cards → submit `{action_type: "peek_center", targets: {center_indices: [X, Y]}}`
- **Optional:** Can skip (timer expires → action skipped)
- **Result:** Shown on Night Action Result screen
