# Haiku trial

Purpose: find out what haiku workers can be trusted with. Haiku is allowed as a worker model on
trial; until this page says otherwise, use it only where something else checks the result.

The owner, 22 Nov 2026: "Test to see what you can trust haiku for. Haiku will go a long way and
it's faster."

The coordinator fills in the table after each trial task, against a known answer.

## Results, 22 Nov 2026

| task kind | example | result (pass/fail vs a known answer) | trust? |
| --- | --- | --- | --- |
| Lookup in the code, with evidence | Which checks the commit gate runs for `.github/`; the phase cross-fade duration; the debug toolbar default | Pass, 3 of 3, file and line right; also noticed a stale comment. 19 s | Yes |
| Run the checks, prove a failure's cause | `just check` and `just test`; one known failure | Pass: found the failing test and proved the cause to the line; made no changes. 4 min (the suite) | Yes |
| Fact-check a doc against the code | 41 claims in `docs/design/feel.md` | Pass: 37 true, 2 false, 2 "cannot tell", all four confirmed when followed up. 2 min | Yes |
| Judge a screen picture | The night board golden | Agreed with the earlier review on the main weaknesses and added sound points. Not checked claim by claim | As a second opinion, not the only one |
| Write an issue from given facts | Issue #29 | Pass: house style, checked for duplicates, added nothing. 17 s | Yes |
| Bookkeeping across the board and the tracker | Filing seven owner answers: 14 board writes, 2 issues, 3 comments, 1 body edit | Pass by its report; said what it had not done. 47 s | Yes, from an exact brief |
| An exact edit to docs | The owner's board page; four corrections to the feel page | Pass. When the link check refused the commit it stopped and asked instead of forcing it | Yes |
| A small build with tests | Issue #29: one helper for every repo-scanning test, six scanners moved, seven tests | Sound, and it found every scanner. The reviewer found one real gap (new, not yet added files were skipped), which haiku had itself flagged as unsure, and one leftover (`__pycache__`). Fixed on request. 24 min, then 11 min | Yes, with a reviewer; not for the server, the game's rules or anything players see |

## What this means

- Give haiku: lookups, running checks and reporting, fact-checks, write-ups and bookkeeping from
  given facts, exact edits. These need no second worker, only the usual checks.
- Haiku may build a small, well-specified fix when a reviewer follows. It is not faster than
  sonnet there: the speed is in the small jobs.
- It says when it is unsure and stops when blocked. Read the "unsure" line of its report: both
  times it pointed at the real problem.
- Not yet tried: design, anything visible to players, server or game-rule changes, work with a
  loose brief. Until tried, those stay with sonnet or opus.
