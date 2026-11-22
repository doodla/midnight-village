# Running the work

For the session that talks to the owner and hands work out. Someone given one piece of work
does that piece and reports; the rest of this page is not theirs to do.

## The shape of a piece

1. One builder, in its own worktree with its own `DB_NAME`, gets a brief with the owner's words
   in it and builds one finished piece. It commits in small steps that each pass the checks.
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
  and every check required on main. Not on until the owner imports it (`docs/claude-architecture.md`,
  "GitHub: the wall"); until then the rule is ours to keep.
- Add, rename or remove a check: change the job and `docs/dev/main-ruleset.json` in the same
  commit (a test fails until they match), then the owner imports the file again.

One heavy piece at a time: every worker shares this one machine. No extra cloud sessions.
Step back often and look at the whole game, not the last report.

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

## Outside this repository

- Fetch and merge before pushing: the deployment session pushes to the same branch. After
  pushing anything that changes the server, tell it (its id is in `docs/dev/status.md`).
- Never open or read https://github.com/mankidev/antialgorithm in this session. A worker may,
  and must not reproduce it in its report.

## The owner

What needs the owner's eyes or a decision goes on the owner's board, never in an issue or pull request alone: `docs/dev/owner-board.md`.

Their reports from the live app, in their words, and what is in flight:
`docs/dev/owner-feedback.md`. Keep it current: it is what a new session starts from.
