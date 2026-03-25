# Vote Reveal

**Stitch ID:** `ae0a67d7c8754e5b9cadcaf6273a8fdd`
**Phase:** Voting → Results transition

## Prompt

```
Vote reveal screen for "Midnight Village" werewolf game. All votes are shown simultaneously. Mobile, dark theme.

Background: Near-black (#0F0D0B).

Top: "VOTES" centered in large bold gold uppercase.

Main content: A list of vote entries. Each entry is a row showing:
- Voter name on the left
- An arrow line (--->) in muted gold
- Target name on the right

Five vote entries stacked:
"Alice  ---------> Carol"
"Bob    ---------> Alice"
"Carol  ---------> Bob"
"Dave   ---------> Alice"
"Eve    ---------> Alice"

Below the votes: A divider line, then "VOTE TALLY" section header.

Horizontal bar chart showing vote counts:
- "Alice" with a long red bar, "3 votes" label — this is the maximum, highlighted in blood-ember red
- "Carol" with a short bar, "1 vote" in muted grey
- "Bob" with a short bar, "1 vote" in muted grey

The bars should clearly show Alice received the most votes. The red bar pulses subtly.

At the bottom: A small muted text "Alice received the most votes" as summary.

Feel: The moment of truth. Clean, dramatic data visualization. Like counting ballots in candlelight.
```

## Data

- **Source:** `vote_reveal` WebSocket event with full vote list
- **Animation:** Staggered reveal (400ms per vote, client-side)
- **Tally bars:** Animate from 0 → final width after all votes shown
- **Auto-advance:** 3 seconds after tally visible → Elimination screen
