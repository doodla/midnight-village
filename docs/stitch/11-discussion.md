# Discussion Phase

**Stitch ID:** `f5c95559e35e477ab40c4e0340b63c97`
**Phase:** Discussion
**Route:** `/game/:gameId/discussion`

## Prompt

```
Discussion phase screen for "Midnight Village" werewolf game. Players are now talking face-to-face — the phone is a reference card. Mobile, dark but slightly warmer than night (#151210 background).

Top bar: Phase label "DISCUSSION" in small caps gold, right side shows a large countdown timer "4:32" in tallow gold (#C8A24D) monospace font.

Below top bar: A compact "Your Info" card on a dark surface (#1A1714) with thin gold border. Shows:
- Left: Small role icon and "SEER" label in gold
- Right: "You saw Carol's card: Werewolf" in warm off-white, with "Werewolf" in red

Below that: A collapsible section "Roles in Play" with a down-arrow. When expanded, shows a wrap of small chips/badges for each role in the game: "Werewolf x2", "Seer", "Robber", "Troublemaker", "Villager x2", "Drunk". Each chip has its team color as a left border (red for werewolf, gold for village).

Below that: A section "Players (5)" showing a simple compact list: Alice, Bob, Carol, Dave, Eve. Just names with their avatar circles. No role info.

At the bottom (host only): A large outlined button "End Discussion Early" with a warning/timer icon.

The screen should feel minimal and utilitarian. The real action is in the room, not on the phone. This is a reference sheet, not a game board.
```

## Data & Interactions

- **Timer:** Server-configured duration (5-10 min), counts down client-side
- **Your Info:** From `night_action_data` stored locally from night phase
- **Roles in Play:** From `game.settings.roles` (public information)
- **Host action:** `POST /api/onuw/games/<id>/end-discussion/` (with confirmation dialog)
- **Timer colors:** Gold > amber (60s left) > red pulse (15s left)
- **Auto-transition:** Timer expires → voting phase via `phase_change` WebSocket
