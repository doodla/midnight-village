# Reference Games

> Complete example games, traced from the deal to the result. Use them to test the rules engine and to check that the results screen explains every outcome.
>
> Every game here has been replayed through two night models written from the rules (one role at a time, and one shared window) and through the engine's vote and win logic. All three agree on every game. The table at the end lists what each game covers and the cases with no game yet.

Center cards are numbered 1 to 3. The night is listed in the official order, which is the order the server applies actions in.

---

## Game 1: Clean Village Win

The baseline. A lone Werewolf looks at a center card, the Seer finds the Werewolf, the Robber's swap changes two players' cards, and the village wins.

**Players (5):** Alice = Werewolf, Bob = Seer, Carol = Robber, Dave = Villager, Eve = Villager

**Center:** Werewolf, Troublemaker, Minion

### Night

1. **Werewolves.** Alice wakes alone. As the lone Werewolf, Alice looks at center card 1 and sees Werewolf.
2. **Seer.** Bob looks at Alice's card and sees Werewolf.
3. **Robber.** Carol swaps cards with Dave and sees the card they took: Villager.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Werewolf | Werewolf | Werewolf |
| Bob | Seer | Seer | Village |
| Carol | Robber | **Villager** | Village |
| Dave | Villager | **Robber** | Village |
| Eve | Villager | Villager | Village |

### Vote and result

Votes: Alice → Bob, Bob → Alice, Carol → Alice, Dave → Alice, Eve → Alice.

- **Voted out:** Alice.
- **Winners:** Village.
- **Players who win:** Bob, Carol, Dave and Eve.

---

## Game 2: No One Dies

Nobody gets two votes, so nobody dies and the surviving Werewolf wins. Also: a lone Werewolf who chooses not to look, and a Seer who looks at two center cards.

**Players (4):** Alice = Werewolf, Bob = Villager, Carol = Villager, Dave = Seer

**Center:** Werewolf, Minion, Insomniac

### Night

1. **Werewolves.** Alice wakes alone. Alice chooses not to look at a center card.
2. **Seer.** Dave looks at center cards 1 and 2 and sees Werewolf and Minion.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Werewolf | Werewolf | Werewolf |
| Bob | Villager | Villager | Village |
| Carol | Villager | Villager | Village |
| Dave | Seer | Seer | Village |

### Vote and result

Votes: Alice → Bob, Bob → Carol, Carol → Dave, Dave → Alice.

- **Dies:** nobody. No player has two votes.
- **Winners:** Werewolf team.
- **Players who win:** Alice.

---

## Game 3: The Seer Trap

The Seer's information goes stale. The Seer sees the Werewolf, then the Robber takes that card, and the village kills an innocent.

**Players (5):** Alice = Werewolf, Bob = Seer, Carol = Robber, Dave = Villager, Eve = Troublemaker

**Center:** Werewolf, Minion, Drunk

### Night

1. **Werewolves.** Alice wakes alone. As the lone Werewolf, Alice looks at center card 2 and sees Minion.
2. **Seer.** Bob looks at Alice's card and sees Werewolf.
3. **Robber.** Carol swaps cards with Alice and sees the card they took: Werewolf.
4. **Troublemaker.** Eve swaps Bob's and Dave's cards. Nobody is shown anything.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Werewolf | **Robber** | Village |
| Bob | Seer | **Villager** | Village |
| Carol | Robber | **Werewolf** | Werewolf |
| Dave | Villager | **Seer** | Village |
| Eve | Troublemaker | Troublemaker | Village |

### Vote and result

Votes: Alice → Bob, Bob → Alice, Carol → Alice, Dave → Alice, Eve → Alice.

- **Voted out:** Alice.
- **Winners:** Werewolf team.
- **Players who win:** Carol.

---

## Game 4: Doppelganger Chaos

The Doppelganger copies the Robber and steals the Werewolf card at once. The player who was dealt Werewolf still wakes as a Werewolf, alone, and does not see the thief. A dead player holding the Doppelganger card counts as the role it copied.

**Players (5):** Alice = Doppelganger, Bob = Robber, Carol = Werewolf, Dave = Seer, Eve = Villager

**Center:** Werewolf, Troublemaker, Drunk

### Night

1. **Doppelganger.** Alice looks at Bob's card, sees Robber, and copies it. Acting at once: Alice (as Robber) swaps cards with Carol and sees the card they took: Werewolf.
2. **Werewolves.** Carol wakes alone. As the lone Werewolf, Carol looks at center card 1 and sees Werewolf.
3. **Seer.** Dave looks at Eve's card and sees Villager.
4. **Robber.** Bob swaps cards with Dave and sees the card they took: Seer.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Doppelganger | **Werewolf** | Werewolf |
| Bob | Robber | **Seer** | Village |
| Carol | Werewolf | **Doppelganger (copied Robber)** | Village |
| Dave | Seer | **Robber** | Village |
| Eve | Villager | Villager | Village |

### Vote and result

Votes: Alice → Carol, Bob → Carol, Dave → Carol, Carol → Eve, Eve → Alice.

- **Voted out:** Carol.
- **Winners:** Werewolf team.
- **Players who win:** Alice.

---

## Game 5: Hunter Chain + Tanner Block

The Hunter dies and takes their vote target with them. That target is the Tanner, who wins by dying, and the Tanner's death stops the Werewolf winning.

**Players (6):** Alice = Werewolf, Bob = Hunter, Carol = Seer, Dave = Villager, Eve = Tanner, Frank = Villager

**Center:** Werewolf, Minion, Robber

### Night

1. **Werewolves.** Alice wakes alone. As the lone Werewolf, Alice looks at center card 2 and sees Minion.
2. **Seer.** Carol looks at Alice's card and sees Werewolf.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Werewolf | Werewolf | Werewolf |
| Bob | Hunter | Hunter | Village |
| Carol | Seer | Seer | Village |
| Dave | Villager | Villager | Village |
| Eve | Tanner | Tanner | Tanner (own team) |
| Frank | Villager | Villager | Village |

### Vote and result

Votes: Alice → Bob, Bob → Eve, Carol → Alice, Dave → Bob, Eve → Bob, Frank → Alice.

- **Voted out:** Bob.
- **Hunter:** Bob holds the Hunter and voted for Eve, who dies too.
- **Winners:** Tanner.
- **Players who win:** Eve.

---

## Game 6: No-Werewolf Minion

Both Werewolf cards are in the center. The Minion card is swapped to a player who never learns it, and that player wins when someone else dies.

**Players (5):** Alice = Minion, Bob = Seer, Carol = Villager, Dave = Troublemaker, Eve = Mason

**Center:** Werewolf, Werewolf, Mason

### Night

1. **Minion.** Alice is shown the Werewolves: nobody.
2. **Masons.** Eve wakes alone. The other Mason card is not at the table.
3. **Seer.** Bob looks at Carol's card and sees Villager.
4. **Troublemaker.** Dave swaps Alice's and Carol's cards. Nobody is shown anything.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Minion | **Villager** | Village |
| Bob | Seer | Seer | Village |
| Carol | Villager | **Minion** | Werewolf |
| Dave | Troublemaker | Troublemaker | Village |
| Eve | Mason | Mason | Village |

### Vote and result

Votes: Alice → Bob, Carol → Bob, Dave → Bob, Eve → Bob, Bob → Alice.

- **Voted out:** Bob.
- **Winners:** Werewolf team.
- **Players who win:** Carol.

---

## Game 7: Doppelganger-as-Minion

The Doppelganger copies the Minion, so two players know the Werewolf and the Werewolf knows neither. The Seer looking at the Doppelganger sees 'Doppelganger', not what it copied.

**Players (5):** Alice = Doppelganger, Bob = Minion, Carol = Werewolf, Dave = Seer, Eve = Villager

**Center:** Werewolf, Mason, Mason

### Night

1. **Doppelganger.** Alice looks at Bob's card, sees Minion, and copies it. Still awake, Alice is shown the Werewolves: Carol.
2. **Werewolves.** Carol wakes alone. As the lone Werewolf, Carol looks at center card 1 and sees Werewolf.
3. **Minion.** Bob is shown the Werewolves: Carol.
4. **Seer.** Dave looks at Alice's card and sees Doppelganger.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Doppelganger | Doppelganger (copied Minion) | Werewolf |
| Bob | Minion | Minion | Werewolf |
| Carol | Werewolf | Werewolf | Werewolf |
| Dave | Seer | Seer | Village |
| Eve | Villager | Villager | Village |

### Vote and result

Votes: Alice → Dave, Bob → Dave, Carol → Dave, Dave → Carol, Eve → Carol.

- **Voted out:** Dave.
- **Winners:** Werewolf team.
- **Players who win:** Alice, Bob and Carol.

---

## Game 8: Drunk Into Werewolf

The Drunk swaps blind into the Werewolf card and never knows. The village still wins by killing the other Werewolf. The Insomniac confirms an unchanged card.

**Players (5):** Alice = Werewolf, Bob = Seer, Carol = Drunk, Dave = Villager, Eve = Insomniac

**Center:** Werewolf, Villager, Troublemaker

### Night

1. **Werewolves.** Alice wakes alone. As the lone Werewolf, Alice looks at center card 1 and sees Werewolf.
2. **Seer.** Bob looks at Carol's card and sees Drunk.
3. **Drunk.** Carol swaps their card with center card 1 without seeing it.
4. **Insomniac.** Eve looks at their own card: Insomniac.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Werewolf | Werewolf | Werewolf |
| Bob | Seer | Seer | Village |
| Carol | Drunk | **Werewolf** | Werewolf |
| Dave | Villager | Villager | Village |
| Eve | Insomniac | Insomniac | Village |

Center at dawn: Drunk, Villager, Troublemaker

### Vote and result

Votes: Alice → Bob, Bob → Alice, Carol → Alice, Dave → Alice, Eve → Alice.

- **Voted out:** Alice.
- **Winners:** Village.
- **Players who win:** Bob, Dave and Eve.

---

## Game 9: Kitchen Sink

Many mechanics at once: the Doppelganger robs, is robbed in turn, the Hunter's power follows the card, three players tie and all die, and two teams win together.

**Players (7):** Alice = Doppelganger, Bob = Werewolf, Carol = Minion, Dave = Seer, Eve = Robber, Frank = Hunter, Grace = Tanner

**Center:** Werewolf, Troublemaker, Drunk

### Night

1. **Doppelganger.** Alice looks at Eve's card, sees Robber, and copies it. Acting at once: Alice (as Robber) swaps cards with Frank and sees the card they took: Hunter.
2. **Werewolves.** Bob wakes alone. As the lone Werewolf, Bob looks at center card 2 and sees Troublemaker.
3. **Minion.** Carol is shown the Werewolves: Bob.
4. **Seer.** Dave looks at Bob's card and sees Werewolf.
5. **Robber.** Eve swaps cards with Alice and sees the card they took: Hunter.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Doppelganger | **Robber** | Village |
| Bob | Werewolf | Werewolf | Werewolf |
| Carol | Minion | Minion | Werewolf |
| Dave | Seer | Seer | Village |
| Eve | Robber | **Hunter** | Village |
| Frank | Hunter | **Doppelganger (copied Robber)** | Village |
| Grace | Tanner | Tanner | Tanner (own team) |

### Vote and result

Votes: Alice → Bob, Bob → Grace, Carol → Dave, Dave → Grace, Eve → Bob, Frank → Dave, Grace → Alice.

- **Voted out:** Bob, Dave and Grace (tied).
- **Winners:** Tanner and Village.
- **Players who win:** Alice, Dave, Eve, Frank and Grace.

---

## Game 10: Two Werewolves, two Masons

Two Werewolves see each other and neither may look at the center. Two Masons see each other.

**Players (6):** Alice = Werewolf, Bob = Werewolf, Carol = Mason, Dave = Mason, Eve = Seer, Frank = Villager

**Center:** Robber, Drunk, Villager

### Night

1. **Werewolves.** Alice and Bob wake and see each other. With more than one awake, nobody looks at the center.
2. **Masons.** Carol and Dave wake and see each other.
3. **Seer.** Eve looks at Alice's card and sees Werewolf.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Werewolf | Werewolf | Werewolf |
| Bob | Werewolf | Werewolf | Werewolf |
| Carol | Mason | Mason | Village |
| Dave | Mason | Mason | Village |
| Eve | Seer | Seer | Village |
| Frank | Villager | Villager | Village |

### Vote and result

Votes: Alice → Frank, Bob → Frank, Carol → Alice, Dave → Alice, Eve → Alice, Frank → Alice.

- **Voted out:** Alice.
- **Winners:** Village.
- **Players who win:** Carol, Dave, Eve and Frank.

---

## Game 11: The Insomniac wakes up changed

The Insomniac's card is swapped for the Werewolf and the Insomniac finds out at dawn. The player dealt Werewolf no longer holds it and does not know.

**Players (4):** Alice = Werewolf, Bob = Insomniac, Carol = Troublemaker, Dave = Villager

**Center:** Werewolf, Seer, Robber

### Night

1. **Werewolves.** Alice wakes alone. As the lone Werewolf, Alice looks at center card 2 and sees Seer.
2. **Troublemaker.** Carol swaps Alice's and Bob's cards. Nobody is shown anything.
3. **Insomniac.** Bob looks at their own card: Werewolf.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Werewolf | **Insomniac** | Village |
| Bob | Insomniac | **Werewolf** | Werewolf |
| Carol | Troublemaker | Troublemaker | Village |
| Dave | Villager | Villager | Village |

### Vote and result

Votes: Alice → Dave, Bob → Alice, Carol → Alice, Dave → Alice.

- **Voted out:** Alice.
- **Winners:** Werewolf team.
- **Players who win:** Bob.

---

## Game 12: Robber, Troublemaker and Drunk touch the same cards

Order matters. The Robber, the Troublemaker and the Drunk all touch the same cards, and the result depends on applying them Robber, then Troublemaker, then Drunk. The Robber sees the card they took before the Troublemaker moves it on.

**Players (5):** Alice = Robber, Bob = Troublemaker, Carol = Drunk, Dave = Werewolf, Eve = Villager

**Center:** Seer, Minion, Werewolf

### Night

1. **Werewolves.** Dave wakes alone. As the lone Werewolf, Dave looks at center card 3 and sees Werewolf.
2. **Robber.** Alice swaps cards with Dave and sees the card they took: Werewolf.
3. **Troublemaker.** Bob swaps Alice's and Eve's cards. Nobody is shown anything.
4. **Drunk.** Carol swaps their card with center card 1 without seeing it.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Robber | **Villager** | Village |
| Bob | Troublemaker | Troublemaker | Village |
| Carol | Drunk | **Seer** | Village |
| Dave | Werewolf | **Robber** | Village |
| Eve | Villager | **Werewolf** | Werewolf |

Center at dawn: Drunk, Minion, Werewolf

### Vote and result

Votes: Alice → Dave, Bob → Alice, Carol → Alice, Dave → Alice, Eve → Alice.

- **Voted out:** Alice.
- **Winners:** Werewolf team.
- **Players who win:** Eve.

---

## Game 13: Three players, no Werewolf at the table, nobody dies

The smallest game. Both Werewolf cards are in the center and nobody dies, so the village wins.

**Players (3):** Alice = Seer, Bob = Robber, Carol = Villager

**Center:** Werewolf, Werewolf, Troublemaker

### Night

1. **Seer.** Alice looks at center cards 1 and 2 and sees Werewolf and Werewolf.
2. **Robber.** Bob swaps cards with Carol and sees the card they took: Villager.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Seer | Seer | Village |
| Bob | Robber | **Villager** | Village |
| Carol | Villager | **Robber** | Village |

### Vote and result

Votes: Alice → Bob, Bob → Carol, Carol → Alice.

- **Dies:** nobody. No player has two votes.
- **Winners:** Village.
- **Players who win:** Alice, Bob and Carol.

---

## Game 14: No Werewolf at the table and someone dies

Both Werewolf cards are in the center, there is no Minion, and the village kills someone anyway. Nobody wins.

**Players (4):** Alice = Seer, Bob = Robber, Carol = Villager, Dave = Villager

**Center:** Werewolf, Werewolf, Drunk

### Night

1. **Seer.** Alice looks at Bob's card and sees Robber.
2. **Robber.** Bob does nothing.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Seer | Seer | Village |
| Bob | Robber | Robber | Village |
| Carol | Villager | Villager | Village |
| Dave | Villager | Villager | Village |

### Vote and result

Votes: Alice → Carol, Bob → Carol, Carol → Alice, Dave → Carol.

- **Voted out:** Carol.
- **Winners:** nobody.
- **Players who win:** nobody.

---

## Game 15: The Minion takes the fall

The Minion is killed and the Werewolf survives. The Werewolf team wins, and so does the dead Minion.

**Players (5):** Alice = Werewolf, Bob = Minion, Carol = Seer, Dave = Villager, Eve = Villager

**Center:** Werewolf, Robber, Drunk

### Night

1. **Werewolves.** Alice wakes alone. As the lone Werewolf, Alice looks at center card 2 and sees Robber.
2. **Minion.** Bob is shown the Werewolves: Alice.
3. **Seer.** Carol looks at Bob's card and sees Minion.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Werewolf | Werewolf | Werewolf |
| Bob | Minion | Minion | Werewolf |
| Carol | Seer | Seer | Village |
| Dave | Villager | Villager | Village |
| Eve | Villager | Villager | Village |

### Vote and result

Votes: Alice → Bob, Bob → Carol, Carol → Bob, Dave → Bob, Eve → Bob.

- **Voted out:** Bob.
- **Winners:** Werewolf team.
- **Players who win:** Alice and Bob.

---

## Game 16: Only the Minion dies and no Werewolf is at the table

No Werewolf at the table and the only death is the Minion. Nobody wins.

**Players (4):** Alice = Minion, Bob = Seer, Carol = Villager, Dave = Villager

**Center:** Werewolf, Werewolf, Robber

### Night

1. **Minion.** Alice is shown the Werewolves: nobody.
2. **Seer.** Bob looks at center cards 1 and 3 and sees Werewolf and Robber.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Minion | Minion | Werewolf |
| Bob | Seer | Seer | Village |
| Carol | Villager | Villager | Village |
| Dave | Villager | Villager | Village |

### Vote and result

Votes: Alice → Bob, Bob → Alice, Carol → Alice, Dave → Alice.

- **Voted out:** Alice.
- **Winners:** nobody.
- **Players who win:** nobody.

---

## Game 17: Two-way tie: a Werewolf and a Villager die together

A two-way tie. Both tied players die, one of them is a Werewolf, and the village wins. The dead Villager wins too.

**Players (5):** Alice = Werewolf, Bob = Villager, Carol = Seer, Dave = Robber, Eve = Villager

**Center:** Werewolf, Minion, Troublemaker

### Night

1. **Werewolves.** Alice wakes alone. As the lone Werewolf, Alice looks at center card 1 and sees Werewolf.
2. **Seer.** Carol looks at Eve's card and sees Villager.
3. **Robber.** Dave does nothing.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Werewolf | Werewolf | Werewolf |
| Bob | Villager | Villager | Village |
| Carol | Seer | Seer | Village |
| Dave | Robber | Robber | Village |
| Eve | Villager | Villager | Village |

### Vote and result

Votes: Alice → Bob, Bob → Alice, Carol → Alice, Dave → Bob, Eve → Carol.

- **Voted out:** Alice and Bob (tied).
- **Winners:** Village.
- **Players who win:** Bob, Carol, Dave and Eve.

---

## Game 18: The Doppelganger joins the Werewolves

The Doppelganger copies a Werewolf and joins them: the two see each other and neither is 'lone'. The Insomniac's card is unchanged. Killing the Doppelganger counts as killing a Werewolf.

**Players (5):** Alice = Doppelganger, Bob = Werewolf, Carol = Seer, Dave = Villager, Eve = Insomniac

**Center:** Werewolf, Robber, Drunk

### Night

1. **Doppelganger.** Alice looks at Bob's card, sees Werewolf, and copies it.
2. **Werewolves.** Alice and Bob wake and see each other. With more than one awake, nobody looks at the center.
3. **Seer.** Carol looks at Alice's card and sees Doppelganger.
4. **Insomniac.** Eve looks at their own card: Insomniac.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Doppelganger | Doppelganger (copied Werewolf) | Werewolf |
| Bob | Werewolf | Werewolf | Werewolf |
| Carol | Seer | Seer | Village |
| Dave | Villager | Villager | Village |
| Eve | Insomniac | Insomniac | Village |

### Vote and result

Votes: Alice → Carol, Bob → Carol, Carol → Alice, Dave → Alice, Eve → Alice.

- **Voted out:** Alice.
- **Winners:** Village.
- **Players who win:** Carol, Dave and Eve.

---

## Game 19: The Hunter shoots a copied Hunter: no second shot

The Doppelganger copies the Hunter. The real Hunter dies and shoots the Doppelganger, who dies. The Doppelganger's own Hunter power does not fire in turn, so the Werewolf they voted for survives and wins.

**Players (5):** Alice = Doppelganger, Bob = Hunter, Carol = Werewolf, Dave = Villager, Eve = Seer

**Center:** Werewolf, Minion, Robber

### Night

1. **Doppelganger.** Alice looks at Bob's card, sees Hunter, and copies it.
2. **Werewolves.** Carol wakes alone. As the lone Werewolf, Carol looks at center card 1 and sees Werewolf.
3. **Seer.** Eve looks at Carol's card and sees Werewolf.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Doppelganger | Doppelganger (copied Hunter) | Village |
| Bob | Hunter | Hunter | Village |
| Carol | Werewolf | Werewolf | Werewolf |
| Dave | Villager | Villager | Village |
| Eve | Seer | Seer | Village |

### Vote and result

Votes: Alice → Carol, Bob → Alice, Carol → Bob, Dave → Bob, Eve → Bob.

- **Voted out:** Bob.
- **Hunter:** Bob holds the Hunter and voted for Alice, who dies too.
- **Winners:** Werewolf team.
- **Players who win:** Carol.

---

## Game 20: The Doppelganger copies the Tanner

The Doppelganger copies the Tanner and is killed, so the Doppelganger wins alone. The real Tanner is alive and loses.

**Players (5):** Alice = Doppelganger, Bob = Tanner, Carol = Werewolf, Dave = Seer, Eve = Villager

**Center:** Werewolf, Robber, Drunk

### Night

1. **Doppelganger.** Alice looks at Bob's card, sees Tanner, and copies it.
2. **Werewolves.** Carol wakes alone. As the lone Werewolf, Carol looks at center card 2 and sees Robber.
3. **Seer.** Dave looks at Alice's card and sees Doppelganger.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Doppelganger | Doppelganger (copied Tanner) | Tanner (own team) |
| Bob | Tanner | Tanner | Tanner (own team) |
| Carol | Werewolf | Werewolf | Werewolf |
| Dave | Seer | Seer | Village |
| Eve | Villager | Villager | Village |

### Vote and result

Votes: Alice → Bob, Bob → Alice, Carol → Alice, Dave → Alice, Eve → Alice.

- **Voted out:** Alice.
- **Winners:** Tanner.
- **Players who win:** Alice.

---

## Game 21: Nobody acts

Every player with a choice lets the clock run out. No cards move. The Drunk does not swap (see the open ruling in the design brief).

**Players (5):** Alice = Werewolf, Bob = Seer, Carol = Robber, Dave = Troublemaker, Eve = Drunk

**Center:** Werewolf, Insomniac, Villager

### Night

1. **Werewolves.** Alice wakes alone. Alice chooses not to look at a center card.
2. **Seer.** Bob does nothing.
3. **Robber.** Carol does nothing.
4. **Troublemaker.** Dave does nothing.
5. **Drunk.** Eve does nothing.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Werewolf | Werewolf | Werewolf |
| Bob | Seer | Seer | Village |
| Carol | Robber | Robber | Village |
| Dave | Troublemaker | Troublemaker | Village |
| Eve | Drunk | Drunk | Village |

### Vote and result

Votes: Alice → Bob, Bob → Alice, Carol → Alice, Dave → Alice, Eve → Alice.

- **Voted out:** Alice.
- **Winners:** Village.
- **Players who win:** Bob, Carol, Dave and Eve.

---

## Game 22: Ten players

The largest game. Two Werewolves, a Minion who sees both, two Masons, and three swaps in a row. A tie kills a Werewolf and the Tanner together.

**Players (10):** Alice = Werewolf, Bob = Werewolf, Carol = Minion, Dave = Mason, Eve = Mason, Frank = Seer, Grace = Robber, Heidi = Troublemaker, Ivan = Drunk, Judy = Insomniac

**Center:** Hunter, Tanner, Villager

### Night

1. **Werewolves.** Alice and Bob wake and see each other. With more than one awake, nobody looks at the center.
2. **Minion.** Carol is shown the Werewolves: Alice and Bob.
3. **Masons.** Dave and Eve wake and see each other.
4. **Seer.** Frank looks at Judy's card and sees Insomniac.
5. **Robber.** Grace swaps cards with Alice and sees the card they took: Werewolf.
6. **Troublemaker.** Heidi swaps Judy's and Bob's cards. Nobody is shown anything.
7. **Drunk.** Ivan swaps their card with center card 2 without seeing it.
8. **Insomniac.** Judy looks at their own card: Werewolf.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Werewolf | **Robber** | Village |
| Bob | Werewolf | **Insomniac** | Village |
| Carol | Minion | Minion | Werewolf |
| Dave | Mason | Mason | Village |
| Eve | Mason | Mason | Village |
| Frank | Seer | Seer | Village |
| Grace | Robber | **Werewolf** | Werewolf |
| Heidi | Troublemaker | Troublemaker | Village |
| Ivan | Drunk | **Tanner** | Tanner (own team) |
| Judy | Insomniac | **Werewolf** | Werewolf |

Center at dawn: Hunter, Drunk, Villager

### Vote and result

Votes: Alice → Grace, Dave → Grace, Eve → Grace, Frank → Grace, Bob → Ivan, Carol → Ivan, Heidi → Ivan, Judy → Ivan, Grace → Alice, Ivan → Alice.

- **Voted out:** Grace and Ivan (tied).
- **Winners:** Tanner and Village.
- **Players who win:** Alice, Bob, Dave, Eve, Frank, Heidi and Ivan.

---

## Game 23: Open ruling: only the Tanner dies, no Werewolf at the table, a Minion is

Records what the code does today in a case the rules leave unclear: the Tanner wins alone and the Minion does not. See the design brief's open questions.

**Players (4):** Alice = Minion, Bob = Tanner, Carol = Seer, Dave = Villager

**Center:** Werewolf, Werewolf, Robber

### Night

1. **Minion.** Alice is shown the Werewolves: nobody.
2. **Seer.** Carol looks at Alice's card and sees Minion.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Minion | Minion | Werewolf |
| Bob | Tanner | Tanner | Tanner (own team) |
| Carol | Seer | Seer | Village |
| Dave | Villager | Villager | Village |

### Vote and result

Votes: Alice → Bob, Bob → Alice, Carol → Bob, Dave → Bob.

- **Voted out:** Bob.
- **Winners:** Tanner.
- **Players who win:** Bob.

---

## The Doppelganger's other copies

Games 4, 7, 9, 18, 19 and 20 cover the Robber, Minion, Werewolf, Hunter and Tanner. These six short games cover the rest. They stop at dawn.

---

## Game D1: Doppelganger copies the Seer

The Doppelganger acts as Seer at once, before anyone else, and sees a card as it was dealt.

**Players (4):** Alice = Doppelganger, Bob = Seer, Carol = Werewolf, Dave = Villager

**Center:** Werewolf, Robber, Drunk

### Night

1. **Doppelganger.** Alice looks at Bob's card, sees Seer, and copies it. Acting at once: Alice (as Seer) looks at Carol's card and sees Werewolf.
2. **Werewolves.** Carol wakes alone. As the lone Werewolf, Carol looks at center card 3 and sees Drunk.
3. **Seer.** Bob looks at center cards 1 and 2 and sees Werewolf and Robber.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Doppelganger | Doppelganger (copied Seer) | Village |
| Bob | Seer | Seer | Village |
| Carol | Werewolf | Werewolf | Werewolf |
| Dave | Villager | Villager | Village |

---

## Game D2: Doppelganger copies the Troublemaker

The Doppelganger swaps two other players at once. The player dealt Werewolf has lost the card but still wakes as the Werewolf; the real Troublemaker then hands the Doppelganger card on.

**Players (5):** Alice = Doppelganger, Bob = Troublemaker, Carol = Werewolf, Dave = Villager, Eve = Seer

**Center:** Werewolf, Robber, Drunk

### Night

1. **Doppelganger.** Alice looks at Bob's card, sees Troublemaker, and copies it. Acting at once: Alice (as Troublemaker) swaps Carol's and Dave's cards. Nobody is shown anything.
2. **Werewolves.** Carol wakes alone. As the lone Werewolf, Carol looks at center card 1 and sees Werewolf.
3. **Seer.** Eve looks at Dave's card and sees Werewolf.
4. **Troublemaker.** Bob swaps Alice's and Eve's cards. Nobody is shown anything.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Doppelganger | **Seer** | Village |
| Bob | Troublemaker | Troublemaker | Village |
| Carol | Werewolf | **Villager** | Village |
| Dave | Villager | **Werewolf** | Werewolf |
| Eve | Seer | **Doppelganger (copied Troublemaker)** | Village |

---

## Game D3: Doppelganger copies the Drunk

The Doppelganger swaps itself into the center at once, so the Doppelganger card is in the center when the lone Werewolf looks there. The real Drunk then picks that same card up.

**Players (4):** Alice = Doppelganger, Bob = Drunk, Carol = Werewolf, Dave = Villager

**Center:** Werewolf, Seer, Robber

### Night

1. **Doppelganger.** Alice looks at Bob's card, sees Drunk, and copies it. Acting at once: Alice (as Drunk) swaps their card with center card 1 without seeing it.
2. **Werewolves.** Carol wakes alone. As the lone Werewolf, Carol looks at center card 1 and sees Doppelganger.
3. **Drunk.** Bob swaps their card with center card 1 without seeing it.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Doppelganger | **Werewolf** | Werewolf |
| Bob | Drunk | **Doppelganger (copied Drunk)** | Village |
| Carol | Werewolf | Werewolf | Werewolf |
| Dave | Villager | Villager | Village |

Center at dawn: Drunk, Seer, Robber

---

## Game D4: Doppelganger copies the Insomniac

The Doppelganger is answered at dawn with the real Insomniac. The Robber took the Doppelganger card in between, so it sees 'Robber'.

**Players (4):** Alice = Doppelganger, Bob = Insomniac, Carol = Robber, Dave = Werewolf

**Center:** Werewolf, Seer, Villager

### Night

1. **Doppelganger.** Alice looks at Bob's card, sees Insomniac, and copies it.
2. **Werewolves.** Dave wakes alone. As the lone Werewolf, Dave looks at center card 2 and sees Seer.
3. **Robber.** Carol swaps cards with Alice and sees the card they took: Doppelganger.
4. **Insomniac.** Bob looks at their own card: Insomniac.
5. **Doppelganger, as Insomniac.** Alice looks at their own card: Robber.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Doppelganger | **Robber** | Village |
| Bob | Insomniac | Insomniac | Village |
| Carol | Robber | **Doppelganger (copied Insomniac)** | Village |
| Dave | Werewolf | Werewolf | Werewolf |

---

## Game D5: Doppelganger copies a Mason

The Doppelganger copies a Mason and the two see each other, even though the second Mason card is in the center.

**Players (4):** Alice = Doppelganger, Bob = Mason, Carol = Werewolf, Dave = Villager

**Center:** Mason, Seer, Werewolf

### Night

1. **Doppelganger.** Alice looks at Bob's card, sees Mason, and copies it.
2. **Werewolves.** Carol wakes alone. As the lone Werewolf, Carol looks at center card 1 and sees Mason.
3. **Masons.** Alice and Bob wake and see each other.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Doppelganger | Doppelganger (copied Mason) | Village |
| Bob | Mason | Mason | Village |
| Carol | Werewolf | Werewolf | Werewolf |
| Dave | Villager | Villager | Village |

---

## Game D6: Doppelganger copies a Villager

Nothing further happens. Listed so that every card the Doppelganger can copy has a game.

**Players (4):** Alice = Doppelganger, Bob = Villager, Carol = Werewolf, Dave = Seer

**Center:** Werewolf, Robber, Drunk

### Night

1. **Doppelganger.** Alice looks at Bob's card, sees Villager, and copies it.
2. **Werewolves.** Carol wakes alone. As the lone Werewolf, Carol looks at center card 2 and sees Robber.
3. **Seer.** Dave looks at Alice's card and sees Doppelganger.

### Cards at dawn

| Player | Dealt | Holds at dawn | Team |
|---|---|---|---|
| Alice | Doppelganger | Doppelganger (copied Villager) | Village |
| Bob | Villager | Villager | Village |
| Carol | Werewolf | Werewolf | Werewolf |
| Dave | Seer | Seer | Village |

---

## What the games cover

| Covered | Games |
|---|---|
| Lone Werewolf looks at the center / declines | 1, 3, 4, 5, 8 / 2 |
| Two Werewolves see each other | 10, 22 |
| Minion sees Werewolves / sees none | 9, 15, 22 / 6, 16, 23 |
| Masons: a pair / alone | 10, 22 / 6 |
| Seer: a player / two center cards | 1, 3 / 2, 13 |
| Seer's information goes stale | 3, 8 |
| Robber | 1, 3, 4, 9, 12, 22 |
| Troublemaker | 3, 6, 11, 12, 22 |
| Drunk | 8, 12, 22 |
| Insomniac: unchanged / changed | 8, 18 / 11, 22 |
| Robber, Troublemaker and Drunk on the same cards | 12, 22 |
| A player wins or loses without knowing their card moved | 6, 8, 11, 12 |
| Doppelganger copies: Robber, Minion, Werewolf, Hunter, Tanner | 4 and 9, 7, 18, 19, 20 |
| Doppelganger copies: Seer, Troublemaker, Drunk, Insomniac, Mason, Villager | D1 to D6 |
| Nobody dies | 2, 13 |
| Two-way tie / three-way tie | 17, 22 / 9 |
| Hunter takes someone with them / Hunter power does not chain | 5 / 19 |
| Tanner wins alone / with the village | 5, 20 / 9, 22 |
| No Werewolf at the table: nobody dies / a villager dies with no Minion / only the Minion dies / Minion wins | 13 / 14 / 16 / 6 |
| Minion dies, Werewolf team still wins | 15 |
| Nobody acts at night | 21 |
| 3 players / 10 players | 13 / 22 |

### No game yet

- **A phone drops mid-game.** The earlier game for this assumed pause rules that have since changed. It needs writing once the new rules (grace period, continue without a player) are built.
- **A Hunter whose target is already dying in the same tie.** No extra effect by the rules; not yet traced.
- **Only the Tanner dies with no Werewolf at the table and a Minion present.** Game 23 records today's behaviour. The ruling is still open.
