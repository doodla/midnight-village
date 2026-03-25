# Night Role Reveal

**Stitch ID:** `9e6725f960bc450c8434f88aadbb23d9`
**Phase:** Night (start)
**Route:** `/game/:gameId` (night sub-state)

## Prompt

```
Night phase role reveal screen for "Midnight Village" werewolf game. The dramatic moment when a player first sees their secret role. Mobile, very dark atmospheric background.

The screen should feel like opening a secret envelope in candlelight.

Background: Near-black (#0D0B0F) with a subtle radial gradient of warm amber light emanating from the center, like a candle glow.

Center of screen: A large role card, portrait orientation. The card has a dark surface (#1A1714) with a thin gold (#C8A24D) border. Inside the card:
- Top edge: A thin team-color bar (gold for village, red for werewolf)
- A large role icon/symbol in the center (an eye symbol for the Seer)
- Role name "SEER" in large bold uppercase Epilogue font, gold colored
- Team label "Village Team" in small muted text
- A divider line
- Role description: "You may look at one other player's card, or two cards from the center." in body text

Below the card: A subtle pulsing text "The night begins..." in muted warm grey, small size.

At the very bottom: A circular timer ring showing the countdown, with "7s" in the center. The ring depletes clockwise in tallow gold.

The entire composition should feel reverent and secretive. This is YOUR secret identity.
```

## Data

- **Source:** `GET /api/onuw/games/<id>/me/` → `your_role.original_role`
- **Duration:** Brief (auto-transitions to first wave action or waiting)
- **Animation:** Card flip from face-down to face-up (3D Y-axis rotation, ~600ms)
