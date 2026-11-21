# Night protocol 2: a TLA+ model of one game

> These models predate the protocol-1 cleanup (20 November 2026): they speak of "protocol 2", the contract's "Third amendment" (now `docs/specs/onuw/api-contract-v2.md`, sections 5 and 9), `ProtocolTwoGameNotifier` (now `LiveGameNotifier`), the server module night2 (now `apps/onuw/choose_night.py`) and sample names ending in `_v2` (now plain names); the one flow they model is the only one left.

A model of a protocol-2 game from the deal (look stage) to the results, written from the
code, and checked with TLC. It found the Doppelganger resend bug fixed in commit
`fb229fb` (`fix(onuw): a resent choose is answered, never read as the next one`; see "The
finding").
Kept here so the next person can extend it instead of starting again.

## Files

| File | What it is |
|---|---|
| `Night2.tla` | The model. The header comment says what each part was modelled from. |
| `Night2.cfg` | The run that found the bug: every invariant, both temporal properties, `VIEW NormView`. |
| `rest.cfg` | The same without the two invariants about the bug, to see whether everything else holds. |
| `view.mjs` | The reader's words for the chart: a name for each state and arrow. |
| `bug-chart.mmd` | Mermaid state chart of the bug paths (the full graph is too big to draw). |
| `bug-report.md` | The shortest paths to each broken invariant, in those words. |
| `rest-report.md` | The `rest.cfg` run: which rules held, which were not checked and why. |

The tool that turned TLC's output into the chart and the reports is not in the repository,
nor is TLC (`tla2tools.jar`).

## What it models

Three phones: `d` the Doppelganger, `r` the Robber (also the host), `v` a Villager (the
phone that can drop). At the granularity the code really has:

- every request handler is ONE atomic step under the Game row lock, and `require_stage`
  refuses any token but the current one, storing nothing, so only requests that name the
  current stage are steps;
- timer `schedule` / `cancel` run AFTER commit (`on_commit`): a pending batch applied by a
  later step, in any order with other batches;
- `timers.fire` locks the row, checks its token, deletes it and runs the job in that
  transaction, so a firing is "a row exists" (late, duplicate and stale deliveries are
  no-ops);
- `GET /me/` reads the Game unlocked, then `ensure_timers` schedules from that snapshot when
  the key's row is missing: two steps;
- `v` drops, its grace period runs out (`Tick`) and it comes back;
- the clock is abstracted: "has the minimum length passed?" and "has the deadline passed
  when a deferred close fires?" are free choices.

The Doppelganger's phone can send her look, resend the look ONCE as if its answer was lost
(`retried`), and send her follow-up (rob `v`). Rules checked: `ChooseLimit`,
`AppliedAtMostOnce`, `AppliedExactlyOnce`, `LockedVoteKept`, `FollowUpFromFollowUpRequest`
(the follow-up applied came from her follow-up request), `FollowUpNotRefused`, and the
temporal `PhaseForward` and `ReachesResults`. `VIEW NormView` treats timer rows and pending
ops for a stage the game has passed as equal (they can only fire as no-ops).

## What it does not model

- Roles other than these three, the picks' meaning (`engine/choose.py`), card movements and
  the win: it counts how many times each action is applied and where it came from.
- Resends of anything but her look (the tests in `backend/tests/onuw/test_resend.py` cover
  every request type, including a seeded whole game with every request sent twice).
- The `chosen` echo that fixed the bug: the model is the code as it was BEFORE the fix. To
  check the fix, add the request's `chosen` to `Choose` (a resend carries the count it was
  sent with; `n > that` = no-op) and re-run `Night2.cfg`: both bug invariants should hold.
- Several workers' timing beyond what the locks allow, the queue backend's retries, the
  sweep, host handover, play again, more than one dropped phone.
- Liveness under the abstracted clock is only as good as the fairness in `Spec`.

## How it was run

TLC 2.19 (08 August 2024), Java 21, one worker, breadth-first, through a wrapper that
also drew the chart and wrote the reports. The plain equivalent:

```bash
java -cp tla2tools.jar tlc2.TLC -config Night2.cfg Night2.tla
java -cp tla2tools.jar tlc2.TLC -config rest.cfg Night2.tla
```

`MaxPending == 2` bounds the after-commit batches not yet applied. The `Night2.cfg` run
stops at the first violation (about a minute). The `rest.cfg` run explored 2,533,694
states with `ChooseLimit`, `AppliedAtMostOnce`, `AppliedExactlyOnce`, `LockedVoteKept` and
no deadlock holding, then TLC failed writing its state queue to disk before checking the
two temporal properties (a TLC error, `rest-report.md`), so `PhaseForward` and
`ReachesResults` are NOT verified.

## The finding

Shortest path (4 steps): the look stage ends, window 1 opens; she looks at the Robber
(copies him); the answer is lost and her phone sends the same body again with the same
stage token; the server counted it as her SECOND choose and read it as the Robber's action:
she robbed the player she had looked at. Her real follow-up was then refused
`409 already_chosen`, and window 1 closed applying the resend's swap. Both
`FollowUpFromFollowUpRequest` and `FollowUpNotRefused` break. A test reproduced it against
the real code (now `TestTheDoppelgangersResentLook` in
`backend/tests/onuw/test_resend.py`).

The fix is general, not a Doppelganger case: every `choose` carries `chosen`, the count of
the prompt it answers; under the Game lock a lower count than the stored one is a resend
(the same `200`, nothing stored). The other protocol-2 requests were checked for the same
class of bug: `docs/specs/onuw/api-contract-v2.md`, "Third amendment".
