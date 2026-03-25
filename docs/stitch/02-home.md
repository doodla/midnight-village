# Home Screen (Create/Join)

**Stitch ID:** `2edeb079ce89482585594235140fcd76`
**Phase:** Pre-game (authenticated)
**Route:** `/home`

## Prompt

```
Home screen for "Midnight Village" social deduction game. The player is logged in and sees two main actions. Dark atmospheric background with warm brown-black tones.

Top: A simple app bar with "Midnight Village" title and a small person icon on the right for profile/settings.

Below app bar: A greeting "Hello, SwiftOwl!" in warm off-white text, centered.

Main content: Two large tappable action cards stacked vertically with generous spacing.

Card 1 - "Create Game": A prominent elevated card with a subtle warm surface color (#1A1714). Shows a plus/create icon, title "Create Game" in bold, and subtitle "Start a new lobby" in muted text. Full width.

Card 2 - "Join Game": An outlined card style. Shows a group/people icon, title "Join Game" in bold, subtitle "Enter a lobby code" in muted text. Full width.

Below the Join Game card: An expandable area showing a 6-character text input field for the lobby code in monospace font (wide letter-spacing), with a "Join" button next to it. The code input should look like: _ _ _ _ _ _

Bottom: Small muted text link for "Logout".

The feel should be warm and inviting, like a tavern notice board. Cards should feel tactile and physical.
```

## Data & Interactions

- **APIs:**
  - `POST /api/lobbies/` (create lobby)
  - `POST /api/lobbies/<code>/join/` (join lobby)
  - `GET /api/onuw/me/current-game/` (check for active game on mount)
- **Create Game:** Tap → creates lobby → navigates to `/lobby/{code}`
- **Join Game:** Tap → expand code input → type 6-char code → tap Join → navigates to `/lobby/{code}`
- **Errors:** 404 "No lobby with that code", 400 "Lobby is full", 400 "Game already in progress"
- **Reconnection:** On mount, check for active game → show "Rejoin" banner if found
