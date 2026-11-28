---
name: correct
description: Turn a mistake that happened here (a review's must-fix, a red GitHub run after a READY hand-over, an owner hit, a bug-fix commit) into a check that would have caught it, or say that no honest check exists.
---

# Correct

Input: one mistake that happened, with its evidence: a review file, a red run, a line of
`docs/dev/owner-feedback.md`, a fix commit. Not one that might happen. Decide alone; ask no one.

1. **Name the promise it broke**, in one sentence, not the instance: "a recipe name means one
   thing in every folder", not "`cd frontend && just test` ran the backend's tests". Say who is
   hurt when it breaks: a player, the owner, a builder.
2. **Look for the guard that should have caught it**: `just prove-guards --list` (each
   promise and the tests that kill its breaks), the tests beside the code. If one covers
   the promise and missed, widen its cases rather than add a second check.
3. **Make it impossible first, if you can**: one owner for the state, one way to do the task,
   a type that cannot hold the bad value, the old way deleted. Else **write the check** to
   `docs/claude-architecture.md`, "Adding a check":
   - it tests the promise, so the next case of the class fails too, not only this one;
   - it takes its cases from the code or a registry (a justfile, the screen table, the agent
     definitions), never from a list someone keeps;
   - it has no list of exceptions that can grow;
   - it fails with `file:line: what is wrong. Fix: <command or edit>`;
   - it runs where the mistake is made (the commit gate for seconds, a test for the rest),
     and GitHub runs it too. A test that holds a rule for the whole app carries `Guard file`.
4. **Prove it on the original mistake.** Bring the mistake back (revert the fix, or the
   smallest edit that re-creates it), see the check fail with its message, undo, see it pass.
   It passes on today's tree with no exception, or it tests the wrong promise.
   Record it as a break, run by `just prove-guards`: the mistake, its promise, the test that
   must fail (`tool/breaks_tools.py`, `tool/breaks_server.py`, `tool/breaks_app.py`).
5. **Delete the prose the check replaces** in the same change: the line in a `CLAUDE.md`, an
   agent definition, a README, a "do not" comment. Prose stays only where judgment is needed.
6. **If no honest check is possible, say so and stop.** A check that tests the shape of the
   last bug, needs a growing list, or passes while the promise breaks costs every agent and
   catches nothing: none is better than a weak one. Leave the prose; name the higher fix.

Reply in five lines:

```text
promise: <one sentence; who is hurt>
check: <path>, reads <its cases from>, says "<its message>"
the break that proves it: <command> fails with "<output>"
prose deleted: <file:line, or none and why>
what it cannot catch: <the cases left, plainly>
```
