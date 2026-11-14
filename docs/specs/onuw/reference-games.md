# Reference Games

> Ordered by complexity. Each scenario has a complete game state trace and identifies which spec edge cases it exercises. Use these to test the rules engine and to check that the results screen handles every outcome correctly.

---

## Scenario 1: Clean Village Win (Baseline)

**Complexity:** Low — the happy path. Every other scenario is a deviation from this.

**Setup:** 5 players — Alice=Werewolf, Bob=Seer, Carol=Robber, Dave=Villager, Eve=Villager
**Center:** Werewolf, Troublemaker, Minion

### Night
1. W2: Alice (Werewolf) wakes alone. Lone Werewolf. Peeks center card 0 → Werewolf.
2. W3: Bob (Seer) peeks Alice → Werewolf.
3. W3: Carol (Robber) swaps with Dave → Carol=Villager, Dave=Robber. Carol sees "Villager."

### Final State
| Player | Original | Final Card | Team |
|--------|----------|-----------|------|
| Alice | Werewolf | Werewolf | Werewolf |
| Bob | Seer | Seer | Village |
| Carol | Robber | Villager | Village |
| Dave | Villager | Robber | Village |
| Eve | Villager | Villager | Village |

### Voting
Bob accuses Alice. Village trusts the Seer claim. Alice=4 votes. Alice eliminated.

### Resolution
- Alice (Werewolf) dies → **Village wins.**
- Results table: Carol "Robber → Villager", Dave "Villager → Robber" (Robber swap)

### Edge Cases Exercised
- Lone Werewolf center peek (optional action)
- Seer information becomes the basis for discussion
- Robber swap changes two players' final cards
- Straightforward win condition (Werewolf dies = Village wins)
- Results table shows role transitions for swapped players

---

## Scenario 2: No One Dies — Werewolf Survives

**Complexity:** Low — tests the "no elimination" path.

**Setup:** 4 players — Alice=Werewolf, Bob=Villager, Carol=Villager, Dave=Seer
**Center:** Werewolf, Minion, Insomniac

### Night
1. W2: Alice (Werewolf) wakes alone. Lone Werewolf. Declines center peek (optional — timer expires).
2. W3: Dave (Seer) peeks center cards 0 and 1 → Werewolf, Minion.

### Voting
- Alice→Bob, Bob→Carol, Carol→Dave, Dave→Alice
- Everyone has 1 vote. No one reaches the ≥2 threshold. **No one dies.**

### Resolution
- No deaths. Werewolves among players: [Alice]. No Werewolf died → **Werewolf team wins.**

### Edge Cases Exercised
- Vote split where no player reaches 2-vote threshold
- M-05 "no elimination" cold blue treatment
- NC-ELIM-NONE narrator cue
- Optional action declined (lone Werewolf skips peek)
- Seer peeking center cards (Option B)
- Werewolf wins by survival

---

## Scenario 3: The Seer Trap — Stale Information

**Complexity:** Medium — the Seer's information becomes wrong due to a swap.

**Setup:** 5 players — Alice=Werewolf, Bob=Seer, Carol=Robber, Dave=Villager, Eve=Troublemaker
**Center:** Werewolf, Minion, Drunk

### Night (Wave 3 order is critical: Seer → Robber → Troublemaker)
1. W2: Alice (Werewolf) wakes alone. Peeks center → Minion.
2. W3: Bob (Seer) peeks Alice → **Werewolf** (pre-swap state).
3. W3: Carol (Robber) swaps with Alice → Carol=Werewolf, Alice=Robber. Carol sees "Werewolf."
4. W3: Eve (Troublemaker) swaps Bob and Dave → Bob=Villager, Dave=Seer. Blind swap.

### Final State
| Player | Original | Final Card | Team |
|--------|----------|-----------|------|
| Alice | Werewolf | Robber | Village |
| Bob | Seer | Villager | Village |
| Carol | Robber | **Werewolf** | **Werewolf** |
| Dave | Villager | Seer | Village |
| Eve | Troublemaker | Troublemaker | Village |

### Voting
Bob accuses Alice based on Seer peek ("Alice is Werewolf"). Village votes Alice. Alice=4 votes.

### Resolution
- Alice (Robber) dies. Alice is on Village team. No Werewolf died.
- Carol holds Werewolf. Carol is alive. → **Werewolf team wins.**
- Bob's Seer information was stale — correct at peek time but invalidated by Carol's Robber swap.

### Edge Cases Exercised
- Seer sees pre-swap state (Wave 3 ordering matters)
- Robber swap invalidates Seer information
- Troublemaker swap changes two uninvolved players
- Village eliminates a Village member based on stale info
- Results must show: Alice "Werewolf → Robber" (swapped), Bob "Seer → Villager" (swapped), Carol "Robber → Werewolf"
- Autopsy reveals the chain of swaps that made the Seer info wrong

---

## Scenario 4: Doppelganger Chaos — Multi-Swap Chain

**Complexity:** High — Doppelganger-as-Robber creates a 3-player card shuffle.

**Setup:** 5 players — Alice=Doppelganger, Bob=Robber, Carol=Werewolf, Dave=Seer, Eve=Villager
**Center:** Werewolf, Troublemaker, Drunk

### Night
1. W1: Alice (Doppelganger) peeks Bob → Robber. Becomes Doppelganger-as-Robber.
2. W1 follow-up: Alice (as Robber) swaps with Carol → Alice=Werewolf, Carol=Doppelganger(Robber). Alice sees "Werewolf." **Alice is now Werewolf team.**
3. W2: Carol (dealt Werewolf) wakes for Werewolf call. Carol is lone Werewolf (she holds Doppelganger card, but wake is by original deal). Peeks center → Werewolf.
4. W3: Dave (Seer) peeks Eve → Villager.
5. W3: Bob (Robber) swaps with Dave → Bob=Seer, Dave=Robber. Bob sees "Seer."

### Final State
| Player | Card | Team |
|--------|------|------|
| Alice | Werewolf | **Werewolf** |
| Bob | Seer | Village |
| Carol | Doppelganger (copied Robber) | Village |
| Dave | Robber | Village |
| Eve | Villager | Village |

### Voting
Village votes Carol (suspicious behavior). Carol=3 votes. Eliminated.

### Resolution
- Carol (Doppelganger/Robber, Village team) dies. No Werewolf died. → **Werewolf team wins.**
- Carol's elimination reveals "Robber" (effective role of Doppelganger card) — not "Werewolf" despite Carol being dealt Werewolf.

### Edge Cases Exercised
- Doppelganger-as-Robber immediate follow-up in Wave 1
- Wake-by-original-deal: Carol wakes as Werewolf despite no longer holding the card
- Doppelganger card carries copied role for team resolution
- Elimination of Doppelganger card holder shows effective (copied) role
- Two Robber actions in one game (Doppelganger-as-Robber in W1, real Robber in W3)
- Alice holds Werewolf card but was never called for the Werewolf wake
- Carol's "Werewolf → Robber" transition in results table
- Autopsy must show Doppelganger peek + follow-up as separate entries

---

## Scenario 5: Hunter Chain + Tanner Block

**Complexity:** High — two deaths via Hunter chain, multiple win conditions evaluated.

**Setup:** 6 players — Alice=Werewolf, Bob=Hunter, Carol=Seer, Dave=Villager, Eve=Tanner, Frank=Villager
**Center:** Werewolf, Minion, Robber

### Night
1. W2: Alice (lone Werewolf) peeks center → Minion.
2. W3: Carol (Seer) peeks Alice → Werewolf.

### Voting
- Alice→Bob, Bob→Eve, Carol→Alice, Dave→Bob, Eve→Bob, Frank→Alice
- Bob=3 votes, Alice=2 votes, Eve=1 vote.

### Resolution
1. Bob dies (3 votes, highest, ≥2 threshold).
2. **Hunter chain:** Bob (Hunter) voted for Eve → Eve also dies.
3. **Win condition evaluation:**
   - Werewolf players: [Alice]. Alice alive. No Werewolf died.
   - Tanner players: [Eve]. Eve died → **Tanner wins.**
   - Tanner died + no Werewolf died → Tanner death **blocks** Werewolf win.
   - **Winners: Tanner only.**

### Edge Cases Exercised
- Hunter passive ability triggers on death (card-based, not player-based)
- Hunter chain kill is NOT from voting — Eve had only 1 vote
- Tanner wins by being eliminated (via Hunter chain, not direct vote)
- Tanner death blocks Werewolf team win (official rule override)
- "Tanner wins only" — Village loses, Werewolves lose despite surviving
- Results headline: "TANNER WINS!" — only Eve wins
- Elimination sequence: M-04 for Bob → 600ms Hunter pause → "The Hunter takes aim..." → M-04 for Eve
- Results must show elimination reason (vote vs Hunter chain)
- NC-ELIM-HUNTER and NC-ELIM-HUNTER-TARGET narrator cues

---

## Scenario 6: No-Werewolf Minion — Unwitting Winner

**Complexity:** High — Minion special rule, Troublemaker swap creates an unknowing winner.

**Setup:** 5 players — Alice=Minion, Bob=Seer, Carol=Villager, Dave=Troublemaker, Eve=Mason
**Center:** Werewolf, Werewolf, Mason

### Night
1. W2: Alice (Minion) wakes. Werewolves extend thumbs — **zero thumbs up.** Both Werewolves are in center. Alice sees: "No werewolves among players."
2. W2: Eve (Mason) wakes alone. Lone Mason. "You are the lone Mason."
3. W3: Bob (Seer) peeks Carol → Villager.
4. W3: Dave (Troublemaker) swaps Alice and Carol → Alice=Villager, Carol=Minion. Blind swap.

### Final State
| Player | Card | Team |
|--------|------|------|
| Alice | Villager | Village |
| Bob | Seer | Village |
| Carol | **Minion** | **Werewolf** |
| Dave | Troublemaker | Village |
| Eve | Mason | Village |

### Voting
Alice frames Bob. Everyone votes Bob. Bob=4 votes. Eliminated.

### Resolution
- Bob (Seer, Village) dies.
- No Werewolves among players → Scenario B.
- Minion players: [Carol]. A non-Minion player (Bob) died → **Werewolf team wins** (Minion special rule).
- Carol wins but has NO IDEA she holds the Minion card.
- Alice loses despite orchestrating the kill as original Minion.

### Edge Cases Exercised
- Minion sees zero Werewolf thumbs (both in center)
- Minion special rule: no Werewolves among players + non-Minion dies = Werewolf team wins
- Troublemaker swap unknowingly transfers Minion card
- Player wins without knowing they're on the winning team
- Player loses despite executing the winning strategy (Alice)
- "WEREWOLF TEAM WINS!" headline with no Werewolves among players
- Results must explain WHY Werewolf team won (Resolution Summary)
- Night action summary: Carol shows "No night action" (original=Villager), not Minion info
- Autopsy reveals the Troublemaker swap that transferred the Minion card

---

## Scenario 7: Doppelganger-as-Minion (Both Sub-Cases)

**Complexity:** High — tests the two-axis Doppelganger-as-Minion condition.

### Sub-Case A: Minion Also In Play

**Setup:** 5 players — Alice=Doppelganger, Bob=Minion, Carol=Werewolf, Dave=Seer, Eve=Villager
**Center:** Werewolf, Mason, Mason

### Night
1. W1: Alice (Doppelganger) peeks Bob → Minion. Becomes Doppelganger-as-Minion. **Team → Werewolf.**
2. W1 special script: NC-W1-MINION-SUB fires. "If you are now a Minion, keep your eyes open." Werewolves extend thumbs. Alice sees Carol's thumb. NC-W1-MINION-END fires.
3. W2: Carol (Werewolf) wakes. Lone Werewolf (1 WW dealt to players). Peeks center → Werewolf.
4. W2: Bob (Minion) wakes. Sees Carol's thumb. Bob knows Carol is Werewolf.
5. W3: Dave (Seer) peeks Alice → **Doppelganger** (physical card is still Doppelganger).

### Key Points
- Alice and Bob BOTH know Carol is Werewolf (both saw thumbs)
- Carol does NOT know Alice or Bob are on her team
- Dave sees "Doppelganger" — not "Minion" — because the physical card didn't change
- The NC-W1-MINION-SUB narrator script fires in Wave 1 (~21s total with identification window)

### Edge Cases Exercised
- Doppelganger-as-Minion Wave 1 special script (NC-W1-MINION-SUB, NC-W1-MINION-END)
- Two Minion-type roles in same game (Doppelganger-as-Minion + real Minion)
- Werewolves don't know there are two Minion-seers
- Seer sees "Doppelganger" not "Minion" (physical card)
- Wave 1 extended duration (~21s) for sub-case A

### Sub-Case B: Minion NOT In Game Setup

Sub-case B is a **narrator timing concern**, not a separate gameplay scenario. It applies when the Doppelganger is in the game but the Minion card is NOT in the game setup at all. Since the Doppelganger can only copy a player's card (not a center card), Alice cannot become Doppelganger-as-Minion if no player holds the Minion card.

The distinction matters for narrator cue timing:
- **Sub-case A** (Minion in game): Full 6-step W1 sequence runs (~21s) — the identification window must be long enough to not reveal whether the Doppelganger actually copied Minion, since NC-W2-MIN-WAKE will fire later.
- **Sub-case B** (Minion not in game): Shorter 3-step W1 sequence (~13s) — NC-W1-MINION-SUB does NOT fire, NC-W2-MIN-WAKE does NOT fire.

Both sub-cases are handled in `narrator-cues.md`. Sub-case A is exercised by the scenario above.

### Edge Cases Exercised (Sub-Case B, narrator only)
- Shorter Wave 1 duration when Minion is not in the game
- NC-W1-MINION-SUB/END are conditional on Minion being in game setup
- Wave timing concealment: W1 duration should not reveal whether Minion is in the game

---

## Scenario 8: The Drunk Into Werewolf — Unknowing Team Change

**Complexity:** Medium — player doesn't know their own team.

**Setup:** 5 players — Alice=Werewolf, Bob=Seer, Carol=Drunk, Dave=Villager, Eve=Insomniac
**Center:** Werewolf, Villager, Troublemaker

### Night
1. W2: Alice (Werewolf) wakes alone. Lone Werewolf. Peeks center card 0 → Werewolf. (Confirms both WW cards accounted for.)
2. W3: Bob (Seer) peeks Carol → **Drunk** (pre-swap — Seer acts before Drunk in W3).
3. W3: Carol (Drunk) MUST swap with a center card. Swaps with center card 0 → Carol=**Werewolf**, center=[Drunk, Villager, Troublemaker]. **Carol does NOT see her new card.** Carol has no idea she's now a Werewolf.
4. W4: Eve (Insomniac) peeks own card → still Insomniac. Not swapped.

### Final State
| Player | Card | Team | Knows Their Team? |
|--------|------|------|-------------------|
| Alice | Werewolf | Werewolf | Yes |
| Bob | Seer | Village | Yes |
| Carol | **Werewolf** | **Werewolf** | **No — thinks she's Drunk** |
| Dave | Villager | Village | Yes |
| Eve | Insomniac | Village | Yes (verified) |

### Voting
Carol truthfully claims Drunk: "I swapped with a center card, no idea what I am." Bob claims Seer: "Carol was the Drunk when I peeked." This is true but stale — Carol is now Werewolf. If village votes Alice (the known Werewolf) AND Carol is also Werewolf, village might still win if they get Alice. But if they accidentally trust Carol...

Village votes Alice. Alice=4 votes. Eliminated.

### Resolution
- Alice (Werewolf) dies → at least one Werewolf died → **Village wins!**
- Carol is also a Werewolf but survived. Village still wins because at least one WW died.
- Carol sees "You Lose" — she's on the Werewolf team and didn't know it.

### Edge Cases Exercised
- Drunk mandatory swap (no option to skip)
- Drunk does NOT see new card (blind swap)
- Drunk swaps into Werewolf team unknowingly
- Seer's pre-swap peek is stale (saw Drunk, Carol is now Werewolf)
- Insomniac confirms own card (Wave 4)
- Two Werewolves among players at resolution (Alice + Carol)
- Village wins by killing at least one Werewolf (doesn't need to kill all)
- Carol "Drunk → Werewolf" in results — the swap is the story
- Autopsy: Drunk swap entry, Seer peek (stale), Insomniac self-check

---

## Scenario 9: The Kitchen Sink — Maximum Complexity

**Complexity:** Extreme — every complex mechanic in one game.

**Setup:** 7 players — Alice=Doppelganger, Bob=Werewolf, Carol=Minion, Dave=Seer, Eve=Robber, Frank=Hunter, Grace=Tanner
**Center:** Werewolf, Troublemaker, Drunk

### Night
1. W1: Alice (Doppelganger) peeks Eve → Robber. Becomes Doppelganger-as-Robber. Immediately robs Frank → Alice=Hunter, Frank=Doppelganger(Robber). Alice sees "Hunter." Team stays Village.
2. W2: Bob (Werewolf) wakes. Lone Werewolf (other WW in center). Peeks center → Troublemaker.
3. W2: Carol (Minion) wakes. Sees Bob's thumb. Carol knows Bob is Werewolf. Bob doesn't know Carol.
4. W3: Dave (Seer) peeks Bob → **Werewolf.**
5. W3: Eve (Robber) swaps with Alice → Eve=Hunter, Alice=Robber. Eve sees "Hunter."
6. (Troublemaker, Drunk in center — no active player)

### Final State
| Player | Original | Final Card | Team |
|--------|----------|-----------|------|
| Alice | Doppelganger | Robber | Village |
| Bob | Werewolf | Werewolf | **Werewolf** |
| Carol | Minion | Minion | **Werewolf** |
| Dave | Seer | Seer | Village |
| Eve | Robber | Hunter | Village |
| Frank | Hunter | Doppelganger(Robber) | Village |
| Grace | Tanner | Tanner | **Independent** |

### Key Information Each Player Has
- Alice: "I copied Robber. I robbed Frank: got Hunter." (Alice doesn't know Eve later robbed her — she thinks she still holds Hunter.)
- Bob: Knows he's Werewolf. Peeked Troublemaker in center.
- Carol: Knows Bob is Werewolf. Will protect Bob.
- Dave: "Bob is Werewolf" (Seer peek — still accurate, Bob wasn't swapped).
- Eve: "I robbed Alice: got Hunter." Eve thinks she has the Hunter passive.
- Frank: No night info. Thinks he's Hunter. Actually holds Doppelganger(Robber).
- Grace: No night info. Wants to get eliminated.

### Voting
Dave accuses Bob. Carol deflects. Grace acts suspicious. Bob claims Villager.
- Alice→Bob, Bob→Grace, Carol→Dave, Dave→Grace, Eve→Bob, Frank→Dave, Grace→Alice
- Bob=2 votes (Alice, Eve). Grace=2 votes (Bob, Dave). Dave=2 votes (Carol, Frank). Alice=1 vote (Grace).
- Three-way tie at 2 votes (≥2 threshold). **All three die: Bob, Grace, Dave.**

### Resolution
1. **Deaths from voting:** Bob (2 votes, tied), Grace (2 votes, tied), Dave (2 votes, tied).
2. **Hunter check:** Eve holds Hunter card. Eve is alive → no Hunter chain. Frank holds Doppelganger(Robber) — NOT Hunter. Frank doesn't trigger Hunter even though he was originally dealt Hunter.
3. **Win condition:**
   - Bob (Werewolf) died → Village condition met.
   - Grace (Tanner) died → Tanner wins.
   - Both Tanner and Village win? Yes — Tanner + Werewolf death in same game.
   - **Winners: Village AND Tanner.** Werewolf team loses.

### Edge Cases Exercised
- Doppelganger-as-Robber immediate follow-up
- Two Robber actions (Doppelganger W1, real Robber W3)
- Robber steals from Doppelganger (Eve robs Alice who already robbed Frank)
- Hunter passive belongs to CARD not PLAYER (Eve has it, not Frank)
- Three deaths in one game (three-way tie at ≥2 votes)
- Tanner wins alongside Village (both can win simultaneously)
- Minion knows Werewolf but couldn't save them
- NC-ELIM-DEATH-TIE for Bob, Grace, and Dave (three-way tie)
- Results: 3 eliminated players, 2 winning teams, Hunter passive did NOT trigger
- Autopsy: complex chain of Doppelganger → Robber → Robber swaps
- 7-player grid layouts (3-column variant)

---

## Scenario Index

| # | Name | Complexity | Key Mechanics Tested |
|---|------|-----------|---------------------|
| 1 | Clean Village Win | Low | Baseline happy path, Robber swap, Seer info |
| 2 | No One Dies — Werewolf Survives | Low | Vote split, no elimination, M-05, Werewolf survival win |
| 3 | The Seer Trap | Medium | Stale Seer info, Wave 3 ordering, wrong elimination |
| 4 | Doppelganger Chaos | High | Doppelganger-as-Robber, wake-by-deal, copied role display |
| 5 | Hunter Chain + Tanner Block | High | Hunter passive, chain kill, Tanner blocks WW win |
| 6 | No-Werewolf Minion | High | Minion special rule, unknowing winner, zero WW thumbs |
| 7 | Doppelganger-as-Minion | High | W1 special script, two Minion-seers, narrator timing |
| 8 | Drunk Into Werewolf | Medium | Blind swap, unknowing team change, stale Seer peek |
| 9 | Kitchen Sink | Extreme | All mechanics simultaneously, 3 deaths, dual winners |
