# Night Action Result

**Stitch ID:** `76d3795d919940e4a9e4555a3fdbd6f2`
**Phase:** Night (after action submission)

## Prompt

```
Night action result screen for "Midnight Village" werewolf game. Shown briefly after a player performs their night action, revealing what they learned. Mobile, dark theme.

Background: Deep void (#0D0B0F) with a faint warm amber glow in the center.

The screen shows the Seer's peek result. Layout:

Top: Small "SEER" role label in gold with eye icon.

Center: A revealed card — the target player's role. The card appears face-up in the center of the screen with a warm glow around it.
- Card header: "Carol's card"
- Card content: Large role icon and role name "WEREWOLF" displayed in red (#C94038), the werewolf team color
- Card has a thin red top border indicating werewolf team

Below the card: Explanatory text "Carol is a Werewolf" in warm off-white, with the word "Werewolf" in red.

At the bottom: A muted auto-dismiss text "Memorize this... returning to sleep" with a brief countdown "3s".

The reveal should feel like a flash of forbidden knowledge — a single moment of clarity in the darkness before you must close your eyes again.
```

## Data

- **Source:** `action_result` WebSocket event with `revealed_info`
- **Variants by role:**
  - Seer (peek player): Shows target's role card
  - Seer (peek center): Shows 2 center cards
  - Robber: Shows new role (the card you took)
  - Werewolf (see team): Shows teammate names
  - Mason: Shows fellow Mason name
  - Minion: Shows werewolf player names
  - Insomniac: Shows own current card
  - Troublemaker/Drunk: No result (blind swap)
- **Auto-dismiss:** ~3 seconds, then transitions to waiting or next wave
