# Night Waiting

**Stitch ID:** `036587c80dce4447b2557e463ab834c3`
**Phase:** Night (all waves, for non-acting players)

## Prompt

```
Night waiting screen for "Midnight Village" werewolf game. Shown to players who have no action during the current wave. Mobile, very dark atmospheric theme.

Background: Deep void black (#0D0B0F) with a very subtle misty texture or noise overlay.

Center of screen: A large crescent moon icon in muted warm grey, slightly glowing. Below it, the text "The village sleeps..." in muted warm grey (#9C9084), italic style.

Below that: A wave progress indicator showing 4 dots (representing the 4 night waves). Dot 2 is active (filled gold #C8A24D), dots 1 is completed (dim gold), dots 3-4 are empty (grey outline). Small label "Wave 2 of 4" below.

At the bottom: A small muted text "Other players are performing their actions" with a subtle pulse animation indicator (three dots animating).

The screen should feel serene but tense — like lying in bed at night hearing sounds outside. Minimal UI, maximum atmosphere. The darkness itself is the design.
```

## Data

- **WebSocket event:** `wave_waiting` (tells you this wave doesn't need you)
- **Wave progress:** from `current_wave` in game state
- **Auto-transitions:** When `wave_complete` or `action_prompt` arrives
