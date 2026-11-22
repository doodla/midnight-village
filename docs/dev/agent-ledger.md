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
| 22 Nov 2026 | card flip (pass 3) | frontend-developer | sonnet | 93 | 279k (notice) | briefed before the lean rules; fixes by fresh helpers: 16 and 7 calls |
