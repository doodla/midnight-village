# Agent ledger

One row per finished piece, from the completion notice (agent type, model, tool calls, tokens).
Newest last. Calls past about 150 or a big token count are the signal to cut the next piece smaller.

| Date | Piece | Agent type | Model | Calls | Tokens | Note |
|---|---|---|---|---|---|---|
| 22 Nov 2026 | loading states | builder | sonnet | 603 | ~306M read | baseline |
| 22 Nov 2026 | polish pass 2 | builder | sonnet | 484 | ~244M read | baseline |
| 22 Nov 2026 | scan and join links | builder | sonnet | 289 | ~108M read | baseline |
| 22 Nov 2026 | back swipe and card hold | builder | not kept | n/a | n/a | before the ledger; figures not kept |
| 22 Nov 2026 | speed: fewer round trips, faster first load | builder | not kept | 298 | 373k (notice) | before lean rules; one agent for both parts, too big: split next time |
| 22 Nov 2026 | speed review | reviewer | not kept | n/a | n/a | before the ledger; figures not kept |
| 22 Nov 2026 | speed: requests on open (found already done) | frontend-developer | opus | 11 | 103k (notice) | lean brief; checked main first, no code needed |
| 22 Nov 2026 | vote lock (pass 4a) | builder | sonnet | 121 | 235k | first builder briefed under the lean rules |
| 22 Nov 2026 | vote lock (pass 4a) fixes | builder | sonnet | 68 | 154k | |
| 22 Nov 2026 | the count (pass 4b) | builder | sonnet | 77 | 174k | |
| 22 Nov 2026 | the count (pass 4b) fixes | builder | sonnet | 44 | 100k | |
| 22 Nov 2026 | card flip (pass 3) | frontend-developer | sonnet | 93 | 279k (notice) | briefed before the lean rules; fixes by fresh helpers: 16 and 7 calls |
| 22 Nov 2026 | same-address API trial | frontend-developer | opus | 35 | 71k (notice) | lean brief, one step |
| 23 Nov 2026 | deck dead end | frontend-developer | sonnet | builder 139 calls 266k tokens; review fixes 145 calls 255k | too big for one piece: should have been split in two |
| 23 Nov 2026 | paper on three screens | frontend-developer | sonnet | 150 | 267k | builder |
| 23 Nov 2026 | paper foundation (dress and parts) | frontend-developer | sonnet | 170 | 354k | too big: split foundation from fixes next time |
