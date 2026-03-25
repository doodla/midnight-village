# Lobby Waiting Room

**Stitch ID:** `9697d1c72b874004920415b80895fe6f`
**Phase:** Lobby
**Route:** `/lobby/:code`

## Prompt

```
Lobby waiting room screen for "Midnight Village" social deduction game. Mobile, dark atmospheric theme with warm brown-black tones.

Top app bar: Back arrow on left, "Lobby" title center.

Hero section below app bar: A large banner area with a slightly lighter warm surface. Centered text "SHARE THIS CODE" in small muted uppercase label. Below it, the lobby code "A B C 1 2 3" displayed huge (48px), monospace, bold, letter-spaced, in tallow gold (#C8A24D). Below that: "4/6 players" subtitle.

Player list section: 4 player rows. Each row has a circular avatar (initials in a colored circle), display name, and a ready status icon on the right (green checkmark for ready, grey circle outline for not ready). Show "Host" badge next to the first player. The current user's row has a subtle highlighted border.

Players: "SwiftOwl (Host)" ready, "NightHawk" ready, "MoonRaven" not ready, "ShadowFox" ready.

Bottom action area (sticky): A "Roles Summary" bar showing "8 roles selected" with an edit icon. Below it, a row with an "Ready" toggle button (outlined style, green tint) and a large "Start Game" filled button in blood-ember red. The Start button shows disabled state since not all players are ready.
```

## Data & Interactions

- **APIs:**
  - `GET /api/lobbies/<code>/` (initial load)
  - `POST /api/lobbies/<code>/ready/` (toggle ready)
  - `POST /api/lobbies/<code>/leave/` (leave)
  - `POST /api/onuw/lobbies/<code>/start/` (host starts)
- **WebSocket:** `ws/lobby/<code>/` — player_joined, player_left, player_ready, game.started
- **Lobby code:** Large, letter-spaced, tap to copy. Uses unambiguous charset (no 0/O/I/1/L)
- **Start conditions:** All players ready + valid role config + >= 3 players
- **Host leaves:** Lobby disbanded, all clients navigate to `/home`
