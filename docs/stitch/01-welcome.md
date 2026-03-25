# Welcome/Auth Screen

**Stitch ID:** `bf6805196fe34a6cbdb0c552daccb018`
**Phase:** Pre-game
**Route:** `/welcome`

## Prompt

```
Welcome screen for a social deduction game called "Midnight Village" (like Werewolf). Dark, atmospheric, gothic tavern aesthetic. Warm blacks and deep browns, not cold blue-grey.

Top section: Large atmospheric illustration area showing a misty village at midnight with faint moonlight. Silhouettes of houses with one lit window.

Center: Game title "MIDNIGHT" in thin wide-tracked uppercase letters, then "VILLAGE" below it in bold uppercase, larger, with a blood-ember red (#B8432F) accent color. Below the title, a tagline in muted warm grey: "Who among you is the werewolf?"

Bottom section: A text input field labeled "Your name" with placeholder "Leave blank for a random name". Below it, a large full-width button "Enter the Village" in blood-ember red (#B8432F). The button should be tall (56px) for easy one-handed mobile tapping.

Overall feel: moody, mysterious, inviting. Like approaching a candlelit tavern door at midnight.
```

## Data & Interactions

- **API:** `POST /api/auth/guest/` (optional `display_name`)
- **Input:** Display name text field (optional, max 20 chars)
- **Action:** "Enter the Village" → creates guest account, stores JWT
- **Transition:** On success → `/home`
- **Edge cases:** Network error, validation error, double-tap prevention

## Design Notes

- First screen players see — should create atmosphere and excitement
- Most players spend under 10 seconds here
- Large touch targets for mobile
- Existing `AuthNotifier` handles the full auth flow
