# Agent ledger

One row per finished piece, from the completion notice (agent type, model, tool calls, tokens).
Newest last. Calls past about 150 or a big token count are the signal to cut the next piece smaller.

| Date | Piece | Agent type | Model | Calls | Tokens | Note |
|---|---|---|---|---|---|---|
| 22 Nov 2026 | loading states | builder | sonnet | 603 | ~306M read | baseline |
| 22 Nov 2026 | polish pass 2 | builder | sonnet | 484 | ~244M read | baseline |
| 22 Nov 2026 | scan and join links | builder | sonnet | 289 | ~108M read | baseline |
| 22 Nov 2026 | vote lock (pass 4a) | builder | sonnet | 121 | 235k | first builder briefed under the lean rules |
| 22 Nov 2026 | vote lock (pass 4a) fixes | builder | sonnet | 68 | 154k | |
| 22 Nov 2026 | the count (pass 4b) | builder | sonnet | 77 | 174k | |
| 22 Nov 2026 | the count (pass 4b) fixes | builder | sonnet | 44 | 100k | |
