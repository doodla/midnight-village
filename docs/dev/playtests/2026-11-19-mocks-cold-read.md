# Cold-read playtest of the mocks (19 November 2026)

Five simulated first-time users were shown only the mock pictures (`docs/design/mocks/`), one at
a time, in game order, with no rules, brief or code. Each said what they thought the screen was,
where their finger would go first, and what they read. This is the method to repeat on the real
screens (`just screens`) as each is rebuilt; see "How to rerun".

Participants: **Sam** (34, never played a hidden-role game), **Priya** (27, plays the card game a
lot, hates tutorials), **Margaret** (62, reading glasses, afraid of pressing the wrong thing),
**Leo** (15, never reads, taps the brightest thing), **Dan** (41, first-time host, table watching).

## What worked (keep)

- "Hold to flip" on a face-down card with a thumbprint (07): 5/5 understood, highest confidence.
- A primary button that names the action and the person: "Look at Cleo's card", "Lock in Cleo".
- Big serif headlines with one idea: "The village sleeps", "Who dies today?", "Dev dies."
- The big clocks and the big table code.
- The night timeline diagram, for the experienced player only (settles arguments).

## Findings, ranked by how many participants hit them

| # | Finding | Who | Screens |
|---|---|---|---|
| 1 | **The count and the results contradict each other.** "Dev dies. Dev was the Werewolf." then "The Werewolf wins", Cleo dead as Robber. Partly a mock data error, but also real: nobody had learned that cards move in the night, so "who is the Werewolf" is ambiguous. | 5/5 | 10, 11 |
| 2 | **A pre-selected player** (Cleo) on the night action and the vote reads as "the app chose for me"; Leo spent his action and his vote on the default. | 5/5 | 06, 09 |
| 3 | **"Holding. Let go and the card turns face down."** The card arrives face up; nobody was shown a hold. "What am I holding?" | 5/5 | 04 |
| 4 | **The thing to do is not the brightest thing** on 6 of 10 player screens: Start a table (for a guest), Deal the cards (before everyone is in), I know my card (before reading it), Done (before holding), I'm ready to vote (before talking). Leo tapped Done before looking and wasted his night action: not recoverable. | Leo, Margaret, Sam | 01, 02, 04, 07, 08 |
| 5 | **The red X on the picked name** reads as "remove", not "condemned". | 4/5 | 09 |
| 6 | **"Waiting for Dev to reconnect"**: alarming, technical, tiny, and tells the table whose phone dropped. The host has no visible way to carry on. | 5/5 | 05 |
| 7 | **"Tap the cards while you wait"**: unclear whether it is the real action, whether it is safe, why. | 4/5 | 05 |
| 8 | **The prefilled name "Ana"** is taken for someone else's name. | 5/5 | 01 |
| 9 | **Tokens with no names** (ready pips, voters in the count) cannot be read; and with tokens they show WHO is slow. | 5/5 | 04, 07, 08, 09, 10 |
| 10 | **"8 cards" for 5 players, "x2", "Change"**: nobody knows cards = players + 3. The host is asked for deck and pace decisions he cannot judge. "Double" means nothing. | Dan, Sam, Margaret, Leo | 02, 03 |
| 11 | **How to pick two center cards** is only in the headline sentence, which three people skipped. | 4/5 | 06 |
| 12 | **Small grey text is not read or not readable**: footer lines, labels like LEFT TO TALK, ACCUSED / VOTED BY, CENTER, n of 5. | 5/5 | most |
| 13 | **Nothing teaches the goal**: which team am I on, what wins, may I lie, who does a vote kill. The host says it all out loud. | Sam, Margaret, Leo, Dan | 04, 08, 09 |
| 14 | **A parked thumb is a tell** (hold to flip at night, hold "My night" in the talk); the acting player's night screen looks different from a sleeper's; a huge role name is readable from the side. | Priya | 04, 06, 07, 08 |
| 15 | **Reading a six-character code aloud** stalls the table (Q vs 4); no link or QR. | Dan | 02 |
| 16 | **"Do nothing tonight"** sits directly under the primary button (thumb slip) and "Take out of deck" beside "Close". | Margaret, Dan | 06, 03b |
| 17 | **Lock in / Deal the cards sound permanent** and nothing says whether they are. An 18-second vote after a 5-minute talk is a shock. | Margaret, Dan | 02, 09 |
| 18 | **The primary button changes colour** between night (amber) and day (ink): reads as a different kind of button. | Margaret | 08-10 |
| 19 | **The talk is four minutes with nothing on the phone**; Leo taps "I'm ready to vote" to make it end. | Leo | 08 |

## How to rerun

1. `just screens` (and `just screens 390 report nightPrint`).
2. Copy the PNGs for one player's journey, in game order, to an empty folder under neutral names
   (`screen-01.png` ...) so file names give nothing away.
3. Give each participant only those files and the persona brief; one screen at a time; ask: what is
   this, where does your finger go first (tap, hold, wait), confidence 1-5, what did you read and
   skip, what do you expect next. No rules, no brief, no code.
4. A screen passes when at least 4 of 5 name the right first action with confidence 4 or more and
   nobody makes an unrecoverable mistake.
