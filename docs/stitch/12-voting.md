# Voting Phase

**Stitch ID:** `790a6b1760da44c3bd265fbce19ca389`
**Phase:** Voting
**Route:** `/game/:gameId/voting`

## Prompt

```
Voting screen for "Midnight Village" werewolf game. The climactic moment — each player secretly chooses who to accuse. Mobile, dark theme with tense atmosphere.

Background: Dark (#12100E) with a subtle warm tension.

Top bar: "VOTE" in large bold uppercase gold letters. Right side: countdown timer "0:28" in monospace, and a vote counter "3/5" showing how many have voted.

Main content: A 2-column grid of player cards. 5 players total. Each player card is a dark surface (#1A1714) rectangle with rounded corners containing:
- A circular avatar with initials and unique color
- Player name below the avatar
- A subtle checkmark overlay on players who have already voted

Player cards: "Alice" (has voted checkmark), "Bob" (has voted), "Carol" (no checkmark, this is the selected target with glowing blood-red border), "Dave" (has voted), "You" (greyed out, disabled, cannot self-vote).

Bottom panel (slides up when a target is selected): Dark surface with text "Vote to eliminate Carol?" in warm off-white. Two buttons: a large "CONFIRM VOTE" filled button in blood-ember red (#B8432F), and a small "Change" text button to the right.

Feel: High-stakes, irreversible, judgmental. Like pointing your finger at someone in the dark.
```

## Data & Interactions

- **Submit:** `POST /api/onuw/games/<id>/vote/` with `{target_player_id: X}`
- **No self-votes, no abstaining** (timer skip if no vote)
- **Real-time:** `vote_submitted` WebSocket shows WHO voted (not target)
- **Vote counter:** Updates as `vote_submitted` events arrive
- **Two-step confirm:** Select target → tap "CONFIRM VOTE" (prevents mis-taps)
- **Post-vote:** Grid becomes non-interactive, shows "Vote locked in"
- **Transition:** All votes in or timer expires → `vote_reveal` event → Vote Reveal screen
