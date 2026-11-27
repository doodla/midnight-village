# Running the work

For the session that talks to the owner and hands work out. Someone given one piece of work
does that piece and reports; the rest of this page is not theirs to do.

## The shape of a piece

GitHub Issues is the tracker: one issue for a piece, one pull request for an issue, and the pull
request's description says "Closes #N" so the issue closes when it merges. `docs/dev/status.md`
links to the issues and repeats nothing from them. What needs the owner's eyes or a decision
goes on the owner's board (`docs/dev/owner-board.md`), never in an issue alone.

1. One builder, in its own worktree with its own `DB_NAME`, gets a brief and builds one
   finished piece. The brief says `just brief <screen>` (or, for work that is not a screen,
   `just brief <area>`: `just brief` alone lists them) and the task: that command prints the
   spec's section and the owner's words about the screen as they are written, with its
   states, files, tests and who else is in them, so nothing is paraphrased from memory. It
   commits in small steps that each pass the checks.
   A builder hands over with `just handover <file>` and in no other way: it refuses work
   that is not committed, pushed and mergeable with main, runs the checks the change
   reaches, draws every screen state it reaches beside main at 412x915 and 360x640, and
   writes the hand-over file (checks with their results, the changed states, the guard
   lines, the words that changed, the spec touched or not). The reader starts from that
   file and its contact sheets, not from the builder's summary.
2. One fresh reviewer, not given the builder's conclusions, reads the change and looks at the
   pictures. The builder fixes what it found; this session checks the fixes against the list.
   A second review only for a serious finding in the server or the game's rules.
3. Anything visible goes to the owner as before and after pictures before it merges.
4. The piece becomes its own pull request and is merged when its checks are green. The owner
   has asked for this as the standing way of working. Nothing unfinished merges; no giant
   changes.
   A pull request is squash-merged (the owner's preference): its title is in the commit style
   `type(scope): description` and its body summarises the piece. After a squash, main holds
   one new commit that is not the builder's: a builder never continues on a branch whose pull
   request was squashed. The coordinator starts the next piece's branch from main.

## The wall is GitHub

The commit gate on a builder's machine runs only what takes seconds (format, lint, types,
analyze, the hook tests). Every other check runs on GitHub, on every pull request: backend
`just check` and `just test` (coverage floor, contract samples current, migrations),
frontend analyze and format, generated code current, widget, golden and web integration
tests, every screen strict at 360 and 390, the release build without the debug toolbar, and
the end-to-end harness.

- A piece merges only when every GitHub check on its head commit is green. Nobody merges on
  red, or while a check is still running.
- A red check is read, not re-run: find the cause (the job's log, the uploaded pictures) and
  fix it. A job is re-run at most once, and only after saying why it is believed flaky; a
  second red is a cause to find.
- To know before you push: `just gate-full` runs the local part (backend, frontend, hook
  tests, generated code, screens) in parallel, in minutes. It skips the browser, build and
  harness jobs, which only GitHub runs.
- The ruleset `docs/dev/main-ruleset.json` is the wall: it makes a squash-merged pull request
  and every check required on main. It is on (`docs/claude-architecture.md`, "GitHub: the wall").
- Add, rename or remove a check: change the job and `docs/dev/main-ruleset.json` in the same
  commit (a test fails until they match), then the owner imports the file again.

Heavy work shares the machine, so it goes through one queue (next section). Two sessions run
the work (23 November 2026): the coordinating one (design and the app) and the codebase health
one (checks, hooks, setup, docs, the server queue); each has its own machine and its own
branch, and they talk through the remote `send_message` tool. No other cloud sessions.
Step back often and look at the whole game, not the last report.

## Waiting, and the heavy queue

**The waiting rule.** A command that may take more than two minutes (a test suite, a build,
`just screens`, `just phone-frames`, `just handover`): start it once with `run_in_background`,
end your turn, you are woken about two seconds after it exits. Never poll with a sleep loop
(`until ...; do sleep`, `while ...; sleep` around `pgrep` or a log). One helper spent 47 of 97
steps that way. A hook refuses such a command and says this (`.claude/hooks/poll_guard.py`); `just brief`
prints the rule too.

**The queue.** Every heavy command goes through `tool/heavy.py` (`just heavy <command...>`), and the
heavy recipes use it themselves (tests, builds, screens, the harness, phone-frames and
phone-timing, `just piece-check` and `just handover` for each heavy step), so nobody has to remember it.
It lets 3 jobs run at once; the rest wait in order and say where they stand at once and every 30 seconds.

- `just heavy --status`: who holds a slot, since when, who waits, and the last runs with their peak memory.
- A command inside a heavy command runs at once (a recipe calling a recipe); on GitHub nothing queues.
- A command never holds a slot after it ends: the lock is not inherited by any child, it is released on any exit
  (`kill -9` too, which also kills the command), and what the command left running is stopped, and said.
- `HEAVY_SLOTS=n` overrides the count; the state is in `/tmp/midnight-village-heavy`, shared by every checkout.

**Why 3** (measured 27 Nov 2026 on this machine: 15 GB, 4 cores; peak memory is the sum over every
process of the job, shared pages counted once; Postgres is not in it, it is small):

| Job | Time alone | Peak memory |
|---|---|---|
| backend `just test` (all cores) | 4 min 48 s | 0.8 GB |
| frontend `just test` (the whole suite) | 8 min 27 s | 2.1 GB |
| `flutter build web --release` | 49 s | 2.5 GB |
| `just screens 390 strict` | 1 min 30 s | 3.2 GB |
| `just phone-frames` (build, backend, Chrome, 3 bots) | 11 min 48 s | 2.6 GB |

The worst is 3.2 GB; with a job counted at 4 GB and 3 GB left for the system and Postgres,
(15.7 - 3) / 4 gives 3. The count follows the memory the machine has (`tool/heavy.py`), never below 1.
Five Flutter builds at once restarted the machine; three use under 10 GB. The cores are the other limit:
Flutter tests use all four, so three at once each take longer than alone.
Re-measure when the machine changes: `just heavy --status` shows each run's time and peak.

## Who does what

A hook refuses any worker that is not on an allowed model with an effort set
(`.claude/guardrails/config.toml` holds the list; `docs/claude-architecture.md` describes it).

- Only `opus`, `sonnet` or `haiku`. Never this session's own model, never a fork (a fork
  inherits this session's model): start a fresh worker with the context in its brief.
- Haiku is allowed on trial at the owner's request (22 Nov 2026: "Haiku will go a long way and
  it's faster"), for now only for work whose result is checked by something else (a test, a
  check script, or a reviewer).
- What haiku can be trusted with: `docs/dev/haiku-trial.md`.
- Opus for design-heavy or tricky work and for reviews. Sonnet for well-specified work and
  lookups.
- Effort: `low` for lookups, `medium` for routine edits, `high` for design and review.

- A change to words or screens runs `just test-harness` before its pull request: the commit
  gate skips it (too slow) and GitHub's "End-to-end Harness" job runs it after.

## Lean helpers

Measured on 22 Nov 2026 from the transcripts: an agent defined with all tools starts at about
78k tokens of context, one with `tools: Read, Grep, Glob, Bash` at 7-10k (the difference is
tool descriptions from connectors a builder never uses). Builders opened 625 screenshots one
by one, 96% of all tool-result bytes, and a picture read once is re-read on every later call.
Three builders made 300-600 calls each because one agent was resumed for every fix and every
"merge main". So:

- A fresh agent for each step (build, fix, merge main), with a short note of where things stand;
  never one resumed builder.
- Size a piece to finish within about 150 calls. A builder that nears that hands back with a note of what is left.
- Builders do not open screenshots one by one: they hand the PNGs to `eyes` or view one
  `just contact-sheet` (in `frontend/`).
- Small jobs (a lookup, running checks, a fact-check, bookkeeping, an exact edit) go to `worker`.
- A brief points at files and stays short; it does not paste them.
- This session still judges the screens by eye, as before and after pictures.
- Log each finished piece in `docs/dev/agent-ledger.md` so these numbers keep being measured.

## The two critics

Every piece a player can see, and every mock, goes to both critics as pictures (a contact sheet
first) before it goes to the owner's board: `critic-editor` (what to cut or merge) and
`critic-art-director` (type, hierarchy, density, consistency). Their top issues are fixed or
answered in one line each. They do not replace the code reviewer.

The blind test that chose them (23 Nov 2026): six personas critiqued the live game's screens
and were scored against the owner's own 15 points. Scores were close: 0.61 to 0.44 weighted
recall on 9 points, one grader, and the walk-through mixed several games. The editor was the
only one to catch the merge of count and results; the art director read stills best.
The next test must fix: one clean recorded game, the missing states rendered, three runs each,
two graders, scored against the owner's next play-through. Method and brief:
`docs/dev/critic-test/`.

## Outside this repository

- Never open or read https://github.com/mankidev/antialgorithm in this session. A worker may,
  and must not reproduce it in its report.

## The owner

What needs the owner's eyes or a decision goes on the owner's board, never in an issue or pull request alone: `docs/dev/owner-board.md`.

Their reports from the live app, in their words, and what is in flight:
`docs/dev/owner-feedback.md`. Keep it current: it is what a new session starts from.
