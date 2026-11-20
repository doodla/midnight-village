# Night2

TLC reached more states than the chart budget of 500, so the chart draws only the bug paths: 5 states and 5 arrows.
With VIEW, TLC keeps one representative for each group of states that it counts as the same. An arrow can lead to the representative rather than to the state that the step reaches.

## FollowUpFromFollowUpRequest breaks
The shortest path has 4 steps:
0. Looking at cards
1. the host moves on: Doppelganger window: nothing copied yet
2. she looks at a player: Doppelganger window: she copied the Robber
3. her phone resends the look (answer lost): Doppelganger window: her repeated look is stored as her rob
4. the host moves on: Night window

## FollowUpNotRefused breaks
The shortest path has 4 steps:
0. Looking at cards
1. the host moves on: Doppelganger window: nothing copied yet
2. she looks at a player: Doppelganger window: she copied the Robber
3. her phone resends the look (answer lost): Doppelganger window: her repeated look is stored as her rob
4. she sends her rob: Doppelganger window: her repeated look is stored as her rob

## Rules not checked
ChooseLimit, AppliedAtMostOnce, AppliedExactlyOnce, LockedVoteKept, NoDeadlock, PhaseForward, ReachesResults
After the first break, each TLC run stops at 100,000 distinct states. A run reached that bound before it checked these rules in every state.
