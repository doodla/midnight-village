# Elimination Announcement

**Stitch ID:** `9f9ec58f42984d4890a688a74d844c67`
**Phase:** Results

## Prompt

```
Elimination announcement screen for "Midnight Village" werewolf game. Someone has been voted out. Mobile, dramatic dark theme.

Background: Near-black (#0D0B0F) fading to deep red at the edges, like a blood-tinted vignette.

Center of screen, vertically and horizontally centered:

The eliminated player's name "ALICE" displayed very large (40px+), in blood-ember red (#B8432F), bold uppercase. Below it, "has been eliminated" in smaller warm off-white text.

Above the name: A subtle skull or crossed-out circle icon in muted red.

Below the subtitle: A thin horizontal divider.

Below the divider: The reveal text "Alice's role was..." then a brief pause area, then "ROBBER" in gold (#C8A24D) with "Village Team" label below in small muted text.

At the very bottom: Small muted text "Proceeding to results..." with a subtle loading indicator.

The screen should feel solemn, final, and dramatic. Like a verdict being read in a candlelit court. Maximum negative space — the name dominates the screen.
```

## Data

- **Derived from vote tally:** Max votes >= 2 → eliminated. Ties → all tied die.
- **Scenarios:**
  - Single elimination: "[Name] has been eliminated"
  - Tie: "[Name1] and [Name2] have been eliminated"
  - No elimination: "NO ONE DIES" (cold blue tone instead of red)
  - Hunter chain: After 2s pause, "The Hunter's revenge!" + additional elimination
- **Auto-advance:** 3 seconds → Results screen
